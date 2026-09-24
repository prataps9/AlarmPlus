import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/celebration_event.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';

/// Something the user did today that daily quests can count.
enum QuestMetric {
  xp,
  noSnoozeWake,
  missions,
  sleepLog,
  moodCheckIn,
  wakeScore80,
  dailyGoal,
}

/// A preset daily XP target, in the spirit of Duolingo's Casual → Intense.
enum DailyGoal {
  casual(50, 'Casual'),
  regular(100, 'Regular'),
  serious(150, 'Serious'),
  intense(250, 'Intense');

  const DailyGoal(this.xp, this.label);

  final int xp;
  final String label;

  static DailyGoal fromName(String? name) =>
      DailyGoal.values.firstWhere((g) => g.name == name, orElse: () => DailyGoal.regular);
}

class QuestDefinition {
  const QuestDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.metric,
    required this.target,
    required this.gems,
  });

  final String id;
  final String title;
  final String icon;
  final QuestMetric metric;
  final int target;
  final int gems;
}

class QuestProgress {
  const QuestProgress({required this.quest, required this.progress, required this.completed});

  final QuestDefinition quest;
  final int progress;
  final bool completed;

  double get fraction => (progress / quest.target).clamp(0.0, 1.0);
}

class DailyProgress {
  const DailyProgress({
    required this.goal,
    required this.xpToday,
    required this.quests,
    required this.gems,
    required this.boostUntil,
    required this.weekXp,
  });

  final DailyGoal goal;
  final int xpToday;
  final List<QuestProgress> quests;
  final int gems;

  /// When the active double-XP boost ends, or null if none is running.
  final DateTime? boostUntil;

  /// XP earned on each of the last 7 days, oldest first; the last entry is today.
  final List<int> weekXp;

  bool get goalMet => xpToday >= goal.xp;
  double get goalFraction => (xpToday / goal.xp).clamp(0.0, 1.0);
  int get questsCompleted => quests.where((q) => q.completed).length;
  bool get boostActive => boostUntil != null;
}

enum ShopItem {
  streakFreeze(150, 'Streak Freeze', 'Protects your streak the next time you miss an alarm.'),
  xpBoost(100, 'Double XP', 'Earn 2× XP from everything for the next 30 minutes.'),
  streakRepair(300, 'Streak Repair', 'Bring back the streak you just lost.');

  const ShopItem(this.price, this.title, this.description);

  final int price;
  final String title;
  final String description;
}

enum PurchaseResult { ok, notEnoughGems, maxOwned, unavailable }

/// Duolingo-style daily loop layered on top of [SmartAlarmService]'s XP:
/// a daily XP goal, three rotating daily quests that pay out gems, a gem
/// shop, and a timed double-XP boost.
///
/// Everything is keyed by local calendar day, so the day's ledger resets at
/// midnight without any scheduled job.
class ProgressionService {
  ProgressionService._();

  static const _gemsKey = 'progress.gems';
  static const _goalKey = 'progress.daily_goal';
  static const _dayKey = 'progress.day';
  static const _xpHistoryKey = 'progress.xp_history';
  static const _boostUntilKey = 'progress.boost_until';

  static const maxStreakFreezes = 2;
  static const boostMultiplier = 2;
  static const boostDuration = Duration(minutes: 30);
  static const allQuestsBonusGems = 20;

