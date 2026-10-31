import 'package:flutter/material.dart';

class StreakCalendarWidget extends StatelessWidget {
  const StreakCalendarWidget({super.key, required this.history});

  /// Keys are 'YYYY-MM-DD', values: true = dismissed, false = missed/snoozed
  final Map<String, bool> history;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final startDate = today.subtract(const Duration(days: 89));
    final days = List.generate(90, (i) => startDate.add(Duration(days: i)));

    // Group by week
    final weeks = <List<DateTime?>>[];
    var currentWeek = <DateTime?>[];
    // Pad first week
    final firstWeekday = days.first.weekday % 7; // 0=Sun
    for (var i = 0; i < firstWeekday; i++) {
      currentWeek.add(null);
    }
    for (final day in days) {
      currentWeek.add(day);
      if (currentWeek.length == 7) {
        weeks.add(List<DateTime?>.from(currentWeek));
        currentWeek = [];
      }
    }
    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) { currentWeek.add(null); }
      weeks.add(currentWeek);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day labels
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) {
            return Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        ...weeks.map((week) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: week.map((day) {
                if (day == null) {
                  return const Expanded(child: SizedBox(height: 14));
                }
                final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                final isFuture = day.isAfter(today);
                final status = history[key];

                Color cellColor;
                if (isFuture) {
                  cellColor = scheme.surfaceContainerHighest;
                } else if (status == null) {
                  cellColor = scheme.outlineVariant;
                } else if (status) {
                  cellColor = const Color(0xFF22C55E);
                } else {
                  cellColor = const Color(0xFFEF4444);
                }

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    height: 14,
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(3),
                      border: isToday
                          ? Border.all(color: isDark ? scheme.onSurface : const Color(0xFF1E40AF), width: 1.5)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            _LegendDot(color: const Color(0xFF22C55E), label: 'Dismissed'),
            const SizedBox(width: 12),
            _LegendDot(color: const Color(0xFFEF4444), label: 'Missed'),
            const SizedBox(width: 12),
            _LegendDot(color: scheme.outlineVariant, label: 'No alarm'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
