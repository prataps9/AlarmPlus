import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceMemoService {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static bool _recorderOpen = false;

  static Future<void> _ensureRecorderOpen() async {
    if (!_recorderOpen) {
      await _recorder.openRecorder();
      _recorderOpen = true;
    }
  }

  static Future<String?> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('VoiceMemoService: microphone permission denied');
      return null;
    }
    await _ensureRecorderOpen();
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/memo_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
    return path;
  }

  static Future<String?> stopRecording() async {
    return _recorder.stopRecorder();
  }

  static Future<void> playMemo(String path) async {
    await _player.setFilePath(path);
    await _player.play();
  }

  /// Fires when a memo finishes playing on its own.
  static Stream<void> get playbackCompleted => _player.playerStateStream
      .where((s) => s.processingState == ProcessingState.completed)
      .map((_) {});

  /// Whether the app may use the microphone, and whether the user can still
  /// be asked (false once they chose "don't ask again").
  static Future<({bool granted, bool canAsk})> microphoneStatus() async {
    final status = await Permission.microphone.status;
    return (granted: status.isGranted, canAsk: !status.isPermanentlyDenied);
  }

  static Future<void> stopPlayback() async {
    await _player.stop();
  }

  static Future<void> deleteMemo(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete voice memo: $e');
    }
  }

  static bool get isRecording => _recorder.isRecording;
  static bool get isPlaying => _player.playing;
}
