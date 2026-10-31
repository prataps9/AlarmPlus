import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:alarm_plus/core/services/smart_alarm_service.dart';

class WakeReportCard extends StatelessWidget {
  const WakeReportCard({super.key, required this.history});

  final List<WakeScore> history;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          'Complete your first alarm dismiss to see your Wake Report.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final last7 = history.reversed.take(7).toList().reversed.toList();
    final avg = last7.isEmpty ? 0 : last7.map((s) => s.total).reduce((a, b) => a + b) ~/ last7.length;
    final best = last7.isEmpty ? null : last7.reduce((a, b) => a.total >= b.total ? a : b);
    final worst = last7.isEmpty ? null : last7.reduce((a, b) => a.total <= b.total ? a : b);
    final prevWeek = history.length >= 14
        ? history.reversed.skip(7).take(7).map((s) => s.total).toList()
        : null;
    final prevAvg = prevWeek == null || prevWeek.isEmpty
        ? null
        : prevWeek.reduce((a, b) => a + b) ~/ prevWeek.length;

    String trendLabel;
    IconData trendIcon;
    Color trendColor;
    if (prevAvg == null) {
      trendLabel = 'First week';
      trendIcon = Icons.star_rounded;
      trendColor = const Color(0xFF6366F1);
    } else if (avg > prevAvg + 3) {
      trendLabel = '+${avg - prevAvg} pts vs last week';
      trendIcon = Icons.trending_up_rounded;
      trendColor = const Color(0xFF22C55E);
    } else if (avg < prevAvg - 3) {
      trendLabel = '${avg - prevAvg} pts vs last week';
      trendIcon = Icons.trending_down_rounded;
      trendColor = const Color(0xFFEF4444);
    } else {
      trendLabel = 'Steady this week';
      trendIcon = Icons.trending_flat_rounded;
      trendColor = scheme.onSurfaceVariant;
    }

    final tip = history.isNotEmpty ? SmartAlarmService.wakeScoreTip(history.last) : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Wake Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: scheme.onSurface)),
              const Spacer(),
              Row(
                children: [
                  Icon(trendIcon, color: trendColor, size: 18),
                  const SizedBox(width: 4),
                  Text(trendLabel, style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ScoreCircle(score: avg),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (best != null)
                      Text('Best: ${best.total}/100', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF22C55E))),
                    if (worst != null)
                      Text('Worst: ${worst.total}/100', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(tip, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (last7.length >= 2)
            SizedBox(
              height: 60,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: last7.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.total.toDouble())).toList(),
                      isCurved: true,
                      color: const Color(0xFF6366F1),
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0x1A6366F1),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 100,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? const Color(0xFF22C55E)
        : score >= 50
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100.0,
            strokeWidth: 7,
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '$score',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
