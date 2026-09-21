import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

/// Mirrors the soonest enabled alarm to Android via
/// `AlarmManager.setAlarmClock` (see `NextAlarmRegistrar.kt`).
///
/// This is what puts the alarm icon in the status bar, the next-alarm text on
/// the lock screen and in the system Clock, and makes the alarm visible to
/// other apps through `getNextAlarmClock()` — the things that distinguish a
/// real alarm app from one that merely schedules notifications.
///
/// It does not schedule the ring: the `alarm` package still owns scheduling
/// and playback. Registering here only tells the OS an alarm is coming.
///
/// Android-only. iOS has no equivalent public API — an alarm there can't
/// surface outside the app without a Live Activity extension.
class NextAlarmClockService {
  NextAlarmClockService._();

  static const _channel = MethodChannel('alarmplus/alarm_controls');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Registers the next enabled alarm, or clears the registration when none
  /// is armed. Safe to call as often as the alarm set changes.
  static Future<void> sync() async {
    if (!_supported) return;
    try {
      final next = soonestEnabledAlarm(
        AlarmService.getAllAlarms(),
        DateTime.now(),
      );
      await _channel.invokeMethod<void>('setNextAlarmClock', {
        // 0 tells the native side to clear the registration.
        'triggerAtMillis': next?.millisecondsSinceEpoch ?? 0,
      });
    } catch (e) {
      debugPrint('NextAlarmClockService.sync failed: $e');
    }
  }
}

/// Pure: when the soonest enabled alarm in [alarms] next fires, or null when
/// none is enabled. Extracted so the choice is testable without the channel.
DateTime? soonestEnabledAlarm(List<AlarmModel> alarms, DateTime now) {
  DateTime? soonest;
  for (final alarm in alarms) {
    if (!alarm.isEnabled) continue;
    final next = alarm.nextDateTimeFrom(now);
    if (soonest == null || next.isBefore(soonest)) {
      soonest = next;
    }
  }
  return soonest;
}
