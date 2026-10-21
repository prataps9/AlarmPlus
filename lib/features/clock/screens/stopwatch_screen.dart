import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/clock/models/clock_models.dart';
import 'package:alarm_plus/features/clock/services/clock_service.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen>
    with SingleTickerProviderStateMixin {
  StopwatchState _state = StopwatchState.reset;
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    ClockService.loadStopwatch().then((s) {
      if (!mounted) return;
      setState(() => _state = s);
      if (s.isRunning) _ticker.start();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _update(StopwatchState next) {
    HapticFeedback.selectionClick();
    setState(() => _state = next);
    ClockService.saveStopwatch(next);
    if (next.isRunning && !_ticker.isActive) _ticker.start();
    if (!next.isRunning && _ticker.isActive) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final elapsed = _state.elapsed(now);
    final splits = _state.lapSplits;
    final best = splits.length > 1 ? splits.reduce((a, b) => a < b ? a : b) : null;
    final worst = splits.length > 1 ? splits.reduce((a, b) => a > b ? a : b) : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stopwatch',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 30)),
            const SizedBox(height: Spacing.xl),
            Center(
              child: SizedBox.square(
                dimension: 260,
                child: CustomPaint(
                  painter: _SecondsRing(
                    fraction: (elapsed.inMilliseconds % 60000) / 60000,
                    track: scheme.outlineVariant,
                    color: scheme.primary,
                  ),
                  child: Center(
                    child: Text(
                      TimeFormat.stopwatch(elapsed),
                      style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w300,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xl),
            Expanded(
              child: ListView(
                children: [
                  for (var i = splits.length - 1; i >= 0; i--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text('Lap ${i + 1}',
                                style: theme.textTheme.bodyMedium),
                          ),
                          Expanded(
                            child: Text(
                              TimeFormat.stopwatch(splits[i]),
                              style: TextStyle(
                                fontSize: 17,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: splits[i] == best
                                    ? Palette.green600
                                    : splits[i] == worst
                                        ? Palette.red500
                                        : scheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            TimeFormat.stopwatch(_state.laps[i]),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _state.isPristine
                        ? null
                        : () => _update(_state.isRunning
                            ? _state.lap(DateTime.now())
                            : StopwatchState.reset),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(_state.isRunning ? 'Lap' : 'Reset'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _update(_state.isRunning
                        ? _state.pause(DateTime.now())
                        : _state.start(DateTime.now())),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                      backgroundColor:
                          _state.isRunning ? Palette.red500 : scheme.primary,
                    ),
                    child: Text(_state.isRunning
                        ? 'Pause'
                        : _state.isPristine
                            ? 'Start'
                            : 'Resume'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin ring that fills once per minute.
class _SecondsRing extends CustomPainter {
  _SecondsRing({required this.fraction, required this.track, required this.color});

  final double fraction;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(6);
    canvas.drawArc(ring, 0, math.pi * 2, false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    canvas.drawArc(ring, -math.pi / 2, math.pi * 2 * fraction, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_SecondsRing old) => old.fraction != fraction;
}
