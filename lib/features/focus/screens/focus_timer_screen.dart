import 'dart:async';

import 'package:flutter/material.dart';

import 'package:alarm_plus/core/services/live_timer_notification_service.dart';
import 'package:alarm_plus/features/focus/services/focus_timer_service.dart';
import 'package:alarm_plus/shared/widgets/focus_ring.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  static const routeName = '/focus-timer';

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  static const int _initialSeconds = 25 * 60;

  int _secondsLeft = _initialSeconds;
  Timer? _timer;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_initialSeconds - _secondsLeft) / _initialSeconds;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FOCUS TIMER',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            letterSpacing: 3,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            FocusRing(progress: progress, timeLabel: _formatTime(_secondsLeft)),
            const SizedBox(height: 34),
            Text(
              _running ? 'Flow in progress' : 'Ready to start a deep session',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _running ? _pause : _start,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_running ? 'Pause' : 'Start'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _start() {
    if (_running) {
      return;
    }

    setState(() {
      _running = true;
    });

    unawaited(FocusTimerService.start(Duration(seconds: _secondsLeft)));
    unawaited(LiveTimerNotificationService.showFocus(_secondsLeft));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _running = false;
        });
        unawaited(FocusTimerService.cancel());
        unawaited(LiveTimerNotificationService.cancel());
        return;
      }

      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _running = false;
    });
    unawaited(FocusTimerService.cancel());
    unawaited(LiveTimerNotificationService.cancel());
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _initialSeconds;
      _running = false;
    });
    unawaited(FocusTimerService.cancel());
    unawaited(LiveTimerNotificationService.cancel());
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
