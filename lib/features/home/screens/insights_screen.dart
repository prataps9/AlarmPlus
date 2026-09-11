import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/core/services/share_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/shared/widgets/share_card_widget.dart';
import 'package:alarm_plus/shared/widgets/streak_calendar.dart';
import 'package:alarm_plus/shared/widgets/wake_report_widget.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _selectedDayIndex = 0;

  @override
  Widget build(BuildContext context) {
    final alarmsAsync = ref.watch(alarmsListProvider);

    return SafeArea(
      child: alarmsAsync.when(
        data: (alarms) {
          final insightData = _buildInsightData(alarms);
          final sleepSnapshotFuture = SmartAlarmService.buildSleepCoachSnapshot(
            alarms,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
            children: [
              Text(
                'YOUR WEEK',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  letterSpacing: 3,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Insights',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),
              // Wake Quality Report
              FutureBuilder<List<WakeScore>>(
                future: SmartAlarmService.getWakeScoreHistory(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WAKE REPORT',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 3, color: const Color(0xFF64748B))),
                      const SizedBox(height: 10),
                      WakeReportCard(history: snap.data!),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
              // Streak Calendar
              FutureBuilder<Map<String, bool>>(
                future: SmartAlarmService.getCalendarHistory(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STREAK HISTORY',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 3, color: const Color(0xFF64748B))),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: StreakCalendarWidget(history: snap.data!),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
              _buildBarChart(context, insightData),
              const SizedBox(height: 12),
              _buildLineChart(context, insightData),
              const SizedBox(height: 12),
              _buildSelectedDaySummary(context, insightData),
              const SizedBox(height: 18),
              Text(
                'FOCUS INTENSITY',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  letterSpacing: 3,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              _HeatMap(values: insightData.heatValues),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x070F172A),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        insightData.focusText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<(AlarmStats, int, int)>(
                future: Future.wait([
                  SmartAlarmService.getStats(),
                  SmartAlarmService.getXp(),
                  SmartAlarmService.getBestWakeScore(),
                ]).then((r) => (r[0] as AlarmStats, r[1] as int, r[2] as int)),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final stats = data?.$1;
                  final xp = data?.$2 ?? 0;
                  final bestScore = data?.$3;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          stats == null
                              ? 'Loading wake behavior metrics...'
                              : 'Streak ${stats.currentStreak} days · Best ${stats.bestStreak} · Snooze ${stats.snoozeCount} · Missed ${stats.missedCount}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (stats != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => ShareService.shareCard(
                              context,
                              card: ShareCardWidget(
                                data: ShareCardData(
                                  streak: stats.currentStreak,
                                  xp: xp,
                                  levelLabel: SmartAlarmService.levelLabel(xp),
                                  wakeScoreTotal: bestScore,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.ios_share_rounded, size: 18),
                            label: const Text('Share My Progress'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              foregroundColor: const Color(0xFF22C55E),
                              side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              FutureBuilder<SleepCoachSnapshot>(
                future: sleepSnapshotFuture,
                builder: (context, snapshot) {
                  final coach = snapshot.data;
                  return FutureBuilder<bool>(
                    future: PremiumService.canUse(PremiumFeature.sleepCoachPro),
                    builder: (context, premiumSnapshot) {
                      final unlocked = premiumSnapshot.data ?? false;
                      return FutureBuilder<PremiumSleepSnapshot>(
                        future: SmartAlarmService.buildPremiumSleepSnapshot(
                          alarms,
                        ),
                        builder: (context, premiumSleepSnapshot) {
                          final premiumSleep = premiumSleepSnapshot.data;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: unlocked && coach == null && premiumSleep == null
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    unlocked
                                        ? (premiumSleep != null
                                              ? '${premiumSleep.recoveryHeadline} · Recovery ${premiumSleep.recoveryIntensity} · ${premiumSleep.recoveryActions.take(2).join(' · ')}'
                                              : coach?.headline ?? 'Enable an alarm to get your personalised sleep coach target.')
                                        : 'Sleep Coach Pro, recovery planner, and weekend drift guard are part of Lifetime Premium ₹299.',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, _InsightData insightData) {
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F172A),
              getTooltipItem: (group, _, rod, __) {
                const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                return BarTooltipItem(
                  '${labels[group.x]}: ${rod.toY.toStringAsFixed(0)}%',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                );
              },
            ),
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions) {
                return;
              }
              final spot = response?.spot;
              if (spot == null) {
                return;
              }
              setState(() => _selectedDayIndex = spot.touchedBarGroupIndex);
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final index = value.toInt();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  final isSelected = index == _selectedDayIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[index],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        letterSpacing: 1.8,
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(
            insightData.bars.length,
            (index) {
              final isSelected = index == _selectedDayIndex;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: insightData.bars[index],
                    width: isSelected ? 20 : 16,
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(BuildContext context, _InsightData insightData) {
    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F172A),
              getTooltipItems: (spots) => spots
                  .map(
                    (spot) => LineTooltipItem(
                      '${spot.y.toStringAsFixed(0)}%',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions) {
                return;
              }
              final spots = response?.lineBarSpots;
              final spot = (spots != null && spots.isNotEmpty) ? spots.first : null;
              if (spot == null) {
                return;
              }
              setState(() => _selectedDayIndex = spot.x.toInt());
            },
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: const Color(0xFF0F172A),
              barWidth: 2.2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) {
                  final isSelected = spot.x.toInt() == _selectedDayIndex;
                  return FlDotCirclePainter(
                    radius: isSelected ? 4.5 : 3.0,
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                    strokeWidth: 0,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0x140F172A),
              ),
              spots: List.generate(
                insightData.bars.length,
                (index) => FlSpot(index.toDouble(), insightData.bars[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDaySummary(BuildContext context, _InsightData insightData) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayLabel = labels[_selectedDayIndex];
    final value = insightData.bars[_selectedDayIndex].toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        '$dayLabel focus score: $value%',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  _InsightData _buildInsightData(List<AlarmModel> alarms) {
    final enabledAlarms = alarms.where((alarm) => alarm.isEnabled).toList();
    final dayCounts = List<double>.filled(7, 0);

    for (final alarm in enabledAlarms) {
      if (alarm.repeatDays.isEmpty) {
        final dayIndex = alarm.nextDateTimeFrom(DateTime.now()).weekday - 1;
        dayCounts[dayIndex] += 1;
      } else {
        for (final day in alarm.repeatDays) {
          dayCounts[day - 1] += 1;
        }
      }
    }

    final maxCount = dayCounts.reduce((a, b) => a > b ? a : b);
    final bars = dayCounts
        .map((count) => maxCount == 0 ? 20.0 : 20 + ((count / maxCount) * 72))
        .toList();

    final heatValues = List<int>.generate(28, (index) {
      final dayIndex = index % 7;
      final intensity = maxCount == 0
          ? 0
          : (dayCounts[dayIndex] / maxCount) * 4;
      return intensity.round().clamp(0, 4);
    });

    final focusText = _buildFocusText(enabledAlarms, dayCounts);
    return _InsightData(
      bars: bars,
      heatValues: heatValues,
      focusText: focusText,
    );
  }

  String _buildFocusText(List<AlarmModel> alarms, List<double> dayCounts) {
    if (alarms.isEmpty) {
      return 'Add and enable alarms to unlock personalized focus insights.';
    }

    var totalMinutes = 0;
    for (final alarm in alarms) {
      totalMinutes += (alarm.time.hour * 60) + alarm.time.minute;
    }
    final avgMinutes = (totalMinutes / alarms.length).round();
    final avgHour = avgMinutes ~/ 60;
    final avgMinute = avgMinutes % 60;

    var bestDayIndex = 0;
    var bestDayValue = dayCounts[0];
    for (var i = 1; i < dayCounts.length; i++) {
      if (dayCounts[i] > bestDayValue) {
        bestDayValue = dayCounts[i];
        bestDayIndex = i;
      }
    }

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hh = avgHour == 0 ? 12 : (avgHour > 12 ? avgHour - 12 : avgHour);
    final mm = avgMinute.toString().padLeft(2, '0');
    final period = avgHour >= 12 ? 'PM' : 'AM';

    return 'Most alarms cluster on ${dayLabels[bestDayIndex]} around $hh:$mm $period.';
  }

}

class _HeatMap extends StatelessWidget {
  const _HeatMap({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final shades = [
      const Color(0xFF000000),
      const Color(0xFF5B5B5B),
      const Color(0xFF808080),
      const Color(0xFFB0B0B0),
      const Color(0xFFD4D4D4),
    ];

    return GridView.builder(
      itemCount: values.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: shades[values[index]],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

class _InsightData {
  const _InsightData({
    required this.bars,
    required this.heatValues,
    required this.focusText,
  });

  final List<double> bars;
  final List<int> heatValues;
  final String focusText;
}
