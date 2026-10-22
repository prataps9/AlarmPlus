import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:alarm_plus/core/services/smart_alarm_service.dart';

class MathChallengeWidget extends StatefulWidget {
  const MathChallengeWidget({
    super.key,
    required this.difficulty,
    required this.isBossMode,
    required this.onCompleted,
    required this.onFailed,
  });

  final MathDifficulty difficulty;
  final bool isBossMode;
  final void Function(int wrongCount, int totalMs, int quickSolveXp) onCompleted;
  final VoidCallback onFailed;

  @override
  State<MathChallengeWidget> createState() => _MathChallengeWidgetState();
}

class _MathChallengeWidgetState extends State<MathChallengeWidget> {
  static const _totalQuestions = 3;

  int _currentQuestion = 0;
  int _wrongCount = 0;
  bool _isLocked = false;
  bool _showCorrect = false;
  bool _showWrong = false;

  late MathQuestion _question;
  late int _timeLeft;
  late int _timeLimitSeconds;
  Timer? _questionTimer;
  final _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
  int _questionStartMs = DateTime.now().millisecondsSinceEpoch;

  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNextQuestion();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _loadNextQuestion() {
    final eff = widget.isBossMode ? MathDifficulty.boss : widget.difficulty;
    _question = SmartAlarmService.generateMathQuestion(eff);
    _timeLimitSeconds = _question.timeLimitSeconds;
    _timeLeft = _timeLimitSeconds;
    _questionStartMs = DateTime.now().millisecondsSinceEpoch;
    _controller.clear();
    _isLocked = false;
    _showCorrect = false;
    _showWrong = false;
    _startTimer();
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _questionTimer?.cancel();
          _handleTimeout();
        }
      });
    });
  }

  Future<void> _handleTimeout() async {
    _wrongCount++;
    setState(() {
      _isLocked = true;
      _showWrong = true;
    });
    HapticFeedback.heavyImpact();
    await SmartAlarmService.recordMathResult(
      correct: false,
      solveMs: _timeLimitSeconds * 1000,
      difficulty: _question.difficulty,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    // Timeout = treated like snooze (go back, don't dismiss)
    widget.onFailed();
  }

  Future<void> _checkAnswer() async {
    if (_isLocked) return;
    final input = int.tryParse(_controller.text.trim());
    if (input == null) return;

    final solveMs = DateTime.now().millisecondsSinceEpoch - _questionStartMs;
    _questionTimer?.cancel();

    if (input == _question.answer) {
      HapticFeedback.lightImpact();
      await SmartAlarmService.recordMathResult(correct: true, solveMs: solveMs, difficulty: _question.difficulty);
      setState(() => _showCorrect = true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      if (_currentQuestion + 1 >= _totalQuestions) {
        // All done
        final totalMs = DateTime.now().millisecondsSinceEpoch - _sessionStartMs;
        final quickSolveXp = totalMs < 15000 ? 25 : 0;
        widget.onCompleted(_wrongCount, totalMs, quickSolveXp);
      } else {
        setState(() {
          _currentQuestion++;
          _loadNextQuestion();
        });
      }
    } else {
      HapticFeedback.heavyImpact();
      _wrongCount++;
      await SmartAlarmService.recordMathResult(correct: false, solveMs: solveMs, difficulty: _question.difficulty);
      setState(() {
        _showWrong = true;
        _isLocked = true;
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _showWrong = false;
        _isLocked = false;
        _controller.clear();
        // Resume timer from where it was (give 10s after wrong)
        _timeLeft = 10;
        _startTimer();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerFraction = _timeLeft / _timeLimitSeconds;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x18000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isBossMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'BOSS MODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 3,
                ),
              ),
            ).animate().shake(duration: 600.ms),
          if (widget.isBossMode) const SizedBox(height: 12),
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalQuestions, (i) {
              return Container(
                width: 28,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i <= _currentQuestion ? const Color(0xFF22C55E) : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'Question ${_currentQuestion + 1} of $_totalQuestions',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          // Timer ring
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: timerFraction,
                  strokeWidth: 5,
                  backgroundColor: scheme.outlineVariant,
                  valueColor: AlwaysStoppedAnimation(
                    timerFraction > 0.4 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  ),
                ),
                Text(
                  '$_timeLeft',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Question display
          Text(
            _question.display,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ).animate(
            effects: _showCorrect
                ? [ScaleEffect(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 300.ms)]
                : _showWrong
                ? [ShakeEffect(duration: 400.ms)]
                : [],
          ),
          const SizedBox(height: 20),
          // Answer field
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showCorrect
                    ? const Color(0xFF22C55E)
                    : _showWrong
                    ? const Color(0xFFEF4444)
                    : scheme.outline,
                width: 2,
              ),
              color: _showCorrect
                  ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                  : _showWrong
                  ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                  : scheme.surfaceContainer,
            ),
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              enabled: !_isLocked,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: '?',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _checkAnswer(),
            ),
          ),
          const SizedBox(height: 16),
          if (_showWrong)
            Text(
              'Wrong! Try again in 2s…',
              style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600),
            ).animate().fadeIn(duration: 200.ms),
          if (_showCorrect)
            const Text(
              '✓ Correct!',
              style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w700, fontSize: 16),
            ).animate().fadeIn(duration: 200.ms),
          const SizedBox(height: 8),
          if (!_isLocked && !_showCorrect)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                ),
                child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }
}
