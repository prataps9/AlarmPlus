import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/home/providers/insights_providers.dart';

AlarmModel _alarm({
  required int hour,
  required int minute,
  List<int> repeatDays = const [],
  bool isEnabled = true,
}) {
  return AlarmModel(
    id: '$hour:$minute-${repeatDays.join()}',
    time: TimeOfDay(hour: hour, minute: minute),
    label: 'Test',
    tag: 'Steady wake',
    sound: 'default',
    isEnabled: isEnabled,
    repeatDays: repeatDays,
  );
}

void main() {
  group('buildWeekdayLoad', () {
    test('counts a repeating alarm on each of its days', () {
      final load = buildWeekdayLoad([
        _alarm(hour: 7, minute: 0, repeatDays: const [1, 3, 5]),
      ]);

      expect(load.countsByWeekday, [1, 0, 1, 0, 1, 0, 0]);
      expect(load.max, 1);
      expect(load.isEmpty, isFalse);
    });

    test('stacks alarms that share a weekday', () {
      final load = buildWeekdayLoad([
        _alarm(hour: 6, minute: 30, repeatDays: const [1]),
        _alarm(hour: 7, minute: 30, repeatDays: const [1]),
        _alarm(hour: 8, minute: 0, repeatDays: const [2]),
      ]);

      expect(load.countsByWeekday[0], 2);
      expect(load.countsByWeekday[1], 1);
      expect(load.max, 2);
    });

    test('ignores disabled alarms', () {
      final load = buildWeekdayLoad([
        _alarm(hour: 7, minute: 0, repeatDays: const [1], isEnabled: false),
      ]);

      expect(load.isEmpty, isTrue);
      expect(load.headline, contains('Add and enable'));
    });

    test('is empty with no alarms at all', () {
      final load = buildWeekdayLoad([]);

      expect(load.countsByWeekday, List.filled(7, 0));
      expect(load.isEmpty, isTrue);
    });

    test('headline names the busiest day and the average time', () {
      final load = buildWeekdayLoad([
        _alarm(hour: 6, minute: 0, repeatDays: const [3]),
        _alarm(hour: 8, minute: 0, repeatDays: const [3]),
        _alarm(hour: 7, minute: 0, repeatDays: const [1]),
      ]);

      // Wednesday has two alarms; the three alarms average to 7:00 AM.
      expect(load.headline, contains('Wed'));
      expect(load.headline, contains('7:00 AM'));
    });

    test('a one-off alarm lands on exactly one weekday', () {
      final load = buildWeekdayLoad([_alarm(hour: 9, minute: 15)]);

      expect(load.countsByWeekday.where((c) => c > 0).length, 1);
      expect(load.max, 1);
    });
  });
}
