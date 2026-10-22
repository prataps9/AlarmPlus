import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/sleep/models/bedtime_schedule.dart';
import 'package:alarm_plus/features/sleep/services/bedtime_service.dart';

AlarmModel _alarm(String tag) => AlarmModel(
      id: 'x',
      time: const TimeOfDay(hour: 14, minute: 30),
      label: '',
      tag: tag,
      sound: 'default',
      isEnabled: true,
      repeatDays: const [],
    );

void main() {
  test('nap and arrival alarms are system alarms; user alarms are not', () {
    expect(_alarm(AlarmModel.napTag).isSystem, isTrue);
    expect(_alarm(AlarmModel.locationTag).isSystem, isTrue);
    expect(_alarm('Steady wake').isSystem, isFalse);
    expect(_alarm('').isSystem, isFalse);
  });

  group('bedtime reminder time', () {
    BedtimeSchedule bed(int h, int m, {int windDown = 30}) => BedtimeSchedule(
        targetBedtime: TimeOfDay(hour: h, minute: m), windDownMinutes: windDown);

    test('later today when it is still ahead', () {
      expect(BedtimeService.reminderTime(bed(22, 30), DateTime(2026, 10, 22, 20)),
          DateTime(2026, 10, 22, 22));
    });

    test('tomorrow, same wall-clock time, once it has passed', () {
      // The day before Europe's clocks go back: a 24-hour Duration landed an
      // hour off there; calendar fields keep 22:00.
      expect(BedtimeService.reminderTime(bed(22, 30), DateTime(2026, 10, 24, 23)),
          DateTime(2026, 10, 25, 22));
    });

    test('a wind-down that starts before midnight for a bedtime after it', () {
      expect(BedtimeService.reminderTime(bed(0, 15), DateTime(2026, 10, 22, 20)),
          DateTime(2026, 10, 22, 23, 45));
    });
  });
}
