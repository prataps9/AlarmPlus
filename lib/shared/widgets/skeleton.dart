import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';

/// A shimmering placeholder block. Used instead of a spinner so the screen
/// keeps its shape while loading rather than collapsing and popping back.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = Radii.md,
  });

  /// A pill-shaped line of text, sized like a [TextStyle] of [fontSize].
  const Skeleton.text({
    super.key,
    this.width = double.infinity,
    double fontSize = 14,
  })  : height = fontSize * 1.4,
        radius = Radii.sm;

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: Motion.fast)
        .then()
        .fade(begin: 1, end: 0.45, duration: 700.ms, curve: Curves.easeInOut);
  }
}

/// Several stacked skeleton lines, for paragraph-shaped content.
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({super.key, this.lines = 3, this.fontSize = 14});

  final int lines;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) const SizedBox(height: Spacing.sm),
          Skeleton.text(
            fontSize: fontSize,
            // Ragged right edge on the final line, like real text.
            width: i == lines - 1 ? 160 : double.infinity,
          ),
        ],
      ],
    );
  }
}
