import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum MascotMood { sleepy, happy, worried, excited, neutral }

/// A small, code-drawn alarm-clock mascot (no image assets) with a handful
/// of expressive moods, an idle "breathing" bob, and a periodic blink.
class MascotWidget extends StatefulWidget {
  const MascotWidget({
    super.key,
    this.mood = MascotMood.neutral,
    this.size = 96,
    this.animate = true,
    this.color,
  });

  final MascotMood mood;
  final double size;
  final bool animate;
  final Color? color;

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _blinkController;
  late final AnimationController _popController;
  late final Animation<double> _popScale;
  Timer? _blinkTimer;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 0.94).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.94, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(_popController);

    if (widget.animate) {
      _idleController.repeat(reverse: true);
      _scheduleBlink();
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    if (!mounted || !widget.animate) return;
    if (widget.mood == MascotMood.sleepy) {
      // Sleepy mascot keeps its eyes half-closed instead of blinking.
      return;
    }
    final isExcited = widget.mood == MascotMood.excited;
    final minMs = isExcited ? 1200 : 2500;
    final maxMs = isExcited ? 2500 : 5000;
    final delay = Duration(milliseconds: minMs + _rng.nextInt(maxMs - minMs));
    _blinkTimer = Timer(delay, () async {
      if (!mounted) return;
      await _blinkController.forward();
      if (!mounted) return;
      await _blinkController.reverse();
      _scheduleBlink();
    });
  }

  @override
  void didUpdateWidget(covariant MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      if (widget.mood == MascotMood.excited) {
        _popController.forward(from: 0);
      }
      _scheduleBlink();
    }
    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        _idleController.repeat(reverse: true);
        _scheduleBlink();
      } else {
        _idleController.stop();
        _blinkTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idleController.dispose();
    _blinkController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyColor = widget.color ?? const Color(0xFF22C55E);
    final outlineColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return SizedBox(
      width: widget.size,
      height: widget.size * 1.2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_idleController, _blinkController, _popScale]),
            builder: (context, _) {
              final bob = widget.animate
                  ? math.sin(_idleController.value * math.pi) * (widget.size * 0.03)
                  : 0.0;
              return Transform.translate(
                offset: Offset(0, -bob),
                child: Transform.scale(
                  scale: _popScale.value,
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _MascotPainter(
                      mood: widget.mood,
                      blink: _blinkController.value,
                      bodyColor: bodyColor,
                      outlineColor: outlineColor,
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.mood == MascotMood.sleepy && widget.animate)
            Positioned(
              top: 0,
              right: widget.size * 0.02,
              child: Text(
                'z',
                style: TextStyle(
                  fontSize: widget.size * 0.22,
                  fontWeight: FontWeight.w700,
                  color: outlineColor.withValues(alpha: 0.55),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 300.ms)
                  .moveY(begin: 0, end: -widget.size * 0.18, duration: 1400.ms)
                  .fadeOut(delay: 900.ms, duration: 500.ms),
            ),
        ],
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({
    required this.mood,
    required this.blink,
    required this.bodyColor,
    required this.outlineColor,
  });

  final MascotMood mood;
  final double blink; // 0 = eyes open, 1 = fully closed
  final Color bodyColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w * 0.5, size.height * 0.56);
    final radius = w * 0.34;

    final fill = Paint()..color = bodyColor;
    final stroke = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;

    // Feet
    for (final dx in [-0.42, 0.42]) {
      final footCenter = Offset(center.dx + dx * w, center.dy + radius * 0.88);
      final footRect = Rect.fromCenter(center: footCenter, width: w * 0.16, height: w * 0.1);
      canvas.drawOval(footRect, fill);
      canvas.drawOval(footRect, stroke);
    }

    // Bell ears
    for (final dx in [-0.62, 0.62]) {
      final earCenter = Offset(center.dx + dx * radius, center.dy - radius * 0.92);
      canvas.drawCircle(earCenter, radius * 0.34, fill);
      canvas.drawCircle(earCenter, radius * 0.34, stroke);
    }

    // Body (clock face)
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);

    _paintFace(canvas, center, radius);
  }

  void _paintFace(Canvas canvas, Offset center, double radius) {
    final lineColor = const Color(0xFF0F172A);
    final browPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.09
      ..strokeCap = StrokeCap.round;

    final eyeDx = radius * 0.42;
    final eyeDy = -radius * 0.06;
    final leftEye = Offset(center.dx - eyeDx, center.dy + eyeDy);
    final rightEye = Offset(center.dx + eyeDx, center.dy + eyeDy);

    switch (mood) {
      case MascotMood.sleepy:
        _drawClosedEye(canvas, leftEye, radius * 0.22, browPaint);
        _drawClosedEye(canvas, rightEye, radius * 0.22, browPaint);
        _drawMouth(canvas, center, radius, curve: 0.05);
        break;
      case MascotMood.happy:
        _drawEye(canvas, leftEye, radius * 0.16);
        _drawEye(canvas, rightEye, radius * 0.16);
        _drawMouth(canvas, center, radius, curve: 0.45);
        break;
      case MascotMood.worried:
        _drawEye(canvas, leftEye, radius * 0.13);
        _drawEye(canvas, rightEye, radius * 0.13);
        _drawBrows(canvas, center, radius, worried: true);
        _drawMouth(canvas, center, radius, curve: -0.22);
        break;
      case MascotMood.excited:
        _drawEye(canvas, leftEye, radius * 0.2, highlight: true);
        _drawEye(canvas, rightEye, radius * 0.2, highlight: true);
        _drawMouth(canvas, center, radius, curve: 0.55, open: true);
        _drawSparkles(canvas, center, radius);
        break;
      case MascotMood.neutral:
        _drawEye(canvas, leftEye, radius * 0.15);
        _drawEye(canvas, rightEye, radius * 0.15);
        _drawMouth(canvas, center, radius, curve: 0.1);
        break;
    }
  }

  void _drawClosedEye(Canvas canvas, Offset center, double r, Paint paint) {
    final rect = Rect.fromCenter(center: center, width: r * 2.2, height: r * 1.6);
    canvas.drawArc(rect, 0.15 * math.pi, 0.7 * math.pi, false, paint);
  }

  void _drawEye(Canvas canvas, Offset center, double r, {bool highlight = false}) {
    final openAmount = (1 - blink).clamp(0.0, 1.0);
    if (openAmount < 0.08) {
      final linePaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx - r, center.dy),
        Offset(center.dx + r, center.dy),
        linePaint,
      );
      return;
    }

    final height = r * 2 * openAmount;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 2, height: height),
      Paint()..color = Colors.white,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 1.1, height: math.max(height * 0.55, 1)),
      Paint()..color = const Color(0xFF0F172A),
    );
    if (highlight) {
      canvas.drawCircle(
        Offset(center.dx - r * 0.25, center.dy - height * 0.2),
        r * 0.22,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawBrows(Canvas canvas, Offset center, double radius, {required bool worried}) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.07
      ..strokeCap = StrokeCap.round;
    final dy = -radius * 0.36;
    final tilt = worried ? radius * 0.12 : 0.0;
    canvas.drawLine(
      Offset(center.dx - radius * 0.55, center.dy + dy + tilt),
      Offset(center.dx - radius * 0.22, center.dy + dy - tilt * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + radius * 0.22, center.dy + dy - tilt * 0.4),
      Offset(center.dx + radius * 0.55, center.dy + dy + tilt),
      paint,
    );
  }

  void _drawMouth(Canvas canvas, Offset center, double radius, {required double curve, bool open = false}) {
    final mouthCenter = Offset(center.dx, center.dy + radius * 0.42);
    final width = radius * 0.5;
    if (open) {
      final paint = Paint()..color = const Color(0xFF0F172A);
      final path = Path()
        ..moveTo(mouthCenter.dx - width, mouthCenter.dy)
        ..quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + radius * curve,
          mouthCenter.dx + width,
          mouthCenter.dy,
        )
        ..quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + radius * 0.08,
          mouthCenter.dx - width,
          mouthCenter.dy,
        )
        ..close();
      canvas.drawPath(path, paint);
    } else {
      final paint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(mouthCenter.dx - width, mouthCenter.dy)
        ..quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + radius * curve,
          mouthCenter.dx + width,
          mouthCenter.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  void _drawSparkles(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..color = const Color(0xFFFBBF24);
    _drawStar(canvas, Offset(center.dx - radius * 1.05, center.dy - radius * 0.9), radius * 0.14, paint);
    _drawStar(canvas, Offset(center.dx + radius * 1.1, center.dy - radius * 0.6), radius * 0.14, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final angle = (math.pi / 2) * i;
      final outer = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      final innerAngle = angle + math.pi / 4;
      final inner = Offset(
        center.dx + r * 0.35 * math.cos(innerAngle),
        center.dy + r * 0.35 * math.sin(innerAngle),
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.blink != blink ||
        oldDelegate.bodyColor != bodyColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}
