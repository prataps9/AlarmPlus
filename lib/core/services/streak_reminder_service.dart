import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

/// Schedules a single evening "your streak is at risk" local notification
/// whenever the user has no alarm coming up soon — mirroring Duolingo's
/// end-of-day streak reminder. Re-evaluated (and rescheduled or cancelled)
/// from the same hook points as `WidgetSyncService`: alarm
/// schedule/cancel/toggle/delete, dismiss/miss, and app startup.
class StreakReminderService {
  StreakReminderService._();

  // Arbitrary, fixed id distinct from alarm/wind-down notification ids
  // (which are derived per-alarm via AlarmService.alarmIntId).
  static const _notificationId = 919191919;
  static const _reminderHour = 21; // 9 PM local
  static const _lookaheadHours = 18;

  static const _channelId = 'alarm_plus_streak_risk';
  static const _channelName = 'Alarm+ Streak Reminders';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const List<String> _messages = [
    "Don't let it slip — set tomorrow's alarm and keep the fire going.",
    'One tap now saves the streak you worked hard for.',
    "Future you will thank you for setting tomorrow's alarm tonight.",
    'A quick alarm now keeps your momentum alive.',
  ];

  static Future<void> refresh() async {
    if (kIsWeb) return;
    try {
      final stats = await SmartAlarmService.getStats();
      if (stats.currentStreak <= 0 || _hasUpcomingAlarmSoon()) {
        await _notifications.cancel(_notificationId);
        return;
      }

      final now = DateTime.now();
      final fireTime = DateTime(now.year, now.month, now.day, _reminderHour);
      if (!fireTime.isAfter(now)) {
        // Too late to warn about tonight; nothing pending until the streak
        // is next re-evaluated (e.g. tomorrow's alarm scheduling/dismissal).
        await _notifications.cancel(_notificationId);
        return;
      }

      final rng = math.Random(now.day);
      final message =
          "🔥 Your ${stats.currentStreak}-day streak is about to break! "
          '${_messages[rng.nextInt(_messages.length)]}';

      await _notifications.zonedSchedule(
        _notificationId,
        'Your streak needs you',
        message,
        tz.TZDateTime.from(fireTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription:
                'Warns when you have no upcoming alarm and your streak is at risk',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      // Best-effort — never let a reminder scheduling failure break the
      // calling flow (alarm scheduling, dismissal, etc.).
      debugPrint('StreakReminderService.refresh failed: $e');
    }
  }

  static bool _hasUpcomingAlarmSoon() {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(hours: _lookaheadHours));
    return AlarmService.getAllAlarms().any((alarm) {
      if (!alarm.isEnabled) return false;
      return alarm.nextDateTimeFrom(now).isBefore(cutoff);
    });
  }
}
