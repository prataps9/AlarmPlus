import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

AlarmModel _alarm({
  required String id,
  bool isEnabled = true,
  List<int> repeatDays = const [],
}) {
  return AlarmModel(
    id: id,
    time: const TimeOfDay(hour: 7, minute: 0),
    label: 'Wake',
    repeatDays: repeatDays,
    isEnabled: isEnabled,
    tag: '',
    sound: 'default',
  );
}

void main() {
  final now = DateTime(2026, 3, 14, 9, 0);

  group('alarmsNeedingReschedule', () {
    test('an enabled alarm with nothing scheduled needs re-arming', () {
      final alarm = _alarm(id: 'a');

      final stale = alarmsNeedingReschedule(
        alarms: [alarm],
        scheduled: const {},
        now: now,
      );

      expect(stale.map((a) => a.id), ['a']);
    });

    test('an alarm scheduled in the future is left alone', () {
      final alarm = _alarm(id: 'a');

      final stale = alarmsNeedingReschedule(
        alarms: [alarm],
        scheduled: {
          AlarmService.alarmIntId('a'): now.add(const Duration(hours: 22)),
        },
        now: now,
      );

      expect(stale, isEmpty);
    });

    test('an occurrence already in the past needs re-arming', () {
      // This is the broken repeat chain: the alarm fired, was never dismissed
      // in-app, and so the next occurrence was never scheduled.
      final alarm = _alarm(id: 'a', repeatDays: const [1, 2, 3, 4, 5]);

      final stale = alarmsNeedingReschedule(
        alarms: [alarm],
        scheduled: {
          AlarmService.alarmIntId('a'): now.subtract(const Duration(hours: 2)),
        },
        now: now,
      );

      expect(stale.map((a) => a.id), ['a']);
    });

    test('an occurrence exactly at now counts as past', () {
      final alarm = _alarm(id: 'a');

      final stale = alarmsNeedingReschedule(
        alarms: [alarm],
        scheduled: {AlarmService.alarmIntId('a'): now},
        now: now,
      );

      expect(stale.map((a) => a.id), ['a']);
    });

    test('disabled alarms are never re-armed', () {
      final alarm = _alarm(id: 'a', isEnabled: false);

      final stale = alarmsNeedingReschedule(
        alarms: [alarm],
        scheduled: const {},
        now: now,
      );

      expect(stale, isEmpty);
    });

    test('only the stale alarms come back from a mixed set', () {
      final fresh = _alarm(id: 'fresh');
      final stale = _alarm(id: 'stale');
      final off = _alarm(id: 'off', isEnabled: false);

      final result = alarmsNeedingReschedule(
        alarms: [fresh, stale, off],
        scheduled: {
          AlarmService.alarmIntId('fresh'): now.add(const Duration(hours: 5)),
          AlarmService.alarmIntId('stale'): now.subtract(const Duration(days: 1)),
        },
        now: now,
      );

      expect(result.map((a) => a.id), ['stale']);
    });
  });
}
