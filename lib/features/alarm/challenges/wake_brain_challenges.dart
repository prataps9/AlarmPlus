import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:alarm_plus/core/services/native_controls.dart';
import 'package:alarm_plus/core/theme/app_theme_ext.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/challenges/morning_quiz.dart';
import 'package:alarm_plus/features/alarm/challenges/recall_round.dart';

/// Reads [text] aloud with Android's own text-to-speech, on the alarm
/// stream so it is heard over the ringing and at alarm volume. Silent
/// where there is no engine (tests, desktop).
Future<void> sayAloud(String text) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await NativeControls.channel
        .invokeMethod<void>('speak', {'text': text, 'alarmStream': true});
  } catch (_) {}
}

/// The flat card both challenges sit in, with a title row and a "read it
/// again" button.
class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.icon,
    required this.title,
    required this.progress,
    required this.child,
    this.onSpeak,
  });

  final IconData icon;
  final String title;
  final String progress;
  final Widget child;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSurface),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary, size: 22),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: scheme.primary)),
              ),
              Text(progress,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
              if (onSpeak != null)
                IconButton(
                  tooltip: 'Read aloud',
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          AnimatedSwitcher(
            duration: Motion.normal,
            switchInCurve: Motion.standard,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.06, 0), end: Offset.zero)
                    .animate(a),
                child: child,
              ),
            ),
            child: child,
          ),
        ],
      ),
      ),
    );
  }
}

/// A tappable answer that turns green/red once answered.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.onTap,
    this.state,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;

  /// true = shown as right, false = shown as wrong, null = not marked.
  final bool? state;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.semantics;
    var bg = scheme.surfaceContainerHighest;
    var border = scheme.outlineVariant;
    var fg = scheme.onSurface;
    if (selected) {
      bg = scheme.primary.withValues(alpha: 0.12);
      border = scheme.primary;
      fg = scheme.primary;
    }
    if (state == true) {
      bg = s.success.withValues(alpha: 0.14);
      border = s.success;
      fg = s.success;
    } else if (state == false) {
      bg = s.danger.withValues(alpha: 0.14);
      border = s.danger;
      fg = s.danger;
    }
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: fg)),
        ),
      ),
    );
  }
}

/// "Wake-up questions": orientation questions about today and this alarm
/// (see [MorningQuiz]). A wrong answer swaps in a new question; the alarm
/// stops only after [count] right answers.
class MorningQuizChallengeWidget extends StatefulWidget {
  const MorningQuizChallengeWidget({
    super.key,
    required this.onPassed,
    this.facts = const QuizFacts(),
    this.count = 3,
    this.now,
    this.random,
    this.speak = true,
  });

  final VoidCallback onPassed;
  final QuizFacts facts;
  final int count;
  final DateTime? now;
  final Random? random;
  final bool speak;

  @override
  State<MorningQuizChallengeWidget> createState() =>
      _MorningQuizChallengeWidgetState();
}

class _MorningQuizChallengeWidgetState extends State<MorningQuizChallengeWidget> {
  late final Random _rng = widget.random ?? Random();
  late List<QuizQuestion> _questions;
  int _index = 0;
  int? _picked;
  int _version = 0;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _questions = MorningQuiz.generate(_now, widget.facts, _rng, count: widget.count);
    _say();
  }

  QuizQuestion get _q => _questions[_index];

  void _say() {
    if (widget.speak) sayAloud(_q.spoken ?? _q.prompt);
  }

  void _answer(int i) {
    if (_picked != null) return;
    final right = i == _q.answerIndex;
    right ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() => _picked = i);
    Future.delayed(Duration(milliseconds: right ? 600 : 900), () {
      if (!mounted) return;
      if (right && _index + 1 >= _questions.length) {
        widget.onPassed();
        return;
      }
      setState(() {
        if (right) {
          _index++;
        } else {
          // A new question in its place, so guessing doesn't pay.
          _questions[_index] = MorningQuiz.one(_now, widget.facts, _rng);
        }
        _picked = null;
        _version++;
      });
      _say();
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    return _ChallengeCard(
      icon: Icons.wb_twilight_rounded,
      title: 'Wake-up questions',
      progress: '${_index + 1}/${_questions.length}',
      onSpeak: widget.speak ? _say : null,
      child: Column(
        key: ValueKey(_version),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(q.prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: Spacing.lg),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _Choice(
                label: q.options[i],
                onTap: () => _answer(i),
                state: _picked == null
                    ? null
                    : i == q.answerIndex
                        ? true
                        : i == _picked
                            ? false
                            : null,
              ),
            ),
        ],
      ),
    );
  }
}

enum _RecallStep { memorise, sum, recall }

