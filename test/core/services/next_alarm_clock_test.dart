import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/services/next_alarm_clock_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';

AlarmModel _alarm({
  required String id,
  required int hour,
  int minute = 0,
  bool isEnabled = true,
  List<int> repeatDays = const [],
}) {
  return AlarmModel(
    id: id,
    time: TimeOfDay(hour: hour, minute: minute),
    label: 'Wake',
    repeatDays: repeatDays,
    isEnabled: isEnabled,
    tag: '',
    sound: 'default',
  );
}

void main() {
  // A Saturday, mid-morning.
  final now = DateTime(2026, 3, 14, 9, 0);

  group('soonestEnabledAlarm', () {
    test('returns null when there are no alarms', () {
      expect(soonestEnabledAlarm(const [], now), isNull);
    });

    test('returns null when every alarm is disabled', () {
      expect(
        soonestEnabledAlarm(
          [_alarm(id: 'a', hour: 7, isEnabled: false)],
          now,
        ),
        isNull,
      );
    });

    test('picks the earliest upcoming occurrence', () {
      final result = soonestEnabledAlarm(
        [
          _alarm(id: 'late', hour: 23),
          _alarm(id: 'soon', hour: 18),
          _alarm(id: 'later-still', hour: 21),
        ],
        now,
      );

      expect(result, DateTime(2026, 3, 14, 18, 0));
    });

    test('ignores disabled alarms even when they would be sooner', () {
      final result = soonestEnabledAlarm(
        [
          _alarm(id: 'off', hour: 10, isEnabled: false),
          _alarm(id: 'on', hour: 20),
        ],
        now,
      );

      expect(result, DateTime(2026, 3, 14, 20, 0));
    });

    test('a time already past today rolls to tomorrow', () {
      final result = soonestEnabledAlarm(
        [_alarm(id: 'a', hour: 7)],
        now,
      );

      expect(result, DateTime(2026, 3, 15, 7, 0));
    });
  });
}
