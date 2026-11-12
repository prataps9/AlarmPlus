import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/models/upcoming_rings.dart';
import 'package:alarm_plus/features/sleep/models/sleep_cycles.dart';

AlarmModel _alarm(String id, int h, int m,
        {List<int> days = const [], bool on = true, DateTime? date, String tag = ''}) =>
    AlarmModel(
      id: id,
      time: TimeOfDay(hour: h, minute: m),
      label: id,
      tag: tag,
      sound: 'default',
      isEnabled: on,
      repeatDays: days,
      date: date,
    );

void main() {
  group('sleep-cycle wake times', () {
    test('15 min to fall asleep, then 4, 5 and 6 cycles of 90 min', () {
      final times = SleepCycles.wakeTimes(DateTime(2026, 10, 27, 23));
      expect([for (final t in times) t.wakeAt], [
        DateTime(2026, 10, 28, 5, 15),
        DateTime(2026, 10, 28, 6, 45),
        DateTime(2026, 10, 28, 8, 15),
      ]);
      expect([for (final t in times) SleepCycles.sleepLabel(t.cycles)],
          ['6 h', '7.5 h', '9 h']);
    });

    test('rounded up to the next 5 minutes', () {
      final t = SleepCycles.wakeTimes(DateTime(2026, 10, 27, 23, 2, 30)).first;
      expect(t.wakeAt, DateTime(2026, 10, 28, 5, 20));
      final exact = SleepCycles.wakeTimes(DateTime(2026, 10, 27, 23, 0, 10)).first;
      expect(exact.wakeAt, DateTime(2026, 10, 28, 5, 20),
          reason: 'never earlier than the cycle end');
    });
  });

  group('next 7 days', () {
    // Tuesday 27 Oct 2026, 09:00.
    final now = DateTime(2026, 10, 27, 9);

    test('weekday alarm rings on each weekday in the window, in order', () {
      final rings = upcomingRings([_alarm('work', 7, 0, days: [1, 2, 3, 4, 5])], now);
      expect([for (final r in rings) r.at], [
        DateTime(2026, 10, 28, 7), // Wed
        DateTime(2026, 10, 29, 7),
        DateTime(2026, 10, 30, 7),
        DateTime(2026, 11, 2, 7), // Mon
        DateTime(2026, 11, 3, 7), // Tue
      ]);
    });

    test('one-offs once, dated ones on their day, off/expired/system never', () {
      final rings = upcomingRings([
        _alarm('once', 6, 30),
        _alarm('dated', 8, 0, date: DateTime(2026, 10, 30)),
        _alarm('off', 6, 0, days: [1, 2, 3, 4, 5, 6, 7], on: false),
        _alarm('gone', 8, 0, date: DateTime(2026, 10, 26)),
        _alarm('nap', 14, 0, tag: AlarmModel.napTag),
        _alarm('far', 8, 0, date: DateTime(2026, 11, 20)),
      ], now);
      expect([for (final r in rings) r.alarm.id], ['once', 'dated']);
    });
  });
}
