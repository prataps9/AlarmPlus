import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/live_timer_notification_service.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

class NapService {
  static const _activeKey = 'nap_active';
  static const _startMsKey = 'nap_start_ms';
  static const _durationKey = 'nap_duration_minutes';
  static const _historyKey = 'nap_history';

  static Future<void> scheduleNap(int durationMinutes) async {
    final wakeTime = DateTime.now().add(Duration(minutes: durationMinutes));
    await AlarmService.scheduleNapAlarm(wakeTime);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, true);
    await prefs.setInt(_startMsKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_durationKey, durationMinutes);
    await LiveTimerNotificationService.showNap(durationMinutes * 60);
  }

  static Future<void> cancelNap() async {
    await AlarmService.cancelNapAlarm();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, false);
    await prefs.remove(_startMsKey);
    await prefs.remove(_durationKey);
    await LiveTimerNotificationService.cancel();
  }

  static Future<bool> isNapActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activeKey) ?? false;
  }

  static Future<int> getRemainingSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt(_startMsKey) ?? 0;
    final durationMin = prefs.getInt(_durationKey) ?? 0;
    final endMs = startMs + durationMin * 60 * 1000;
    final remaining = (endMs - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    return remaining.clamp(0, durationMin * 60);
  }

  static Future<bool> checkMissedNap() async {
    final active = await isNapActive();
    if (!active) return false;
    final remaining = await getRemainingSeconds();
    if (remaining <= 0) {
      // Alarm already rang; just clear state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_activeKey, false);
      await LiveTimerNotificationService.cancel();
      return true;
    }
    return false;
  }

  static Future<void> saveNapHistory(int durationMinutes, int rating) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    final List<dynamic> history = raw != null ? jsonDecode(raw) as List : [];
    history.insert(0, {
      'duration': durationMinutes,
      'rating': rating,
      'timestamp': DateTime.now().toIso8601String(),
    });
    while (history.length > 10) { history.removeLast(); }
    await prefs.setString(_historyKey, jsonEncode(history));

    // Clear active state after rating
    await prefs.setBool(_activeKey, false);
  }

  static Future<List<Map<String, dynamic>>> getNapHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
