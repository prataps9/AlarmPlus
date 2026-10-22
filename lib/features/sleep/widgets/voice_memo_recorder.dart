import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:alarm_plus/features/sleep/services/voice_memo_service.dart';

class VoiceMemoRecorder extends StatefulWidget {
  const VoiceMemoRecorder({
    super.key,
    required this.onMemoSaved,
    this.initialPath,
  });

  final ValueChanged<String?> onMemoSaved;
  final String? initialPath;

  @override
  State<VoiceMemoRecorder> createState() => _VoiceMemoRecorderState();
}

class _VoiceMemoRecorderState extends State<VoiceMemoRecorder>
    with SingleTickerProviderStateMixin {
  bool _recording = false;
  bool _playing = false;
  String? _savedPath;
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _waveController;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _savedPath = widget.initialPath;
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveController.dispose();
    if (_recording) VoiceMemoService.stopRecording();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final started = await VoiceMemoService.startRecording();
    if (started == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
    setState(() {
      _recording = true;
      _seconds = 0;
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await VoiceMemoService.stopRecording();
    setState(() {
      _recording = false;
      _savedPath = path;
    });
    widget.onMemoSaved(path);
  }

  Future<void> _playPause() async {
    if (_playing) {
      await VoiceMemoService.stopPlayback();
      setState(() => _playing = false);
    } else {
      if (_savedPath == null) return;
      await VoiceMemoService.playMemo(_savedPath!);
      setState(() => _playing = true);
    }
  }

  Future<void> _delete() async {
    if (_savedPath != null) {
      await VoiceMemoService.deleteMemo(_savedPath!);
    }
    setState(() {
      _savedPath = null;
      _seconds = 0;
    });
    widget.onMemoSaved(null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice Memo',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Record a message to play after your alarm challenge',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_recording) _buildWaveform(),
          if (_savedPath != null && !_recording) _buildPlaybackRow(),
          if (!_recording && _savedPath == null) _buildRecordButton(),
          if (_recording)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Stop  ${_seconds}s',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _startRecording,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(40),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_rounded, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text('Hold to Record', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(20, (i) {
              final h = 8.0 + (_rng.nextDouble() * 28) * _waveController.value;
              return Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildPlaybackRow() {
    return Row(
      children: [
        IconButton(
          icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          onPressed: _playPause,
          color: const Color(0xFF22C55E),
        ),
        Text('Voice memo saved', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
          onPressed: _delete,
        ),
      ],
    );
  }
}