/// "Remember & recall": memorise words, solve a sum, pick the words again.
/// Any mistake starts a fresh round with new words.
class RecallChallengeWidget extends StatefulWidget {
  const RecallChallengeWidget({
    super.key,
    required this.onPassed,
    this.random,
    this.speak = true,
    this.memoriseFor = const Duration(seconds: 8),
  });

  final VoidCallback onPassed;
  final Random? random;
  final bool speak;
  final Duration memoriseFor;

  @override
  State<RecallChallengeWidget> createState() => _RecallChallengeWidgetState();
}

class _RecallChallengeWidgetState extends State<RecallChallengeWidget> {
  late final Random _rng = widget.random ?? Random();
  late RecallRound _round;
  late QuizQuestion _sum;
  _RecallStep _step = _RecallStep.memorise;
  final Set<String> _picked = {};
  int? _sumPicked;
  bool? _result;
  Timer? _memoTimer;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    _round = RecallRound.create(_rng);
    _sum = MorningQuiz.sum(_rng);
    _step = _RecallStep.memorise;
    _picked.clear();
    _sumPicked = null;
    _result = null;
    _memoTimer?.cancel();
    _memoTimer = Timer(widget.memoriseFor, _toSum);
    if (widget.speak) sayAloud('Remember these words: ${_round.words.join(', ')}');
  }

  void _toSum() {
    _memoTimer?.cancel();
    if (!mounted || _step != _RecallStep.memorise) return;
    setState(() => _step = _RecallStep.sum);
    if (widget.speak) sayAloud(_sum.spoken ?? _sum.prompt);
  }

  void _answerSum(int i) {
    if (_sumPicked != null) return;
    final right = i == _sum.answerIndex;
    right ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() => _sumPicked = i);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        if (right) {
          _step = _RecallStep.recall;
        } else {
          _sum = MorningQuiz.sum(_rng);
          _sumPicked = null;
        }
      });
      if (widget.speak) {
        sayAloud(right ? 'Now pick the ${_round.words.length} words.' : (_sum.spoken ?? _sum.prompt));
      }
    });
  }

  void _toggle(String w) {
    if (_result != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (!_picked.remove(w) && _picked.length < _round.words.length) _picked.add(w);
    });
  }

  void _check() {
    final ok = _round.check(_picked);
    ok ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() => _result = ok);
    Future.delayed(Duration(milliseconds: ok ? 700 : 1400), () {
      if (!mounted) return;
      if (ok) {
        widget.onPassed();
      } else {
        setState(_newRound);
      }
    });
  }

  @override
  void dispose() {
    _memoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = _round.words.length;
    late final Widget body;
    switch (_step) {
      case _RecallStep.memorise:
        body = Column(
          key: ValueKey('m${_round.words.join()}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Remember these $n words',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: Spacing.lg),
            for (final w in _round.words)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Text(w,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: scheme.primary)),
              ),
            const SizedBox(height: Spacing.md),
            FilledButton(onPressed: _toSum, child: const Text("I've got them")),
          ],
        );
      case _RecallStep.sum:
        body = Column(
          key: ValueKey('s${_sum.prompt}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quick sum first',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.sm),
            Text(_sum.prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(height: Spacing.lg),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: Spacing.sm,
              crossAxisSpacing: Spacing.sm,
              childAspectRatio: 2.6,
              children: [
                for (var i = 0; i < _sum.options.length; i++)
                  _Choice(
                    label: _sum.options[i],
                    onTap: () => _answerSum(i),
                    state: _sumPicked == null
                        ? null
                        : i == _sum.answerIndex
                            ? true
                            : i == _sumPicked
                                ? false
                                : null,
                  ),
              ],
            ),
          ],
        );
      case _RecallStep.recall:
        body = Column(
          key: const ValueKey('r'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                _result == false
                    ? 'Not quite. New words coming…'
                    : 'Which $n words did you see?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: Spacing.lg),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: Spacing.sm,
              crossAxisSpacing: Spacing.sm,
              childAspectRatio: 2.6,
              children: [
                for (final w in _round.choices)
                  _Choice(
                    label: w,
                    selected: _picked.contains(w),
                    onTap: () => _toggle(w),
                    state: _result == null
                        ? null
                        : _round.words.contains(w)
                            ? true
                            : _picked.contains(w)
                                ? false
                                : null,
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            FilledButton(
              onPressed: _picked.length == n && _result == null ? _check : null,
              child: Text('Check (${_picked.length}/$n)'),
            ),
          ],
        );
    }
    return _ChallengeCard(
      icon: Icons.psychology_rounded,
      title: 'Remember & recall',
      progress: '${_step.index + 1}/3',
      onSpeak: widget.speak
          ? () => sayAloud(switch (_step) {
                _RecallStep.memorise => _round.words.join(', '),
                _RecallStep.sum => _sum.spoken ?? _sum.prompt,
                _RecallStep.recall => 'Pick the $n words you saw.',
              })
          : null,
      child: body,
    );
  }
}
