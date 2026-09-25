import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import 'package:alarm_plus/core/services/celebration_event.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_mascot.dart';
import 'package:alarm_plus/shared/widgets/confetti_overlay.dart';

/// Sits above the [Navigator] (wired in via `MaterialApp.builder`) so it can
/// show a confetti burst + banner for level-ups and badge unlocks no matter
/// which screen is currently pushed — including the alarm ring screen.
class CelebrationOverlayHost extends StatefulWidget {
  const CelebrationOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<CelebrationOverlayHost> createState() => _CelebrationOverlayHostState();
}

class _CelebrationOverlayHostState extends State<CelebrationOverlayHost> {
  final _confettiKey = GlobalKey<ConfettiOverlayState>();
  final _player = AudioPlayer();
  StreamSubscription<CelebrationEvent>? _subscription;
  String? _bannerText;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _subscription = SmartAlarmService.celebrationEvents.listen(_onEvent);
  }

  void _onEvent(CelebrationEvent event) {
    _confettiKey.currentState?.burst();
    unawaited(_playFeedback());

    if (CelebrationBus.mutePresentation) return;

    final text = switch (event.kind) {
      CelebrationKind.levelUp =>
        'Level Up! ${SmartAlarmService.levelLabel((event.level ?? 0) * 500)}',
      CelebrationKind.badgeUnlocked =>
        'Badge Unlocked: ${SmartAlarmService.badgeDisplayName(event.badgeId ?? '') ?? event.badgeId}',
      CelebrationKind.streakMilestone => '${event.streakDays}-Day Streak!',
    };

    setState(() => _bannerText = text);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _bannerText = null);
    });
  }

  Future<void> _playFeedback() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        unawaited(Vibration.vibrate(duration: 60));
      }
    } catch (_) {
      // Vibration is best-effort feedback; ignore platforms without it.
    }
    try {
      await _player.play(AssetSource('sounds/celebration.wav'));
    } catch (_) {
      // Fall back to a system click if the asset can't be played for some
      // reason (e.g. audio session unavailable on this platform/device).
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _bannerTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned.fill(child: ConfettiOverlay(key: _confettiKey)),
        if (_bannerText != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: _CelebrationBanner(text: _bannerText!, isDark: isDark),
            ),
          ),
      ],
    );
  }
}

class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PipMascot(mood: MascotMood.cheering, size: 48),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
