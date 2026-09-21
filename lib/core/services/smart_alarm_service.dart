import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:alarm_plus/core/services/celebration_event.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/missions/models/mission_model.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';
import 'package:alarm_plus/shared/models/day_type_profile.dart';

enum DismissChallengeType { none, math, memory, qr, steps }


class AlarmReliabilityStatus {
  const AlarmReliabilityStatus({
    required this.notificationsGranted,
    required this.exactAlarmGranted,
    required this.batteryOptimizationIgnored,
  });

  final bool notificationsGranted;
  final bool exactAlarmGranted;
  final bool batteryOptimizationIgnored;
}

class AlarmStats {
  const AlarmStats({
    required this.dismissCount,
    required this.snoozeCount,
    required this.missedCount,
    required this.currentStreak,
    required this.bestStreak,
    this.moodCheckInCount = 0,
  });

  final int dismissCount;
  final int snoozeCount;
  final int missedCount;
  final int currentStreak;
  final int bestStreak;
  final int moodCheckInCount;

  AlarmStats copyWith({
    int? dismissCount,
    int? snoozeCount,
    int? missedCount,
    int? currentStreak,
    int? bestStreak,
    int? moodCheckInCount,
  }) {
    return AlarmStats(
      dismissCount: dismissCount ?? this.dismissCount,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      missedCount: missedCount ?? this.missedCount,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      moodCheckInCount: moodCheckInCount ?? this.moodCheckInCount,
    );
  }
}

class DismissReward {
  const DismissReward({
    required this.xpEarned,
    required this.totalXp,
    required this.newlyUnlockedBadges,
    required this.stats,
    required this.wasNoSnooze,
    this.hitStreakMilestone,
    this.comebackBonus,
  });

  final int xpEarned;
  final int totalXp;
  final List<String> newlyUnlockedBadges;
  final AlarmStats stats;
  final bool wasNoSnooze;
  final int? hitStreakMilestone;
  final int? comebackBonus;
}

class MoodCheckIn {
  const MoodCheckIn({
    required this.energy,
    required this.mood,
    required this.sleepQuality,
    required this.at,
  });

  final int energy;
  final int mood;
  final int sleepQuality;
  final DateTime at;

  Map<String, dynamic> toMap() => {
    'energy': energy,
    'mood': mood,
    'sleepQuality': sleepQuality,
    'at': at.toIso8601String(),
  };

