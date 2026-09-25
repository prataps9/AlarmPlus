import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('streak counts days, not dismissals', () {
    test('two dismissals on the same day only extend the streak once',
        () async {
      await SmartAlarmService.recordDismissed();
      final second = await SmartAlarmService.recordDismissed();

      expect(second.stats.currentStreak, 1);
      expect(second.stats.dismissCount, 2);
      // XP is still earned for every wake-up.
      expect(second.xpEarned, greaterThan(0));
    });

    test('a later miss on the same day keeps the day marked as won',
        () async {
      await SmartAlarmService.recordDismissed();
      await SmartAlarmService.recordMissed();

      final history = await SmartAlarmService.getCalendarHistory();
      expect(history.values.single, isTrue);
    });
  });

  group('streak freezes', () {
    test('a miss with no freeze resets the streak', () async {
      await SmartAlarmService.recordDismissed();
      final saved = await SmartAlarmService.recordMissed();

      expect(saved, isFalse);
      expect((await SmartAlarmService.getStats()).currentStreak, 0);
    });

    test('an owned freeze is spent to keep the streak alive', () async {
      SharedPreferences.setMockInitialValues({'smart.streak.freezes': 1});
      await SmartAlarmService.recordDismissed();

      final saved = await SmartAlarmService.recordMissed();

      expect(saved, isTrue);
      expect((await SmartAlarmService.getStats()).currentStreak, 1);
      expect(await SmartAlarmService.getStreakFreezesOwned(), 0);
    });

    test('repeated misses on one day spend only one freeze', () async {
      SharedPreferences.setMockInitialValues({'smart.streak.freezes': 2});
      await SmartAlarmService.recordDismissed();

      await SmartAlarmService.recordMissed();
      await SmartAlarmService.recordMissed();

      expect(await SmartAlarmService.getStreakFreezesOwned(), 1);
      expect((await SmartAlarmService.getStats()).currentStreak, 1);
    });

    test('no freeze is spent when there is no streak to protect', () async {
      SharedPreferences.setMockInitialValues({'smart.streak.freezes': 1});
      await SmartAlarmService.recordMissed();
      expect(await SmartAlarmService.getStreakFreezesOwned(), 1);
    });
  });

  group('AlarmModel.nextDateTimeFrom', () {
    test('rolling to the next day keeps the wall-clock time', () {
      final alarm = AlarmModel(
        id: 'a',
        time: const TimeOfDay(hour: 6, minute: 30),
        label: '',
        tag: '',
        sound: 'default',
        isEnabled: true,
        repeatDays: const [1], // Mondays
      );
      // Friday evening → the following Monday, across a month boundary.
      final next = alarm.nextDateTimeFrom(DateTime(2026, 10, 30, 20));
      expect(next, DateTime(2026, 11, 2, 6, 30));
    });
  });
}
