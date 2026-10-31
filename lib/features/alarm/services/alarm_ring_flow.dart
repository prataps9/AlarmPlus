import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/models/alarm_ring_event.dart';
import 'package:alarm_plus/features/alarm/screens/alarm_ring_screen.dart';
import 'package:alarm_plus/features/sleep/services/sleep_sound_service.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/core/services/app_settings.dart';
import 'package:alarm_plus/core/services/native_controls.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/core/services/guardian_service.dart';
import 'package:alarm_plus/features/sleep/services/sleep_analytics_service.dart';
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
  /// The ring screen's route while it is open. Tracking the route itself,
  /// not a flag: the plugin's ringing stream used to clear the flag midway
  /// through a snooze, so the screen was never popped; and a back press
  /// popped the screen but left the flag set, so it could never reopen.
  static Route<void>? _ringRoute;
  static bool get _ringScreenVisible => _ringRoute?.isActive ?? false;

  /// Alarms with a snooze in flight (volume keys, notification, button and
  /// MediaSession can all fire for one press).
  static final Set<int> _snoozing = <int>{};

  /// When each snoozed alarm is due to re-ring; a ring that isn't that
  /// re-ring starts a fresh session (snooze count and "had snooze" reset).
  static final Map<int, DateTime> _snoozeDueAt = <int, DateTime>{};
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

  static const _channel = NativeControls.channel;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Tracks ring start time for Guardian Alert threshold
  static final Map<int, DateTime> _ringStartTimes = <int, DateTime>{};
  static final Map<int, Timer> _guardianTimers = <int, Timer>{};

  static Future<void> bindNativeAlarmEvents() async {
    // Register wake-check tap handler to avoid circular import
    AlarmService.registerWakeCheckHandler(cancelWakeUpCheck);

    NativeControls.register('snooze', (args) async {
      final id = (args as int?) ?? _currentRingingId;
      if (id <= 0) return null;
      // Volume keys and the notification button snooze without looking at
      // the screen, which is exactly what Hardcore mode exists to stop.
      if (AlarmService.findByIntId(id)?.hardcoreMode == true) return null;
      await snoozeAlarm(id);
      return null;
    });
    NativeControls.register('stopFromNotification', (args) async {
      final id = (args as int?) ?? _currentRingingId;
      if (id <= 0) return null;
      // Never dismiss from the notification: that skipped every challenge
      // (and still paid out XP). Bring up the ring screen instead.
      await _showRingScreen(id);
      return null;
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

      // Another alarm is still ringing once the screen for the first one
      // closed (overlapping alarms): bring the screen back for it.
      if (ids.isNotEmpty && !_ringScreenVisible) {
        final next = ids.contains(_currentRingingId) ? _currentRingingId : ids.first;
        _currentRingingId = next;
        unawaited(_showRingScreen(next));
      }
    });

    await _ringIntentSubscription?.cancel();
    _ringIntentSubscription = AlarmService.ringIntents.listen((alarmId) {
      if (alarmId <= 0) {
        return;
      }
      onAlarmRing(alarmId);
    });

    // A foreground service left running by a previous process (swiped away,
    // killed mid-ring) has nothing to ring for once nothing is ringing.
    var anyRinging = false;
    try {
      for (final a in await Alarm.getAlarms()) {
        if (await Alarm.isRinging(a.id)) anyRinging = true;
      }
    } catch (_) {
      anyRinging = true; // unknown: leave the service alone
    }
    if (!anyRinging) unawaited(_stopForegroundService());

    // A notification tap that cold-started the app arrived before these
    // listeners existed; replay it now.
    final launch = AlarmService.takeLaunchResponse();
    final payload = launch?.payload?.trim() ?? '';
    if (payload.startsWith('wakecheck:')) {
      final id = int.tryParse(payload.substring('wakecheck:'.length));
      if (id != null) await cancelWakeUpCheck(id);
    } else if (launch != null && int.tryParse(payload) == null) {
      // "Dismiss now", "Time's up" and other non-alarm notifications.
      AlarmService.handleNotificationResponse(launch);
    } else {
      final id = int.tryParse(payload);
      if (id != null && id > 0 && await Alarm.isRinging(id).catchError((_) => false)) {
        onAlarmRing(id);
      }
    }
  }

  static Future<void> onAlarmRing(int alarmId) async {
    _currentRingingId = alarmId;
    // A fresh ring (not the re-ring of a snooze) starts a new session, so a
    // snooze from yesterday doesn't bring Boss Mode or a spent snooze limit.
    final due = _snoozeDueAt[alarmId];
    final isSnoozeReRing = due != null &&
        DateTime.now().difference(due).abs() < const Duration(minutes: 2);
    // Re-delivered events for a ring already in progress (a notification
    // tap, a cold-start replay) keep the session.
    final repeatEvent = _knownRingingIds.contains(alarmId);
    if (!isSnoozeReRing && !repeatEvent) {
      _snoozedIds.remove(alarmId);
      _snoozeSessionCount.remove(alarmId);
      _ringStartTimes.remove(alarmId);
    }
    _snoozeDueAt.remove(alarmId);
    unawaited(AlarmService.cancelUpcomingNotice(alarmId));
    // Sleep sounds set to "play until alarm" only ducked under the alarm,
    // then came back at full volume and looped all morning.
    unawaited(SleepSoundService.stop(fadeOutSeconds: 0));
    // The widget's Snooze button only works while it knows we're ringing.
    unawaited(WidgetSyncService.refresh());
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
      final hasVibrator = pattern.isNotEmpty &&
          await AppSettings.readVibrationEnabled() &&
          await Vibration.hasVibrator();
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
        final route = MaterialPageRoute<void>(
          settings: RouteSettings(
            name: AlarmRingScreen.routeName,
            arguments: {
              'alarmId': alarmId,
              'snoozeCount': _snoozeSessionCount[alarmId] ?? 0,
            },
          ),
          builder: (_) => const AlarmRingScreen(),
        );
        _ringRoute = route;
        unawaited(_lockScreen('ringScreenShown'));
        unawaited(navigator.push(route).whenComplete(() {
          if (identical(_ringRoute, route)) _ringRoute = null;
          if (_ringRoute == null) unawaited(_lockScreen('ringScreenClosed'));
        }));
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
    if (alarm != null && alarm.isSystem) {
      // An unanswered nap or arrival alarm isn't a missed wake-up.
      await AlarmService.deleteAlarm(alarm.id);
      _snoozedIds.remove(alarmId);
      _snoozeSessionCount.remove(alarmId);
      _guardianTimers.remove(alarmId)?.cancel();
      _ringStartTimes.remove(alarmId);
      await _stopEffects();
      _closeRingScreen();
      _currentRingingId = 0;
      return;
    }
    if (alarm != null) {
      if (alarm.repeatDays.isNotEmpty && alarm.isEnabled) {
        await AlarmService.scheduleAlarm(alarm, persist: false);
      } else {
        await AlarmService.saveAlarm(alarm.copyWith(isEnabled: false));
      }
      AlarmService.notifyChanged();
    }
    final frozen = await SmartAlarmService.recordMissed();
    // Sleep Insights only ever saw dismissals, so its on-time share was
    // always 100% and a missed morning never lowered the weekly score.
    await SleepAnalyticsService.recordEvent(AlarmRingEvent(
      alarmId: alarm?.id ?? '',
      scheduledTime:
          _ringStartTimes[alarmId] ?? DateTime.now().subtract(autoSilenceAfter),
      snoozeCount: _snoozeSessionCount[alarmId] ?? 0,
      wasMissed: true,
      wakeScore: 0,
    ));
    _snoozedIds.remove(alarmId);
    _snoozeSessionCount.remove(alarmId);
    _guardianTimers.remove(alarmId)?.cancel();
    _ringStartTimes.remove(alarmId);
    await _stopEffects();
    _closeRingScreen();
    _currentRingingId = 0;
    await _notifications.show(
      AlarmService.missedNoticeId(alarmId),
      'You slept through your alarm',
      frozen
          // Kept by a freeze, or because an earlier alarm today was won.
          ? 'Your streak is still alive. Try a louder tone or a tougher challenge.'
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
    // One snooze per press, and only for an alarm that is actually ringing:
    // repeated key events each passed the limit check and cost XP.
    if (_snoozing.contains(alarmId)) return false;
    if (!await Alarm.isRinging(alarmId).catchError((_) => false)) return false;

    final used = _snoozeSessionCount[alarmId] ?? 0;
    if (!canSnoozeAgain(used: used, maxSnoozes: alarm.maxSnoozes)) {
      return false;
    }
    _snoozing.add(alarmId);
    try {
      return await _snooze(alarm, alarmId);
    } finally {
      _snoozing.remove(alarmId);
    }
  }

  static Future<bool> _snooze(AlarmModel alarm, int alarmId) async {
    // Count it before any await, so a parallel call sees the new total.
    _snoozedIds.add(alarmId);
    _snoozeSessionCount[alarmId] = (_snoozeSessionCount[alarmId] ?? 0) + 1;
    // Close the screen first: the plugin's ringing stream fires during the
    // awaits below and must not find a stale screen.
    _closeRingScreen();
    final dueAt = DateTime.now().add(Duration(minutes: alarm.snoozeMinutes));
    _snoozeDueAt[alarmId] = dueAt;

    await AlarmService.cancelAlarm(alarm.id);

    // Absolute time: rewriting alarm.time would drop seconds and, for a
    // repeating alarm, let nextDateTimeFrom move the snooze to another day.
    await AlarmService.scheduleAlarm(alarm, persist: false, at: dueAt);
    await SmartAlarmService.recordSnoozed();
    if (_currentRingingId == alarmId) _currentRingingId = 0;

    // The guardian alert keeps counting from the first ring of the session
    // (it used to restart on every snooze, so it could never fire).
    _guardianTimers[alarmId]?.cancel();
    _guardianTimers.remove(alarmId);

    await _stopEffects();
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

    if (alarm.isSystem) {
      // A nap or arrival alarm: done once it has rung, and not a wake-up,
      // so no streak, XP or wake-up check.
      await AlarmService.deleteAlarm(alarm.id);
      _snoozedIds.remove(alarmId);
      _snoozeSessionCount.remove(alarmId);
      _missedRecoveryTimers.remove(alarmId)?.cancel();
      _guardianTimers.remove(alarmId)?.cancel();
      _ringStartTimes.remove(alarmId);
      await _stopEffects();
      return null;
    }

    if (alarm.repeatDays.isNotEmpty) {
      await AlarmService.scheduleAlarm(alarm);
    } else {
      await AlarmService.saveAlarm(alarm.copyWith(isEnabled: false));
    }
    // The alarm list only reloads on this signal; without it a finished
    // one-off still showed ON (and editing it re-armed it).
    AlarmService.notifyChanged();

    // Dismissing a wake-up check re-ring finishes the morning that was
    // already counted: no second reward, and no further check (it used to
    // pay XP again and schedule another check, every time).
    final reRing = await AlarmService.isWakeCheckReRing(alarmId);
    await AlarmService.clearWakeCheckReRing(alarmId);

    // Determine if user snoozed before finally dismissing
    final hadSnooze = _snoozedIds.remove(alarmId);
    final snoozeCount = _snoozeSessionCount.remove(alarmId) ?? 0;
    final reward = reRing
        ? null
        : await SmartAlarmService.recordDismissed(
            hadSnooze: hadSnooze, snoozeCount: snoozeCount);
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
    if (alarm.wakeUpCheckEnabled && !reRing) {
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
    await AlarmService.markWakeCheckReRing(alarmId, times.reringAt);
  }

  /// The user confirmed they're awake: drop the pending re-ring and restore
  /// the alarm's regular schedule.
  static Future<void> cancelWakeUpCheck(int alarmId) async {
    await _notifications.cancel(wakeCheckNotificationId(alarmId));
    await AlarmService.clearWakeCheckReRing(alarmId);
    final alarm = AlarmService.findByIntId(alarmId);
    if (alarm == null) return;
    if (await Alarm.isRinging(alarmId).catchError((_) => false)) return;
    await AlarmService.cancelAlarm(alarm.id);
    if (alarm.isEnabled) {
      // Back to the regular schedule: the pending re-ring is what's dropped.
      await AlarmService.scheduleAlarm(alarm, persist: false, keepPending: false);
    }
  }

  /// Call this after the ring screen celebration modal is dismissed to pop the screen.
  /// Safe to call twice: the second call finds no ring screen and does nothing
  /// (it used to pop whatever screen was on top, e.g. the morning check-in).
  static void completeRingScreenDismiss() {
    final args = _ringRoute?.settings.arguments;
    final dismissed = args is Map ? args['alarmId'] as int? : null;
    _closeRingScreen();
    _currentRingingId = 0;
    unawaited(_showNextRinging(except: dismissed));
  }

  /// Another alarm that rang while this one's screen was up (overlapping
  /// alarms) is still going once it closes: show the screen for it.
  static Future<void> _showNextRinging({int? except}) async {
    for (final id in _knownRingingIds.toList()) {
      if (id == except) continue;
      if (await Alarm.isRinging(id).catchError((_) => false)) {
        _currentRingingId = id;
        await _showRingScreen(id);
        return;
      }
    }
  }

  /// Closes the ring screen and anything opened over it (a challenge
  /// dialog), and nothing else.
  static void _closeRingScreen() {
    final route = _ringRoute;
    _ringRoute = null;
    final navigator = appNavigatorKey.currentState;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
      // Dialogs that were opened from the ring screen go with it.
      navigator.popUntil((r) => r.isFirst || r is! PopupRoute);
    }
  }

  /// The ring screen shows over the lock screen; once it closes the phone
  /// asks to be unlocked instead of leaving the whole app open over it.
  static Future<void> _lockScreen(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (e) {
      debugPrint('$method channel error: $e');
    }
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
