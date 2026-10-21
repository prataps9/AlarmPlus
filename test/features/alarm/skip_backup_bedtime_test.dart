import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/services/backup_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/sleep/models/bedtime_schedule.dart';
import 'package:alarm_plus/shared/widgets/alarm_card.dart';

AlarmModel _weekday({DateTime? skip}) => AlarmModel(
      id: 'w',
      time: const TimeOfDay(hour: 7, minute: 0),
      label: 'Work',
      tag: '',
      sound: 'default',
      isEnabled: true,
      repeatDays: const [1, 2, 3, 4, 5],
      skipDate: skip,
    );

void main() {
  // Friday 2026-09-25, 21:00.
  final fridayNight = DateTime(2026, 9, 25, 21);

  group('skip next occurrence', () {
    test('skipping jumps to the following occurrence', () {
      final a = _weekday().skipNext(fridayNight);
      expect(a.skipDate, DateTime(2026, 9, 28)); // Monday
      expect(a.nextDateTimeFrom(fridayNight), DateTime(2026, 9, 29, 7)); // Tuesday
      expect(a.isSkippingFrom(fridayNight), isTrue);
    });

    test('once the skipped day has passed it has no effect', () {
      final a = _weekday(skip: DateTime(2026, 9, 28));
      final tuesdayNight = DateTime(2026, 9, 29, 21);
      expect(a.isSkippingFrom(tuesdayNight), isFalse);
      expect(a.nextDateTimeFrom(tuesdayNight), DateTime(2026, 9, 30, 7));
    });

    test('un-skip and persistence', () {
      final a = _weekday().skipNext(fridayNight);
      expect(a.copyWith(skipDate: null).nextDateTimeFrom(fridayNight), DateTime(2026, 9, 28, 7));
      expect(AlarmModel.fromMap(a.toMap()).skipDate, DateTime(2026, 9, 28));
      expect(AlarmModel.fromMap(_weekday().toMap()).skipDate, isNull);
    });

    testWidgets('card offers Skip next and shows the skipped day', (tester) async {
      bool? skipped;
      Widget card(AlarmModel a) => MaterialApp(
            home: Scaffold(
              body: AlarmCard(alarm: a, onToggle: (_) {}, onSkipNext: (v) => skipped = v),
            ),
          );
      await tester.pumpWidget(card(_weekday()));
      await tester.tap(find.text('Skip next'));
      expect(skipped, isTrue);

      final future = DateTime.now().add(const Duration(days: 3));
      await tester.pumpWidget(card(_weekday(skip: DateTime(future.year, future.month, future.day))));
      expect(find.textContaining('Skips '), findsOneWidget);
      await tester.tap(find.byTooltip('Undo skip'));
      expect(skipped, isFalse);
    });
  });

  test('bedtime works back from the next alarm and the goal', () {
    expect(
      BedtimeSchedule.bedtimeFor(DateTime(2026, 9, 26, 6, 30), 8 * 60),
      DateTime(2026, 9, 25, 22, 30),
    );
    final s = BedtimeSchedule.fromJson(const {'bedtimeHour': 23, 'bedtimeMinute': 0});
    expect(s.sleepGoalMinutes, BedtimeSchedule.defaultSleepGoalMinutes);
    expect(BedtimeSchedule.fromJson(s.copyWith(sleepGoalMinutes: 450).toJson()).sleepGoalMinutes, 450);
  });

  group('BackupCodec', () {
    final data = BackupData(
      alarms: [_weekday(skip: DateTime(2026, 9, 28))],
      settings: const {
        'onboarding_complete': true,
        'smart.xp': 1250,
        'clock.world.cities': ['Tokyo', 'London'],
        'premium.lifetime.unlocked': true,
        'alarm.native_ringtone.123': 'content://x',
        'clock.timer': '{}',
      },
    );

    test('round-trips alarms and portable settings', () {
      final back = BackupCodec.decode(BackupCodec.encode(data));
      expect(back.alarms.single.label, 'Work');
      expect(back.alarms.single.skipDate, DateTime(2026, 9, 28));
      expect(back.settings['smart.xp'], 1250);
      expect(back.settings['clock.world.cities'], ['Tokyo', 'London']);
      expect(back.createdAt, isNotNull);
    });

    test('never carries the Pro unlock or device/ephemeral state', () {
      final json = BackupCodec.encode(data);
      expect(json, isNot(contains('premium.')));
      expect(json, isNot(contains('native_ringtone')));
      expect(json, isNot(contains('clock.timer')));
      // Even a hand-edited file can't grant Pro on restore.
      final forged = json.replaceFirst('"settings": {', '"settings": {"premium.lifetime.unlocked": true,');
      expect(BackupCodec.decode(forged).settings.containsKey('premium.lifetime.unlocked'), isFalse);
    });

    test('rejects files that are not Alarm+ backups', () {
      expect(() => BackupCodec.decode('not json'), throwsFormatException);
      expect(() => BackupCodec.decode('{"app":"other","version":1}'), throwsFormatException);
      expect(() => BackupCodec.decode('{"app":"alarm_plus","version":99}'), throwsFormatException);
    });

    test('skips an unreadable alarm instead of failing the restore', () {
      const raw = '{"app":"alarm_plus","version":1,"alarms":[{"id":"x"}],"settings":{}}';
      expect(BackupCodec.decode(raw).alarms, isEmpty);
    });
  });
}
