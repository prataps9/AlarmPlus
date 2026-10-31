import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/models/upcoming_rings.dart';
import 'package:alarm_plus/features/sleep/models/bedtime_schedule.dart';
import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/features/sleep/services/bedtime_service.dart';
import 'package:alarm_plus/features/focus/services/nap_service.dart';
import 'package:alarm_plus/features/sleep/services/sleep_analytics_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/shared/widgets/alarm_card.dart';
import 'package:alarm_plus/features/alarm/screens/alarms_screen.dart';
import 'package:alarm_plus/features/alarm/widgets/reliability_banner.dart';
import 'package:alarm_plus/features/focus/screens/focus_timer_screen.dart';
import 'package:alarm_plus/features/missions/screens/morning_missions_screen.dart';
import 'package:alarm_plus/features/focus/screens/nap_timer_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_diary_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_insights_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_sounds_screen.dart';
import 'package:alarm_plus/features/sleep/screens/wind_down_screen.dart';
import 'package:alarm_plus/features/home/widgets/shortcut_card.dart';
import 'package:alarm_plus/core/theme/app_theme_ext.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/sleep/widgets/bedtime_card.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';
import 'package:alarm_plus/features/alarm/widgets/next_alarm_capsule.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmsAsync = ref.watch(alarmsListProvider);

    return SafeArea(
      child: alarmsAsync.when(
        data: (alarms) => ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
          children: [
            Row(
              children: [
                Text(
                  'Alarm',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'New alarm',
                  // Straight into the editor; it used to open the alarm list.
                  onPressed: () => AlarmsScreen.showEditor(context, ref),
                  icon: const Icon(Icons.add, size: 34),
                ),
              ],
            ),
            const SizedBox(height: 10),
            NextAlarmCapsule(alarms: alarms),
            const SizedBox(height: 18),
            const ReliabilityBanner(),
            // Streak / XP hero widget
            FutureBuilder<(AlarmStats, int)>(
              future: Future.wait([
                SmartAlarmService.getStats(),
                SmartAlarmService.getXp(),
              ]).then((r) => (r[0] as AlarmStats, r[1] as int)),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(height: 80);
                final (stats, xp) = snapshot.data!;
                return _StreakHeroWidget(
                  stats: stats,
                  xp: xp,
                  onTap: () =>
                      ref.read(currentTabIndexProvider.notifier).state = AppTab.insights,
                );
              },
            ),
            const SizedBox(height: 16),
            // Morning Missions card
            FutureBuilder<List<dynamic>>(
              future: SmartAlarmService.getTodayMissions(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final missions = snap.data!;
                final completed = missions.where((m) => (m as dynamic).isCompleted == true).length;
                final total = missions.length;
                if (total == 0) return const SizedBox.shrink();
                return ShortcutCard(
                  emoji: '🌅',
                  title: 'Morning Missions',
                  subtitle:
                      '$completed/$total completed · +${completed * 15} XP earned',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < total; i++)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(left: Spacing.xs),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < completed
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                  onTap: () => Navigator.of(context)
                      .pushNamed(MorningMissionsScreen.routeName),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              'YOUR TODAY',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(letterSpacing: 2.8),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: _buildTodayTiles(context, alarms),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                // Expanded (not Text + Spacer) so a large system font
                // shrinks the label instead of pushing "View all" off-screen.
                Expanded(
                  child: Text(
                    'UPCOMING ALARMS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(letterSpacing: 2.8),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AlarmsScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View all',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._upcomingFirst(alarms)
                .take(2)
                .map(
                  (alarm) => AlarmCard(
                    alarm: alarm,
                    onToggle: (value) => ref
                        .read(alarmsMapProvider.notifier)
                        .toggleAlarm(alarm.id, value),
                    onSkipNext: (skip) => ref
                        .read(alarmsMapProvider.notifier)
                        .setSkipNext(alarm.id, skip: skip),
                  ),
                ),
            const SizedBox(height: 14),
            BedtimeCard(alarms: alarms),
            const SizedBox(height: 8),
            // Sleep Insights summary card
            FutureBuilder<int>(
              future: SleepAnalyticsService.weeklyScore(),
              builder: (context, snap) {
                final score = snap.data;
                return ShortcutCard(
                  emoji: '\u{1F634}',
                  title: 'Sleep Insights',
                  subtitle: score != null
                      ? 'Weekly score $score \u00b7 ${SleepAnalyticsService.scoreLabel(score)}'
                      : 'Tap to view your sleep trends',
                  trailing: score == null
                      ? null
                      : Text(
                          '$score',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                  onTap: () => Navigator.of(context)
                      .pushNamed(SleepInsightsScreen.routeName),
                );
              },
            ),
            FutureBuilder<bool>(
              future: NapService.isNapActive(),
              builder: (context, napSnap) {
                final napActive = napSnap.data ?? false;
                return ShortcutCard(
                  emoji: '\u{1F4A4}',
                  title: 'Nap Timer',
                  subtitle: napActive
                      ? 'Nap in progress \u00b7 tap to manage'
                      : '20 \u00b7 45 \u00b7 90 min presets',
                  onTap: () =>
                      Navigator.of(context).pushNamed(NapTimerScreen.routeName),
                );
              },
            ),
            ShortcutCard(
              emoji: '\u{1F4D3}',
              title: 'Sleep Diary',
              subtitle: "Log last night's sleep",
              onTap: () => Navigator.of(context)
                  .pushNamed(SleepDiaryScreen.routeName),
            ),
            FutureBuilder<BedtimeSchedule?>(
              future: BedtimeService.load(),
              builder: (context, snap) {
                final schedule = snap.data;
                final active = schedule != null && schedule.isEnabled;
                // Wind-down session (with sleep sounds) — previously this
                // card went to bedtime setup, leaving Wind-Down unreachable.
                return ShortcutCard(
                  emoji: '\u{1F319}',
                  title: 'Wind Down',
                  subtitle: active
                      ? 'Bedtime ${BedtimeService.nextBedtimeLabel(schedule)} '
                          '\u00b7 relax with a guided wind-down'
                      : 'Relax before bed with a guided wind-down',
                  onTap: () => Navigator.of(context)
                      .pushNamed(WindDownScreen.routeName),
                );
              },
            ),
            ShortcutCard(
              emoji: '\u{1F3B5}',
              title: 'Sleep Sounds',
              subtitle: 'Rain, ocean, fan, white noise and more',
              onTap: () =>
                  Navigator.of(context).pushNamed(SleepSoundsScreen.routeName),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/wake-routine');
                    },
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: const Text('Wake Routine'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamed(FocusTimerScreen.routeName);
                    },
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('Start Focus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ],
            ),
          ].animate(interval: 70.ms).fadeIn(duration: 240.ms).move(
            begin: const Offset(0, 8),
            end: Offset.zero,
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  /// The alarms that ring soonest, then the rest (so the card list isn't
  /// just the earliest clock times, switched-off ones included).
  static List<AlarmModel> _upcomingFirst(List<AlarmModel> alarms) {
    final next = <AlarmModel>[];
    for (final r in upcomingRings(alarms, DateTime.now())) {
      if (!next.contains(r.alarm)) next.add(r.alarm);
    }
    return [...next, ...alarms.where((a) => !next.contains(a))];
  }

  List<Widget> _buildTodayTiles(BuildContext context, List<AlarmModel> alarms) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Rings today, with skips, pauses and dates applied (a skipped or
    // paused weekday alarm used to be listed anyway).
    final todayAlarms = alarms.where((alarm) {
      if (!alarm.isEnabled || alarm.isSystem) return false;
      final from =
          alarm.repeatDays.isEmpty && alarm.date == null ? now : startOfToday;
      final next = alarm.nextDateTimeFrom(from);
      return next.year == now.year &&
          next.month == now.month &&
          next.day == now.day;
    }).toList()
      ..sort(
        (a, b) => (a.time.hour * 60 + a.time.minute)
            .compareTo(b.time.hour * 60 + b.time.minute),
      );

    if (todayAlarms.isEmpty) {
      return [
        const _TimelineTile(
          time: '--:--',
          title: 'Rest day',
          subtitle: 'No alarms scheduled for today',
        ),
      ];
    }

    final tiles = <Widget>[];
    for (final alarm in todayAlarms.take(2)) {
      final clock = TimeFormat.clock(alarm.time.hour, alarm.time.minute,
          use24h: MediaQuery.alwaysUse24HourFormatOf(context));
      tiles.add(
        _TimelineTile(
          time: clock.time,
          title: alarm.label.isEmpty ? 'Wake Alarm' : alarm.label,
          subtitle: clock.period == null
              ? alarm.repeatLabel
              : '${clock.period} · ${alarm.repeatLabel}',
        ),
      );
    }

    tiles.add(
      const _TimelineTile(
        time: '+25m',
        title: 'Focus Sprint',
        subtitle: 'Suggested after wake — tap Start Focus',
      ),
    );

    return tiles;
  }
}

class _StreakHeroWidget extends StatelessWidget {
  const _StreakHeroWidget({
    required this.stats,
    required this.xp,
    required this.onTap,
  });

  final AlarmStats stats;
  final int xp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final streak = stats.currentStreak;
    final label = SmartAlarmService.levelLabel(xp);
    final progress = SmartAlarmService.xpLevelProgress(xp);
    final toNext = SmartAlarmService.xpToNextLevel(xp);
    final nextMilestone = SmartAlarmService.getStreakMilestoneNext(streak);
    final milestoneProgress = streak / nextMilestone;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 28,
                    color: context.semantics.streakTier(streak),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$streak',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'day streak',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onSurface),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('$xp XP · $toNext to next level',
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$streak / $nextMilestone days to milestone',
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: milestoneProgress.clamp(0.0, 1.0),
                          backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onSurface),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FutureBuilder<int>(
                  future: SmartAlarmService.getStreakFreezesOwned(),
                  builder: (ctx, snap) {
                    final freezes = snap.data ?? 0;
                    if (freezes == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Text('×$freezes freeze',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.time,
    required this.title,
    required this.subtitle,
  });

  final String time;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            time,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 14),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
