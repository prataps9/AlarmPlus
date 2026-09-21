import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';

AlarmModel _alarm({
  required int hour,
  List<int> repeatDays = const [],
  DateTime? skipped,
}) {
  return AlarmModel(
    id: 'a',
    time: TimeOfDay(hour: hour, minute: 0),
    label: 'Wake',
    repeatDays: repeatDays,
    isEnabled: true,
    tag: '',
    sound: 'default',
    skippedOccurrence: skipped,
  );
}

void main() {
  // 2026-03-16 is a Monday.
  final monday9am = DateTime(2026, 3, 16, 9, 0);

  group('nextDateTimeFrom with a skipped occurrence', () {
    test('without a skip, returns the next occurrence as before', () {
      final alarm = _alarm(hour: 7, repeatDays: const [1, 2, 3, 4, 5]);

      expect(
        alarm.nextDateTimeFrom(monday9am),
        DateTime(2026, 3, 17, 7, 0), // Tuesday
      );
    });

    test('skipping the next weekday occurrence moves to the one after', () {
      final tuesday = DateTime(2026, 3, 17, 7, 0);
      final alarm = _alarm(
        hour: 7,
        repeatDays: const [1, 2, 3, 4, 5],
        skipped: tuesday,
      );

      expect(
        alarm.nextDateTimeFrom(monday9am),
        DateTime(2026, 3, 18, 7, 0), // Wednesday
      );
    });

    test('only one occurrence is skipped, not every future one', () {
      final tuesday = DateTime(2026, 3, 17, 7, 0);
      final alarm = _alarm(
        hour: 7,
        repeatDays: const [1, 2, 3, 4, 5],
        skipped: tuesday,
      );

      // Asking from after the skipped occurrence gives the normal schedule.
      expect(
        alarm.nextDateTimeFrom(DateTime(2026, 3, 18, 9, 0)),
        DateTime(2026, 3, 19, 7, 0), // Thursday
      );
    });

    test('skipping a weekend-only alarm jumps a whole week', () {
      // Saturday and Sunday.
      final saturday = DateTime(2026, 3, 21, 8, 0);
      final alarm = _alarm(
        hour: 8,
        repeatDays: const [6, 7],
        skipped: saturday,
      );

      expect(
        alarm.nextDateTimeFrom(monday9am),
        DateTime(2026, 3, 22, 8, 0), // Sunday, the next one along
      );
    });

    test('skipping a one-shot alarm pushes it to the following day', () {
      final tomorrow = DateTime(2026, 3, 17, 7, 0);
      final alarm = _alarm(hour: 7, skipped: tomorrow);

      expect(
        alarm.nextDateTimeFrom(monday9am),
        DateTime(2026, 3, 18, 7, 0),
      );
    });

    test('a skip that does not match the next occurrence is ignored', () {
      // A stale skip for an occurrence that has already gone by.
      final alarm = _alarm(
        hour: 7,
        repeatDays: const [1, 2, 3, 4, 5],
        skipped: DateTime(2026, 3, 9, 7, 0),
      );

      expect(
        alarm.nextDateTimeFrom(monday9am),
        DateTime(2026, 3, 17, 7, 0),
      );
    });
  });

  group('isSkippingNext', () {
    test('is false when nothing is skipped', () {
      expect(_alarm(hour: 7).isSkippingNext, isFalse);
    });

    test('is true while the skipped occurrence is still ahead', () {
      final alarm = _alarm(
        hour: 7,
        skipped: DateTime.now().add(const Duration(hours: 5)),
      );
      expect(alarm.isSkippingNext, isTrue);
    });

    test('is false once the skipped occurrence has passed', () {
      final alarm = _alarm(
        hour: 7,
        skipped: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(alarm.isSkippingNext, isFalse);
    });
  });

  group('round-trip', () {
    test('a skipped occurrence survives toMap/fromMap', () {
      final skipped = DateTime(2026, 3, 17, 7, 0);
      final alarm = _alarm(hour: 7, skipped: skipped);

      final restored = AlarmModel.fromMap(alarm.toMap());

      expect(restored.skippedOccurrence, skipped);
    });

    test('copyWith can clear the skip', () {
      final alarm = _alarm(hour: 7, skipped: DateTime(2026, 3, 17, 7, 0));

      expect(alarm.copyWith(skippedOccurrence: null).skippedOccurrence, isNull);
      // ...and leaves it alone when not mentioned.
      expect(alarm.copyWith(label: 'x').skippedOccurrence, isNotNull);
    });
  });
}
