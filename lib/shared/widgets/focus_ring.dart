import 'dart:math';

import 'package:flutter/material.dart';

class FocusRing extends StatelessWidget {
  const FocusRing({super.key, required this.progress, required this.timeLabel});

  final double progress;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(280),
            painter: _FocusRingPainter(
              progress: progress,
              trackColor: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('FOCUS TIMER', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              Text(
                timeLabel,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 54,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({required this.progress, required this.trackColor});

  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = trackColor;
    const accentPaint = Color(0xFF22C55E);

    final strokeBackground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = backgroundPaint;

    final strokeProgress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = accentPaint;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12;

    canvas.drawCircle(center, radius, strokeBackground);

    final sweep = 2 * pi * progress.clamp(0, 1);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      strokeProgress,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor;
  }
}
