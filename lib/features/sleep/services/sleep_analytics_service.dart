import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/alarm/models/alarm_ring_event.dart';

class SleepAnalyticsService {
  static const _key = 'sleep_analytics_events';

  static Future<void> recordEvent(AlarmRingEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(event.toJson()));
    // Keep last 90 days max (at most 4 alarms/day = 360 entries)
    while (raw.length > 360) {
      raw.removeAt(0);
    }
    await prefs.setStringList(_key, raw);
  }

  static Future<List<AlarmRingEvent>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) {
      try {
        return AlarmRingEvent.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<AlarmRingEvent>().toList();
  }

  static Future<List<AlarmRingEvent>> getLast7Days() async {
    final all = await _loadAll();
    // Today and the six calendar days before it, the same days the daily
    // chart shows (a rolling 168 hours took in part of an eighth day).
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day - 6);
    return all.where((e) => !e.scheduledTime.isBefore(cutoff)).toList();
  }

  static Future<List<AlarmRingEvent>> getLast30Days() async {
    final all = await _loadAll();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return all.where((e) => e.scheduledTime.isAfter(cutoff)).toList();
  }

  static Future<int> weeklyScore() async {
    final events = await getLast7Days();
    if (events.isEmpty) return 0;
    final dismissed = events.where((e) => !e.wasMissed);
    if (dismissed.isEmpty) return 0;

    final avgWakeScore = dismissed.map((e) => e.wakeScore).reduce((a, b) => a + b) / dismissed.length;
    final onTimePct = dismissed.length / events.length * 100;
    final noSnoozePct = dismissed.where((e) => e.snoozeCount == 0).length / dismissed.length * 100;

    return (avgWakeScore * 0.5 + onTimePct * 0.3 + noSnoozePct * 0.2).round().clamp(0, 100);
  }

  static Future<String> bestWakeDay() async {
    final events = await getLast7Days();
    final dismissed = events.where((e) => !e.wasMissed && e.snoozeCount == 0).toList();
    if (dismissed.isEmpty) return '--';

    final dayCounts = <int, int>{};
    for (final e in dismissed) {
      final weekday = e.scheduledTime.weekday;
      dayCounts[weekday] = (dayCounts[weekday] ?? 0) + 1;
    }

    final best = dayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[best];
  }

  static Future<double> avgSnoozeCount() async {
    final events = await getLast7Days();
    if (events.isEmpty) return 0;
    final total = events.map((e) => e.snoozeCount).reduce((a, b) => a + b);
    return total / events.length;
  }

  static Future<int> sleepDebt() async {
    final events = await getLast7Days();
    final totalSnoozes = events.map((e) => e.snoozeCount).fold(0, (a, b) => a + b);
    return totalSnoozes * 9;
  }

  static Future<List<double>> dailyScores() async {
    final events = await getLast7Days();
    final now = DateTime.now();
    final scores = List<double>.filled(7, 0);

    for (var i = 0; i < 7; i++) {
      // Calendar days: 24-hour steps skip or repeat a day across DST.
      final day = DateTime(now.year, now.month, now.day - (6 - i));
      final dayEvents = events.where((e) =>
        e.scheduledTime.year == day.year &&
        e.scheduledTime.month == day.month &&
        e.scheduledTime.day == day.day &&
        !e.wasMissed,
      ).toList();

      if (dayEvents.isNotEmpty) {
        final avg = dayEvents.map((e) => e.wakeScore).reduce((a, b) => a + b) / dayEvents.length;
        scores[i] = avg;
      }
    }

    return scores;
  }

  static String scoreLabel(int score) {
    if (score >= 80) return 'Great';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Work';
  }
}
