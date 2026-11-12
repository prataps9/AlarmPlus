import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/services/system_alarm_request.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';

AlarmModel _alarm(int h, int m, {String label = '', List<int> days = const [], bool on = true, String tag = ''}) =>
    AlarmModel(
      id: 'x$h$m',
      time: TimeOfDay(hour: h, minute: m),
      label: label,
      tag: tag,
      sound: 'default',
      isEnabled: on,
      repeatDays: days,
    );

void main() {
  group('SET_ALARM parsing', () {
    test('a plain "set an alarm for 6:30" becomes a one-off', () {
      final r = SystemAlarmRequest.parse({'hour': 6, 'minute': 30})!;
      expect(r.time, const TimeOfDay(hour: 6, minute: 30));
      expect(r.label, '');
      expect(r.repeatDays, isEmpty);
    });

    test('Android numbers days Sunday = 1; the app numbers Monday = 1', () {
      expect(SystemAlarmRequest.appDay(1), 7); // Sunday
      expect(SystemAlarmRequest.appDay(2), 1); // Monday
      expect(SystemAlarmRequest.appDay(7), 6); // Saturday
      final weekdays = SystemAlarmRequest.parse(
          {'hour': 7, 'minute': 0, 'days': [2, 3, 4, 5, 6]})!;
      expect(weekdays.repeatDays, [1, 2, 3, 4, 5]);
      final weekend =
          SystemAlarmRequest.parse({'hour': 9, 'minute': 0, 'days': [7, 1]})!;
      expect(weekend.repeatDays, [6, 7]);
    });

    test('duplicate and out-of-range days are dropped', () {
      final r = SystemAlarmRequest.parse(
          {'hour': 7, 'minute': 0, 'days': [2, 2, 0, 9, -1]})!;
      expect(r.repeatDays, [1]);
    });

    test('impossible times are ignored, not clamped', () {
      expect(SystemAlarmRequest.parse({'hour': 24, 'minute': 0}), isNull);
      expect(SystemAlarmRequest.parse({'hour': -1, 'minute': 0}), isNull);
      expect(SystemAlarmRequest.parse({'hour': 7, 'minute': 75}), isNull);
      expect(SystemAlarmRequest.parse({'minute': 30}), isNull);
    });

    test('a missing minute means on the hour; the label is trimmed and capped', () {
      expect(SystemAlarmRequest.parse({'hour': 8})!.time,
          const TimeOfDay(hour: 8, minute: 0));
      expect(SystemAlarmRequest.parse({'hour': 8, 'message': '  Gym  '})!.label, 'Gym');
      final long = 'x' * 200;
      expect(SystemAlarmRequest.parse({'hour': 8, 'message': long})!.label.length, 60);
    });
  });

  group('not creating the same alarm twice', () {
    final request = SystemAlarmRequest.parse(
        {'hour': 6, 'minute': 30, 'message': 'Gym', 'days': [2, 3]})!;

    test('finds an identical enabled alarm', () {
      final existing = _alarm(6, 30, label: 'Gym', days: const [2, 1]);
      expect(request.findExisting([_alarm(7, 0), existing]), existing);
    });

    test('a different time, label, days, or a switched-off alarm does not count', () {
      expect(request.findExisting([_alarm(6, 31, label: 'Gym', days: const [1, 2])]), isNull);
      expect(request.findExisting([_alarm(6, 30, label: 'Run', days: const [1, 2])]), isNull);
      expect(request.findExisting([_alarm(6, 30, label: 'Gym', days: const [1])]), isNull);
      expect(request.findExisting([_alarm(6, 30, label: 'Gym', days: const [1, 2], on: false)]), isNull);
    });

    test('hidden system alarms (nap, arrival) never match', () {
      expect(
          request.findExisting([
            _alarm(6, 30, label: 'Gym', days: const [1, 2], tag: AlarmModel.napTag),
          ]),
          isNull);
    });
  });
}
