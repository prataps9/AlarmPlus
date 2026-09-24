import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/progression_service.dart';
import 'package:alarm_plus/features/sleep/models/sleep_entry.dart';

class SleepDiaryService {
  static const _key = 'sleep_diary_entries';

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Map<String, SleepEntry>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, SleepEntry.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveEntry(SleepEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();
    all[entry.date] = entry;
    await prefs.setString(_key, jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))));
    await ProgressionService.recordActivity(QuestMetric.sleepLog);
  }

  static Future<SleepEntry?> getEntryForDate(DateTime date) async {
    final all = await _loadAll();
    return all[dateKey(date)];
  }

  static Future<List<SleepEntry?>> getLast7Days() async {
    final all = await _loadAll();
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return all[dateKey(day)];
    });
  }

  static Future<double> getAverageQuality() async {
    final entries = (await getLast7Days()).whereType<SleepEntry>().toList();
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.sleepQuality).reduce((a, b) => a + b) / entries.length;
  }

  static Future<String> getCorrelationWithBedtime() async {
    final entries = (await getLast7Days()).whereType<SleepEntry>().where((e) => e.bedtime != null).toList();
    if (entries.length < 3) return 'Log more entries to see correlations';

    final highQuality = entries.where((e) => e.sleepQuality >= 4).toList();
    final lowQuality = entries.where((e) => e.sleepQuality <= 2).toList();

    if (highQuality.isEmpty || lowQuality.isEmpty) return 'Keep logging to discover patterns';

    final avgHighBedHour = highQuality.map((e) => e.bedtime!.hour).reduce((a, b) => a + b) / highQuality.length;
    final avgLowBedHour = lowQuality.map((e) => e.bedtime!.hour).reduce((a, b) => a + b) / lowQuality.length;

    if (avgHighBedHour < avgLowBedHour) {
      return 'Earlier bedtimes correlated with better sleep quality';
    }
    return 'No clear bedtime pattern yet — keep logging!';
  }

  static Future<List<String>> getRecentNotes({int limit = 3}) async {
    final all = await _loadAll();
    final sorted = all.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return sorted
        .where((e) => e.value.notes?.isNotEmpty == true)
        .take(limit)
        .map((e) => '${e.key}: ${e.value.notes!}')
        .toList();
  }
}
