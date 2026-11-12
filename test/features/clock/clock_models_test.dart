import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'package:alarm_plus/features/clock/models/clock_models.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('CityTime', () {
    final tokyo = WorldCity.byName('Tokyo')!;
    final newYork = WorldCity.byName('New York')!;

    test('wall time and offset from an IST phone', () {
      // 2026-09-25 10:00 UTC = 15:30 IST = 19:00 Tokyo.
      final t = CityTime.of(tokyo, DateTime.utc(2026, 9, 25, 10), const Duration(hours: 5, minutes: 30));
      expect(t.wallTime.hour, 19);
      expect(t.wallTime.minute, 0);
      expect(t.offsetFromLocal, const Duration(hours: 3, minutes: 30));
      expect(t.dayLabel, 'Today');
    });

    test('day label crosses midnight both ways', () {
      // 20:00 UTC: IST is 01:30 next day; New York (EDT) is still 16:00.
      final ny = CityTime.of(newYork, DateTime.utc(2026, 9, 25, 20), const Duration(hours: 5, minutes: 30));
      expect(ny.dayLabel, 'Yesterday');
      final tk = CityTime.of(tokyo, DateTime.utc(2026, 9, 25, 16), Duration.zero);
      expect(tk.dayLabel, 'Tomorrow'); // 01:00 in Tokyo
    });

    test('follows DST: New York is UTC-4 in September, UTC-5 in January', () {
      expect(CityTime.of(newYork, DateTime.utc(2026, 9, 1, 12), Duration.zero).offsetFromLocal,
          const Duration(hours: -4));
      expect(CityTime.of(newYork, DateTime.utc(2026, 1, 15, 12), Duration.zero).offsetFromLocal,
          const Duration(hours: -5));
    });

    test('every picker city resolves to a real zone', () {
      for (final c in WorldCity.all) {
        expect(() => CityTime.of(c, DateTime.utc(2026), Duration.zero), returnsNormally, reason: c.name);
      }
    });
  });

  group('TimeFormat', () {
    test('alarmIn reads like a clock app', () {
      expect(TimeFormat.alarmIn(null), 'No alarms set');
      expect(TimeFormat.alarmIn(const Duration(hours: 7, minutes: 20)), 'Alarm in 7 hr 20 min');
      expect(TimeFormat.alarmIn(const Duration(seconds: 10)), 'Alarm in 1 min');
      expect(TimeFormat.alarmIn(const Duration(days: 2, hours: 3)), 'Alarm in 2 days 3 hr');
    });

    test('city offset', () {
      expect(TimeFormat.offsetFromLocal(Duration.zero), 'Same time');
      expect(TimeFormat.offsetFromLocal(const Duration(hours: 5, minutes: 30)), '+5 hr 30 min');
      expect(TimeFormat.offsetFromLocal(const Duration(hours: -3)), '−3 hr');
    });
  });
}
