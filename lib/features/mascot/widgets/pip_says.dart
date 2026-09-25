import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/mascot/models/mascot_line.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_mascot.dart';

/// Pip with a speech bubble beside them — the Duolingo-style "the owl is
/// talking to you" row. The bubble pops in again whenever the text changes.
class PipSays extends StatelessWidget {
  const PipSays({
    super.key,
    required this.line,
    this.size = 84,
    this.onTap,
  });

  final MascotLine line;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        PipMascot(mood: line.mood, size: size, onTap: onTap),
        const SizedBox(width: Spacing.xs),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.3),
            child: SpeechBubble(text: line.text),
          ),
        ),
      ],
    );
  }
}

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _BubblePainter(
        fill: scheme.surfaceContainerHighest,
        border: scheme.outlineVariant,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg + 8, Spacing.md, Spacing.lg, Spacing.md),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                height: 1.35,
              ),
        ),
      ),
    )
        .animate(key: ValueKey(text))
        .fadeIn(duration: 180.ms)
        .scale(
          begin: const Offset(0.85, 0.85),
          alignment: Alignment.bottomLeft,
          duration: 420.ms,
          curve: Curves.elasticOut,
        );
  }
}

/// Rounded bubble with a small tail on the bottom-left pointing at Pip.
class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  static const _tail = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(_tail, 0, size.width - _tail, size.height),
      const Radius.circular(Radii.lg),
    );
    final tail = Path()
      ..moveTo(_tail + 2, size.height - 22)
      ..lineTo(0, size.height - 8)
      ..lineTo(_tail + 2, size.height - 12)
      ..close();
    // Union so the border traces one outline instead of drawing the
    // bubble's edge across the base of the tail.
    final path =
        Path.combine(PathOperation.union, Path()..addRRect(body), tail);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.fill != fill || old.border != border;
}
