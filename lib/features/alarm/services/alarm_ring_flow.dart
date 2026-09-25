import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
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

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Whether another snooze should be allowed. [maxSnoozes] of 0 means
/// unlimited. Kept as a pure function — free of Hive/plugins/statics — so
/// the cap itself is directly testable rather than only reachable through
/// [AlarmRingFlow.snoozeAlarm]'s full native-dependent call chain.
bool canSnoozeAgain({required int used, required int maxSnoozes}) {
  return maxSnoozes <= 0 || used < maxSnoozes;
}

/// How long an unattended alarm rings before it is silenced and recorded
/// as missed — Android's own Clock app defaults to 10 minutes; heavy
/// sleepers get longer.
const autoSilenceAfter = Duration(minutes: 30);

/// Notification id for an alarm's wake-up check. Kept apart from the alarm
/// and wind-down ids derived in [AlarmService].
int wakeCheckNotificationId(int alarmId) => alarmId + 2000000;

/// When the wake-up check notification appears and, if it isn't tapped,
/// when the alarm rings again.
({DateTime checkAt, DateTime reringAt}) wakeCheckTimes(
  DateTime dismissedAt,
  int minutes,
) {
  final checkAt = dismissedAt.add(Duration(minutes: minutes));
  return (checkAt: checkAt, reringAt: checkAt.add(const Duration(seconds: 60)));
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

  static Future<void> bindNativeAlarmEvents() async {
    // Register wake-check tap handler to avoid circular import
    AlarmService.registerWakeCheckHandler(cancelWakeUpCheck);

    _channel.setMethodCallHandler((call) async {
      final id = (call.arguments as int?) ?? _currentRingingId;
      if (id <= 0) return;
      if (call.method == 'snooze') {
        // Volume keys and the notification button snooze without looking at
        // the screen, which is exactly what Hardcore mode exists to stop.
        if (AlarmService.findByIntId(id)?.hardcoreMode == true) return;
        await snoozeAlarm(id);
      } else if (call.method == 'stopFromNotification') {
        // Never dismiss from the notification: that skipped every challenge
        // (and still paid out XP). Bring up the ring screen instead.
        await _showRingScreen(id);
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

    // A notification tap that cold-started the app arrived before these
    // listeners existed; replay it now.
    final launch = AlarmService.takeLaunchResponse();
    final payload = launch?.payload?.trim() ?? '';
    if (payload.startsWith('wakecheck:')) {
      final id = int.tryParse(payload.substring('wakecheck:'.length));
      if (id != null) await cancelWakeUpCheck(id);
    } else {
      final id = int.tryParse(payload);
      if (id != null && id > 0 && await Alarm.isRinging(id).catchError((_) => false)) {
        onAlarmRing(id);
      }
    }
  }

  static Future<void> onAlarmRing(int alarmId) async {
    _currentRingingId = alarmId;
    // Keep the *first* ring time of this session, so re-delivered ring
    // events don't push the guardian alert further away.
    _ringStartTimes.putIfAbsent(alarmId, DateTime.now);
    await WakelockPlus.enable();

    // Start foreground service for lock-screen takeover + volume-snooze
    await _startForegroundService(alarmId);

    // Guardian alert: fire webhook after 10 minutes of ignored alarm,
    // counted from the first ring (not reset by repeat ring events).
    final guardianIn = const Duration(minutes: 10) -
        DateTime.now().difference(_ringStartTimes[alarmId]!);
    _guardianTimers[alarmId]?.cancel();
    _guardianTimers[alarmId] =
        Timer(guardianIn.isNegative ? Duration.zero : guardianIn, () async {
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

    await _showRingScreen(alarmId);

    _missedRecoveryTimers[alarmId]?.cancel();
    _missedRecoveryTimers[alarmId] = Timer(autoSilenceAfter, () async {
      _missedRecoveryTimers.remove(alarmId);
      if (await Alarm.isRinging(alarmId).catchError((_) => false)) {
        await _autoSilence(alarmId);
      }
    });
  }

  /// Pushes the ring screen, waiting for the navigator if the alarm rang
  /// before `runApp` built it (cold start from the alarm notification).
  static Future<void> _showRingScreen(int alarmId) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (_ringScreenVisible) return;
      final navigator = appNavigatorKey.currentState;
      if (navigator != null) {
        _ringScreenVisible = true;
        unawaited(navigator.pushNamed(
          AlarmRingScreen.routeName,
          arguments: {
            'alarmId': alarmId,
            'snoozeCount': _snoozeSessionCount[alarmId] ?? 0,
          },
        ));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('Ring screen: navigator never became available for $alarmId');
  }

  /// Nobody answered for [autoSilenceAfter]: stop ringing, record the miss
  /// once (a streak freeze may save the streak), and keep the next
  /// occurrence scheduled. Replaces a 2-minute "recovery" that stopped the
  /// alarm mid-challenge, overwrote the user's alarm time with a backup, and
  /// recorded a miss on every cycle.
  static Future<void> _autoSilence(int alarmId) async {
    final alarm = AlarmService.findByIntId(alarmId);
    await Alarm.stop(alarmId);
    if (alarm != null) {
      if (alarm.repeatDays.isNotEmpty && alarm.isEnabled) {
        await AlarmService.scheduleAlarm(alarm, persist: false);
      } else {
        await AlarmService.saveAlarm(alarm.copyWith(isEnabled: false));
      }
    }
    final frozen = await SmartAlarmService.recordMissed();
    _snoozedIds.remove(alarmId);
    _snoozeSessionCount.remove(alarmId);
    _guardianTimers.remove(alarmId)?.cancel();
    _ringStartTimes.remove(alarmId);
    await _stopEffects();
    if (_ringScreenVisible) {
      appNavigatorKey.currentState?.pop();
      _ringScreenVisible = false;
    }
    _currentRingingId = 0;
    await _notifications.show(
      alarmId,
      'You slept through your alarm',
      frozen
          ? 'A streak freeze kept your streak alive. Try a louder tone or a tougher challenge.'
          : 'Your streak reset. Try a louder tone or a tougher challenge tomorrow.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_plus_missed',
          'Missed alarms',
          channelDescription: 'Shown when an alarm rang unanswered',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    unawaited(WidgetSyncService.refresh());
    unawaited(StreakReminderService.refresh());
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

    // Absolute time: rewriting alarm.time would drop seconds and, for a
    // repeating alarm, let nextDateTimeFrom move the snooze to another day.
    await AlarmService.scheduleAlarm(
      alarm,
      persist: false,
      at: DateTime.now().add(Duration(minutes: alarm.snoozeMinutes)),
    );
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
      await _scheduleWakeUpCheck(alarm, alarmId);
    }

    return reward;
  }

  /// Both halves of the check are handed to the OS — a scheduled
  /// notification, and a real alarm 60 s after it — so they survive the app
  /// being killed. (In-memory `Timer`s did not, and the re-ring's
  /// `TimeOfDay(now + 5 s)` rounded into the past and slipped to tomorrow.)
  /// Tapping the notification calls [cancelWakeUpCheck].
  static Future<void> _scheduleWakeUpCheck(AlarmModel alarm, int alarmId) async {
    final times = wakeCheckTimes(DateTime.now(), alarm.wakeUpCheckMinutes);
    try {
      await _notifications.zonedSchedule(
        wakeCheckNotificationId(alarmId),
        'Are you awake? 👁️',
        "Tap within a minute to confirm you're up: ${alarm.label.isEmpty ? "Alarm+" : alarm.label}",
        tz.TZDateTime.from(times.checkAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_plus_wakecheck',
            'Wake-Up Check',
            channelDescription:
                'Verify you are still awake after dismissing an alarm',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: await AlarmService.exactScheduleMode(),
        payload: 'wakecheck:$alarmId',
      );
    } catch (e) {
      debugPrint('Wake-up check notification failed: $e');
    }
    // Reuses the alarm's id: this temporarily replaces the next regular
    // occurrence, which cancelWakeUpCheck (or the re-ring's own dismiss)
    // puts back.
    await AlarmService.scheduleAlarm(alarm, persist: false, at: times.reringAt);
  }

  /// The user confirmed they're awake: drop the pending re-ring and restore
  /// the alarm's regular schedule.
  static Future<void> cancelWakeUpCheck(int alarmId) async {
    await _notifications.cancel(wakeCheckNotificationId(alarmId));
    final alarm = AlarmService.findByIntId(alarmId);
    if (alarm == null) return;
    if (await Alarm.isRinging(alarmId).catchError((_) => false)) return;
    await AlarmService.cancelAlarm(alarm.id);
    if (alarm.isEnabled) {
      await AlarmService.scheduleAlarm(alarm, persist: false);
    }
  }

  /// Call this after the ring screen celebration modal is dismissed to pop the screen.
  static void completeRingScreenDismiss() {
    appNavigatorKey.currentState?.pop();
    _ringScreenVisible = false;
    _currentRingingId = 0;
  }

  static Future<void> _stopEffects() async {
    await Vibration.cancel();
    await WakelockPlus.disable();
    await _stopForegroundService();
  }

  static Future<void> _startForegroundService(int alarmId) async {
    try {
      final alarm = AlarmService.findByIntId(alarmId);
      await _channel.invokeMethod<void>('startAlarmService', {
        'alarmId': alarmId,
        'hardcore': alarm?.hardcoreMode ?? false,
        'snoozeMinutes': alarm?.snoozeMinutes ?? 5,
      });
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
