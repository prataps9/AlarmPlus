import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:alarm_plus/features/sleep/models/bedtime_schedule.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

class BedtimeService {
  static const _key = 'bedtime_schedule';
  static const _inBedKey = 'last_in_bed_date';
  static const _notifId = 9901;

  static final _notifs = FlutterLocalNotificationsPlugin();

  static Future<void> save(BedtimeSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(schedule.toJson()));
    if (schedule.isEnabled) {
      await _scheduleWindDownNotification(schedule);
    } else {
      await _notifs.cancel(_notifId);
    }
  }

  static Future<BedtimeSchedule?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return BedtimeSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> recordInBed() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    await prefs.setString(_inBedKey, today);
    await SmartAlarmService.addXp(20);
  }

  static Future<bool> isInBedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_inBedKey);
    return saved == _dateKey(DateTime.now());
  }

  static String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Next wind-down reminder: bedtime minus the wind-down, as a wall-clock
  /// time, today or tomorrow. Built from calendar fields; adding a 24-hour
  /// Duration across a DST change put the (daily-repeating) reminder an hour
  /// off for good.
  @visibleForTesting
  static DateTime reminderTime(BedtimeSchedule schedule, DateTime now) {
    final bed = schedule.targetBedtime;
    final minutes =
        (bed.hour * 60 + bed.minute - schedule.windDownMinutes) % (24 * 60);
    final h = minutes ~/ 60, m = minutes % 60;
    final today = DateTime(now.year, now.month, now.day, h, m);
    return today.isBefore(now)
        ? DateTime(now.year, now.month, now.day + 1, h, m)
        : today;
  }

  static Future<void> _scheduleWindDownNotification(BedtimeSchedule schedule) async {
    await _notifs.cancel(_notifId);

    final bedtime = reminderTime(schedule, DateTime.now());

    final tzBedtime = tz.TZDateTime.from(bedtime, tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_plus_winddown',
        'Alarm+ Wind-down',
        channelDescription: 'Bedtime wind-down reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _notifs.zonedSchedule(
      _notifId,
      'Time to Wind Down',
      'Your bedtime is in ${schedule.windDownMinutes} minutes. Start relaxing.',
      tzBedtime,
      details,
      androidScheduleMode: await AlarmService.exactScheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static String nextBedtimeLabel(BedtimeSchedule schedule) {
    final h = schedule.targetBedtime.hour;
    final m = schedule.targetBedtime.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h % 12 == 0 ? 12 : h % 12;
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }
}
