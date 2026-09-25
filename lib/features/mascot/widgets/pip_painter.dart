import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';

/// Draws Pip — a round alarm-clock buddy with twin bells, big eyes and
/// stubby arms — in a 100×100 design box scaled to the canvas.
///
/// Everything that moves is a constructor parameter so `PipMascot` can drive
/// it from its animation controllers; the painter itself holds no state.
class PipPainter extends CustomPainter {
  PipPainter({
    required this.mood,
    required this.body,
    required this.accessory,
    this.blink = 0,
    this.lift = 0,
    this.squash = 0,
    this.armSwing = 0,
    this.bellShake = 0,
    this.phase = 0,
  });

  final MascotMood mood;
  final Color body;
  final MascotAccessory accessory;

  /// 0 = eyes open, 1 = fully closed.
  final double blink;

  /// How far Pip's body is lifted off the ground, in design units. The
  /// shadow stays put and shrinks, which is what sells a jump.
  final double lift;

  /// Positive squashes wide, negative stretches tall.
  final double squash;

  /// -1..1 oscillation for waving / flapping arms.
  final double armSwing;

  /// Bell rotation in radians.
  final double bellShake;

  /// 0..1 looping phase for the floating "z"s and twinkling sparkles.
  final double phase;

  static const _face = Color(0xFFFFFBEB);
  static const _ink = Color(0xFF1E293B);
  static const _cheek = Color(0xFFFB7185);
  static const _gold = Color(0xFFFBBF24);

  Color get _outline => _shade(body, 0.28);
  Color get _bellColor => _shade(body, 0.12);

