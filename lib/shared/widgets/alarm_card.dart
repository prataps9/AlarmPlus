import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';

class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onToggle,
    this.onTap,
    this.onDelete,
    this.onSkipNext,
  });

  final AlarmModel alarm;
  final ValueChanged<bool> onToggle;

  /// Opens the alarm for editing.
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// Skips (true) or restores (false) the next occurrence. Only offered for
  /// enabled, repeating alarms.
  final ValueChanged<bool>? onSkipNext;

  @override
  Widget build(BuildContext context) {
    final card = _buildCard(context);
    if (onDelete == null) return card;

    // Swipe is the only delete affordance; the card used to carry a trash
    // icon as well, which meant two paths to the same confirmation dialog.
    return Dismissible(
      key: ValueKey(alarm.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.xxl),
        margin: const EdgeInsets.only(bottom: Spacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.onError,
          size: 28,
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete!(),
      child: card,
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final subtitle = alarm.label.isNotEmpty
        ? '${alarm.timeLabel} ${alarm.periodLabel} — ${alarm.label}'
        : '${alarm.timeLabel} ${alarm.periodLabel}';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete alarm?'),
        content: Text('$subtitle will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // A disabled alarm reads as muted rather than a different design.
    final timeColor =
        alarm.isEnabled ? scheme.onSurface : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.xl),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.xl,
              vertical: Spacing.xxl,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.xl),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontSize: 58,
                              fontWeight: FontWeight.w500,
                              color: timeColor,
                              height: 0.95,
                            ),
                            children: [
                              TextSpan(text: alarm.timeLabel),
                              TextSpan(
                                text: ' ${alarm.periodLabel}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w400,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Switch(value: alarm.isEnabled, onChanged: onToggle),
                  ],
                ),
                if (alarm.label.isNotEmpty) ...[
                  const SizedBox(height: Spacing.xs),
                  Text(
                    alarm.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: timeColor,
                    ),
                  ),
                ],
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    if (alarm.tag.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md,
                          vertical: Spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          alarm.tag,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                    ],
                    Expanded(
                      child: Text(
                        alarm.repeatLabel,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (onSkipNext != null &&
                        alarm.isEnabled &&
                        alarm.repeatDays.isNotEmpty)
                      _SkipChip(alarm: alarm, onChanged: onSkipNext!),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Skip next" / "Skips Mon, 29 Sep ✕" for a repeating alarm.
class _SkipChip extends StatelessWidget {
  const _SkipChip({required this.alarm, required this.onChanged});

  final AlarmModel alarm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final skipping = alarm.isSkippingFrom(DateTime.now());
    if (!skipping) {
      return TextButton(
        onPressed: () => onChanged(true),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        ),
        child: const Text('Skip next'),
      );
    }
    return InputChip(
      label: Text('Skips ${DateFormat('EEE, d MMM').format(alarm.skipDate!)}'),
      avatar: const Icon(Icons.event_busy_rounded, size: 18),
      onDeleted: () => onChanged(false),
      deleteButtonTooltipMessage: 'Undo skip',
      backgroundColor: const Color(0xFFFEF3C7),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
