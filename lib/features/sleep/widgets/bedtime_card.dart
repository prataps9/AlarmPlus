import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/sleep/models/bedtime_schedule.dart';
import 'package:alarm_plus/features/sleep/services/bedtime_service.dart';

/// "Go to bed by 10:30 PM for 8 h of sleep" — bedtime worked back from the
/// next alarm and the user's sleep goal, with an optional nightly reminder.
class BedtimeCard extends StatefulWidget {
  const BedtimeCard({super.key, required this.alarms});

  final List<AlarmModel> alarms;

  @override
  State<BedtimeCard> createState() => _BedtimeCardState();
}

class _BedtimeCardState extends State<BedtimeCard> {
  BedtimeSchedule? _schedule;

  @override
  void initState() {
    super.initState();
    BedtimeService.load().then((s) {
      if (mounted) setState(() => _schedule = s);
    });
  }

  BedtimeSchedule get _current =>
      _schedule ??
      const BedtimeSchedule(targetBedtime: TimeOfDay(hour: 22, minute: 30));

  DateTime? get _nextAlarm {
    final now = DateTime.now();
    DateTime? next;
    for (final a in widget.alarms.where((a) => a.isEnabled)) {
      final t = a.nextDateTimeFrom(now);
      if (next == null || t.isBefore(next)) next = t;
    }
    return next;
  }

  Future<void> _save(BedtimeSchedule s) async {
    setState(() => _schedule = s);
    await BedtimeService.save(s);
  }

  static String _goalLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  Future<void> _edit() async {
    var goal = _current.sleepGoalMinutes;
    var remind = _current.isEnabled;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sleep goal: ${_goalLabel(goal)}',
                  style: Theme.of(ctx).textTheme.titleMedium),
              Slider(
                value: goal.toDouble(),
                min: 5 * 60,
                max: 10 * 60,
                divisions: 10,
                label: _goalLabel(goal),
                onChanged: (v) => setSheet(() => goal = v.round()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bedtime reminder'),
                subtitle: Text(
                    'A nudge ${_current.windDownMinutes} min before bedtime'),
                value: remind,
                onChanged: (v) => setSheet(() => remind = v),
              ),
              const SizedBox(height: Spacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final alarm = _nextAlarm;
    final bedtime = alarm == null
        ? null
        : BedtimeSchedule.bedtimeFor(alarm, goal);
    await _save(_current.copyWith(
      sleepGoalMinutes: goal,
      isEnabled: remind,
      targetBedtime: bedtime == null ? null : TimeOfDay.fromDateTime(bedtime),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final alarm = _nextAlarm;
    final goal = _current.sleepGoalMinutes;
    final bedtime =
        alarm == null ? null : BedtimeSchedule.bedtimeFor(alarm, goal);
    final fmt = DateFormat.jm();

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: _edit,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Icon(Icons.bedtime_outlined, color: scheme.onSurface, size: 28),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bedtime == null
                            ? 'Bedtime'
                            : 'Go to bed by ${fmt.format(bedtime)}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bedtime == null
                            ? 'Set an alarm to get a bedtime for your ${_goalLabel(goal)} sleep goal'
                            : '${_goalLabel(goal)} of sleep before your ${fmt.format(alarm!)} alarm',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_current.isEnabled)
                  Icon(Icons.notifications_active_outlined,
                      size: 20, color: scheme.onSurfaceVariant),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
