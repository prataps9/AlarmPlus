import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/celebration_event.dart';
import 'package:alarm_plus/core/services/progression_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';

void main() {
  var now = DateTime(2026, 9, 24, 8);
  late List<CelebrationEvent> events;
  late StreamSubscription<CelebrationEvent> sub;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 9, 24, 8);
    ProgressionService.clock = () => now;
    events = [];
    sub = SmartAlarmService.celebrationEvents.listen(events.add);
  });

  tearDown(() async {
    await sub.cancel();
    ProgressionService.clock = DateTime.now;
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('questsFor', () {
    test('picks one XP quest and two habit quests with distinct metrics', () {
      for (var i = 0; i < 60; i++) {
        final quests = ProgressionService.questsFor(DateTime(2026, 1, 1 + i));
        expect(quests, hasLength(3));
        expect(quests.first.metric, QuestMetric.xp);
        expect(quests.map((q) => q.metric).toSet(), hasLength(3));
      }
    });

    test('is stable within a day and rotates across days', () {
      final morning = ProgressionService.questsFor(DateTime(2026, 9, 24, 6));
      final night = ProgressionService.questsFor(DateTime(2026, 9, 24, 23));
      expect(morning.map((q) => q.id), night.map((q) => q.id));

      final distinct = {
        for (var i = 0; i < 14; i++)
          ProgressionService.questsFor(DateTime(2026, 9, 1 + i)).map((q) => q.id).join(','),
      };
      expect(distinct.length, greaterThan(1));
    });
  });

  group('daily goal', () {
    test('awarded XP counts toward the goal and celebrates once when met', () async {
      await SmartAlarmService.awardXp(60);
      var progress = await ProgressionService.getDailyProgress();
      expect(progress.xpToday, 60);
      expect(progress.goalMet, isFalse);

      await SmartAlarmService.awardXp(50);
      await SmartAlarmService.awardXp(50);
      await flush();
      progress = await ProgressionService.getDailyProgress();
      expect(progress.xpToday, 160);
      expect(progress.goalMet, isTrue);
      expect(events.where((e) => e.kind == CelebrationKind.dailyGoalMet), hasLength(1));
    });

    test('snooze penalties do not take XP off the daily goal', () async {
      await SmartAlarmService.awardXp(40);
      await SmartAlarmService.addXp(-10);
      expect((await ProgressionService.getDailyProgress()).xpToday, 40);
    });

    test('resets at midnight and remembers the week', () async {
      await SmartAlarmService.awardXp(120);
      now = DateTime(2026, 9, 25, 7);
      await SmartAlarmService.awardXp(30);

      final progress = await ProgressionService.getDailyProgress();
      expect(progress.xpToday, 30);
      expect(progress.weekXp, [0, 0, 0, 0, 0, 120, 30]);
    });

    test('lowering the goal below today\'s XP counts it as met', () async {
      await SmartAlarmService.awardXp(60);
      await ProgressionService.setDailyGoal(DailyGoal.casual);
      await flush();
      expect((await ProgressionService.getDailyProgress()).goalMet, isTrue);
      expect(events.any((e) => e.kind == CelebrationKind.dailyGoalMet), isTrue);
    });
  });

  group('quests', () {
    test('pay out gems once each, plus a bonus for clearing all three', () async {
      final quests = ProgressionService.questsFor(now);
      for (final q in quests) {
        await ProgressionService.recordActivity(q.metric, q.target);
      }
      // Doing it all again the same day pays nothing more.
      for (final q in quests) {
        await ProgressionService.recordActivity(q.metric, q.target);
      }
      await flush();

      final expected = quests.fold<int>(0, (sum, q) => sum + q.gems) +
          ProgressionService.allQuestsBonusGems;
      final progress = await ProgressionService.getDailyProgress();
      expect(progress.gems, expected);
      expect(progress.questsCompleted, 3);
      expect(events.where((e) => e.kind == CelebrationKind.questCompleted), hasLength(3));
      expect(events.where((e) => e.kind == CelebrationKind.allQuestsCompleted), hasLength(1));
    });

    test('progress is capped at the target', () async {
      final xpQuest = ProgressionService.questsFor(now).first;
      await ProgressionService.recordActivity(QuestMetric.xp, xpQuest.target * 3);
      final progress = await ProgressionService.getDailyProgress();
      expect(progress.quests.first.progress, xpQuest.target);
      expect(progress.quests.first.fraction, 1.0);
    });
  });

  group('XP boost', () {
    test('doubles gains while active and stops when it expires', () async {
      await ProgressionService.activateBoost();
      final boosted = await SmartAlarmService.awardXp(25);
      expect(boosted.earned, 50);
      expect(await SmartAlarmService.getXp(), 50);

      now = now.add(ProgressionService.boostDuration + const Duration(seconds: 1));
      final plain = await SmartAlarmService.awardXp(25);
      expect(plain.earned, 25);
    });

    test('never doubles a penalty', () async {
      await ProgressionService.activateBoost();
      expect(await ProgressionService.boosted(-10), -10);
    });

    test('buying again extends rather than restarts the boost', () async {
      final first = await ProgressionService.activateBoost();
      final second = await ProgressionService.activateBoost();
      expect(second.difference(first), ProgressionService.boostDuration);
    });
  });

  group('shop', () {
    test('refuses purchases the user cannot afford', () async {
      expect(await ProgressionService.purchase(ShopItem.xpBoost), PurchaseResult.notEnoughGems);
      expect(await ProgressionService.getBoostUntil(), isNull);
    });

    test('sells streak freezes up to the cap', () async {
      await ProgressionService.addGems(1000);
      expect(await ProgressionService.purchase(ShopItem.streakFreeze), PurchaseResult.ok);
      expect(await ProgressionService.purchase(ShopItem.streakFreeze), PurchaseResult.ok);
      expect(await ProgressionService.purchase(ShopItem.streakFreeze), PurchaseResult.maxOwned);
      expect(await SmartAlarmService.getStreakFreezesOwned(), 2);
      expect(await ProgressionService.getGems(), 1000 - 2 * ShopItem.streakFreeze.price);
    });

    test('streak repair is unavailable with no lost streak', () async {
      await ProgressionService.addGems(1000);
      expect(await ProgressionService.purchase(ShopItem.streakRepair), PurchaseResult.unavailable);
      expect(await ProgressionService.getGems(), 1000);
    });
  });

  group('streak protection', () {
    Future<void> buildStreak(int days) async {
      for (var i = 0; i < days; i++) {
        await SmartAlarmService.recordDismissed();
      }
    }

    test('a freeze saves the streak, and only one is spent per day', () async {
      await buildStreak(3);
      await SmartAlarmService.addStreakFreeze();
      await SmartAlarmService.addStreakFreeze();

      expect(await SmartAlarmService.recordMissed(), isTrue);
      // The recovery backup ringing out as well shouldn't cost a second one.
      expect(await SmartAlarmService.recordMissed(), isTrue);
      await flush();

      final stats = await SmartAlarmService.getStats();
      expect(stats.currentStreak, 3);
      expect(stats.missedCount, 2);
      expect(await SmartAlarmService.getStreakFreezesOwned(), 1);
      expect(events.where((e) => e.kind == CelebrationKind.streakFrozen), hasLength(1));
    });

    test('without a freeze the streak resets and can be repaired', () async {
      await buildStreak(5);
      expect(await SmartAlarmService.recordMissed(), isFalse);
      expect((await SmartAlarmService.getStats()).currentStreak, 0);

      final lost = await SmartAlarmService.getRepairableStreak();
      expect(lost?.days, 5);

      await buildStreak(1);
      // The dismissals above also earn XP, which can finish quests and pay gems.
      final gemsBefore = await ProgressionService.addGems(ShopItem.streakRepair.price);
      expect(await ProgressionService.purchase(ShopItem.streakRepair), PurchaseResult.ok);

      final stats = await SmartAlarmService.getStats();
      expect(stats.currentStreak, 6);
      expect(stats.bestStreak, 6);
      expect(await SmartAlarmService.getRepairableStreak(), isNull);
      expect(await ProgressionService.getGems(), gemsBefore - ShopItem.streakRepair.price);
    });

    test('a streak lost too long ago is no longer repairable', () async {
      SharedPreferences.setMockInitialValues({
        'smart.streak.lost':
            '{"days":9,"at":"${DateTime.now().subtract(const Duration(hours: 49)).toIso8601String()}"}',
      });
      expect(await SmartAlarmService.getRepairableStreak(), isNull);
    });

    test('no-snooze wake-ups count toward the no-snooze quest metric', () async {
      await SmartAlarmService.recordDismissed(hadSnooze: true);
      await SmartAlarmService.recordDismissed();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('progress.day'), contains('"noSnoozeWake":1'));
    });
  });
}
