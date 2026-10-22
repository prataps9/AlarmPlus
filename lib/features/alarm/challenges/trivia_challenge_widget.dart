import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:alarm_plus/features/missions/services/trivia_service.dart';

enum TriviaMode { trivia, wordScramble }

class TriviaChallengeWidget extends StatefulWidget {
  const TriviaChallengeWidget({
    super.key,
    required this.onPassed,
    required this.onFailed,
    this.mode = TriviaMode.trivia,
  });

  final VoidCallback onPassed;
  final VoidCallback onFailed;
  final TriviaMode mode;

  @override
  State<TriviaChallengeWidget> createState() => _TriviaChallengeWidgetState();
}

class _TriviaChallengeWidgetState extends State<TriviaChallengeWidget> {
  static const _totalQuestions = 3;
  static const _timeLimitSeconds = 30;

  List<TriviaQuestion>? _triviaQuestions;
  List<String>? _wordList;
  int _currentIndex = 0;
  int _correctCount = 0;
  int _timeLeft = _timeLimitSeconds;
  Timer? _timer;
  bool _loading = true;
  bool _answered = false;
  int? _selectedOption;

  // Word scramble state
  String _currentWord = '';
  String _scrambled = '';
  final _wordController = TextEditingController();
  bool _wordWrong = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (widget.mode == TriviaMode.trivia) {
      final questions = await TriviaService.getQuestions(count: _totalQuestions);
      if (!mounted) return;
      setState(() {
        _triviaQuestions = questions;
        _loading = false;
      });
    } else {
      final words = await TriviaService.getWordList();
      if (!mounted) return;
      final picked = (words..shuffle()).take(_totalQuestions).toList();
      setState(() {
        _wordList = picked;
        _currentWord = picked[0];
        _scrambled = TriviaService.scrambleWord(_currentWord);
        _loading = false;
      });
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        _timer?.cancel();
        _advanceOrFinish(correct: false);
      }
    });
  }

  void _selectOption(int index) {
    if (_answered) return;
    final question = _triviaQuestions![_currentIndex];
    final correct = index == question.answerIndex;
    setState(() {
      _answered = true;
      _selectedOption = index;
      if (correct) _correctCount++;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _advanceOrFinish(correct: correct);
    });
  }

  void _submitWord() {
    if (_answered) return;
    final input = _wordController.text.trim().toLowerCase();
    if (input == _currentWord.toLowerCase()) {
      setState(() {
        _answered = true;
        _correctCount++;
        _wordWrong = false;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _advanceOrFinish(correct: true);
      });
    } else {
      setState(() => _wordWrong = true);
    }
  }

  void _advanceOrFinish({required bool correct}) {
    if (_currentIndex + 1 >= _totalQuestions) {
      _timer?.cancel();
      // Need at least 2 of 3 correct to pass
      if (_correctCount >= 2) {
        widget.onPassed();
      } else {
        widget.onFailed();
      }
      return;
    }
    setState(() {
      _currentIndex++;
      _answered = false;
      _selectedOption = null;
      _timeLeft = _timeLimitSeconds;
      _wordWrong = false;
      _wordController.clear();
      if (widget.mode == TriviaMode.wordScramble && _wordList != null) {
        _currentWord = _wordList![_currentIndex];
        _scrambled = TriviaService.scrambleWord(_currentWord);
      }
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                widget.mode == TriviaMode.trivia
                    ? _buildTriviaQuestion()
                    : _buildWordScramble(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final modeLabel = widget.mode == TriviaMode.trivia ? 'Trivia' : 'Word Scramble';
    final color = widget.mode == TriviaMode.trivia
        ? const Color(0xFF6366F1)
        : const Color(0xFF10B981);
    return Row(
      children: [
        Icon(
          widget.mode == TriviaMode.trivia ? Icons.quiz_rounded : Icons.text_fields_rounded,
          color: color,
          size: 22,
        ),
        const SizedBox(width: 8),
        Text(modeLabel,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        const Spacer(),
        _TimerChip(seconds: _timeLeft),
        const SizedBox(width: 10),
        Text('${_currentIndex + 1}/$_totalQuestions',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTriviaQuestion() {
    if (_triviaQuestions == null || _triviaQuestions!.isEmpty) {
      return const Text('No questions available');
    }
    final question = _triviaQuestions![_currentIndex];
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          question.question,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 16),
        ...List.generate(question.options.length, (i) {
          Color bg = scheme.surfaceContainerHighest;
          Color border = scheme.outlineVariant;
          Color text = scheme.onSurface;
          if (_answered) {
            if (i == question.answerIndex) {
              bg = const Color(0xFF22C55E).withValues(alpha: 0.15);
              border = const Color(0xFF22C55E);
              text = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
            } else if (i == _selectedOption && i != question.answerIndex) {
              bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
              border = const Color(0xFFEF4444);
              text = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
            }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _selectOption(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 1.5),
                ),
                child: Text(question.options[i],
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, color: text)),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWordScramble() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Unscramble this word:',
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _scrambled.toUpperCase(),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              color: Color(0xFF10B981),
            ),
          ).animate(key: ValueKey(_scrambled)).fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _wordController,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            hintText: 'Type the word...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _wordWrong ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                width: 2,
              ),
            ),
            errorText: _wordWrong ? 'Not quite — try again' : null,
          ),
          onSubmitted: (_) => _submitWord(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _answered ? null : _submitWord,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final color = seconds <= 10
        ? const Color(0xFFEF4444)
        : seconds <= 20
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_rounded, size: 14, color: color),
        const SizedBox(width: 4),
        Text('${seconds}s',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
