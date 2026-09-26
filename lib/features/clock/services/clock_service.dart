import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/clock/models/clock_models.dart';

/// Persistence for the Clock / Timer / Stopwatch tabs, plus the timer's
/// "time's up" notification.
class ClockService {
  ClockService._();

  static const _citiesKey = 'clock.world.cities';
  static const _stopwatchKey = 'clock.stopwatch';
  static const _timerKey = 'clock.timer';

  /// Fixed id, distinct from the per-alarm ids derived in AlarmService.
  static const timerNotificationId = 919191920;

  static final _notifications = FlutterLocalNotificationsPlugin();

  // ── World clock ───────────────────────────────────────────────────────

  static Future<List<WorldCity>> loadCities() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(_citiesKey);
    if (names == null) {
      // First run: a couple of useful defaults, like stock clock apps.
      return const [
        WorldCity('London', 'United Kingdom', 'Europe/London'),
        WorldCity('New York', 'United States', 'America/New_York'),
      ];
    }
    return names.map(WorldCity.byName).whereType<WorldCity>().toList();
  }

  static Future<void> saveCities(List<WorldCity> cities) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_citiesKey, cities.map((c) => c.name).toList());
  }

  // ── Stopwatch ─────────────────────────────────────────────────────────

  static Future<StopwatchState> loadStopwatch() async {
    final prefs = await SharedPreferences.getInstance();
    return StopwatchState.fromJson(prefs.getString(_stopwatchKey));
  }

  static Future<void> saveStopwatch(StopwatchState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stopwatchKey, s.toJson());
  }

  // ── Timer ─────────────────────────────────────────────────────────────

  static Future<CountdownState?> loadTimer() async {
    final prefs = await SharedPreferences.getInstance();
    return CountdownState.fromJson(prefs.getString(_timerKey));
  }

  /// Saves the timer and keeps its "time's up" notification in step:
  /// scheduled at `endsAt` while running, cancelled otherwise.
  static Future<void> saveTimer(CountdownState? t) async {
    final prefs = await SharedPreferences.getInstance();
    if (t == null) {
      await prefs.remove(_timerKey);
    } else {
      await prefs.setString(_timerKey, t.toJson());
    }
    await _cancelTimerNotification();
    if (t != null && t.isRunning) await _scheduleTimerNotification(t.endsAt!);
  }

  static Future<void> dismissTimesUp() => _cancelTimerNotification();

  static Future<void> _cancelTimerNotification() async {
    try {
      await _notifications.cancel(timerNotificationId);
    } catch (e) {
      debugPrint('Timer notification cancel failed: $e');
    }
  }

  static Future<void> _scheduleTimerNotification(DateTime at) async {
    if (kIsWeb) return;
    try {
      await _notifications.zonedSchedule(
        timerNotificationId,
        "Time's up",
        'Your Alarm+ timer has finished',
        tz.TZDateTime.from(at, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_plus_timer',
            'Timer',
            channelDescription: 'Rings when a countdown timer finishes',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            // Ring on the alarm stream with the system alarm tone, so it
            // isn't silenced by notification volume.
            sound: const UriAndroidNotificationSound(
                'content://settings/system/alarm_alert'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            // FLAG_INSISTENT: keep repeating the sound until it's handled.
            additionalFlags: Int32List.fromList(<int>[4]),
            ongoing: true,
            autoCancel: true,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: await AlarmService.exactScheduleMode(),
        payload: 'timer',
      );
    } catch (e) {
      debugPrint('Timer notification schedule failed: $e');
    }
  }
}
