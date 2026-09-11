import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/services/smart_alarm_service.dart';

void main() {
  group('levelFromXp', () {
    test('boundaries around the 500 XP per level threshold', () {
      expect(SmartAlarmService.levelFromXp(0), 0);
      expect(SmartAlarmService.levelFromXp(499), 0);
      expect(SmartAlarmService.levelFromXp(500), 1);
      expect(SmartAlarmService.levelFromXp(2500), 5);
    });
  });

  group('levelLabel', () {
    test('maps level ranges to the correct label', () {
      expect(SmartAlarmService.levelLabel(0), 'Sleeper');
      expect(SmartAlarmService.levelLabel(500), 'Early Bird'); // level 1
      expect(SmartAlarmService.levelLabel(1000), 'Dawn Warrior'); // level 2
      expect(SmartAlarmService.levelLabel(1500), 'Dawn Warrior'); // level 3, still Dawn Warrior
      expect(SmartAlarmService.levelLabel(2000), 'Circadian Master'); // level 4
      expect(SmartAlarmService.levelLabel(4500), 'Circadian Master'); // level 9
      expect(SmartAlarmService.levelLabel(5000), 'Flow Legend'); // level 10
    });
  });

  group('xpToNextLevel', () {
    test('returns XP remaining until the next level boundary', () {
      expect(SmartAlarmService.xpToNextLevel(0), 500);
      expect(SmartAlarmService.xpToNextLevel(250), 250);
      expect(SmartAlarmService.xpToNextLevel(500), 500);
    });
  });

  group('xpLevelProgress', () {
    test('returns fractional progress toward the next level', () {
      expect(SmartAlarmService.xpLevelProgress(0), 0.0);
      expect(SmartAlarmService.xpLevelProgress(250), 0.5);
      expect(SmartAlarmService.xpLevelProgress(499), closeTo(0.998, 0.001));
      expect(SmartAlarmService.xpLevelProgress(500), 0.0);
    });
  });

  group('calculateWakeScore', () {
    test('awards full points for a perfect wake-up', () {
      final score = SmartAlarmService.calculateWakeScore(
        dismissSpeedSeconds: 30,
        wrongAnswers: 0,
        snoozeCount: 0,
        moodCheckInDoneToday: true,
      );
      expect(score.speedPoints, 25);
      expect(score.accuracyPoints, 25);
      expect(score.snoozePoints, 25);
      expect(score.moodPoints, 25);
      expect(score.total, 100);
    });

    test('deducts points for a slow, imperfect wake-up', () {
      final score = SmartAlarmService.calculateWakeScore(
        dismissSpeedSeconds: 90, // 2 extra 30s blocks past the 30s baseline
        wrongAnswers: 1,
        snoozeCount: 1,
        moodCheckInDoneToday: false,
      );
      expect(score.speedPoints, 15); // 25 - 2*5
      expect(score.accuracyPoints, 15);
      expect(score.snoozePoints, 15);
      expect(score.moodPoints, 0);
      expect(score.total, 45);
    });

    test('clamps speed points at zero rather than going negative', () {
      final score = SmartAlarmService.calculateWakeScore(
        dismissSpeedSeconds: 600,
        wrongAnswers: 3,
        snoozeCount: 3,
        moodCheckInDoneToday: false,
      );
      expect(score.speedPoints, 0);
      expect(score.accuracyPoints, 5);
      expect(score.snoozePoints, 0);
    });
  });

  group('WakeScore map round-trip', () {
    test('toMap/fromMap preserves all fields', () {
      final original = WakeScore(
        total: 82,
        speedPoints: 20,
        accuracyPoints: 25,
        snoozePoints: 25,
        moodPoints: 12,
        date: DateTime(2026, 5, 17, 7, 30),
      );

      final restored = WakeScore.fromMap(original.toMap());

      expect(restored.total, original.total);
      expect(restored.speedPoints, original.speedPoints);
      expect(restored.accuracyPoints, original.accuracyPoints);
      expect(restored.snoozePoints, original.snoozePoints);
      expect(restored.moodPoints, original.moodPoints);
      expect(restored.date, original.date);
    });
  });
}
