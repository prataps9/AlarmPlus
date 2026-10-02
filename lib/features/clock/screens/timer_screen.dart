import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/clock/models/clock_models.dart';
import 'package:alarm_plus/features/clock/services/clock_service.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';

/// Countdown timer with keypad entry, like the stock clock app. The
/// "time's up" alert is an OS-scheduled notification (see ClockService), so
/// it rings even if the app is closed.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
  TimerInput _input = const TimerInput();
  CountdownState? _timer;
  bool _timesUp = false;
  late final Ticker _ticker = createTicker(_onTick);

  static const _presets = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  @override
  void initState() {
    super.initState();
    ClockService.loadTimer().then((t) {
      if (!mounted || t == null) return;
      setState(() => _timer = t);
      if (t.isRunning) _ticker.start();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    final t = _timer;
    if (t != null && !_timesUp && t.isDone(DateTime.now())) {
      HapticFeedback.heavyImpact();
      _timesUp = true;
    }
    setState(() {});
  }

  Future<void> _set(CountdownState? next) async {
    setState(() {
      _timer = next;
      if (next == null || !next.isDone(DateTime.now())) _timesUp = false;
    });
    if (next != null && next.isRunning) {
      if (!_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive && !_timesUp) {
      _ticker.stop();
    }
    await ClockService.saveTimer(next);
  }

  void _start(Duration d) {
    if (d == Duration.zero) return;
    HapticFeedback.selectionClick();
    _input = const TimerInput();
    _set(CountdownState.startNew(d, DateTime.now()));
  }

  Future<void> _stopAlert() async {
    await ClockService.dismissTimesUp();
    _ticker.stop();
    await _set(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timer',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 30)),
            Expanded(child: _timer == null ? _buildEntry(context) : _buildRunning(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String two(int v) => v.toString().padLeft(2, '0');
    Widget field(int v, String unit) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(two(v),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w300,
                  color: _input.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
                )),
            Text(unit, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
          ],
        );

    return Column(
      children: [
        const SizedBox(height: Spacing.xl),
        // Scales down on narrow phones / large font settings instead of
        // overflowing.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(_input.hours, 'h'),
              field(_input.minutes, 'm'),
              field(_input.seconds, 's'),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.sm,
          children: [
            for (final p in _presets)
              ActionChip(
                label: Text('${p.inMinutes} min'),
                onPressed: () => _start(p),
              ),
          ],
        ),
        const Spacer(),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.9,
          children: [
            for (final d in [1, 2, 3, 4, 5, 6, 7, 8, 9])
              _Key(label: '$d', onTap: () => setState(() => _input = _input.type(d))),
            _Key(
              label: '00',
              onTap: () => setState(() => _input = _input.type(0).type(0)),
            ),
            _Key(label: '0', onTap: () => setState(() => _input = _input.type(0))),
            _Key(
              icon: Icons.backspace_outlined,
              onTap: () => setState(() => _input = _input.backspace()),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        FloatingActionButton.large(
          heroTag: 'timer-start',
          tooltip: 'Start',
          onPressed: _input.isEmpty ? null : () => _start(_input.duration),
          backgroundColor: _input.isEmpty ? scheme.surfaceContainerHighest : scheme.primary,
          child: Icon(Icons.play_arrow_rounded,
              size: 40, color: _input.isEmpty ? scheme.onSurfaceVariant : scheme.onPrimary),
        ),
      ],
    );
  }

  Widget _buildRunning(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = _timer!;
    final now = DateTime.now();
    final remaining = t.remaining(now);
    // Flash the readout while it's ringing.
    final flashOn = !_timesUp || (now.millisecondsSinceEpoch ~/ 500).isEven;

    return Column(
      children: [
        const Spacer(),
        SizedBox.square(
          dimension: 280,
          child: CustomPaint(
            painter: _CountdownRing(
              fraction: t.fraction(now),
              track: scheme.outlineVariant,
              color: _timesUp ? Palette.red500 : scheme.primary,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: flashOn ? 1 : 0.25,
                    child: Text(
                      _timesUp
                          ? "Time's up"
                          : TimeFormat.stopwatch(
                              // Round up so it shows 0:01 until the last second ends.
                              remaining + const Duration(milliseconds: 999),
                              centis: false,
                            ),
                      style: TextStyle(
                        fontSize: _timesUp ? 36 : 54,
                        fontWeight: FontWeight.w300,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: _timesUp ? Palette.red500 : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (!_timesUp && t.isPaused)
                    Text('Paused', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        if (!_timesUp)
          TextButton(
            onPressed: () => _set(t.extend(const Duration(minutes: 1), DateTime.now())),
            child: const Text('+1:00'),
          ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.outlined(
              tooltip: 'Delete timer',
              iconSize: 28,
              onPressed: _stopAlert,
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: Spacing.xxl),
            FloatingActionButton.large(
              heroTag: 'timer-toggle',
              tooltip: _timesUp ? 'Stop' : t.isRunning ? 'Pause' : 'Resume',
              backgroundColor: _timesUp ? Palette.red500 : scheme.primary,
              onPressed: () {
                HapticFeedback.selectionClick();
                if (_timesUp) {
                  _stopAlert();
                } else if (t.isRunning) {
                  _set(t.pause(DateTime.now()));
                } else {
                  _set(t.resume(DateTime.now()));
                }
              },
              child: Icon(
                _timesUp
                    ? Icons.stop_rounded
                    : t.isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const StadiumBorder(),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Center(
        child: icon != null
            ? Icon(icon, size: 26)
            : Text(label!, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

class _CountdownRing extends CustomPainter {
  _CountdownRing({required this.fraction, required this.track, required this.color});

  final double fraction;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = (Offset.zero & size).deflate(8);
    canvas.drawArc(ring, 0, math.pi * 2, false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);
    if (fraction > 0) {
      canvas.drawArc(ring, -math.pi / 2, math.pi * 2 * fraction, false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_CountdownRing old) =>
      old.fraction != fraction || old.color != color;
}
