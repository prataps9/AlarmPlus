import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/shared/models/challenge_type.dart';

AlarmModel _buildMinimalAlarm() {
  return AlarmModel(
    id: 'alarm-1',
    time: const TimeOfDay(hour: 6, minute: 30),
    label: 'Wake up',
    repeatDays: const [1, 2, 3, 4, 5],
    isEnabled: true,
    tag: 'Steady wake',
    sound: 'default',
  );
}

void main() {
  group('AlarmModel map round-trip', () {
    test('minimal alarm survives toMap/fromMap', () {
      final original = _buildMinimalAlarm();
      final restored = AlarmModel.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.time.hour, original.time.hour);
      expect(restored.time.minute, original.time.minute);
      expect(restored.label, original.label);
      expect(restored.repeatDays, original.repeatDays);
      expect(restored.isEnabled, original.isEnabled);
      expect(restored.tag, original.tag);
      expect(restored.sound, original.sound);
    });

    test('full-featured alarm survives toMap/fromMap', () {
      final original = _buildMinimalAlarm().copyWith(
        challengeType: ChallengeType.math,
        questMode: true,
        questSteps: [ChallengeType.math, ChallengeType.stepCounter],
        wakeUpCheckEnabled: true,
        wakeUpCheckMinutes: 15,
        hardcoreMode: true,
      );

      final restored = AlarmModel.fromMap(original.toMap());

      expect(restored.challengeType, ChallengeType.math);
      expect(restored.questMode, true);
      expect(restored.questSteps, [ChallengeType.math, ChallengeType.stepCounter]);
      expect(restored.wakeUpCheckEnabled, true);
      expect(restored.wakeUpCheckMinutes, 15);
      expect(restored.hardcoreMode, true);
    });

    test('fromMap fills defaults for missing optional keys', () {
      final restored = AlarmModel.fromMap({
        'id': 'alarm-2',
        'hour': 7,
        'minute': 0,
      });

      expect(restored.personality, 'gentle');
      expect(restored.sound, 'default');
      expect(restored.stepGoal, 20);
      expect(restored.wakeUpCheckMinutes, 10);
      expect(restored.hardcoreMode, false);
      expect(restored.tag, 'Steady wake');
    });

    test('fromMap falls back to legacy aiTag when tag is missing', () {
      final restored = AlarmModel.fromMap({
        'id': 'alarm-3',
        'hour': 8,
        'minute': 15,
        'aiTag': 'Commute-friendly wake',
      });

      expect(restored.tag, 'Commute-friendly wake');
    });

    test('fromMap throws when required fields are missing', () {
      expect(() => AlarmModel.fromMap(const {}), throwsFormatException);
    });
  });

  group('repeatLabel', () {
    test('classifies common repeat-day patterns', () {
      expect(_buildMinimalAlarm().copyWith(repeatDays: [1, 2, 3, 4, 5, 6, 7]).repeatLabel, 'Daily');
      expect(_buildMinimalAlarm().copyWith(repeatDays: [1, 2, 3, 4, 5]).repeatLabel, 'Weekdays');
      expect(_buildMinimalAlarm().copyWith(repeatDays: [6, 7]).repeatLabel, 'Weekends');
      expect(_buildMinimalAlarm().copyWith(repeatDays: [1, 3, 5]).repeatLabel, 'Custom');
    });
  });

  group('copyWith sentinel behavior', () {
    test('no-arg copyWith preserves nullable sentinel-guarded fields', () {
      final withChallenge = _buildMinimalAlarm().copyWith(challengeType: ChallengeType.math);
      final unchanged = withChallenge.copyWith();
      expect(unchanged.challengeType, ChallengeType.math);
    });

    test('explicit null clears a sentinel-guarded field', () {
      final withChallenge = _buildMinimalAlarm().copyWith(challengeType: ChallengeType.math);
      final cleared = withChallenge.copyWith(challengeType: null);
      expect(cleared.challengeType, isNull);
    });
  });
}