  factory MoodCheckIn.fromMap(Map<String, dynamic> map) {
    return MoodCheckIn(
      energy: (map['energy'] as num?)?.toInt() ?? 3,
      mood: (map['mood'] as num?)?.toInt() ?? 3,
      sleepQuality: (map['sleepQuality'] as num?)?.toInt() ?? 3,
      at: DateTime.tryParse(map['at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ParsedQuickAlarm {
  const ParsedQuickAlarm({
    required this.hour24,
    required this.minute,
    required this.label,
    required this.dayOffset,
  });

  final int hour24;
  final int minute;
  final String label;
  final int dayOffset;
}

class TeenSleepProfile {
  const TeenSleepProfile({
    required this.age,
    required this.targetSleepHours,
    required this.windDownMinutes,
  });

  final int age;
  final double targetSleepHours;
  final int windDownMinutes;

  Map<String, dynamic> toMap() => {
    'age': age,
    'targetSleepHours': targetSleepHours,
    'windDownMinutes': windDownMinutes,
  };

  factory TeenSleepProfile.fromMap(Map<String, dynamic> map) {
    return TeenSleepProfile(
      age: ((map['age'] as num?)?.toInt() ?? 16).clamp(13, 19),
      targetSleepHours: ((map['targetSleepHours'] as num?)?.toDouble() ?? 8.5)
          .clamp(7.0, 10.0),
      windDownMinutes: ((map['windDownMinutes'] as num?)?.toInt() ?? 30).clamp(
        15,
        60,
      ),
    );
  }
}

class SleepCoachSnapshot {
  const SleepCoachSnapshot({
    required this.profile,
    required this.recommendedSleepHours,
    required this.sleepDebtMinutes,
    required this.consistencyScore,
    required this.headline,
    required this.recommendation,
    this.nextWakeDateTime,
    this.suggestedBedtime,
  });

  final TeenSleepProfile profile;
  final double recommendedSleepHours;
  final int sleepDebtMinutes;
  final int consistencyScore;
  final String headline;
  final String recommendation;
  final DateTime? nextWakeDateTime;
  final TimeOfDay? suggestedBedtime;
}

class PremiumSleepSnapshot {
  const PremiumSleepSnapshot({
    required this.weekdayAverageWakeMinutes,
    required this.weekendAverageWakeMinutes,
    required this.weekendDriftMinutes,
    required this.recoveryIntensity,
    required this.recoveryHeadline,
    required this.recoveryActions,
  });

  final int? weekdayAverageWakeMinutes;
  final int? weekendAverageWakeMinutes;
  final int weekendDriftMinutes;
  final String recoveryIntensity;
  final String recoveryHeadline;
  final List<String> recoveryActions;
}

enum MathDifficulty { easy, medium, hard, adaptive, boss }

class MathQuestion {
  const MathQuestion({
    required this.display,
    required this.answer,
    required this.difficulty,
    required this.timeLimitSeconds,
  });

  final String display;
  final int answer;
  final MathDifficulty difficulty;
  final int timeLimitSeconds;
}

class WakeScore {
  const WakeScore({
    required this.total,
    required this.speedPoints,
    required this.accuracyPoints,
    required this.snoozePoints,
    required this.moodPoints,
    required this.date,
  });

  final int total;
  final int speedPoints;
  final int accuracyPoints;
  final int snoozePoints;
  final int moodPoints;
  final DateTime date;

  Map<String, dynamic> toMap() => {
        'total': total,
        'speedPoints': speedPoints,
        'accuracyPoints': accuracyPoints,
        'snoozePoints': snoozePoints,
        'moodPoints': moodPoints,
        'date': date.toIso8601String(),
      };

  factory WakeScore.fromMap(Map<String, dynamic> map) => WakeScore(
        total: (map['total'] as num?)?.toInt() ?? 0,
        speedPoints: (map['speedPoints'] as num?)?.toInt() ?? 0,
        accuracyPoints: (map['accuracyPoints'] as num?)?.toInt() ?? 0,
        snoozePoints: (map['snoozePoints'] as num?)?.toInt() ?? 0,
        moodPoints: (map['moodPoints'] as num?)?.toInt() ?? 0,
        date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      );
}

class SmartAlarmService {
  static const _challengeKey = 'smart.dismiss.challenge';
  static const _windDownMinutesKey = 'smart.winddown.minutes';
  static const _statsKey = 'smart.alarm.stats';
  static const _moodKey = 'smart.mood.latest';
  static const _teenSleepProfileKey = 'smart.sleep.profile';
  static const _xpKey = 'smart.xp';
  static const _badgesKey = 'smart.badges';
  static const _consecutiveNoSnoozeKey = 'smart.consecutive_no_snooze';
  // Streak overhaul keys
  static const _streakFreezesKey = 'smart.streak.freezes';
  static const _streakFreezeUsedDateKey = 'smart.streak.freeze_used_date';
  static const _streakMilestonesSeenKey = 'smart.streak.milestones_seen';
  static const _streakDismissHistoryKey = 'smart.streak.dismiss_history';
  static const _streakComebackUsedKey = 'smart.streak.comeback_bonus_used';
  // Math challenge keys
  static const _mathDifficultyKey = 'smart.math.difficulty';
  static const _mathStatsKey = 'smart.math.stats';
  static const _mathNoWrongStreakKey = 'smart.math.no_wrong_streak';
  // Morning missions keys
  static const _missionsTodayKey = 'smart.missions.today';
  static const _missionsLastGenKey = 'smart.missions.last_generated_date';
  static const _missionStreakKey = 'smart.missions.streak';
  static const _missionTotalKey = 'smart.missions.total_completed';
  static const _missionsCustomKey = 'smart.missions.custom';
  // Personality keys
  static const _personalityUsageKey = 'smart.personality.usage';
  // Wake score keys
  static const _wakeScoreHistoryKey = 'smart.wake.score_history';
  static const _wakeBestScoreKey = 'smart.wake.best_score';

  static const Duration _reliabilityCacheTtl = Duration(seconds: 20);
  static AlarmReliabilityStatus? _reliabilityCache;
  static DateTime? _reliabilityCacheAt;

  static const _badgeDisplayNames = <String, String>{
    'early_bird': 'Early Bird',
    'streak_7': '7-Day Warrior',
    'streak_30': '30-Day Legend',
    'no_snooze_week': 'No Snooze Week',
    'mood_master': 'Mood Master',
    'night_owl': 'Night Owl',
    'morning_warrior': 'Morning Warrior',
    'math_master': 'Math Master',
    'profile_master': 'Profile Master',
    'perfect_week': 'Perfect Week',
  };

  static const List<int> _streakMilestones = [7, 14, 30, 60, 100];

  static final _celebrationController = StreamController<CelebrationEvent>.broadcast();

  /// Broadcasts a [CelebrationEvent] whenever a level-up, badge unlock, or
  /// streak milestone happens, so UI (see [CelebrationOverlayHost]) can react
  /// with a confetti burst / banner regardless of which call site triggered it.
  static Stream<CelebrationEvent> get celebrationEvents => _celebrationController.stream;

  static const List<Map<String, String>> _missionPool = [
    {'id': 'm1', 'title': 'Drink a glass of water', 'icon': '💧'},
    {'id': 'm2', 'title': '5 deep breaths', 'icon': '🌬️'},
    {'id': 'm3', 'title': 'Write 1 thing you\'re grateful for', 'icon': '📝'},
    {'id': 'm4', 'title': 'No phone for 10 minutes', 'icon': '📵'},
    {'id': 'm5', 'title': 'Stretch for 5 minutes', 'icon': '🧘'},
    {'id': 'm6', 'title': 'Review today\'s tasks', 'icon': '✅'},
    {'id': 'm7', 'title': 'Make your bed', 'icon': '🛏️'},
    {'id': 'm8', 'title': 'Step outside for fresh air', 'icon': '🌤️'},
    {'id': 'm9', 'title': 'Eat a healthy breakfast', 'icon': '🥗'},
    {'id': 'm10', 'title': 'Smile in the mirror', 'icon': '😊'},
  ];

  // ─── XP & Levels ────────────────────────────────────────────────────────────

  static Future<int> getXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_xpKey) ?? 0;
  }

  static Future<int> addXp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_xpKey) ?? 0;
    final next = (current + amount).clamp(0, 999999);
    await prefs.setInt(_xpKey, next);
    final levelBefore = levelFromXp(current);
    final levelAfter = levelFromXp(next);
    if (levelAfter > levelBefore) {
      _celebrationController.add(CelebrationEvent.levelUp(levelAfter));
    }
    return next;
  }

  static int levelFromXp(int xp) => xp ~/ 500;

  static String levelLabel(int xp) {
    final level = levelFromXp(xp);
    if (level >= 10) return 'Flow Legend';
    if (level >= 4) return 'Circadian Master';
    if (level >= 2) return 'Dawn Warrior';
    if (level >= 1) return 'Early Bird';
    return 'Sleeper';
  }

  static int xpToNextLevel(int xp) {
    final nextLevelXp = (levelFromXp(xp) + 1) * 500;
    return nextLevelXp - xp;
  }

  static double xpLevelProgress(int xp) {
    final levelStart = levelFromXp(xp) * 500;
    return ((xp - levelStart) / 500.0).clamp(0.0, 1.0);
  }

