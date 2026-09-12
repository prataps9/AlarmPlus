import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alarm_plus/shared/widgets/mascot_widget.dart';

/// Plain data for [ShareCardWidget] — kept separate from live app state so
/// callers can pass in values already on hand (e.g. from a `DismissReward`)
/// without this widget depending on any service directly.
class ShareCardData {
  const ShareCardData({
    required this.streak,
    required this.bestStreak,
    required this.xp,
    required this.levelLabel,
    this.wakeScoreTotal,
  });

  final int streak;
  final int bestStreak;
  final int xp;
  final String levelLabel;
  final int? wakeScoreTotal;
}

/// A fixed-size, portrait "share card" rendered off-screen and captured as a
/// PNG by [ShareService] — not meant to be shown live in the app's normal
/// widget tree. Sized for Instagram Story / WhatsApp status aspect ratios.
class ShareCardWidget extends StatelessWidget {
  const ShareCardWidget({super.key, required this.data});

  final ShareCardData data;

  static const double width = 1080;
  static const double height = 1350;

  String get _flame {
    if (data.streak >= 30) return '🔥🔥🔥';
    if (data.streak >= 7) return '🔥🔥';
    if (data.streak >= 3) return '🔥';
    return '⭐';
  }

  bool get _isNewBest => data.streak > 0 && data.streak >= data.bestStreak;

  @override
  Widget build(BuildContext context) {
    final mood = data.streak >= 7 ? MascotMood.excited : MascotMood.happy;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(72, 96, 72, 72),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MascotWidget(mood: mood, size: 220, animate: false),
                  const SizedBox(height: 40),
                  Text(_flame, style: const TextStyle(fontSize: 96)),
                  const SizedBox(height: 12),
                  Text(
                    '${data.streak}-Day Streak',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (_isNewBest) ...[
                    const SizedBox(height: 16),
                    const _NewBestBadge(),
                  ],
                  const SizedBox(height: 28),
                  _StatPill(label: data.levelLabel, value: '${data.xp} XP'),
                  if (!_isNewBest && data.bestStreak > 0) ...[
                    const SizedBox(height: 16),
                    _StatPill(label: 'Best Streak', value: '${data.bestStreak} days'),
                  ],
                  if (data.wakeScoreTotal != null) ...[
                    const SizedBox(height: 16),
                    _StatPill(label: 'Wake Score', value: '${data.wakeScoreTotal}/100'),
                  ],
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 2, width: 120, color: const Color(0xFF334155)),
                  const SizedBox(height: 20),
                  Text(
                    'ALARM+',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Wake up. Level up.',
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewBestBadge extends StatelessWidget {
  const _NewBestBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '🏆 NEW PERSONAL BEST',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Text(
        '$label · $value',
        style: GoogleFonts.dmSans(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
