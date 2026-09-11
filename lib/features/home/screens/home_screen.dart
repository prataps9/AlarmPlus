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
import 'package:alarm_plus/features/sleep/screens/sleep_insights_screen.dart';
import 'package:alarm_plus/shared/widgets/mascot_widget.dart';

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
                  'Alarm+',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                  ),
                ),
                const Spacer(),
                IconButton(
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
                      ref.read(currentTabIndexProvider.notifier).state = 1,
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
                return GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed(MorningMissionsScreen.routeName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Text('🌅', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Morning Missions',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              Text('$completed/$total completed · +${completed * 15} XP earned',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                            ],
                          ),
                        ),
                        Row(
                          children: List.generate(total, (i) => Container(
                            width: 10, height: 10,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < completed
                                  ? const Color(0xFF111111)
                                  : const Color(0xFFE0E0E0),
                            ),
                          )),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFFAAAAAA), size: 20),
                      ],
                    ),
                  ),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE0E0E0)),
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
                  ),
                ),
            const SizedBox(height: 22),
            // Sleep Insights summary card
            FutureBuilder<int>(
              future: SleepAnalyticsService.weeklyScore(),
              builder: (context, snap) {
                final score = snap.data ?? 0;
                final label = SleepAnalyticsService.scoreLabel(score);
                return GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed(SleepInsightsScreen.routeName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Text('😴', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sleep Insights',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              Text(
                                snap.hasData
                                    ? 'Weekly score $score · $label'
                                    : 'Tap to view your sleep trends',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                              ),
                            ],
                          ),
                        ),
                        if (snap.hasData)
                          Text(
                            '$score',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111111)),
                          ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFFAAAAAA), size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Nap Timer card
            FutureBuilder<bool>(
              future: NapService.isNapActive(),
              builder: (context, napSnap) {
                final napActive = napSnap.data ?? false;
                return GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed(NapTimerScreen.routeName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Text('💤', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nap Timer',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              Text(
                                napActive
                                    ? 'Nap in progress · tap to manage'
                                    : '20 · 45 · 90 min presets',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFAAAAAA), size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Sleep Diary card
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/sleep-diary'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const Row(
                  children: [
                    Text('📓', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sleep Diary',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Text('Log last night\'s sleep',
                              style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFFAAAAAA), size: 20),
                  ],
                ),
              ),
            ),
            // Bedtime / Wind Down card
            FutureBuilder<BedtimeSchedule?>(
              future: BedtimeService.load(),
              builder: (context, snap) {
                final schedule = snap.data;
                return GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed(BedtimeSetupScreen.routeName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Text('🌙', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Wind Down',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              Text(
                                schedule != null && schedule.isEnabled
                                    ? 'Bedtime ${BedtimeService.nextBedtimeLabel(schedule)} · ${schedule.windDownMinutes}min wind-down'
                                    : 'Set up your bedtime routine',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFAAAAAA), size: 20),
                      ],
                    ),
                  ),
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
                      backgroundColor: const Color(0xFF111111),
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

MascotMood _moodForStreak(int streak, DateTime now) {
  if (streak == 0) return MascotMood.worried;
  final hour = now.hour;
  if (hour >= 22 || hour < 5) return MascotMood.sleepy;
  if (streak >= 7) return MascotMood.excited;
  return MascotMood.happy;
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
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                MascotWidget(mood: _moodForStreak(streak, DateTime.now()), size: 48),
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
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'day streak',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                      Text(label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF666666))),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xFFE0E0E0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF111111)),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('$xp XP · $toNext to next level',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF666666))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFAAAAAA)),
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
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF666666))),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: milestoneProgress.clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFE0E0E0),
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
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Text('×$freezes freeze',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111))),
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
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
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
                    color: const Color(0xFF111111),
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
