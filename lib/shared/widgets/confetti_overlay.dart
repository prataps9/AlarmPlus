import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A hand-rolled, single-burst confetti particle system. No external
/// package or asset is used — everything is generated and drawn on one
/// [CustomPainter] pass per frame.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => ConfettiOverlayState();
}

class ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  static const _durationMs = 1500;
  static const _palette = [
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFFFBBF24),
  ];

  late final AnimationController _controller;
  List<_ConfettiParticle> _particles = const [];
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _durationMs),
    );
  }

  /// Fires (or re-fires) a confetti burst. Capped at 150 particles to bound
  /// the per-frame cost of a hand-rolled particle system.
  void burst({int count = 70, List<Color>? colors, Offset? origin}) {
    final size = MediaQuery.of(context).size;
    final startY = origin?.dy ?? -20.0;
    final palette = colors ?? _palette;
    _particles = List.generate(count.clamp(1, 150), (i) {
      final angle = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 200 + _rng.nextDouble() * 260;
      return _ConfettiParticle(
        start: Offset(origin?.dx ?? _rng.nextDouble() * size.width, startY),
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        rotationSpeed: (_rng.nextDouble() - 0.5) * 10,
        initialRotation: _rng.nextDouble() * math.pi * 2,
        color: palette[_rng.nextInt(palette.length)],
        size: 4 + _rng.nextDouble() * 5,
        isCircle: _rng.nextBool(),
      );
    });
    // Restarting rather than layering a second controller keeps a rapid
    // sequence of events (e.g. a dismiss that both levels up and unlocks
    // two badges) to a single particle pass instead of stacking bursts.
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_particles.isEmpty || (_controller.value >= 1 && !_controller.isAnimating)) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              particles: _particles,
              t: _controller.value,
              durationSeconds: _durationMs / 1000,
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.start,
    required this.velocity,
    required this.rotationSpeed,
    required this.initialRotation,
    required this.color,
    required this.size,
    required this.isCircle,
  });

  final Offset start;
  final Offset velocity;
  final double rotationSpeed;
  final double initialRotation;
  final Color color;
  final double size;
  final bool isCircle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.durationSeconds,
  });

  final List<_ConfettiParticle> particles;
  final double t;
  final double durationSeconds;

  static const _gravity = 700.0; // px/s^2

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final elapsed = t * durationSeconds;
    final opacity = t < 0.7 ? 1.0 : (1.0 - ((t - 0.7) / 0.3)).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    for (final p in particles) {
      final x = p.start.dx + p.velocity.dx * elapsed;
      final y = p.start.dy + p.velocity.dy * elapsed + 0.5 * _gravity * elapsed * elapsed;
      final rotation = p.initialRotation + p.rotationSpeed * elapsed;
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
