import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/screens/alarm_ring_screen.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/core/services/guardian_service.dart';
import 'package:alarm_plus/core/services/streak_reminder_service.dart';
import 'package:alarm_plus/core/services/widget_sync_service.dart';
import 'package:alarm_plus/shared/models/vibration_pattern_type.dart';
import 'package:alarm_plus/core/services/live_timer_notification_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Whether another snooze should be allowed. [maxSnoozes] of 0 means
/// unlimited. Kept as a pure function — free of Hive/plugins/statics — so
/// the cap itself is directly testable rather than only reachable through
/// [AlarmRingFlow.snoozeAlarm]'s full native-dependent call chain.
bool canSnoozeAgain({required int used, required int maxSnoozes}) {
  return maxSnoozes <= 0 || used < maxSnoozes;
}

class AlarmRingFlow {
  static StreamSubscription<dynamic>? _ringSubscription;
  static StreamSubscription<int>? _ringIntentSubscription;
  static bool _ringScreenVisible = false;
  static final Set<int> _knownRingingIds = <int>{};
  static final Map<int, Timer> _missedRecoveryTimers = <int, Timer>{};
  static int _currentRingingId = 0;

  /// The alarm currently ringing, or 0 when none is.
  static int get currentRingingId => _currentRingingId;

  /// Times this alarm has been snoozed in the current ring session.
  static int snoozeCountFor(int alarmId) => _snoozeSessionCount[alarmId] ?? 0;

  // Tracks alarms that were snoozed before being stopped (for XP calculation)
  static final Set<int> _snoozedIds = <int>{};
  // Tracks snooze count per alarm session for Boss Mode
  static final Map<int, int> _snoozeSessionCount = <int, int>{};

  static const _channel = MethodChannel('alarmplus/alarm_controls');

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Tracks ring start time for Guardian Alert threshold
  static final Map<int, DateTime> _ringStartTimes = <int, DateTime>{};
  static final Map<int, Timer> _guardianTimers = <int, Timer>{};
  // Tracks pending wake-up check timers (notification delay + re-ring timer)
  static final Map<int, Timer> _wakeUpCheckTimers = <int, Timer>{};
  static final Map<int, Timer> _wakeUpReringTimers = <int, Timer>{};

