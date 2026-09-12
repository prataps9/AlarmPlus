import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/shared/utils/fuzzy_match.dart';

/// Read a sentence out loud to dismiss. Speaking coherently is much harder to
/// do half-asleep than tapping a button.
///
/// If speech recognition is unavailable — no recogniser installed, permission
/// refused, desktop — this degrades to typing the sentence rather than
/// auto-passing, so the challenge still means something.
class VoiceChallengeWidget extends StatefulWidget {
  const VoiceChallengeWidget({
    super.key,
    required this.onPassed,
    this.onFailed,
  });

  final VoidCallback onPassed;
  final VoidCallback? onFailed;

  static const maxAttempts = 3;

  @override
  State<VoiceChallengeWidget> createState() => _VoiceChallengeWidgetState();
}

class _VoiceChallengeWidgetState extends State<VoiceChallengeWidget> {
  final _speech = SpeechToText();
  final _typedController = TextEditingController();

  String _sentence = 'The early bird catches the worm';
  String _heard = '';
  bool _listening = false;
  bool _typingFallback = false;
  int _attemptsLeft = VoiceChallengeWidget.maxAttempts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSentence();
    _initSpeech();
  }

  Future<void> _loadSentence() async {
    try {
      final raw = await rootBundle
          .loadString('assets/data/read_aloud_sentences.json');
      final list = (jsonDecode(raw) as List).cast<String>();
      if (list.isNotEmpty && mounted) {
        setState(() => _sentence = list[Random().nextInt(list.length)]);
      }
    } catch (_) {
      // Keep the built-in default sentence.
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (mounted && status == 'done') setState(() => _listening = false);
        },
      );
      if (!available && mounted) {
        setState(() => _typingFallback = true);
      }
    } catch (_) {
      if (mounted) setState(() => _typingFallback = true);
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _heard = '';
      _error = null;
      _listening = true;
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _heard = result.recognizedWords);
        if (result.finalResult) _evaluate(_heard);
      },
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  void _evaluate(String spoken) {
    setState(() => _listening = false);

    if (FuzzyMatch.isCloseEnough(_sentence, spoken)) {
      widget.onPassed();
      return;
    }

    setState(() {
      _attemptsLeft--;
      _error = spoken.trim().isEmpty
          ? "Didn't catch that — try again"
          : 'Not quite. Read the whole sentence.';
    });

    if (_attemptsLeft <= 0) {
      // Out of spoken attempts: fall back to typing rather than failing the
      // dismissal outright and leaving the alarm ringing indefinitely.
      setState(() {
        _typingFallback = true;
        _error = 'Type the sentence instead';
      });
    }
  }

  void _submitTyped() {
    if (FuzzyMatch.isCloseEnough(_sentence, _typedController.text)) {
      widget.onPassed();
    } else {
      setState(() => _error = "That doesn't match the sentence");
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _typedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _typingFallback ? '⌨️' : '🗣️',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            _typingFallback ? 'Type this out' : 'Read this out loud',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: Spacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Text(
              _sentence,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          if (_typingFallback) ..._buildTypingControls(theme) else
            ..._buildSpeechControls(theme),
          if (_error != null) ...[
            const SizedBox(height: Spacing.md),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSpeechControls(ThemeData theme) {
    return [
      if (_heard.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md),
          child: Text(
            '"$_heard"',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      FilledButton.icon(
        onPressed: _listening ? null : _startListening,
        icon: Icon(_listening ? Icons.mic : Icons.mic_none_rounded),
        label: Text(_listening ? 'Listening…' : 'Start speaking'),
      ),
      const SizedBox(height: Spacing.sm),
      Text(
        '$_attemptsLeft ${_attemptsLeft == 1 ? 'try' : 'tries'} left',
        style: theme.textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _buildTypingControls(ThemeData theme) {
    return [
      TextField(
        controller: _typedController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Type the sentence'),
        onSubmitted: (_) => _submitTyped(),
      ),
      const SizedBox(height: Spacing.md),
      FilledButton(
        onPressed: _submitTyped,
        child: const Text('Confirm'),
      ),
    ];
  }
}