  // ─── Badges ─────────────────────────────────────────────────────────────────

  static String? badgeDisplayName(String id) => _badgeDisplayNames[id];

  static Future<List<String>> getUnlockedBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_badgesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> checkAndUnlockBadges(AlarmStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getUnlockedBadges();
    final existingSet = existing.toSet();
    final newlyUnlocked = <String>[];
    final consecutiveNoSnooze = prefs.getInt(_consecutiveNoSnoozeKey) ?? 0;
    final mathNoWrongStreak = prefs.getInt(_mathNoWrongStreakKey) ?? 0;
    final missionStreak = prefs.getInt(_missionStreakKey) ?? 0;
    final personalityUsage = await getPersonalityUsage();
    final wakeHistory = await getWakeScoreHistory();
    final mathStats = await getMathStats();

    void maybeUnlock(String id, bool condition) {
      if (condition && !existingSet.contains(id)) {
        existingSet.add(id);
        newlyUnlocked.add(id);
      }
    }

    maybeUnlock('early_bird', stats.dismissCount >= 1 && stats.snoozeCount == 0);
    maybeUnlock('streak_7', stats.currentStreak >= 7);
    maybeUnlock('streak_30', stats.currentStreak >= 30);
    maybeUnlock('no_snooze_week', consecutiveNoSnooze >= 7);
    maybeUnlock('mood_master', stats.moodCheckInCount >= 10);
    maybeUnlock('morning_warrior', missionStreak >= 7);
    maybeUnlock('math_master', mathNoWrongStreak >= 50);
    maybeUnlock('profile_master', personalityUsage.values.every((n) => n >= 1) && personalityUsage.length >= 4);
    // Perfect week: 7 consecutive days with score ≥ 70
    if (wakeHistory.length >= 7) {
      final last7 = wakeHistory.reversed.take(7).toList();
      maybeUnlock('perfect_week', last7.every((s) => s.total >= 70));
    }
    // Math master via old wrong-answer check
    maybeUnlock('math_master_solve50', (mathStats['totalSolved'] as int? ?? 0) >= 50 && mathNoWrongStreak >= 50);

    if (newlyUnlocked.isNotEmpty) {
      await prefs.setString(_badgesKey, jsonEncode(existingSet.toList()));
      for (final id in newlyUnlocked) {
        _celebrationController.add(CelebrationEvent.badgeUnlocked(id));
      }
    }
    return newlyUnlocked;
  }

  static Future<void> checkNightOwlBadge(TimeOfDay alarmTime) async {
    if (alarmTime.hour < 21) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = await getUnlockedBadges();
    if (existing.contains('night_owl')) return;
    await prefs.setString(
      _badgesKey,
      jsonEncode([...existing, 'night_owl']),
    );
    // This badge unlocks from alarm scheduling, outside the dismiss/ring
    // flow, so the global celebration stream is its only UI surface.
    _celebrationController.add(CelebrationEvent.badgeUnlocked('night_owl'));
  }

  // ─── Dismiss / Snooze / Missed ───────────────────────────────────────────────

  static Future<DismissReward> recordDismissed({bool hadSnooze = false, int snoozeCount = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await getStats();
    final newStreak = stats.currentStreak + 1;
    final next = stats.copyWith(
      dismissCount: stats.dismissCount + 1,
      currentStreak: newStreak,
      bestStreak: newStreak > stats.bestStreak ? newStreak : stats.bestStreak,
    );
    await _saveStats(next);

    // XP: base 50, +50 no-snooze bonus, +streak multiplier
    var xp = 50;
    if (!hadSnooze) xp += 50;
    xp += newStreak * 5;

    // Track consecutive no-snooze for badge
    if (!hadSnooze) {
      await prefs.setInt(
        _consecutiveNoSnoozeKey,
        (prefs.getInt(_consecutiveNoSnoozeKey) ?? 0) + 1,
      );
    } else {
      await prefs.setInt(_consecutiveNoSnoozeKey, 0);
    }

    // Streak freeze: award 1 freeze per 7-day streak milestone
    final milestonesSeen = await getStreakMilestonesSeen();
    final hitMilestone = _streakMilestones.contains(newStreak) && !milestonesSeen.contains(newStreak);
    if (hitMilestone) {
      await prefs.setInt(_streakFreezesKey, (prefs.getInt(_streakFreezesKey) ?? 0) + 1);
      final seen = [...milestonesSeen, newStreak];
      await prefs.setString(_streakMilestonesSeenKey, jsonEncode(seen));
      _celebrationController.add(CelebrationEvent.streakMilestone(newStreak));
    }

    // Record dismiss history for calendar heatmap
    await _recordDismissHistory(true);

    // Comeback bonus: +100 XP if returning after ≥3 day break
    final comebackXp = await _checkComebackBonus(prefs, stats.currentStreak);
    xp += comebackXp;

    final totalXp = await addXp(xp);
    final newBadges = await checkAndUnlockBadges(next);

    return DismissReward(
      xpEarned: xp,
      totalXp: totalXp,
      newlyUnlockedBadges: newBadges,
      stats: next,
      wasNoSnooze: !hadSnooze,
      hitStreakMilestone: hitMilestone ? newStreak : null,
      comebackBonus: comebackXp > 0 ? comebackXp : null,
    );
  }

  static Future<int> _checkComebackBonus(SharedPreferences prefs, int previousStreak) async {
    if (previousStreak > 0) return 0; // only on restart from 0
    final lastUsed = prefs.getString(_streakComebackUsedKey);
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    if (lastUsed == todayKey) return 0;
    // Streak was 0, meaning they missed — check if they had a streak before
    final history = await getCalendarHistory();
    final sortedDates = history.keys.toList()..sort();
    if (sortedDates.length < 3) return 0;
    // Find last active date; if it was ≥3 days ago, award bonus
    final lastActive = sortedDates.lastWhere((d) => history[d] == true, orElse: () => '');
    if (lastActive.isEmpty) return 0;
    final lastActiveDate = DateTime.tryParse(lastActive);
    if (lastActiveDate == null) return 0;
    final gap = today.difference(lastActiveDate).inDays;
    if (gap >= 3) {
      await prefs.setString(_streakComebackUsedKey, todayKey);
      return 100;
    }
    return 0;
  }

  static Future<void> recordSnoozed() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await getStats();
    await _saveStats(
      stats.copyWith(snoozeCount: stats.snoozeCount + 1),
    );
    await addXp(-10);
    await prefs.setInt(_consecutiveNoSnoozeKey, 0);
  }