  static Future<void> bindNativeAlarmEvents() async {
    // Register wake-check tap handler to avoid circular import
    AlarmService.registerWakeCheckHandler(cancelWakeUpCheck);

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'snooze') {
        final id = (call.arguments as int?) ?? _currentRingingId;
        if (id > 0) await snoozeAlarm(id);
      } else if (call.method == 'stopFromNotification') {
        final id = (call.arguments as int?) ?? _currentRingingId;
        if (id > 0) await _stopFromNotification(id);
      }
    });

    await _ringSubscription?.cancel();
    _ringSubscription = Alarm.ringing.listen((ringingSet) {
      final ids = ringingSet.alarms.map((alarm) => alarm.id).toSet();
      final newIds = ids.difference(_knownRingingIds);

      for (final id in newIds) {
        onAlarmRing(id);
      }

      _knownRingingIds
        ..clear()
        ..addAll(ids);

      if (ids.isEmpty) {
        _ringScreenVisible = false;
      }
    });

    await _ringIntentSubscription?.cancel();
    _ringIntentSubscription = AlarmService.ringIntents.listen((alarmId) {
      if (alarmId <= 0) {
        return;
      }
      onAlarmRing(alarmId);
    });
  }

  static Future<void> onAlarmRing(int alarmId) async {
    _currentRingingId = alarmId;
    _ringStartTimes[alarmId] = DateTime.now();
    await WakelockPlus.enable();

    // Whatever live nap/focus countdown was showing, this alarm ringing is
    // the terminal event — clear it so a stale notification doesn't linger.
    await LiveTimerNotificationService.cancel();

    // Start foreground service for lock-screen takeover + volume-snooze
    await _startForegroundService(alarmId);

    // Guardian alert: fire webhook after 10 minutes of ignored alarm
    _guardianTimers[alarmId]?.cancel();
    _guardianTimers[alarmId] = Timer(const Duration(minutes: 10), () async {
      final still = await Alarm.isRinging(alarmId).catchError((_) => false);
      if (still) {
        await GuardianService.triggerAlert(alarmId);
      }
    });

    try {
      final pattern =
          AlarmService.findByIntId(alarmId)?.vibrationPattern.pattern ??
              VibrationPatternType.standard.pattern;
      final hasVibrator = pattern.isNotEmpty && await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(pattern: pattern, repeat: 0);
      }
    } catch (_) {
      // Vibration capability differs by device.
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator != null && !_ringScreenVisible) {
      _ringScreenVisible = true;
      navigator.pushNamed(
        AlarmRingScreen.routeName,
        arguments: {'alarmId': alarmId, 'snoozeCount': _snoozeSessionCount[alarmId] ?? 0},
      );
    }

    _missedRecoveryTimers[alarmId]?.cancel();
    _missedRecoveryTimers[alarmId] = Timer(
      const Duration(minutes: 2),
      () async {
        final alarm = AlarmService.findByIntId(alarmId);
        if (alarm == null) {
          return;
        }

        final stillRinging = await Alarm.isRinging(alarmId);
        if (!stillRinging) {
          return;
        }

        await SmartAlarmService.recordMissed();

        final backupTime = DateTime.now().add(const Duration(minutes: 3));
        final backup = alarm.copyWith(
          time: TimeOfDay(hour: backupTime.hour, minute: backupTime.minute),
          tag: 'Recovery backup',
          isEnabled: true,
        );
        await AlarmService.scheduleAlarm(backup);
      },
    );
  }

  /// Snoozes the ringing alarm. Returns false — refusing to snooze — once
  /// the alarm's own [AlarmModel.maxSnoozes] has been reached for this ring
  /// session (0 means unlimited).
  static Future<bool> snoozeAlarm(int alarmId) async {
    final alarm = AlarmService.findByIntId(alarmId);
    if (alarm == null) {
      return false;
    }

    final used = _snoozeSessionCount[alarmId] ?? 0;
    if (!canSnoozeAgain(used: used, maxSnoozes: alarm.maxSnoozes)) {
      return false;
    }

    await AlarmService.cancelAlarm(alarm.id);

    final newTime = DateTime.now().add(Duration(minutes: alarm.snoozeMinutes));
    final updated = alarm.copyWith(
      time: TimeOfDay(hour: newTime.hour, minute: newTime.minute),
      isEnabled: true,
    );

    await AlarmService.scheduleAlarm(updated, persist: false);
    await SmartAlarmService.recordSnoozed();

    // Mark this alarm as having been snoozed before final dismissal
    _snoozedIds.add(alarmId);
    _snoozeSessionCount[alarmId] = (_snoozeSessionCount[alarmId] ?? 0) + 1;

    _guardianTimers[alarmId]?.cancel();
    _guardianTimers.remove(alarmId);
    _ringStartTimes.remove(alarmId);

    await _stopEffects();

    if (_ringScreenVisible) {
      appNavigatorKey.currentState?.pop();
      _ringScreenVisible = false;
    }

    return true;
  }

  /// Stops the alarm and records XP/badges. Does NOT pop the ring screen —
  /// the screen calls [completeRingScreenDismiss] after showing its celebration modal.
  static Future<DismissReward?> stopAlarm(int alarmId) async {
    final alarm = AlarmService.findByIntId(alarmId);
    if (alarm == null) {
      return null;
    }

    await AlarmService.cancelAlarm(alarm.id);

    if (alarm.repeatDays.isNotEmpty) {
      await AlarmService.scheduleAlarm(alarm);
    } else {
      await AlarmService.saveAlarm(alarm.copyWith(isEnabled: false));
    }

    // Determine if user snoozed before finally dismissing
    final hadSnooze = _snoozedIds.remove(alarmId);
    final snoozeCount = _snoozeSessionCount.remove(alarmId) ?? 0;
    final reward = await SmartAlarmService.recordDismissed(hadSnooze: hadSnooze, snoozeCount: snoozeCount);
    unawaited(WidgetSyncService.refresh());
    unawaited(StreakReminderService.refresh());

    _missedRecoveryTimers[alarmId]?.cancel();
    _missedRecoveryTimers.remove(alarmId);
    _guardianTimers[alarmId]?.cancel();
    _guardianTimers.remove(alarmId);
    _ringStartTimes.remove(alarmId);

    // Stop audio/vibration immediately so sound doesn't play during celebration modal
    await _stopEffects();

    // Schedule wake-up check if enabled on this alarm
    if (alarm.wakeUpCheckEnabled) {
      _scheduleWakeUpCheck(alarm, alarmId);
    }

    return reward;
  }

  static void _scheduleWakeUpCheck(AlarmModel alarm, int alarmId) {
    _wakeUpCheckTimers[alarmId]?.cancel();
    final delay = Duration(minutes: alarm.wakeUpCheckMinutes);
    _wakeUpCheckTimers[alarmId] = Timer(delay, () async {
      _wakeUpCheckTimers.remove(alarmId);
      await _fireWakeUpCheckNotification(alarmId, alarm);
    });
  }

  static Future<void> _fireWakeUpCheckNotification(int alarmId, AlarmModel alarm) async {
    const androidDetails = AndroidNotificationDetails(
      'alarm_plus_wakecheck',
      'Wake-Up Check',
      channelDescription: 'Verify you are still awake after dismissing an alarm',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    final checkId = alarmId + 2000000;
    await _notifications.show(
      checkId,
      'Are you awake? 👁️',
      'Tap to confirm you\'re up — ${alarm.label.isEmpty ? "Alarm+" : alarm.label}',
      details,
      payload: 'wakecheck:$alarmId',
    );

    // If not tapped within 60 s, re-ring the alarm
    _wakeUpReringTimers[alarmId]?.cancel();
    _wakeUpReringTimers[alarmId] = Timer(const Duration(seconds: 60), () async {
      _wakeUpReringTimers.remove(alarmId);
      await _notifications.cancel(checkId);
      await AlarmService.scheduleAlarm(
        alarm.copyWith(
          time: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(seconds: 5))),
          isEnabled: true,
        ),
        persist: false,
      );
      debugPrint('Wake-up check failed for ${alarm.id} — re-ringing alarm');
    });
  }

  static void cancelWakeUpCheck(int alarmId) {
    _wakeUpCheckTimers[alarmId]?.cancel();
    _wakeUpCheckTimers.remove(alarmId);
    _wakeUpReringTimers[alarmId]?.cancel();
    _wakeUpReringTimers.remove(alarmId);
    _notifications.cancel(alarmId + 2000000);
  }

  /// Call this after the ring screen celebration modal is dismissed to pop the screen.
  static void completeRingScreenDismiss() {
    appNavigatorKey.currentState?.pop();
    _ringScreenVisible = false;
    _currentRingingId = 0;
  }

  /// Stop button tapped directly on the lock-screen notification.
  /// Silently dismisses — no challenge, no celebration modal.
  static Future<void> _stopFromNotification(int alarmId) async {
    final alarm = AlarmService.findByIntId(alarmId);
    if (alarm == null) return;
    await AlarmService.cancelAlarm(alarm.id);
    if (alarm.repeatDays.isNotEmpty) {
      await AlarmService.scheduleAlarm(alarm);
    } else {
      await AlarmService.saveAlarm(alarm.copyWith(isEnabled: false));
    }
    _snoozedIds.remove(alarmId);
    _snoozeSessionCount.remove(alarmId);
    _missedRecoveryTimers[alarmId]?.cancel();
    _missedRecoveryTimers.remove(alarmId);
    _guardianTimers[alarmId]?.cancel();
    _guardianTimers.remove(alarmId);
    _ringStartTimes.remove(alarmId);
    await SmartAlarmService.recordDismissed(hadSnooze: false, snoozeCount: 0);
    await _stopEffects();
    if (_ringScreenVisible) {
      appNavigatorKey.currentState?.pop();
      _ringScreenVisible = false;
    }
    _currentRingingId = 0;
  }

  static Future<void> _stopEffects() async {
    await Vibration.cancel();
    await WakelockPlus.disable();
    await _stopForegroundService();
  }

  static Future<void> _startForegroundService(int alarmId) async {
    try {
      await _channel.invokeMethod<void>('startAlarmService', {'alarmId': alarmId});
    } catch (e) {
      debugPrint('startAlarmService channel error: $e');
    }
  }

  static Future<void> _stopForegroundService() async {
    try {
      await _channel.invokeMethod<void>('stopAlarmService');
    } catch (e) {
      debugPrint('stopAlarmService channel error: $e');
    }
  }
}
