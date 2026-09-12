import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';

/// Everything the Insights tab renders, resolved in one pass.
///
/// The screen previously ran six futures across four nested FutureBuilders,
/// so it painted in stages and reflowed as each resolved. Loading it all here
/// gives the UI a single loading/error state.
class InsightsSummary {
  const InsightsSummary({
    required this.stats,
    required this.xp,
    required this.bestWakeScore,
    required this.wakeHistory,
    required this.calendar,
    required this.coach,
    required this.premiumSleep,
    required this.premiumUnlocked,
    required this.weekdayLoad,
  });

  final AlarmStats stats;
  final int xp;
  final int bestWakeScore;
  final List<WakeScore> wakeHistory;
  final Map<String, bool> calendar;
  final SleepCoachSnapshot coach;
  final PremiumSleepSnapshot premiumSleep;
  final bool premiumUnlocked;

  /// Alarms scheduled per weekday, Monday first. This is the single source
  /// for the weekly chart — it used to be rendered four different ways.
  final WeekdayLoad weekdayLoad;

  String get levelLabel => SmartAlarmService.levelLabel(xp);
  double get levelProgress => SmartAlarmService.xpLevelProgress(xp);
  int get xpToNextLevel => SmartAlarmService.xpToNextLevel(xp);

  /// Average of the most recent wake scores, or null before any exist.
  int? get averageWakeScore {
    if (wakeHistory.isEmpty) return null;
    final total = wakeHistory.fold<int>(0, (sum, s) => sum + s.total);
    return (total / wakeHistory.length).round();
  }
}

/// How many enabled alarms land on each weekday, plus a derived headline.
class WeekdayLoad {
  const WeekdayLoad({required this.countsByWeekday, required this.headline});

  /// Seven entries, Monday-first.
  final List<double> countsByWeekday;
  final String headline;

  double get max =>
      countsByWeekday.fold<double>(0, (m, v) => v > m ? v : m);

  bool get isEmpty => max == 0;

  static const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
}

final insightsSummaryProvider =
    FutureProvider.autoDispose<InsightsSummary>((ref) async {
  final alarms = await ref.watch(alarmsListProvider.future);

  final coach = await SmartAlarmService.buildSleepCoachSnapshot(alarms);

  final results = await Future.wait([
    SmartAlarmService.getStats(),
    SmartAlarmService.getXp(),
    SmartAlarmService.getBestWakeScore(),
    SmartAlarmService.getWakeScoreHistory(),
    SmartAlarmService.getCalendarHistory(),
    // Reuses the coach snapshot above rather than rebuilding it.
    SmartAlarmService.buildPremiumSleepSnapshot(alarms, coach: coach),
    PremiumService.canUse(PremiumFeature.sleepCoachPro),
  ]);

  return InsightsSummary(
    stats: results[0] as AlarmStats,
    xp: results[1] as int,
    bestWakeScore: results[2] as int,
    wakeHistory: results[3] as List<WakeScore>,
    calendar: results[4] as Map<String, bool>,
    coach: coach,
    premiumSleep: results[5] as PremiumSleepSnapshot,
    premiumUnlocked: results[6] as bool,
    weekdayLoad: buildWeekdayLoad(alarms),
  );
});

/// Pure: counts enabled alarms per weekday and summarizes the cluster.
WeekdayLoad buildWeekdayLoad(List<AlarmModel> alarms) {
  final enabled = alarms.where((a) => a.isEnabled).toList();
  final counts = List<double>.filled(7, 0);

  for (final alarm in enabled) {
    if (alarm.repeatDays.isEmpty) {
      counts[alarm.nextDateTimeFrom(DateTime.now()).weekday - 1] += 1;
    } else {
      for (final day in alarm.repeatDays) {
        counts[day - 1] += 1;
      }
    }
  }

  return WeekdayLoad(
    countsByWeekday: counts,
    headline: _headlineFor(enabled, counts),
  );
}

String _headlineFor(List<AlarmModel> alarms, List<double> counts) {
  if (alarms.isEmpty) {
    return 'Add and enable an alarm to unlock your weekly pattern.';
  }

  final totalMinutes = alarms.fold<int>(
    0,
    (sum, a) => sum + (a.time.hour * 60) + a.time.minute,
  );
  final avgMinutes = (totalMinutes / alarms.length).round();
  final avgHour = avgMinutes ~/ 60;
  final avgMinute = avgMinutes % 60;

  var busiest = 0;
  for (var i = 1; i < counts.length; i++) {
    if (counts[i] > counts[busiest]) busiest = i;
  }

  final hh = avgHour == 0 ? 12 : (avgHour > 12 ? avgHour - 12 : avgHour);
  final mm = avgMinute.toString().padLeft(2, '0');
  final period = avgHour >= 12 ? 'PM' : 'AM';

  return 'Most alarms cluster on ${WeekdayLoad.dayLabels[busiest]} '
      'around $hh:$mm $period.';
}
