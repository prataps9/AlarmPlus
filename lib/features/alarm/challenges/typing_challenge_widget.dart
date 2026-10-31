import 'dart:math';

import 'package:flutter/material.dart';

class TypingChallengeWidget extends StatefulWidget {
  const TypingChallengeWidget({super.key, required this.onPassed, required this.onFailed});

  final VoidCallback onPassed;
  final VoidCallback onFailed;

  @override
  State<TypingChallengeWidget> createState() => _TypingChallengeWidgetState();
}

class _TypingChallengeWidgetState extends State<TypingChallengeWidget> {
  static const _phrases = [
    'I am awake and ready',
    'Good morning sunshine',
    'Time to rise and shine',
    'Today will be great',
    'I choose to be productive',
  ];

  late final String _target;
  final _controller = TextEditingController();
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _target = _phrases[Random().nextInt(_phrases.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    if (_controller.text.trim().toLowerCase() == _target.toLowerCase()) {
      widget.onPassed();
    } else {
      setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Type this phrase to dismiss',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.45)),
            ),
            child: Text(
              '"$_target"',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() => _hasError = false),
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(
              hintText: 'Type here...',
              errorText: _hasError ? 'Not quite right, try again' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _check,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
              ),
              child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
