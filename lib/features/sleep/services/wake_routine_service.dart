import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/missions/models/wake_routine_step.dart';

class WakeRoutineService {
  static const _completedTodayKey = 'wake_routine.completed_today';
  static const _streakKey = 'wake_routine.streak';
  static const _lastCompletedDateKey = 'wake_routine.last_completed_date';

  static const List<WakeRoutineStep> defaultSteps = [
    WakeRoutineStep(
      id: 'drink_water',
      title: 'Drink Water',
      instruction: 'Drink a full glass of water right now.',
      icon: '💧',
      durationSeconds: 30,
    ),
    WakeRoutineStep(
      id: 'deep_breaths',
      title: '10 Deep Breaths',
      instruction: 'Breathe in for 4s, hold 4s, out for 4s.',
      icon: '🌬️',
      durationSeconds: 60,
      isTimedBreath: true,
    ),
    WakeRoutineStep(
      id: 'stretch',
      title: 'Stretch 30s',
      instruction: 'Stand up and reach your arms overhead.',
      icon: '🧘',
      durationSeconds: 30,
    ),
    WakeRoutineStep(
      id: 'sunlight',
      title: 'Get Light',
      instruction: 'Move to a window or step outside briefly.',
      icon: '☀️',
      durationSeconds: 20,
    ),
    WakeRoutineStep(
      id: 'set_intention',
      title: 'Set Intention',
      instruction: 'Name one thing you will complete today.',
      icon: '🎯',
      durationSeconds: 20,
    ),
  ];

  static Future<bool> isRoutineCompletedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_completedTodayKey);
    final today = _todayKey();
    return saved == today;
  }

  static Future<void> markRoutineCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final last = prefs.getString(_lastCompletedDateKey);
    final yesterday = _yesterdayKey();

    final streak = prefs.getInt(_streakKey) ?? 0;
    // A second run on the same day keeps the streak; it used to reset to 1.
    final newStreak = last == today
        ? streak
        : (last == yesterday ? streak + 1 : 1);

    await prefs.setString(_completedTodayKey, today);
    await prefs.setString(_lastCompletedDateKey, today);
    await prefs.setInt(_streakKey, newStreak);
  }

  static Future<int> getRoutineStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  static int calculateAwakeBonus(int completedSteps, int totalSteps) {
    return completedSteps * 10;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  static String _yesterdayKey() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month}-${yesterday.day}';
  }
}
