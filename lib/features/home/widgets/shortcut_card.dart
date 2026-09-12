import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';

/// A tappable row on Home that links to a sub-feature.
///
/// Home previously repeated this layout four times with slightly different
/// hardcoded greys each time.
class ShortcutCard extends StatelessWidget {
  const ShortcutCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Optional value shown before the chevron (e.g. a sleep score).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.lg,
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: Spacing.sm),
                  trailing!,
                ],
                const SizedBox(width: Spacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