  static Future<void> recordMissed() async {
    final stats = await getStats();
    await _saveStats(
      stats.copyWith(
        missedCount: stats.missedCount + 1,
        currentStreak: 0,
      ),
    );
    await _recordDismissHistory(false);
  }

  static Future<AlarmStats> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null || raw.isEmpty) {
      return const AlarmStats(
        dismissCount: 0,
        snoozeCount: 0,
        missedCount: 0,
        currentStreak: 0,
        bestStreak: 0,
        moodCheckInCount: 0,
      );
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AlarmStats(
        dismissCount: (map['dismissCount'] as num?)?.toInt() ?? 0,
        snoozeCount: (map['snoozeCount'] as num?)?.toInt() ?? 0,
        missedCount: (map['missedCount'] as num?)?.toInt() ?? 0,
        currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
        bestStreak: (map['bestStreak'] as num?)?.toInt() ?? 0,
        moodCheckInCount: (map['moodCheckInCount'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const AlarmStats(
        dismissCount: 0,
        snoozeCount: 0,
        missedCount: 0,
        currentStreak: 0,
        bestStreak: 0,
        moodCheckInCount: 0,
      );
    }
  }

  static Future<void> _saveStats(AlarmStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _statsKey,
      jsonEncode({
        'dismissCount': stats.dismissCount,
        'snoozeCount': stats.snoozeCount,
        'missedCount': stats.missedCount,
        'currentStreak': stats.currentStreak,
        'bestStreak': stats.bestStreak,
        'moodCheckInCount': stats.moodCheckInCount,
      }),
    );
  }

  static Future<void> saveMoodCheckIn({
    required int energy,
    required int mood,
    required int sleepQuality,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final checkin = MoodCheckIn(
      energy: energy.clamp(1, 5),
      mood: mood.clamp(1, 5),
      sleepQuality: sleepQuality.clamp(1, 5),
      at: DateTime.now(),
    );
    await prefs.setString(_moodKey, jsonEncode(checkin.toMap()));

    // Increment mood check-in count and award XP
    final stats = await getStats();
    await _saveStats(stats.copyWith(moodCheckInCount: stats.moodCheckInCount + 1));
    await addXp(20);
  }

  // ─── Existing methods ────────────────────────────────────────────────────────

  static Future<DismissChallengeType> getDismissChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_challengeKey) ?? 'math';
    return DismissChallengeType.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => DismissChallengeType.math,
    );
  }

  static Future<void> setDismissChallenge(DismissChallengeType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_challengeKey, type.name);
  }

  static Future<int> getWindDownMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_windDownMinutesKey) ?? 30;
  }

  static Future<void> setWindDownMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = minutes.clamp(15, 60);
    await prefs.setInt(_windDownMinutesKey, clamped);
    final profile = await getTeenSleepProfile();
    await prefs.setString(
      _teenSleepProfileKey,
      jsonEncode(profile.copyWith(windDownMinutes: clamped).toMap()),
    );
  }

  static TimeOfDay suggestBedtime({
    required TimeOfDay wakeTime,
    required double sleepHours,
  }) {
    final wakeMinutes = (wakeTime.hour * 60) + wakeTime.minute;
    final sleepMinutes = (sleepHours * 60).round();
    final bedtimeMinutes = (wakeMinutes - sleepMinutes) % (24 * 60);
    final positive = bedtimeMinutes < 0
        ? bedtimeMinutes + (24 * 60)
        : bedtimeMinutes;
    return TimeOfDay(hour: positive ~/ 60, minute: positive % 60);
  }

  static double recommendedSleepHoursForTeen(int age) {
    if (age <= 15) {
      return 9.0;
    }
    if (age <= 17) {
      return 8.75;
    }
    return 8.5;
  }

  static Future<TeenSleepProfile> getTeenSleepProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_teenSleepProfileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return TeenSleepProfile.fromMap(
          Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // Fall back to defaults below.
      }
    }

    final windDown = prefs.getInt(_windDownMinutesKey) ?? 30;
    return TeenSleepProfile(
      age: 16,
      targetSleepHours: recommendedSleepHoursForTeen(16),
      windDownMinutes: windDown,
    );
  }

  static Future<void> saveTeenSleepProfile({
    int? age,
    double? targetSleepHours,
    int? windDownMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getTeenSleepProfile();
    final next = current.copyWith(
      age: age,
      targetSleepHours: targetSleepHours,
      windDownMinutes: windDownMinutes,
    );
    await prefs.setString(_teenSleepProfileKey, jsonEncode(next.toMap()));
    await prefs.setInt(_windDownMinutesKey, next.windDownMinutes);
  }

  static Future<SleepCoachSnapshot> buildSleepCoachSnapshot(
    List<AlarmModel> alarms,
  ) async {
    final profile = await getTeenSleepProfile();
    final mood = await getLatestMoodCheckIn();
    final enabled = alarms.where((alarm) => alarm.isEnabled).toList()
      ..sort(
        (a, b) => a
            .nextDateTimeFrom(DateTime.now())
            .compareTo(b.nextDateTimeFrom(DateTime.now())),
      );

    final nextWake = enabled.isEmpty
        ? null
        : enabled.first.nextDateTimeFrom(DateTime.now());
    final targetSleepHours = profile.targetSleepHours;
    final suggestedBedtime = nextWake == null
        ? null
        : suggestBedtime(
            wakeTime: TimeOfDay(hour: nextWake.hour, minute: nextWake.minute),
            sleepHours: targetSleepHours,
          );

    final recommended = recommendedSleepHoursForTeen(profile.age);
    final targetDebt = ((recommended - targetSleepHours) * 60).round();
    final moodDebt = mood == null
        ? 0
        : switch (mood.sleepQuality) {
            <= 2 => 45,
            3 => 20,
            4 => 10,
            _ => 0,
          };
    final sleepDebtMinutes = (targetDebt > 0 ? targetDebt : 0) + moodDebt;

    final alarmMinuteValues = enabled
        .map((alarm) => (alarm.time.hour * 60) + alarm.time.minute)
        .toList();
    final consistencyScore = _consistencyScore(alarmMinuteValues);

    final bedtimeText = suggestedBedtime == null
        ? 'Set a wake alarm to get a bedtime target.'
        : 'Aim to be in bed by ${formatTimeOfDay(suggestedBedtime)}.';
    final sleepDebtText = sleepDebtMinutes <= 0
        ? 'Your sleep target is on track.'
        : 'You are carrying about ${sleepDebtMinutes ~/ 60 > 0 ? '${sleepDebtMinutes ~/ 60}h ' : ''}${sleepDebtMinutes % 60}m of sleep debt.';
    final recommendation = mood == null
        ? '$bedtimeText Keep your wake time steady, even on weekends.'
        : mood.sleepQuality <= 2
        ? '$bedtimeText $sleepDebtText Cut screen time 30 minutes earlier tonight.'
        : '$bedtimeText $sleepDebtText Protect the same bedtime for the next 3 nights.';

    final headline = suggestedBedtime == null
        ? 'Teen sleep coach is ready once you enable an alarm.'
        : '${formatTimeOfDay(suggestedBedtime)} is your best bedtime for a ${targetSleepHours.toStringAsFixed(1)}h sleep goal.';

    return SleepCoachSnapshot(
      profile: profile,
      recommendedSleepHours: recommended,
      sleepDebtMinutes: sleepDebtMinutes,
      consistencyScore: consistencyScore,
      headline: headline,
      recommendation: recommendation,
      nextWakeDateTime: nextWake,
      suggestedBedtime: suggestedBedtime,
    );
  }

  /// Pass [coach] when the caller has already built the snapshot, so it isn't
  /// recomputed (it re-reads the sleep profile, mood and every alarm).
  static Future<PremiumSleepSnapshot> buildPremiumSleepSnapshot(
    List<AlarmModel> alarms, {
    SleepCoachSnapshot? coach,
  }) async {
    coach ??= await buildSleepCoachSnapshot(alarms);
    final mood = await getLatestMoodCheckIn();
    final weekdayWake = _averageWakeMinutes(alarms, const [1, 2, 3, 4, 5]);
    final weekendWake = _averageWakeMinutes(alarms, const [6, 7]);
    final drift = weekdayWake == null || weekendWake == null
        ? 0
        : weekendWake - weekdayWake;

    final recoveryIntensity = switch (coach.sleepDebtMinutes) {
      >= 90 => 'High',
      >= 40 => 'Medium',
      _ => 'Light',
    };

    final driftText = drift <= 0
        ? 'Weekend wake time is stable.'
        : 'Weekend drift is $drift min later than weekdays.';
    final recoveryHeadline = mood != null && mood.sleepQuality <= 2
        ? 'Recovery mode recommended tomorrow. $driftText'
        : 'Sleep rhythm check: $driftText';

    final actions = <String>[
      if (coach.suggestedBedtime != null)
        'Start wind-down ${coach.profile.windDownMinutes} min before ${formatTimeOfDay(coach.suggestedBedtime!)}',
      if (drift > 75)
        'Pull weekend alarms earlier by 30-45 min to protect Monday energy',
      if (coach.sleepDebtMinutes >= 40)
        'Use a lighter first block tomorrow and avoid late caffeine',
      if (mood != null && mood.energy <= 2)
        'Keep the first task small and get sunlight within 30 minutes of waking',
      if (actionsWouldBeEmptyPlaceholder(
        coach: coach,
        drift: drift,
        mood: mood,
      ))
        'Your rhythm looks steady. Keep the same wake time for the next 3 days',
    ];

    return PremiumSleepSnapshot(
      weekdayAverageWakeMinutes: weekdayWake,
      weekendAverageWakeMinutes: weekendWake,
      weekendDriftMinutes: drift,
      recoveryIntensity: recoveryIntensity,
      recoveryHeadline: recoveryHeadline,
      recoveryActions: actions,
    );
  }

  static ({TimeOfDay time, List<int> repeatDays, String label, String tag})
  defaultsForProfile(DayTypeProfile profile) {
    switch (profile) {
      case DayTypeProfile.gym:
        return (
          time: const TimeOfDay(hour: 6, minute: 0),
          repeatDays: const [1, 2, 3, 4, 5],
          label: 'Gym Morning',
          tag: 'Training-first wake profile',
        );
      case DayTypeProfile.weekend:
        return (
          time: const TimeOfDay(hour: 8, minute: 15),
          repeatDays: const [6, 7],
          label: 'Weekend Reset',
          tag: 'Consistent but gentle weekend wake',
        );
      case DayTypeProfile.travel:
        return (
          time: const TimeOfDay(hour: 5, minute: 45),
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          label: 'Travel Buffer',
          tag: 'Extra prep time for unpredictable mornings',
        );
      case DayTypeProfile.workday:
        return (
          time: const TimeOfDay(hour: 6, minute: 30),
          repeatDays: const [1, 2, 3, 4, 5],
          label: 'Work Morning',
          tag: 'Stable weekday rhythm',
        );
    }
  }

  static String rotateSoundForDate(DateTime date, String base) {
    if (base != 'rotate') {
      return base;
    }

    const palette = [
      'default',
      'assets/sounds/rain.mp3',
      'assets/sounds/ocean.mp3',
      'assets/sounds/forest.mp3',
      'assets/sounds/white_noise.mp3',
    ];
    return palette[date.weekday % palette.length];
  }

  static Future<AlarmReliabilityStatus> getReliabilityStatus() async {
    final now = DateTime.now();
    final cacheAge = _reliabilityCacheAt == null
        ? null
        : now.difference(_reliabilityCacheAt!);
    if (_reliabilityCache != null &&
        cacheAge != null &&
        cacheAge <= _reliabilityCacheTtl) {
      return _reliabilityCache!;
    }

    bool notificationsGranted = true;
    bool exactAlarmGranted = true;
    var batteryIgnored = true;

    try {
      final notification = await Permission.notification.status;
      notificationsGranted = notification.isGranted;
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      // Keep a safe fallback on platforms where notification status is not exposed.
    }

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid) {
      try {
        final exactAlarm = await Permission.scheduleExactAlarm.status;
        exactAlarmGranted = exactAlarm.isGranted;
      } catch (e) {
        debugPrint('Error checking exact alarm status: $e');
        exactAlarmGranted = false;
      }

      try {
        batteryIgnored = await Permission.ignoreBatteryOptimizations.status.then(
          (value) => value.isGranted,
        );
      } catch (e) {
        debugPrint('Error checking battery optimization status: $e');
        batteryIgnored = true;
      }
    }

    final status = AlarmReliabilityStatus(
      notificationsGranted: notificationsGranted,
      exactAlarmGranted: exactAlarmGranted,
      batteryOptimizationIgnored: batteryIgnored,
    );
    _reliabilityCache = status;
    _reliabilityCacheAt = now;
    return status;
  }

  static Future<MoodCheckIn?> getLatestMoodCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_moodKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return MoodCheckIn.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  static ParsedQuickAlarm? parseQuickAdd(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty) {
      return null;
    }

    final match = RegExp(r'(\d{1,2})[:.](\d{2})\s*(am|pm)?').firstMatch(lower);
    if (match == null) {
      return null;
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!).clamp(0, 59);
    final period = match.group(3);
    if (period == 'pm' && hour < 12) {
      hour += 12;
    } else if (period == 'am' && hour == 12) {
      hour = 0;
    }
    hour = hour.clamp(0, 23);

    final dayOffset = lower.contains('tomorrow') ? 1 : 0;
    final label = lower.contains('gym')
        ? 'Gym Quick Add'
        : lower.contains('travel')
        ? 'Travel Quick Add'
        : 'Quick Add Alarm';

    return ParsedQuickAlarm(
      hour24: hour,
      minute: minute,
      label: label,
      dayOffset: dayOffset,
    );
  }

  static List<String> windDownChecklist() {
    return const [
      'Dim screen and reduce blue light',
      'Do 2 minutes of breathing',
      'No caffeine now',
      'Prep tomorrow task list',
    ];
  }

  static bool actionsWouldBeEmptyPlaceholder({
    required SleepCoachSnapshot coach,
    required int drift,
    required MoodCheckIn? mood,
  }) {
    return coach.suggestedBedtime == null &&
        drift <= 75 &&
        coach.sleepDebtMinutes < 40 &&
        (mood == null || mood.energy > 2);
  }

  static int? _averageWakeMinutes(
    List<AlarmModel> alarms,
    List<int> targetDays,
  ) {
    final matching = alarms.where((alarm) {
      if (!alarm.isEnabled) {
        return false;
      }
      if (alarm.repeatDays.isEmpty) {
        final nextDay = alarm.nextDateTimeFrom(DateTime.now()).weekday;
        return targetDays.contains(nextDay);
      }
      return alarm.repeatDays.any(targetDays.contains);
    }).toList();

    if (matching.isEmpty) {
      return null;
    }

    final total = matching.fold<int>(
      0,
      (sum, alarm) => sum + (alarm.time.hour * 60) + alarm.time.minute,
    );
    return (total / matching.length).round();
  }

  // ─── Streak Overhaul ──────────────────────────────────────────────────────────

  static Future<int> getStreakFreezesOwned() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakFreezesKey) ?? 0;
  }

  static Future<bool> useStreakFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final owned = prefs.getInt(_streakFreezesKey) ?? 0;
    if (owned <= 0) return false;
    await prefs.setInt(_streakFreezesKey, owned - 1);
    final today = DateTime.now();
    await prefs.setString(_streakFreezeUsedDateKey,
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
    return true;
  }

  static Future<List<int>> getStreakMilestonesSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_streakMilestonesSeenKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<int>.from(jsonDecode(raw) as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  static int getStreakMilestoneNext(int currentStreak) {
    for (final m in _streakMilestones) {
      if (m > currentStreak) return m;
    }
    return _streakMilestones.last;
  }

  static Future<void> _recordDismissHistory(bool dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_streakDismissHistoryKey);
    Map<String, dynamic> history = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        history = Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Failed to parse dismiss history: $e');
      }
    }
    final today = DateTime.now();
    final key = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    history[key] = dismissed;
    // Keep only last 90 entries
    if (history.length > 90) {
      final sorted = history.keys.toList()..sort();
      for (final k in sorted.take(history.length - 90)) {
        history.remove(k);
      }
    }
    await prefs.setString(_streakDismissHistoryKey, jsonEncode(history));
  }

  static Future<Map<String, bool>> getCalendarHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_streakDismissHistoryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as bool? ?? false));
    } catch (_) {
      return {};
    }
  }

  // ─── Math Challenge ──────────────────────────────────────────────────────────

  static Future<MathDifficulty> getMathDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mathDifficultyKey) ?? 'easy';
    return MathDifficulty.values.firstWhere((d) => d.name == raw, orElse: () => MathDifficulty.easy);
  }

  static Future<void> setMathDifficulty(MathDifficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mathDifficultyKey, difficulty.name);
  }

  static MathQuestion generateMathQuestion(MathDifficulty difficulty) {
    final rng = math.Random();
    switch (difficulty) {
      case MathDifficulty.easy:
        final a = rng.nextInt(10) + 1;
        final b = rng.nextInt(10) + 1;
        final useAdd = rng.nextBool();
        if (useAdd) {
          return MathQuestion(display: '$a + $b = ?', answer: a + b, difficulty: difficulty, timeLimitSeconds: 45);
        } else {
          final big = math.max(a, b);
          final small = math.min(a, b);
          return MathQuestion(display: '$big − $small = ?', answer: big - small, difficulty: difficulty, timeLimitSeconds: 45);
        }
      case MathDifficulty.medium:
        final a = rng.nextInt(8) + 2;
        final b = rng.nextInt(11) + 2;
        return MathQuestion(display: '$a × $b = ?', answer: a * b, difficulty: difficulty, timeLimitSeconds: 30);
      case MathDifficulty.hard:
        final a = rng.nextInt(7) + 2;
        final b = rng.nextInt(9) + 2;
        final c = rng.nextInt(15) + 5;
        return MathQuestion(display: '($a × $b) + $c = ?', answer: (a * b) + c, difficulty: difficulty, timeLimitSeconds: 20);
      case MathDifficulty.boss:
        final a = rng.nextInt(9) + 2;
        final b = rng.nextInt(9) + 2;
        final c = rng.nextInt(7) + 2;
        final d = rng.nextInt(5) + 1;
        return MathQuestion(display: '($a × $b) − ($c × $d) = ?', answer: (a * b) - (c * d), difficulty: difficulty, timeLimitSeconds: 15);
      case MathDifficulty.adaptive:
        return generateMathQuestion(MathDifficulty.medium);
    }
  }

  static Future<Map<String, dynamic>> getMathStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mathStatsKey);
    if (raw == null || raw.isEmpty) return {'totalSolved': 0, 'wrongCount': 0, 'avgSolveMs': 0};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return {'totalSolved': 0, 'wrongCount': 0, 'avgSolveMs': 0};
    }
  }

  static Future<void> recordMathResult({
    required bool correct,
    required int solveMs,
    required MathDifficulty difficulty,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await getMathStats();
    final totalSolved = (stats['totalSolved'] as int? ?? 0) + (correct ? 1 : 0);
    final wrongCount = (stats['wrongCount'] as int? ?? 0) + (correct ? 0 : 1);
    final prevAvg = stats['avgSolveMs'] as int? ?? 0;
    final newAvg = totalSolved > 0 ? ((prevAvg + solveMs) ~/ 2) : solveMs;

    if (correct) {
      final noWrongStreak = (prefs.getInt(_mathNoWrongStreakKey) ?? 0) + 1;
      await prefs.setInt(_mathNoWrongStreakKey, noWrongStreak);
    } else {
      await prefs.setInt(_mathNoWrongStreakKey, 0);
    }

    await prefs.setString(_mathStatsKey, jsonEncode({
      'totalSolved': totalSolved,
      'wrongCount': wrongCount,
      'avgSolveMs': newAvg,
    }));
  }

  static Future<void> updateMathDifficultyAdaptive(int avgSolveMs, MathDifficulty current) async {
    if (current == MathDifficulty.adaptive) {
      // Auto-adjust: faster → harder, slower → easier
      MathDifficulty next;
      if (avgSolveMs < 8000) {
        next = MathDifficulty.hard;
      } else if (avgSolveMs > 30000) {
        next = MathDifficulty.easy;
      } else {
        next = MathDifficulty.medium;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mathDifficultyKey, next.name);
    }
  }

  // ─── Morning Missions ────────────────────────────────────────────────────────

  static Future<List<MissionModel>> getTodayMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final lastGen = prefs.getString(_missionsLastGenKey);

    if (lastGen == todayKey) {
      final raw = prefs.getString(_missionsTodayKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final list = jsonDecode(raw) as List<dynamic>;
          return list.map((m) => MissionModel.fromMap(Map<String, dynamic>.from(m as Map))).toList();
        } catch (e) {
          debugPrint('Failed to parse cached missions: $e');
        }
      }
    }

    // Generate new missions for today
    return generateDailyMissions();
  }

  static Future<List<MissionModel>> generateDailyMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    // Get custom missions
    final customRaw = prefs.getString(_missionsCustomKey);
    final customMissions = <Map<String, String>>[];
    if (customRaw != null && customRaw.isNotEmpty) {
      try {
        final list = jsonDecode(customRaw) as List<dynamic>;
        for (final m in list) {
          customMissions.add(Map<String, String>.from(m as Map));
        }
      } catch (e) {
        debugPrint('Failed to parse custom missions: $e');
      }
    }

    final allPool = [..._missionPool, ...customMissions];
    final rng = math.Random(today.millisecondsSinceEpoch ~/ 86400000);
    allPool.shuffle(rng);
    final selected = allPool.take(3).map((m) => MissionModel(
      id: m['id'] ?? const Uuid().v4(),
      title: m['title'] ?? '',
      icon: m['icon'] ?? '✅',
      isCustom: customMissions.contains(m),
    )).toList();

    await prefs.setString(_missionsTodayKey, jsonEncode(selected.map((m) => m.toMap()).toList()));
    await prefs.setString(_missionsLastGenKey, todayKey);
    return selected;
  }

  static Future<void> saveTodayMissions(List<MissionModel> missions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_missionsTodayKey, jsonEncode(missions.map((m) => m.toMap()).toList()));
  }

  static Future<int> completeMission(String missionId) async {
    final prefs = await SharedPreferences.getInstance();
    final missions = await getTodayMissions();
    final idx = missions.indexWhere((m) => m.id == missionId);
    if (idx < 0) return 0;
    missions[idx].isCompleted = true;
    missions[idx].completedAt = DateTime.now();
    await saveTodayMissions(missions);

    final xp = missions[idx].xpReward;
    await addXp(xp);
    await prefs.setInt(_missionTotalKey, (prefs.getInt(_missionTotalKey) ?? 0) + 1);

    // Check if all 3 missions complete → update streak
    if (missions.every((m) => m.isCompleted)) {
      await _updateMissionStreak(prefs);
    }
    return xp;
  }

  static Future<void> _updateMissionStreak(SharedPreferences prefs) async {
    final streak = (prefs.getInt(_missionStreakKey) ?? 0) + 1;
    await prefs.setInt(_missionStreakKey, streak);
  }

  static Future<int> getMissionStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_missionStreakKey) ?? 0;
  }

  static Future<int> getMissionTotalCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_missionTotalKey) ?? 0;
  }

  static Future<void> addCustomMission(String title, String icon) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_missionsCustomKey);
    final list = <Map<String, String>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final m in decoded) { list.add(Map<String, String>.from(m as Map)); }
      } catch (e) {
        debugPrint('Failed to parse personality usage map: $e');
      }
    }
    list.add({'id': const Uuid().v4(), 'title': title, 'icon': icon});
    await prefs.setString(_missionsCustomKey, jsonEncode(list));
  }

  // ─── Alarm Personality ───────────────────────────────────────────────────────

  static Future<Map<String, int>> getPersonalityUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_personalityUsageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, int>.from(
        (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())));
    } catch (_) {
      return {};
    }
  }

  static Future<void> recordPersonalityUsed(String personality) async {
    final prefs = await SharedPreferences.getInstance();
    final usage = await getPersonalityUsage();
    usage[personality] = (usage[personality] ?? 0) + 1;
    await prefs.setString(_personalityUsageKey, jsonEncode(usage));
  }

  // ─── Wake Quality Score ──────────────────────────────────────────────────────

  static WakeScore calculateWakeScore({
    required int dismissSpeedSeconds,
    required int wrongAnswers,
    required int snoozeCount,
    required bool moodCheckInDoneToday,
  }) {
    // Speed: fastest (≤30s) = 25pts, each extra 30s = -5pts
    final speedPts = (25 - ((dismissSpeedSeconds - 30) ~/ 30) * 5).clamp(0, 25);
    // Accuracy: 0 wrong=25, 1 wrong=15, 2+=5
    final accuracyPts = wrongAnswers == 0 ? 25 : (wrongAnswers == 1 ? 15 : 5);
    // Snooze: 0=25, 1=15, 2+=0
    final snoozePts = snoozeCount == 0 ? 25 : (snoozeCount == 1 ? 15 : 0);
    // Mood check-in: done today = 25
    final moodPts = moodCheckInDoneToday ? 25 : 0;
    final total = speedPts + accuracyPts + snoozePts + moodPts;
    return WakeScore(
      total: total,
      speedPoints: speedPts,
      accuracyPoints: accuracyPts,
      snoozePoints: snoozePts,
      moodPoints: moodPts,
      date: DateTime.now(),
    );
  }

  static Future<int> saveWakeScore(WakeScore score) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWakeScoreHistory();
    history.add(score);
    // Keep last 60 entries
    final trimmed = history.length > 60 ? history.sublist(history.length - 60) : history;
    await prefs.setString(_wakeScoreHistoryKey, jsonEncode(trimmed.map((s) => s.toMap()).toList()));
    // Update best score
    final best = prefs.getInt(_wakeBestScoreKey) ?? 0;
    if (score.total > best) {
      await prefs.setInt(_wakeBestScoreKey, score.total);
    }
    return best;
  }

  static Future<List<WakeScore>> getWakeScoreHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_wakeScoreHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((m) => WakeScore.fromMap(Map<String, dynamic>.from(m as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<int> getBestWakeScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_wakeBestScoreKey) ?? 0;
  }

  static String wakeScoreTip(WakeScore score) {
    final components = {
      'speed': score.speedPoints,
      'accuracy': score.accuracyPoints,
      'snooze': score.snoozePoints,
      'mood': score.moodPoints,
    };
    final worst = components.entries.reduce((a, b) => a.value < b.value ? a : b);
    switch (worst.key) {
      case 'speed':
        return 'You took a while to dismiss — try putting your phone across the room.';
      case 'accuracy':
        return 'A few math errors today — the challenge wakes your brain faster when you focus.';
      case 'snooze':
        return 'Snoozing cuts your morning momentum — try setting a single, perfect wake time.';
      case 'mood':
        return 'Complete your morning check-in to earn full points and track your energy trends.';
      default:
        return 'Keep it up! Your morning routine is building great habits.';
    }
  }

  static int _consistencyScore(List<int> minuteValues) {
    if (minuteValues.length <= 1) {
      return 92;
    }

    final mean =
        minuteValues.reduce((a, b) => a + b) / minuteValues.length.toDouble();
    final variance =
        minuteValues.fold<double>(
          0,
          (sum, value) => sum + ((value - mean) * (value - mean)),
        ) /
        minuteValues.length.toDouble();
    final deviationMinutes = math.sqrt(variance);
    final score = 100 - (deviationMinutes * 0.9);
    return score.round().clamp(45, 100);
  }

  static String formatTimeOfDay(TimeOfDay time) => formatClockTime(time);
}

extension on TeenSleepProfile {
  TeenSleepProfile copyWith({
    int? age,
    double? targetSleepHours,
    int? windDownMinutes,
  }) {
    return TeenSleepProfile(
      age: (age ?? this.age).clamp(13, 19),
      targetSleepHours: (targetSleepHours ?? this.targetSleepHours).clamp(
        7.0,
        10.0,
      ),
      windDownMinutes: (windDownMinutes ?? this.windDownMinutes).clamp(15, 60),
    );
  }
}
