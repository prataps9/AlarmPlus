import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/services/mascot_service.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_painter.dart';

/// Pip, the Alarm+ mascot.
///
/// Always alive: a breathing bob, random blinks, and per-mood loops (waving
/// arm, ringing bells, floating z's, sparkles). Switching [mood] plays a
/// one-shot entrance (a jump for [MascotMood.cheering], a shiver for
/// [MascotMood.worried], …) and tapping Pip makes them wiggle and ring.
///
/// Respects the OS "reduce motion" setting by freezing on a still pose.
class PipMascot extends StatefulWidget {
  const PipMascot({
    super.key,
    this.mood = MascotMood.idle,
    this.size = 96,
    this.outfit,
    this.animate = true,
    this.ringing = false,
    this.onTap,
  });

  final MascotMood mood;
  final double size;

  /// Forces an outfit (e.g. previews in the wardrobe). When null Pip wears
  /// whatever [MascotService] says the user picked.
  final MascotOutfit? outfit;

  final bool animate;

  /// Alarm going off: bells shake hard and Pip jitters, whatever the mood.
  final bool ringing;

  final VoidCallback? onTap;

  @override
  State<PipMascot> createState() => _PipMascotState();
}

enum _Action { none, jump, hop, shiver, wiggle, pop }

class _PipMascotState extends State<PipMascot> with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _action = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
  );

  final _rng = math.Random();
  Timer? _blinkTimer;
  _Action _currentAction = _Action.none;
  bool _reduceMotion = false;

  bool get _moving => widget.animate && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncLoop();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playEntrance(widget.mood);
    });
  }

  @override
  void didUpdateWidget(covariant PipMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncLoop();
    if (oldWidget.mood != widget.mood) _playEntrance(widget.mood);
  }

  void _syncLoop() {
    if (_moving) {
      if (!_loop.isAnimating) _loop.repeat();
      _scheduleBlink();
    } else {
      _loop.stop();
      _blinkTimer?.cancel();
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    if (!_moving) return;
    _blinkTimer = Timer(
      Duration(milliseconds: 1800 + _rng.nextInt(3200)),
      () async {
        if (!mounted) return;
        await _blink.forward();
        if (!mounted) return;
        await _blink.reverse();
        if (mounted) _scheduleBlink();
      },
    );
  }

  void _playEntrance(MascotMood mood) {
    _play(switch (mood) {
      MascotMood.cheering => _Action.jump,
      MascotMood.happy || MascotMood.waving => _Action.hop,
      MascotMood.worried => _Action.shiver,
      MascotMood.proud => _Action.pop,
      MascotMood.idle || MascotMood.sleepy => _Action.none,
    });
  }

  void _play(_Action action) {
    if (!_moving || action == _Action.none) return;
    _currentAction = action;
    _action.forward(from: 0);
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _play(_Action.wiggle);
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _loop.dispose();
    _action.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pip the Alarm+ mascot',
      image: true,
      child: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: widget.size,
          child: ListenableBuilder(
            listenable: Listenable.merge(
                [_loop, _action, _blink, MascotService.changes]),
            builder: (context, _) => _buildFrame(),
          ),
        ),
      ),
    );
  }

  Widget _buildFrame() {
    final outfit = widget.outfit ?? MascotService.wornOutfit;
    final mood = widget.mood;
    final p = _loop.value;
    final wave = math.sin(p * math.pi * 2);

    var lift = _moving ? 1.5 + 1.5 * wave : 0.0;
    var squash = _moving ? 0.015 * wave : 0.0;
    var armSwing = 0.0;
    var bellShake = 0.0;
    var dx = 0.0;
    var rotation = 0.0;
    var scale = 1.0;

    if (_moving) {
      switch (mood) {
        case MascotMood.waving:
          armSwing = math.sin(p * math.pi * 8);
        case MascotMood.cheering:
          armSwing = math.sin(p * math.pi * 12);
          bellShake = math.sin(p * math.pi * 24) * 0.18;
        case MascotMood.worried:
          dx = math.sin(p * math.pi * 40) * 0.6;
        case MascotMood.idle:
        case MascotMood.happy:
        case MascotMood.sleepy:
        case MascotMood.proud:
          armSwing = wave;
      }
    }

    if (_moving && widget.ringing) {
      bellShake += math.sin(p * math.pi * 48) * 0.32;
      dx += math.sin(p * math.pi * 72) * 0.7;
    }

    if (_action.isAnimating) {
      final t = _action.value;
      final arc = math.sin(t * math.pi);
      final decay = 1 - t;
      switch (_currentAction) {
        case _Action.jump:
          lift += 22 * arc;
          // Crouch before take-off, stretch in the air, squash on landing.
          squash += t < 0.15
              ? 0.12 * (t / 0.15)
              : t > 0.85
                  ? 0.12 * ((t - 0.85) / 0.15)
                  : -0.08 * arc;
          bellShake += math.sin(t * math.pi * 10) * 0.35 * decay;
        case _Action.hop:
          lift += 8 * arc;
          squash -= 0.04 * arc;
        case _Action.shiver:
          dx += math.sin(t * math.pi * 12) * 3 * decay;
        case _Action.wiggle:
          rotation = math.sin(t * math.pi * 6) * 0.16 * decay;
          bellShake += math.sin(t * math.pi * 14) * 0.45 * decay;
          lift += 4 * arc;
        case _Action.pop:
          scale = 1 + 0.14 * arc;
        case _Action.none:
          break;
      }
    }

    return Transform.translate(
      offset: Offset(dx * widget.size / 100, 0),
      child: Transform.rotate(
        angle: rotation,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scale: scale,
          child: CustomPaint(
            painter: PipPainter(
              mood: mood,
              body: outfit.body,
              accessory: outfit.accessory,
              blink: _blink.value,
              lift: lift,
              squash: squash,
              armSwing: armSwing,
              bellShake: bellShake,
              phase: p,
            ),
          ),
        ),
      ),
    );
  }
}
