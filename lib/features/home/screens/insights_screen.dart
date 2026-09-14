import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alarm_plus/core/services/share_service.dart';
import 'package:alarm_plus/core/theme/app_theme_ext.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/home/providers/insights_providers.dart';
import 'package:alarm_plus/features/home/screens/insights_details_screen.dart';
import 'package:alarm_plus/shared/widgets/share_card_widget.dart';
import 'package:alarm_plus/shared/widgets/skeleton.dart';
import 'package:alarm_plus/shared/widgets/stat_tile.dart';

/// The calm overview: one score, one streak, a few stats and a single chart.
/// Everything denser — the 90-day calendar, the focus heat map, the full wake
/// report — lives one tap away in [InsightsDetailsScreen].
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(insightsSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(insightsSummaryProvider),
          child: summaryAsync.when(
            data: (summary) => _InsightsBody(summary: summary),
            loading: () => const _InsightsSkeleton(),
            error: (err, _) => _InsightsError(
              onRetry: () => ref.invalidate(insightsSummaryProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.summary});

  final InsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    final stats = summary.stats;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.sm,
        Spacing.xl,
        Spacing.xxxl,
      ),
      children: [
        _WakeScoreHero(summary: summary),
        const SizedBox(height: Spacing.xxl),

        const SectionHeader(title: 'This week'),
        _StatGrid(summary: summary),
        const SizedBox(height: Spacing.xxl),

        const SectionHeader(title: 'Alarms by day'),
        _WeeklyChart(load: summary.weekdayLoad),
        const SizedBox(height: Spacing.md),
        Text(
          summary.weekdayLoad.headline,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Spacing.xxl),

        _CoachCard(summary: summary),
        const SizedBox(height: Spacing.xxl),

        FilledButton.tonalIcon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => InsightsDetailsScreen(summary: summary),
            ),
          ),
          icon: const Icon(Icons.bar_chart_rounded, size: 20),
          label: const Text('See full history'),
        ),
        const SizedBox(height: Spacing.md),
        OutlinedButton.icon(
          onPressed: () => ShareService.shareCard(
            context,
            card: ShareCardWidget(
              data: ShareCardData(
                streak: stats.currentStreak,
                bestStreak: stats.bestStreak,
                xp: summary.xp,
                levelLabel: summary.levelLabel,
                wakeScoreTotal: summary.bestWakeScore,
              ),
            ),
          ),
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('Share my progress'),
        ),
      ],
    );
  }
}

/// Big single number: how well you've been waking up lately.
class _WakeScoreHero extends StatelessWidget {
  const _WakeScoreHero({required this.summary});

  final InsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final score = summary.averageWakeScore;
    final streak = summary.stats.currentStreak;

    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Row(
        children: [
          _ScoreRing(score: score),
          const SizedBox(width: Spacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score == null ? 'No wake-ups yet' : 'Average wake score',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 20,
                      color: semantics.streakTier(streak),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      streak == 1 ? '1 day streak' : '$streak day streak',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                _LevelBar(summary: summary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final value = score ?? 0;
    final color = switch (value) {
      >= 80 => semantics.success,
      >= 50 => semantics.warning,
      _ => semantics.danger,
    };

    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: score == null ? 0 : value / 100,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: theme.colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            score == null ? '—' : '$value',
            style: theme.textTheme.headlineMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.summary});

  final InsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: summary.levelProgress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: theme.colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          '${summary.levelLabel} · ${summary.xpToNextLevel} XP to next',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});

  final InsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    final stats = summary.stats;
    final semantics = context.semantics;

    final tiles = [
      StatTile(
        label: 'Best streak',
        value: '${stats.bestStreak}',
        caption: stats.bestStreak == 1 ? 'day' : 'days',
        icon: Icons.emoji_events_rounded,
        accent: semantics.streakGold,
      ),
      StatTile(
        label: 'On time',
        value: '${stats.dismissCount}',
        caption: 'wake-ups',
        icon: Icons.check_circle_rounded,
        accent: semantics.success,
      ),
      StatTile(
        label: 'Snoozed',
        value: '${stats.snoozeCount}',
        caption: 'times',
        icon: Icons.snooze_rounded,
        accent: semantics.warning,
      ),
      StatTile(
        label: 'Missed',
        value: '${stats.missedCount}',
        caption: 'alarms',
        icon: Icons.notifications_off_rounded,
        accent: stats.missedCount == 0 ? null : semantics.danger,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: Spacing.md,
      mainAxisSpacing: Spacing.md,
      childAspectRatio: 1.7,
      children: tiles,
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.load});

  final WeekdayLoad load;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    if (load.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Text('No enabled alarms yet', style: theme.textTheme.bodyMedium),
      );
    }

    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: load.max,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${WeekdayLoad.dayLabels[group.x]}\n${rod.toY.toInt()}',
                theme.textTheme.bodySmall ?? const TextStyle(),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(
                    WeekdayLoad.dayLabels[value.toInt()],
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < load.countsByWeekday.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: load.countsByWeekday[i],
                    width: 18,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    color: load.countsByWeekday[i] == load.max
                        ? theme.colorScheme.primary
                        : semantics.chartGrid,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.summary});

  final InsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final message = summary.premiumUnlocked
        ? summary.premiumSleep.recoveryHeadline
        : 'Sleep Coach Pro, the recovery planner and the weekend drift guard '
            'are part of Lifetime Premium.';

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            summary.premiumUnlocked
                ? Icons.lightbulb_rounded
                : Icons.lock_outline_rounded,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: theme.textTheme.bodyLarge),
                if (summary.premiumUnlocked &&
                    summary.premiumSleep.recoveryActions.isNotEmpty) ...[
                  const SizedBox(height: Spacing.sm),
                  Text(
                    summary.premiumSleep.recoveryActions.first,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.sm,
        Spacing.xl,
        Spacing.xxxl,
      ),
      children: const [
        Skeleton(height: 132, radius: Radii.xl),
        SizedBox(height: Spacing.xxl),
        Skeleton.text(width: 90, fontSize: 11),
        SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(child: Skeleton(height: 84, radius: Radii.lg)),
            SizedBox(width: Spacing.md),
            Expanded(child: Skeleton(height: 84, radius: Radii.lg)),
          ],
        ),
        SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(child: Skeleton(height: 84, radius: Radii.lg)),
            SizedBox(width: Spacing.md),
            Expanded(child: Skeleton(height: 84, radius: Radii.lg)),
          ],
        ),
        SizedBox(height: Spacing.xxl),
        Skeleton(height: 150, radius: Radii.lg),
      ],
    );
  }
}

class _InsightsError extends StatelessWidget {
  const _InsightsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.xxxl),
      children: [
        const SizedBox(height: Spacing.xxxl),
        Center(
          child: Icon(
            Icons.error_outline_rounded,
            size: 96,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xl),
        Text(
          "Couldn't load your insights",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Your alarms and streak are safe — this is just the stats view.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Spacing.xl),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
