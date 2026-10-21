import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/screens/alarms_screen.dart';

AlarmModel _alarm({List<int> days = const [1, 2, 3, 4, 5], DateTime? pausedUntil, bool on = true}) =>
    AlarmModel(
      id: 'p',
      time: const TimeOfDay(hour: 7, minute: 0),
      label: '',
      tag: '',
      sound: 'default',
      isEnabled: on,
      repeatDays: days,
      pausedUntil: pausedUntil,
    );

void main() {
  // Wednesday 22 Oct 2025, 09:00.
  final now = DateTime(2025, 10, 22, 9);

  group('pause until a date', () {
    test('no occurrence rings before the resume date', () {
      // Resume Monday 27 Oct: Thu 23 and Fri 24 are held back.
      final a = _alarm(pausedUntil: DateTime(2025, 10, 27));
      expect(a.nextDateTimeFrom(now), DateTime(2025, 10, 27, 7));
      expect(a.isPausedAt(now), isTrue);
    });

    test('resumes on the first repeat day on or after the date', () {
      // Resume Saturday: weekdays only, so Monday.
      final a = _alarm(pausedUntil: DateTime(2025, 10, 25));
      expect(a.nextDateTimeFrom(now), DateTime(2025, 10, 27, 7));
    });

    test('a pause that has ended has no effect', () {
      final a = _alarm(pausedUntil: DateTime(2025, 10, 20));
      expect(a.isPausedAt(now), isFalse);
      expect(a.nextDateTimeFrom(now), DateTime(2025, 10, 23, 7));
    });

    test('one-off alarms ignore a pause', () {
      final a = _alarm(days: const [], pausedUntil: DateTime(2025, 11, 1));
      expect(a.isPausedAt(now), isFalse);
      expect(a.nextDateTimeFrom(now), DateTime(2025, 10, 23, 7));
    });

    test('survives storage and backups', () {
      final a = _alarm(pausedUntil: DateTime(2025, 10, 27));
      expect(AlarmModel.fromMap(a.toMap()).pausedUntil, DateTime(2025, 10, 27));
      expect(AlarmModel.fromMap(_alarm().toMap()).pausedUntil, isNull);
    });

    test('copyWith can clear it', () {
      final a = _alarm(pausedUntil: DateTime(2025, 10, 27));
      expect(a.copyWith(pausedUntil: null).pausedUntil, isNull);
      expect(a.copyWith(label: 'x').pausedUntil, DateTime(2025, 10, 27));
    });

    test('banner shows the latest pause among enabled alarms', () {
      expect(pauseInForce([_alarm()], now), isNull);
      expect(
        pauseInForce([
          _alarm(pausedUntil: DateTime(2025, 10, 27)),
          _alarm(pausedUntil: DateTime(2025, 10, 30)),
          _alarm(pausedUntil: DateTime(2025, 11, 9), on: false),
        ], now),
        DateTime(2025, 10, 30),
      );
    });
  });
}
