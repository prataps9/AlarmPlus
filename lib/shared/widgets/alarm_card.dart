import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';
import 'package:alarm_plus/shared/widgets/press_scale.dart';

class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onToggle,
    this.onTap,
    this.onDelete,
    this.onLongPress,
    this.onSkipNext,
  });

  final AlarmModel alarm;
  final ValueChanged<bool> onToggle;

  /// Opens the alarm for editing.
  final VoidCallback? onTap;

  /// Called after a swipe removes the card. There's no confirmation: the
  /// caller offers Undo instead, which is quicker and just as safe.
  final VoidCallback? onDelete;

  /// More actions (duplicate, delete).
  final VoidCallback? onLongPress;

  /// Skips (true) or restores (false) the next occurrence. Only offered for
  /// enabled, repeating alarms.
  final ValueChanged<bool>? onSkipNext;

  @override
  Widget build(BuildContext context) {
    final card = _buildCard(context);
    if (onDelete == null) return card;

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
      onDismissed: (_) => onDelete!(),
      child: card,
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clock = TimeFormat.clock(
      alarm.time.hour,
      alarm.time.minute,
      use24h: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    // A disabled alarm reads as muted rather than a different design.
    final timeColor =
        alarm.isEnabled ? scheme.onSurface : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: PressScale(child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.xl),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
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
                              TextSpan(text: clock.time),
                              if (clock.period != null)
                                TextSpan(
                                  text: ' ${clock.period}',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
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
                    Switch(
                      value: alarm.isEnabled,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        onToggle(v);
                      },
                    ),
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
                    // Wrap, not a squeezed Row: with a tag, a repeat label
                    // and "Skip next" together, "Weekdays" used to break
                    // mid-word. Now the pieces move to a second line instead.
                    Expanded(
                      child: Wrap(
                        spacing: Spacing.md,
                        runSpacing: Spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (alarm.tag.isNotEmpty)
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
                          Text(
                            alarm.repeatLabel,
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (alarm.isEnabled &&
                              alarm.isPausedAt(DateTime.now()))
                            // While paused, "Skip next" would be meaningless.
                            Text(
                              'Paused until ${DateFormat('EEE, d MMM').format(alarm.pausedUntil!)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.tertiary,
                              ),
                            )
                          else if (onSkipNext != null &&
                              alarm.isEnabled &&
                              alarm.repeatDays.isNotEmpty)
                            _SkipChip(alarm: alarm, onChanged: onSkipNext!),
                        ],
                      ),
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
      )),
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
