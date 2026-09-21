import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';

class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onToggle,
    this.onTap,
    this.onDelete,
    this.onToggleSkip,
  });

  final AlarmModel alarm;
  final ValueChanged<bool> onToggle;

  /// Opens the alarm for editing.
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// Skips the next occurrence, or restores it if already skipped.
  final VoidCallback? onToggleSkip;

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
                // Stated plainly: a silently skipped alarm is exactly the kind
                // of surprise an alarm app must never spring on someone.
                if (alarm.isSkippingNext) ...[
                  const SizedBox(height: Spacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.skip_next_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Expanded(
                        child: Text(
                          'Skipping the next one',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
                    // Skipping only means anything for an armed alarm.
                    if (onToggleSkip != null && alarm.isEnabled)
                      TextButton(
                        onPressed: onToggleSkip,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(alarm.isSkippingNext ? 'Undo' : 'Skip next'),
                      ),
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
