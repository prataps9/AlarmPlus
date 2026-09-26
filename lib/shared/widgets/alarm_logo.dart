import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Alarm+ logo: a line-drawn clock with a gap in its rim and a "+"
/// nestled in the gap — the same mark as the launcher icon
/// (`assets/icon/app_icon.png`), drawn in code so it is crisp at any size.
///
/// [minuteTurns] rotates the minute hand (1.0 = one full sweep), used by
/// the splash to continue the native launch animation.
class AlarmLogo extends StatelessWidget {
  const AlarmLogo({
    super.key,
    this.size = 96,
    this.color,
    this.minuteTurns = 0,
  });

  final double size;

  /// Defaults to the theme's `onSurface` (near-black on the white theme).
  final Color? color;

  final double minuteTurns;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Alarm+ logo',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: AlarmLogoPainter(
            color: color ?? Theme.of(context).colorScheme.onSurface,
            minuteTurns: minuteTurns,
          ),
        ),
      ),
    );
  }
}

/// Paints the logo in a 1400-unit box — the launcher icon's 1254-px artwork
/// re-centred with margin, identical to the viewport of the Android 12
/// splash vector (`res/drawable/splash_logo_animated.xml`) so the two line
/// up exactly during the hand-off.
class AlarmLogoPainter extends CustomPainter {
  AlarmLogoPainter({required this.color, this.minuteTurns = 0});

  final Color color;
  final double minuteTurns;

  /// Shifts the icon artwork so its bounding box is centred in the 1400 box.
  static const _dx = 83.0;
  static const _dy = 102.0;
  static const _center = Offset(624 + _dx, 607 + _dy);
  static const _radius = 320.0;

  static double _deg(double d) => d * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 1400;
    canvas.save();
    canvas.translate(
      (size.width - 1400 * s) / 2,
      (size.height - 1400 * s) / 2,
    );
    canvas.scale(s);

    final rim = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: _center, radius: _radius);
    // Long arc from bottom-right round to top-right, and a short arc on the
    // right; the gaps between them hold the "+".
    canvas.drawArc(rect, _deg(73), _deg(229), false, rim);
    canvas.drawArc(rect, _deg(-15), _deg(34), false, rim);

    final hand = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32
      ..strokeCap = StrokeCap.round;
    // Hour hand at 4 o'clock.
    const hourAngle = 40.0;
    canvas.drawLine(
      _center,
      _center +
          Offset(math.cos(_deg(hourAngle)), math.sin(_deg(hourAngle))) * 135,
      hand,
    );
    // Minute hand at 12, optionally sweeping.
    final minuteAngle = -90 + 360 * minuteTurns;
    canvas.drawLine(
      _center,
      _center +
          Offset(math.cos(_deg(minuteAngle)), math.sin(_deg(minuteAngle))) *
              168,
      hand,
    );
    canvas.drawCircle(_center, 30, Paint()..color = color);

    // The "+".
    const plus = Offset(848 + _dx, 846 + _dy);
    canvas.drawLine(plus.translate(-70, 0), plus.translate(70, 0), hand);
    canvas.drawLine(plus.translate(0, -70), plus.translate(0, 70), hand);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AlarmLogoPainter old) =>
      old.color != color || old.minuteTurns != minuteTurns;
}