  static Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * s) / 2,
      (size.height - 100 * s) / 2,
    );
    canvas.scale(s);

    _paintShadow(canvas);

    canvas.save();
    canvas.translate(0, -lift);
    // Squash/stretch pivots on the feet so Pip stays grounded.
    canvas.translate(50, 94);
    canvas.scale(1 + squash, 1 - squash);
    canvas.translate(-50, -94);

    _paintLegs(canvas);
    _paintBells(canvas);
    _paintArm(canvas, left: true);
    _paintBody(canvas);
    _paintArm(canvas, left: false);
    _paintEyes(canvas);
    _paintCheeks(canvas);
    _paintMouth(canvas);
    _paintAccessory(canvas);
    canvas.restore();

    if (mood == MascotMood.sleepy) _paintZs(canvas);
    if (mood == MascotMood.proud || mood == MascotMood.cheering) {
      _paintSparkles(canvas);
    }
    canvas.restore();
  }

  void _paintShadow(Canvas canvas) {
    final shrink = (1 - (lift / 30)).clamp(0.45, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 96),
        width: 46 * shrink,
        height: 6 * shrink,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.12 * shrink),
    );
  }

  void _paintLegs(Canvas canvas) {
    final paint = Paint()..color = _outline;
    for (final x in const [40.0, 60.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, 88), width: 7, height: 12),
          const Radius.circular(3.5),
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 94), width: 13, height: 6),
        paint,
      );
    }
  }

  void _paintBells(Canvas canvas) {
    final fill = Paint()..color = _bellColor;
    final stroke = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    for (final left in const [true, false]) {
      final pivot = Offset(left ? 33 : 67, 30);
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(left ? -0.4 + bellShake : 0.4 - bellShake);
      final dome = Path()
        ..moveTo(-11, 4)
        ..quadraticBezierTo(-11, -13, 0, -13)
        ..quadraticBezierTo(11, -13, 11, 4)
        ..close();
      canvas.drawPath(dome, fill);
      canvas.drawPath(dome, stroke);
      // Flared rim — what makes the domes read as bells rather than ears.
      canvas.drawLine(
        const Offset(-13, 4),
        const Offset(13, 4),
        Paint()
          ..color = _outline
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(const Offset(0, -15), 2.6, fill);
      canvas.drawCircle(const Offset(0, -15), 2.6, stroke);
      canvas.restore();
    }

    // Hammer between the bells — hidden under hats that cover it.
    if (accessory == MascotAccessory.crown ||
        accessory == MascotAccessory.nightcap) {
      return;
    }
    canvas.save();
    canvas.translate(50, 24);
    canvas.rotate(bellShake * 1.6);
    canvas.drawLine(
      Offset.zero,
      const Offset(0, -8),
      Paint()
        ..color = _outline
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(0, -9.5), 3.2, Paint()..color = _outline);
    canvas.restore();
  }

  void _paintArm(Canvas canvas, {required bool left}) {
    final shoulder = Offset(left ? 20 : 80, 60);
    double angle; // radians from +x, y pointing down
    switch (mood) {
      case MascotMood.cheering:
        angle = -1.15 + armSwing * 0.25;
      case MascotMood.waving:
        angle = left ? 1.0 : -1.05 + armSwing * 0.45;
      case MascotMood.worried:
        angle = 1.35;
      case MascotMood.proud:
        angle = left ? 1.0 : 0.25;
      case MascotMood.sleepy:
        angle = 1.25;
      case MascotMood.idle:
      case MascotMood.happy:
        angle = 0.95 + armSwing * 0.08;
    }
    // Mirror the angle for the left arm so both arms point outward.
    final dx = math.cos(angle) * 16;
    final dy = math.sin(angle) * 16;
    final hand = shoulder + Offset(left ? -dx : dx, dy);
    canvas.drawLine(
      shoulder,
      hand,
      Paint()
        ..color = _outline
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(hand, 4.4, Paint()..color = _outline);
  }

  void _paintBody(Canvas canvas) {
    const center = Offset(50, 58);
    canvas.drawCircle(center, 33, Paint()..color = body);
    canvas.drawCircle(
      center,
      33,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
    // Soft highlight so the body reads as round, not flat.
    canvas.drawCircle(
      const Offset(36, 42),
      7,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawCircle(const Offset(50, 60), 25.5, Paint()..color = _face);

    // Clock ticks at 12/3/6/9 — the only hint Pip is an alarm clock
    // besides the bells.
    final tick = Paint()
      ..color = _ink.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 37), const Offset(50, 40), tick);
    canvas.drawLine(const Offset(50, 80), const Offset(50, 83), tick);
    canvas.drawLine(const Offset(27, 60), const Offset(30, 60), tick);
    canvas.drawLine(const Offset(70, 60), const Offset(73, 60), tick);
  }

  void _paintEyes(Canvas canvas) {
    const centers = [Offset(41, 55), Offset(59, 55)];
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case MascotMood.cheering:
        // Happy "^ ^" eyes.
        for (final c in centers) {
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - 5, c.dy + 2)
              ..quadraticBezierTo(c.dx, c.dy - 6, c.dx + 5, c.dy + 2),
            ink,
          );
        }
        return;
      case MascotMood.sleepy:
        // Closed, drooping "u" eyes.
        for (final c in centers) {
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - 5, c.dy)
              ..quadraticBezierTo(c.dx, c.dy + 5, c.dx + 5, c.dy),
            ink,
          );
        }
        return;
      case MascotMood.idle:
      case MascotMood.happy:
      case MascotMood.waving:
      case MascotMood.worried:
      case MascotMood.proud:
        break;
    }

    final open = (1 - blink).clamp(0.0, 1.0);
    if (open < 0.15) {
      for (final c in centers) {
        canvas.drawLine(c.translate(-5, 0), c.translate(5, 0), ink);
      }
    } else {
      final pupilShift = mood == MascotMood.worried
          ? const Offset(0, -1.8)
          : const Offset(0.6, 0.4);
      for (final c in centers) {
        final sclera = Rect.fromCenter(
          center: c,
          width: 13,
          height: 15 * open,
        );
        canvas.drawOval(sclera, Paint()..color = Colors.white);
        canvas.save();
        canvas.clipPath(Path()..addOval(sclera));
        canvas.drawCircle(c + pupilShift, 4.4, Paint()..color = _ink);
        canvas.drawCircle(
          c + pupilShift + const Offset(-1.5, -1.6),
          1.5,
          Paint()..color = Colors.white,
        );
        if (mood == MascotMood.proud) {
          // Heavy upper lid for a confident, half-closed look.
          canvas.drawRect(
            Rect.fromLTRB(c.dx - 8, c.dy - 9, c.dx + 8, c.dy - 1.5),
            Paint()..color = _face,
          );
        }
        canvas.restore();
        canvas.drawOval(
          sclera,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        if (mood == MascotMood.proud) {
          canvas.drawLine(
            Offset(c.dx - 6, c.dy - 1.5),
            Offset(c.dx + 6, c.dy - 1.5),
            ink..strokeWidth = 2,
          );
          ink.strokeWidth = 2.6;
        }
      }
    }

    if (mood == MascotMood.worried) {
      // Brows with raised inner ends.
      canvas.drawLine(const Offset(35, 44), const Offset(45, 41), ink);
      canvas.drawLine(const Offset(65, 44), const Offset(55, 41), ink);
    }
  }

  void _paintCheeks(Canvas canvas) {
    final paint = Paint()..color = _cheek.withValues(alpha: 0.45);
    for (final x in const [31.0, 69.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 66), width: 8, height: 5),
        paint,
      );
    }
  }

  void _paintMouth(Canvas canvas) {
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case MascotMood.idle:
        canvas.drawPath(
          Path()
            ..moveTo(45, 68)
            ..quadraticBezierTo(50, 72, 55, 68),
          stroke,
        );
      case MascotMood.happy:
        canvas.drawPath(
          Path()
            ..moveTo(43, 67)
            ..quadraticBezierTo(50, 75, 57, 67),
          stroke,
        );
      case MascotMood.cheering:
      case MascotMood.waving:
        final big = mood == MascotMood.cheering;
        final mouth = Path()
          ..moveTo(big ? 41 : 43.5, 66)
          ..lineTo(big ? 59 : 56.5, 66)
          ..quadraticBezierTo(50, big ? 82 : 77, big ? 41 : 43.5, 66)
          ..close();
        canvas.drawPath(mouth, Paint()..color = const Color(0xFF7F1D1D));
        canvas.save();
        canvas.clipPath(mouth);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(50, big ? 76 : 73),
            width: 10,
            height: 7,
          ),
          Paint()..color = const Color(0xFFFB7185),
        );
        canvas.restore();
        canvas.drawPath(mouth, stroke..strokeWidth = 1.8);
      case MascotMood.sleepy:
        canvas.drawCircle(const Offset(50, 70), 2.4, stroke..strokeWidth = 2);
      case MascotMood.worried:
        canvas.drawPath(
          Path()
            ..moveTo(44, 71)
            ..quadraticBezierTo(47, 68, 50, 70)
            ..quadraticBezierTo(53, 72, 56, 69),
          stroke,
        );
      case MascotMood.proud:
        canvas.drawPath(
          Path()
            ..moveTo(44, 68)
            ..quadraticBezierTo(52, 73, 57, 65),
          stroke,
        );
    }
  }

  void _paintAccessory(Canvas canvas) {
    switch (accessory) {
      case MascotAccessory.none:
        return;
      case MascotAccessory.crown:
        final crown = Path()
          ..moveTo(37, 29)
          ..lineTo(35, 13)
          ..lineTo(43, 20)
          ..lineTo(50, 8)
          ..lineTo(57, 20)
          ..lineTo(65, 13)
          ..lineTo(63, 29)
          ..close();
        canvas.drawPath(crown, Paint()..color = _gold);
        canvas.drawPath(
          crown,
          Paint()
            ..color = const Color(0xFFB45309)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawCircle(const Offset(50, 22), 2.6,
            Paint()..color = const Color(0xFFEF4444));
        canvas.drawCircle(const Offset(41.5, 25), 1.8,
            Paint()..color = const Color(0xFF3B82F6));
        canvas.drawCircle(const Offset(58.5, 25), 1.8,
            Paint()..color = const Color(0xFF3B82F6));
      case MascotAccessory.shades:
        final lens = Paint()..color = const Color(0xFF0F172A);
        final left = RRect.fromRectAndRadius(
          const Rect.fromLTRB(32, 49, 48, 60),
          const Radius.circular(5),
        );
        final right = RRect.fromRectAndRadius(
          const Rect.fromLTRB(52, 49, 68, 60),
          const Radius.circular(5),
        );
        canvas.drawRRect(left, lens);
        canvas.drawRRect(right, lens);
        canvas.drawLine(
          const Offset(47, 52),
          const Offset(53, 52),
          Paint()
            ..color = const Color(0xFF0F172A)
            ..strokeWidth = 2.2,
        );
        final glint = Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(35, 55), const Offset(39, 51), glint);
        canvas.drawLine(const Offset(55, 55), const Offset(59, 51), glint);
      case MascotAccessory.nightcap:
        final cap = Path()
          ..moveTo(28, 34)
          ..quadraticBezierTo(38, 14, 58, 16)
          ..quadraticBezierTo(76, 16, 86, 30)
          ..quadraticBezierTo(74, 24, 70, 34)
          ..close();
        canvas.drawPath(cap, Paint()..color = const Color(0xFF1D4ED8));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(26, 30, 74, 37),
            const Radius.circular(3.5),
          ),
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(const Offset(86, 31), 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          const Offset(86, 31),
          4.5,
          Paint()
            ..color = const Color(0xFF1D4ED8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      case MascotAccessory.headphones:
        final band = Paint()
          ..color = const Color(0xFF0F172A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(50, 56), radius: 36),
          math.pi * 1.08,
          math.pi * 0.84,
          false,
          band,
        );
        final cup = Paint()..color = const Color(0xFF0F172A);
        for (final x in const [15.0, 85.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, 52), width: 9, height: 17),
              const Radius.circular(4),
            ),
            cup,
          );
        }
    }
  }

  void _paintZs(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final t = (phase + i / 3) % 1.0;
      final opacity = math.sin(t * math.pi).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: 9 + 5 * t,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF6366F1).withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(74 + 10 * t, 26 - 22 * t));
    }
  }

  void _paintSparkles(Canvas canvas) {
    const spots = [Offset(10, 24), Offset(90, 20), Offset(8, 78), Offset(93, 70)];
    for (var i = 0; i < spots.length; i++) {
      final t = (phase * 2 + i * 0.27) % 1.0;
      final scale = math.sin(t * math.pi);
      if (scale <= 0.05) continue;
      final r = 5.0 * scale;
      final c = spots[i];
      final star = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(star, Paint()..color = _gold.withValues(alpha: scale));
    }
  }

  @override
  bool shouldRepaint(PipPainter old) =>
      old.mood != mood ||
      old.body != body ||
      old.accessory != accessory ||
      old.blink != blink ||
      old.lift != lift ||
      old.squash != squash ||
      old.armSwing != armSwing ||
      old.bellShake != bellShake ||
      old.phase != phase;
}