  /// Overridable so tests can move between days.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static const List<QuestDefinition> xpQuests = [
    QuestDefinition(id: 'xp_100', title: 'Earn 100 XP', icon: '⚡', metric: QuestMetric.xp, target: 100, gems: 10),
    QuestDefinition(id: 'xp_200', title: 'Earn 200 XP', icon: '⚡', metric: QuestMetric.xp, target: 200, gems: 20),
  ];

  static const List<QuestDefinition> habitQuests = [
    QuestDefinition(id: 'no_snooze', title: 'Wake up without snoozing', icon: '⏰', metric: QuestMetric.noSnoozeWake, target: 1, gems: 15),
    QuestDefinition(id: 'missions_2', title: 'Complete 2 morning missions', icon: '🌅', metric: QuestMetric.missions, target: 2, gems: 10),
    QuestDefinition(id: 'missions_3', title: 'Complete 3 morning missions', icon: '🌅', metric: QuestMetric.missions, target: 3, gems: 15),
    QuestDefinition(id: 'sleep_log', title: "Log how you slept", icon: '📓', metric: QuestMetric.sleepLog, target: 1, gems: 10),
    QuestDefinition(id: 'mood', title: 'Do a mood check-in', icon: '😊', metric: QuestMetric.moodCheckIn, target: 1, gems: 10),
    QuestDefinition(id: 'wake_80', title: 'Score 80+ on a wake-up', icon: '🏆', metric: QuestMetric.wakeScore80, target: 1, gems: 20),
    QuestDefinition(id: 'daily_goal', title: 'Hit your daily XP goal', icon: '🎯', metric: QuestMetric.dailyGoal, target: 1, gems: 15),
  ];

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Today's three quests: one XP quest plus two habit quests, picked with a
  /// date-seeded RNG so they're stable all day and change at midnight.
  static List<QuestDefinition> questsFor(DateTime day) {
    final seed = day.year * 10000 + day.month * 100 + day.day;
    final rng = math.Random(seed);
    final xpQuest = xpQuests[rng.nextInt(xpQuests.length)];
    final pool = [...habitQuests]..shuffle(rng);
    final picked = <QuestDefinition>[];
    for (final q in pool) {
      // Two mission quests on one day would be the same task twice.
      if (picked.any((p) => p.metric == q.metric)) continue;
      picked.add(q);
      if (picked.length == 2) break;
    }
    return [xpQuest, ...picked];
  }

  // ─── Day ledger ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _loadDay(SharedPreferences prefs) async {
    final today = dateKey(clock());
    final raw = prefs.getString(_dayKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (map['date'] == today) return map;
      } catch (e) {
        debugPrint('Failed to parse progression day: $e');
      }
    }
    return {
      'date': today,
      'counters': <String, dynamic>{},
      'questsDone': <dynamic>[],
      'goalMet': false,
      'allQuestsRewarded': false,
    };
  }

  static Future<void> _saveDay(SharedPreferences prefs, Map<String, dynamic> day) async {
    await prefs.setString(_dayKey, jsonEncode(day));
  }

  static int _counter(Map<String, dynamic> day, QuestMetric metric) =>
      ((day['counters'] as Map)[metric.name] as num?)?.toInt() ?? 0;

  /// Counts [amount] of [metric] toward today's quests and goal, paying out
  /// gems for anything that completes.
  static Future<void> recordActivity(QuestMetric metric, [int amount = 1]) async {
    if (amount <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final day = await _loadDay(prefs);
    final counters = Map<String, dynamic>.from(day['counters'] as Map);
    counters[metric.name] = _counter(day, metric) + amount;
    day['counters'] = counters;

    if (metric == QuestMetric.xp) {
      await _addHistoryXp(prefs, amount);
      final goal = await getDailyGoal();
      if (day['goalMet'] != true && (counters[metric.name] as int) >= goal.xp) {
        day['goalMet'] = true;
        counters[QuestMetric.dailyGoal.name] = 1;
        SmartAlarmService.celebrate(CelebrationEvent.dailyGoalMet(goal.xp));
      }
    }

    await _settleQuests(prefs, day);
    await _saveDay(prefs, day);
  }

  static Future<void> _settleQuests(SharedPreferences prefs, Map<String, dynamic> day) async {
    final done = List<String>.from(day['questsDone'] as List);
    final quests = questsFor(clock());
    var gems = 0;
    for (final q in quests) {
      if (done.contains(q.id)) continue;
      if (_counter(day, q.metric) >= q.target) {
        done.add(q.id);
        gems += q.gems;
        SmartAlarmService.celebrate(CelebrationEvent.questCompleted(q.title, q.gems));
      }
    }
    if (done.length >= quests.length && day['allQuestsRewarded'] != true) {
      day['allQuestsRewarded'] = true;
      gems += allQuestsBonusGems;
      SmartAlarmService.celebrate(CelebrationEvent.allQuestsCompleted(allQuestsBonusGems));
    }
    day['questsDone'] = done;
    if (gems > 0) await addGems(gems);
  }

  static Future<void> _addHistoryXp(SharedPreferences prefs, int amount) async {
    final history = await _loadXpHistory(prefs);
    final key = dateKey(clock());
    history[key] = (history[key] ?? 0) + amount;
    if (history.length > 30) {
      final sorted = history.keys.toList()..sort();
      for (final k in sorted.take(history.length - 30)) {
        history.remove(k);
      }
    }
    await prefs.setString(_xpHistoryKey, jsonEncode(history));
  }

  static Future<Map<String, int>> _loadXpHistory(SharedPreferences prefs) async {
    final raw = prefs.getString(_xpHistoryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<DailyProgress> getDailyProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final day = await _loadDay(prefs);
    final done = List<String>.from(day['questsDone'] as List);
    final now = clock();
    final history = await _loadXpHistory(prefs);
    return DailyProgress(
      goal: await getDailyGoal(),
      xpToday: _counter(day, QuestMetric.xp),
      quests: [
        for (final q in questsFor(now))
          QuestProgress(
            quest: q,
            progress: math.min(_counter(day, q.metric), q.target),
            completed: done.contains(q.id),
          ),
      ],
      gems: await getGems(),
      boostUntil: await getBoostUntil(),
      weekXp: [
        for (var i = 6; i >= 0; i--)
          history[dateKey(DateTime(now.year, now.month, now.day - i))] ?? 0,
      ],
    );
  }

  // ─── Daily goal ────────────────────────────────────────────────────────────

  static Future<DailyGoal> getDailyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyGoal.fromName(prefs.getString(_goalKey));
  }

  static Future<void> setDailyGoal(DailyGoal goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalKey, goal.name);
    // Lowering the goal below what's already earned today should count now,
    // not wait for the next XP.
    final day = await _loadDay(prefs);
    if (day['goalMet'] != true && _counter(day, QuestMetric.xp) >= goal.xp) {
      day['goalMet'] = true;
      final counters = Map<String, dynamic>.from(day['counters'] as Map);
      counters[QuestMetric.dailyGoal.name] = 1;
      day['counters'] = counters;
      SmartAlarmService.celebrate(CelebrationEvent.dailyGoalMet(goal.xp));
      await _settleQuests(prefs, day);
      await _saveDay(prefs, day);
    }
  }

  // ─── Gems ──────────────────────────────────────────────────────────────────

  static Future<int> getGems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_gemsKey) ?? 0;
  }

  static Future<int> addGems(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final next = math.max(0, (prefs.getInt(_gemsKey) ?? 0) + amount);
    await prefs.setInt(_gemsKey, next);
    return next;
  }

  // ─── XP boost ──────────────────────────────────────────────────────────────

  static Future<DateTime?> getBoostUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_boostUntilKey);
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null || !until.isAfter(clock())) return null;
    return until;
  }

  /// Starts (or extends, if one is already running) a double-XP boost.
  static Future<DateTime> activateBoost([Duration duration = boostDuration]) async {
    final prefs = await SharedPreferences.getInstance();
    final start = await getBoostUntil() ?? clock();
    final until = start.add(duration);
    await prefs.setString(_boostUntilKey, until.toIso8601String());
    return until;
  }

  /// [amount] after the active boost, if any. Penalties are never boosted.
  static Future<int> boosted(int amount) async {
    if (amount <= 0) return amount;
    return await getBoostUntil() != null ? amount * boostMultiplier : amount;
  }

  // ─── Shop ──────────────────────────────────────────────────────────────────

  static Future<PurchaseResult> purchase(ShopItem item) async {
    final gems = await getGems();
    switch (item) {
      case ShopItem.streakFreeze:
        if (await SmartAlarmService.getStreakFreezesOwned() >= maxStreakFreezes) {
          return PurchaseResult.maxOwned;
        }
      case ShopItem.streakRepair:
        if (await SmartAlarmService.getRepairableStreak() == null) {
          return PurchaseResult.unavailable;
        }
      case ShopItem.xpBoost:
        break;
    }
    if (gems < item.price) return PurchaseResult.notEnoughGems;

    await addGems(-item.price);
    switch (item) {
      case ShopItem.streakFreeze:
        await SmartAlarmService.addStreakFreeze();
      case ShopItem.streakRepair:
        await SmartAlarmService.repairStreak();
      case ShopItem.xpBoost:
        await activateBoost();
    }
    return PurchaseResult.ok;
  }
}
