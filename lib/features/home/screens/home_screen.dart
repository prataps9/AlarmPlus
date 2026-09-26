import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/sleep/models/bedtime_schedule.dart';
import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/features/sleep/services/bedtime_service.dart';
import 'package:alarm_plus/features/focus/services/nap_service.dart';
import 'package:alarm_plus/features/sleep/services/sleep_analytics_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/shared/widgets/alarm_card.dart';
import 'package:alarm_plus/features/alarm/screens/alarms_screen.dart';
import 'package:alarm_plus/features/sleep/screens/bedtime_setup_screen.dart';
import 'package:alarm_plus/features/focus/screens/focus_timer_screen.dart';
import 'package:alarm_plus/features/missions/screens/morning_missions_screen.dart';
import 'package:alarm_plus/features/focus/screens/nap_timer_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_diary_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_insights_screen.dart';
import 'package:alarm_plus/features/home/widgets/shortcut_card.dart';
import 'package:alarm_plus/core/theme/app_theme_ext.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/settings/screens/settings_screen.dart';
import 'package:alarm_plus/features/sleep/widgets/bedtime_card.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';

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
                  tooltip: 'Settings',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      // SettingsScreen draws its own "Settings" heading;
                      // the bar only adds the back button.
                      builder: (_) => Scaffold(
                        appBar: AppBar(),
                        body: const SettingsScreen(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 28),
                ),
                IconButton(
                  tooltip: 'New alarm',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AlarmsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 34),
                ),
              ],
            ),
            _NextAlarmLine(alarms: alarms),
            const SizedBox(height: 18),
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
                                : Theme.of(context).colorScheme.outlineVariant,
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
                Text(
                  'UPCOMING ALARMS',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(letterSpacing: 2.8),
                ),
                const Spacer(),
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
            ...alarms
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
                return ShortcutCard(
                  emoji: '\u{1F319}',
                  title: 'Wind Down',
                  subtitle: active
                      ? 'Bedtime ${BedtimeService.nextBedtimeLabel(schedule)} '
                          '\u00b7 ${schedule.windDownMinutes}min wind-down'
                      : 'Set up your bedtime routine',
                  onTap: () => Navigator.of(context)
                      .pushNamed(BedtimeSetupScreen.routeName),
                );
              },
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
                      foregroundColor: Colors.white,
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

  List<Widget> _buildTodayTiles(BuildContext context, List<AlarmModel> alarms) {
    final today = DateTime.now().weekday;
    final now = DateTime.now();

    final todayAlarms = alarms.where((alarm) {
      if (!alarm.isEnabled) return false;
      if (alarm.repeatDays.isEmpty) {
        final next = alarm.nextDateTimeFrom(now);
        return next.year == now.year &&
            next.month == now.month &&
            next.day == now.day;
      }
      return alarm.repeatDays.contains(today);
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
      tiles.add(
        _TimelineTile(
          time: alarm.timeLabel,
          title: alarm.label.isEmpty ? 'Wake Alarm' : alarm.label,
          subtitle: '${alarm.periodLabel} · ${alarm.repeatLabel}',
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

/// Pip's contextual line at the top of Home: greets new users, nags when a
/// streak has no alarm protecting it, and cheers in the morning.
/// "Alarm in 7 hr 20 min" — the line every clock app shows, refreshed
/// each minute.
class _NextAlarmLine extends StatelessWidget {
  const _NextAlarmLine({required this.alarms});

  final List<AlarmModel> alarms;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: Stream<void>.periodic(const Duration(seconds: 30)),
      builder: (context, _) {
        final now = DateTime.now();
        DateTime? next;
        for (final a in alarms.where((a) => a.isEnabled)) {
          final t = a.nextDateTimeFrom(now);
          if (next == null || t.isBefore(next)) next = t;
        }
        return Text(
          TimeFormat.alarmIn(next?.difference(now)),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      },
    );
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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF111111)),
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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF111111)),
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
                        color: const Color(0xFFEEEEEE),
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
