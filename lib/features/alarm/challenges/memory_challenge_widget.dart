import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class MemoryChallengeWidget extends StatefulWidget {
  const MemoryChallengeWidget({super.key, required this.onPassed, required this.onFailed});

  final VoidCallback onPassed;
  final VoidCallback onFailed;

  @override
  State<MemoryChallengeWidget> createState() => _MemoryChallengeWidgetState();
}

class _MemoryChallengeWidgetState extends State<MemoryChallengeWidget> {
  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
  ];
  static const _labels = ['Red', 'Green', 'Blue', 'Yellow'];

  late List<int> _sequence;
  List<int> _userInput = [];
  bool _showing = true;
  int _showIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sequence = List.generate(4, (_) => Random().nextInt(4));
    _startShowSequence();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startShowSequence() {
    _showIndex = 0;
    _showing = true;
    _timer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _showIndex++);
      if (_showIndex >= _sequence.length) {
        t.cancel();
        setState(() => _showing = false);
      }
    });
  }

  void _tap(int colorIdx) {
    if (_showing) return;
    final expected = _sequence[_userInput.length];
    if (colorIdx == expected) {
      _userInput = [..._userInput, colorIdx];
      if (_userInput.length == _sequence.length) {
        widget.onPassed();
      } else {
        setState(() {});
      }
    } else {
      widget.onFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _showing ? 'Remember the sequence!' : 'Tap in the correct order',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_showing) ...[
            Text(
              'Showing: ${_showIndex < _sequence.length ? _labels[_sequence[_showIndex]] : "..."}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_sequence.length, (i) {
                final active = i == _showIndex - 1 && _showing;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: active ? 48 : 36,
                  height: active ? 48 : 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _showIndex ? _colors[_sequence[i]] : scheme.outlineVariant,
                  ),
                );
              }),
            ),
          ] else ...[
            Text(
              '${_userInput.length} / ${_sequence.length}',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: List.generate(4, (i) => GestureDetector(
                onTap: () => _tap(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: _colors[i],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _labels[i],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                ),
              )),
            ),
          ],
        ],
      ),
    );
  }
}
