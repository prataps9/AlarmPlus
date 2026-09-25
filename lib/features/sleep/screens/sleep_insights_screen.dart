import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:alarm_plus/features/sleep/models/sleep_entry.dart';
import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/features/sleep/services/sleep_analytics_service.dart';
import 'package:alarm_plus/features/sleep/services/sleep_diary_service.dart';

class SleepInsightsScreen extends StatefulWidget {
  const SleepInsightsScreen({super.key});

  static const routeName = '/sleep-insights';

  @override
  State<SleepInsightsScreen> createState() => _SleepInsightsScreenState();
}

class _SleepInsightsScreenState extends State<SleepInsightsScreen> {
  late Future<_InsightsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_InsightsData> _load() async {
    final isPremium = await PremiumService.isLifetimePremiumUnlocked();
    final score = await SleepAnalyticsService.weeklyScore();
    final bestDay = await SleepAnalyticsService.bestWakeDay();
    final avgSnooze = await SleepAnalyticsService.avgSnoozeCount();
    final debtMin = await SleepAnalyticsService.sleepDebt();
    final daily = await SleepAnalyticsService.dailyScores();
    final diaryEntries = await SleepDiaryService.getLast7Days();
    final diaryNotes = await SleepDiaryService.getRecentNotes(limit: 3);
    return _InsightsData(
      isPremium: isPremium,
      weeklyScore: score,
      bestDay: bestDay,
      avgSnooze: avgSnooze,
      sleepDebt: debtMin,
      dailyScores: daily,
      diaryEntries: diaryEntries,
      diaryNotes: diaryNotes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'SLEEP INSIGHTS',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF64748B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<_InsightsData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
            children: [
              _buildScoreCard(data),
              const SizedBox(height: 20),
              _buildStatsRow(data),
              const SizedBox(height: 24),
              _buildChartSection(data),
              const SizedBox(height: 24),
              _buildQualityTrendSection(data),
              const SizedBox(height: 24),
              _buildDiaryNotesSection(context, data),
              if (!data.isPremium) ...[
                const SizedBox(height: 24),
                _buildPremiumBanner(context),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildScoreCard(_InsightsData data) {
    final color = data.weeklyScore >= 80
        ? const Color(0xFF22C55E)
        : data.weeklyScore >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weekly Score', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text(
                '${data.weeklyScore}',
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: color),
              ),
              Text(
                SleepAnalyticsService.scoreLabel(data.weeklyScore),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: data.weeklyScore / 100,
                  strokeWidth: 8,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text(
                  '${data.weeklyScore}%',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(_InsightsData data) {
    return Row(
      children: [
        Expanded(child: _StatChip(label: 'Best Day', value: data.bestDay)),
        const SizedBox(width: 10),
        Expanded(child: _StatChip(label: 'Avg Snooze', value: '${data.avgSnooze.toStringAsFixed(1)}×')),
        const SizedBox(width: 10),
        Expanded(child: _StatChip(label: 'Sleep Debt', value: '${data.sleepDebt}m')),
      ],
    );
  }

  Widget _buildChartSection(_InsightsData data) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final labelStart = now.subtract(const Duration(days: 6)).weekday - 1;

    Widget chart = BarChart(
      BarChartData(
        maxY: 100,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = ((labelStart + value.toInt()) % 7).clamp(0, 6);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(dayLabels[idx], style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) {
          final score = data.dailyScores[i];
          final color = score >= 80
              ? const Color(0xFF22C55E)
              : score >= 60
                  ? const Color(0xFFF59E0B)
                  : score > 0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFE2E8F0);
          return BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: score > 0 ? score : 5, color: color, width: 20, borderRadius: BorderRadius.circular(6))],
          );
        }),
      ),
    );

    if (!data.isPremium) {
      chart = Stack(
        children: [
          chart,
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          const Center(
            child: Text(
              'Unlock Full Trends\nwith Pro',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('7-Day Trend', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(height: 180, child: chart),
      ],
    );
  }

  Widget _buildQualityTrendSection(_InsightsData data) {
    final entries = data.diaryEntries;
    final hasData = entries.any((e) => e != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sleep Quality Trend',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        if (!hasData)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text('No diary entries yet — start logging!',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: 1,
                maxY: 5,
                lineTouchData: const LineTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final now = DateTime.now();
                        final day = now.subtract(Duration(days: 6 - value.toInt()));
                        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final label = labels[(day.weekday - 1).clamp(0, 6)];
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(label,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(7, (i) {
                      final entry = entries[i];
                      return FlSpot(i.toDouble(),
                          entry != null ? entry.sleepQuality.toDouble() : double.nan);
                    }),
                    isCurved: true,
                    color: const Color(0xFF6366F1),
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDiaryNotesSection(BuildContext context, _InsightsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Notes',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        if (data.diaryNotes.isEmpty)
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/sleep-diary'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Text('📓', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Start logging your sleep diary →',
                        style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          )
        else
          ...data.diaryNotes.map((note) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(note,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              )),
      ],
    );
  }

  Widget _buildPremiumBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unlock Your Full Sleep Trends', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('See your daily wake scores with Alarm+ Pro', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final unlocked = await PremiumService.showLifetimePaywall(
                  context, PremiumFeature.sleepCoachPro);
              if (unlocked && mounted) setState(() => _dataFuture = _load());
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _InsightsData {
  const _InsightsData({
    required this.isPremium,
    required this.weeklyScore,
    required this.bestDay,
    required this.avgSnooze,
    required this.sleepDebt,
    required this.dailyScores,
    required this.diaryEntries,
    required this.diaryNotes,
  });

  final bool isPremium;
  final int weeklyScore;
  final String bestDay;
  final double avgSnooze;
  final int sleepDebt;
  final List<double> dailyScores;
  final List<SleepEntry?> diaryEntries;
  final List<String> diaryNotes;
}
