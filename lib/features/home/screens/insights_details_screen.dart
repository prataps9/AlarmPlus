import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_theme_ext.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/home/providers/insights_providers.dart';
import 'package:alarm_plus/shared/widgets/stat_tile.dart';
import 'package:alarm_plus/shared/widgets/streak_calendar.dart';
import 'package:alarm_plus/shared/widgets/wake_report_widget.dart';

/// The dense view, reached from the Insights overview. Everything here used to
/// sit on the main tab at once, which is what made that screen overwhelming.
class InsightsDetailsScreen extends StatelessWidget {
  const InsightsDetailsScreen({super.key, required this.summary});

  final InsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Full history')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.sm,
            Spacing.xl,
            Spacing.xxxl,
          ),
          children: [
            const SectionHeader(title: 'Wake report'),
            WakeReportCard(history: summary.wakeHistory),
            const SizedBox(height: Spacing.xxl),

            const SectionHeader(title: 'Streak history'),
            _Card(child: StreakCalendarWidget(history: summary.calendar)),
            const SizedBox(height: Spacing.xxl),

            const SectionHeader(title: 'Sleep coach'),
            _CoachDetail(summary: summary),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _CoachDetail extends StatelessWidget {
  const _CoachDetail({required this.summary});

  final InsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coach = summary.coach;

    if (!summary.premiumUnlocked) {
      return _Card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 22,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                'Recovery planning and weekend drift analysis are part of '
                'Lifetime Premium.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final premium = summary.premiumSleep;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(premium.recoveryHeadline, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Icon(
                Icons.battery_charging_full_rounded,
                size: 18,
                color: context.semantics.success,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                'Recovery: ${premium.recoveryIntensity}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          if (coach.sleepDebtMinutes > 0) ...[
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Icon(
                  Icons.bedtime_rounded,
                  size: 18,
                  color: context.semantics.warning,
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Sleep debt: ${coach.sleepDebtMinutes} min',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
          if (premium.recoveryActions.isNotEmpty) ...[
            const Divider(),
            for (final action in premium.recoveryActions)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(action, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
