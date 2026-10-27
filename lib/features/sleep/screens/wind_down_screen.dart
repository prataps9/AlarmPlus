import 'dart:async';

import 'package:flutter/material.dart';

import 'package:alarm_plus/features/sleep/services/bedtime_service.dart';
import 'package:alarm_plus/features/sleep/services/sleep_sound_service.dart';

class WindDownScreen extends StatefulWidget {
  const WindDownScreen({super.key});

  static const routeName = '/wind-down';

  @override
  State<WindDownScreen> createState() => _WindDownScreenState();
}

class _WindDownScreenState extends State<WindDownScreen>
    with SingleTickerProviderStateMixin {
  // 4-7-8 breathing: inhale 4s, hold 7s, exhale 8s
  static const _phaseDurations = [4, 7, 8];
  static const _phaseLabels = ['Inhale', 'Hold', 'Exhale'];
  static const _phaseColors = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF3B82F6),
  ];

  int _phase = 0;
  int _phaseSecondsLeft = _phaseDurations[0];
  int _cycleCount = 0;
  bool _inBedDone = false;
  bool _markingInBed = false;
  Timer? _timer;
  late AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _phaseSecondsLeft--;
        if (_phaseSecondsLeft <= 0) {
          _phase = (_phase + 1) % 3;
          _phaseSecondsLeft = _phaseDurations[_phase];
          if (_phase == 0) _cycleCount++;
          // Adjust breath animation speed per phase
          _breathController.duration = Duration(seconds: _phaseDurations[_phase]);
          _breathController.forward(from: 0);
          if (_phase == 2) {
            _breathController.reverse(from: 1);
          }
        }
      });
    });
  }

  Future<void> _markInBed() async {
    // A double tap paid the +20 XP twice.
    if (_markingInBed) return;
    _markingInBed = true;
    try {
      await _markInBedOnce();
    } finally {
      _markingInBed = false;
    }
  }

  Future<void> _markInBedOnce() async {
    if (SleepSoundService.isPlaying()) {
      final stop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sleep Sounds Playing'),
          content: const Text('Do you want to stop the sounds now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continue Playing'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Stop Sounds'),
            ),
          ],
        ),
      );
      if (stop == true) SleepSoundService.stop();
    }
    // recordInBed pays the XP, so only call it once a day; reopening the
    // screen let the button be pressed (and paid) again every time.
    final alreadyInBed = await BedtimeService.isInBedToday();
    if (!alreadyInBed) await BedtimeService.recordInBed();
    if (!mounted) return;
    setState(() => _inBedDone = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(alreadyInBed
            ? 'Sweet dreams! 🌙'
            : '+20 XP — Sweet dreams! 🌙'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = _phaseColors[_phase];
    final phaseLabel = _phaseLabels[_phase];

    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    'Cycle $_cycleCount',
                    style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                '4-7-8 Breathing',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24),
              ),
              const SizedBox(height: 8),
              const Text(
                'Breathe in for 4 · Hold for 7 · Out for 8',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              AnimatedBuilder(
                animation: _breathController,
                builder: (context, child) {
                  final scale = 0.6 + (_breathController.value * 0.4);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: phaseColor.withValues(alpha: 0.15),
                        border: Border.all(color: phaseColor, width: 3),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            phaseLabel,
                            style: TextStyle(
                              color: phaseColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            '$_phaseSecondsLeft s',
                            style: const TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/sleep-sounds'),
                  icon: const Text('🎵', style: TextStyle(fontSize: 18)),
                  label: const Text('Sleep Sounds',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Color(0xFF334155)),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!_inBedDone)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _markInBed,
                    icon: const Text('🌙', style: TextStyle(fontSize: 20)),
                    label: const Text("I'm In Bed  +20 XP", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 58),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('✓', style: TextStyle(color: Color(0xFF6366F1), fontSize: 20)),
                      SizedBox(width: 8),
                      Text('Bedtime logged. Sleep well!', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
