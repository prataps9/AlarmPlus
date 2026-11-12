import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/clock/models/clock_models.dart';

/// Persistence for the Clock tab (the world-clock city list).
class ClockService {
  ClockService._();

  static const _citiesKey = 'clock.world.cities';

  // The timer and stopwatch were removed; these are what they left behind.
  static const _retiredKeys = ['clock.stopwatch', 'clock.timer'];
  static const _retiredTimerNotificationId = 919191920;

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

  /// Once per start (cheap): clears what the removed timer and stopwatch
  /// left on an upgraded phone: their saved state, and a "time's up" still
  /// scheduled for a timer that was running when the app updated.
  static Future<void> clearRetiredTimer() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (_retiredKeys.any(prefs.containsKey)) {
      for (final key in _retiredKeys) {
        await prefs.remove(key);
      }
      try {
        await FlutterLocalNotificationsPlugin()
            .cancel(_retiredTimerNotificationId);
      } catch (e) {
        debugPrint('Retired timer notification cancel failed: $e');
      }
    }
  }
}
