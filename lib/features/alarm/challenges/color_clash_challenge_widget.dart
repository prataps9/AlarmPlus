import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The colours a Color Clash round can use.
enum ClashColor {
  red('RED', Color(0xFFEF4444)),
  blue('BLUE', Color(0xFF3B82F6)),
  green('GREEN', Color(0xFF22C55E)),
  yellow('YELLOW', Color(0xFFEAB308)),
  purple('PURPLE', Color(0xFFA855F7));

  const ClashColor(this.word, this.color);

  final String word;
  final Color color;
}

/// One Stroop prompt: [word] printed in [ink]. The answer is the ink.
class ClashRound {
  const ClashRound({required this.word, required this.ink, required this.options});

  final ClashColor word;
  final ClashColor ink;

  /// Four choices, always including [ink] and (on a mismatch) the
  /// tempting [word].
  final List<ClashColor> options;
}

/// Color Clash (a Stroop test): name the *ink* colour, not the word. Reading
/// is automatic, so overriding it takes real attention, which is hard to fake
/// half-asleep and quick once you're awake. A wrong tap resets the streak.
///
/// Kept free of Flutter widgets so the rules are unit-testable.
class ColorClashGame {
  ColorClashGame({Random? random, this.target = 5}) : _rng = random ?? Random() {
    round = _nextRound();
  }

  final Random _rng;

  /// Correct answers in a row needed to pass.
  final int target;

  int streak = 0;
  int mistakes = 0;
  late ClashRound round;

  bool get won => streak >= target;

  /// Scores a tap and deals the next round. Returns whether it was right.
  bool answer(ClashColor choice) {
    final correct = choice == round.ink;
    if (correct) {
      streak++;
    } else {
      streak = 0;
      mistakes++;
    }
    if (!won) round = _nextRound();
    return correct;
  }

  ClashRound _nextRound() {
    final all = ClashColor.values;
    final word = all[_rng.nextInt(all.length)];
    // Mostly mismatched (that's the hard part); an occasional match stops
    // "never tap the word" from becoming a shortcut.
    final mismatch = _rng.nextDouble() < 0.8;
    final inks = mismatch ? all.where((c) => c != word).toList() : [word];
    final ink = inks[_rng.nextInt(inks.length)];

    final options = <ClashColor>{ink, word};
    final rest = all.where((c) => !options.contains(c)).toList()..shuffle(_rng);
    options.addAll(rest.take(4 - options.length));
    return ClashRound(
      word: word,
      ink: ink,
      options: options.toList()..shuffle(_rng),
    );
  }
}

class ColorClashChallengeWidget extends StatefulWidget {
  const ColorClashChallengeWidget({
    super.key,
    required this.onPassed,
    required this.onFailed,
    this.target = 5,
    @visibleForTesting this.random,
  });

  final VoidCallback onPassed;

  /// Part of the shared challenge contract. Color Clash never gives up on
  /// its own: a wrong tap only resets the streak.
  final VoidCallback onFailed;

  final int target;

  /// Seeded in tests so the expected answers are known.
  final Random? random;

  @override
  State<ColorClashChallengeWidget> createState() =>
      _ColorClashChallengeWidgetState();
}

class _ColorClashChallengeWidgetState extends State<ColorClashChallengeWidget> {
  late final ColorClashGame _game =
      ColorClashGame(target: widget.target, random: widget.random);
  int _roundKey = 0;
  bool _shake = false;

  void _tap(ClashColor c) {
    if (_game.won) return;
    final correct = _game.answer(c);
    if (correct) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _roundKey++;
      _shake = !correct;
    });
    if (_game.won) {
      HapticFeedback.mediumImpact();
      Future<void>.delayed(const Duration(milliseconds: 350), widget.onPassed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = _game.round;
    final word = Text(
      round.word.word,
      style: TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: round.ink.color,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Color Clash',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap the colour of the INK, not the word',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _game.target; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i < _game.streak
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 70,
            child: Center(
              child: _shake
                  ? word.animate(key: ValueKey(_roundKey)).shakeX(hz: 6, amount: 8)
                  : word
                      .animate(key: ValueKey(_roundKey))
                      .fadeIn(duration: 150.ms)
                      .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
            ),
          ),
          if (_game.mistakes > 0 && _game.streak == 0) ...[
            const SizedBox(height: 4),
            const Text('Oops, streak reset!',
                style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: [
              for (final c in round.options)
                // Buttons show the colour *name* in neutral text, so the
                // answer can't be matched by colour alone.
                OutlinedButton(
                  key: ValueKey('clash-${c.name}'),
                  onPressed: () => _tap(c),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                  ),
                  child: Text(
                    c.word,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
