import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:alarm_plus/core/services/live_alarm_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

/// The in-app twin of the status-bar capsule (LiveActivity.kt): the next
/// ring as a dark pill with a progress ring that fills over the last two
/// hours, a countdown that turns to seconds inside the last hour, and a warm
/// glow in the final five minutes.
class NextAlarmCapsule extends StatefulWidget {
  const NextAlarmCapsule({super.key, required this.alarms});

  final List<AlarmModel> alarms;

  /// "7h 20m", "1d 3h", or "42:09" inside the last hour. Pure, for tests.
  static String formatCountdown(Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    if (total.inHours < 1) {
      final m = total.inMinutes.toString().padLeft(2, '0');
      final s = (total.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    if (total.inDays >= 1) {
      return '${total.inDays}d ${total.inHours % 24}h';
    }
    return '${total.inHours}h ${(total.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  /// How far the ring is filled: empty until the last [window], then full
  /// at the ring. Pure, for tests.
  static double progress(Duration remaining, Duration window) {
    if (remaining >= window) return 0;
    if (remaining <= Duration.zero) return 1;
    return 1 - remaining.inMilliseconds / window.inMilliseconds;
  }

  @override
  State<NextAlarmCapsule> createState() => _NextAlarmCapsuleState();
}

class _NextAlarmCapsuleState extends State<NextAlarmCapsule>
    with SingleTickerProviderStateMixin {
  static const _window = AlarmService.upcomingNoticeLead;

  late final AnimationController _glow;
  Timer? _tick;
  DateTime _now = DateTime.now();
  Map<int, DateTime> _pending = const {};

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300));
    _loadPending();
    _schedule();
  }

  @override
  void didUpdateWidget(NextAlarmCapsule old) {
    super.didUpdateWidget(old);
    if (old.alarms != widget.alarms) _loadPending();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _glow.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    final p = await AlarmService.pendingRings(widget.alarms);
    if (mounted) setState(() => _pending = p);
  }

  /// Every second inside the last hour (the countdown shows seconds), every
  /// 20 s otherwise.
  void _schedule() {
    _tick?.cancel();
    final ring = LiveAlarmService.pickNext(widget.alarms, DateTime.now(), _pending);
    final remaining = ring?.at.difference(DateTime.now());
    final fast = remaining != null && remaining < const Duration(hours: 1);
    _tick = Timer(Duration(seconds: fast ? 1 : 20), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ring = LiveAlarmService.pickNext(widget.alarms, _now, _pending);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);

    if (ring == null) {
      if (!reduceMotion && !_glow.isAnimating) _glow.repeat(reverse: true);
      return _empty(context, reduceMotion);
    }

    final remaining = ring.at.difference(_now);
    final urgent = remaining < const Duration(minutes: 5);
    final accent = urgent
        ? Color.lerp(const Color(0xFFF59E0B), const Color(0xFFEF4444),
            1 - remaining.inSeconds.clamp(0, 300) / 300)!
        : const Color(0xFF3B82F6);
    if (urgent && !reduceMotion) {
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
    } else if (_glow.isAnimating) {
      _glow.stop();
    }
    final words = LiveAlarmService.wording(ring, _now, use24h: use24h);

    final card = AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1220), Color(0xFF1E293B)],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: urgent ? 0.25 + 0.3 * _glow.value : 0.14),
              blurRadius: urgent ? 18 + 14 * _glow.value : 18,
              spreadRadius: urgent ? 1 + 2 * _glow.value : 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 20, 14),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: NextAlarmCapsule.progress(remaining, _window)),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CustomPaint(
                  painter: _RingPainter(value, accent),
                  child: Center(
                    child: Icon(
                      ring.snoozed
                          ? Icons.snooze_rounded
                          : Icons.alarm_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ring.snoozed ? 'SNOOZED' : 'NEXT ALARM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _Odometer(
                    text: NextAlarmCapsule.formatCountdown(remaining),
                    animate: !reduceMotion,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    words.title.split(' · ').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    words.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final semantics = Semantics(
      container: true,
      label: '${ring.snoozed ? 'Snoozed alarm' : 'Next alarm'} at '
          '${words.title.split(' · ').last}, '
          'in ${remaining.inHours} hours ${remaining.inMinutes % 60} minutes',
      excludeSemantics: true,
      child: card,
    );
    return reduceMotion
        ? semantics
        : semantics
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.12, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
  }

  Widget _empty(BuildContext context, bool reduceMotion) {
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(Icons.alarm_off_rounded,
        color: scheme.onSurfaceVariant, size: 26);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          reduceMotion
              ? icon
              : ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                      CurvedAnimation(parent: _glow, curve: Curves.easeInOut)),
                  child: icon,
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('No alarm set. Tap + to add one.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// Digits that roll upward when they change, like the system capsule's
/// ticking countdown. Fixed-width figures keep the layout still.
class _Odometer extends StatelessWidget {
  const _Odometer({required this.text, required this.animate});

  final String text;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 30,
      height: 1.1,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    if (!animate) return Text(text, style: style);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.45),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.14),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
