import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class EyeOpenChallengeWidget extends StatefulWidget {
  const EyeOpenChallengeWidget({
    super.key,
    required this.onPassed,
    required this.onFailed,
  });

  final VoidCallback onPassed;
  final VoidCallback onFailed;

  @override
  State<EyeOpenChallengeWidget> createState() => _EyeOpenChallengeWidgetState();
}

class _EyeOpenChallengeWidgetState extends State<EyeOpenChallengeWidget> {
  static const _requiredFrames = 3;
  static const _eyeOpenThreshold = 0.75;
  // Fallback: if no face detected for 30s, auto-pass
  static const _fallbackSeconds = 30;

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isProcessing = false;
  int _openFrameCount = 0;
  bool _passed = false;
  bool _cameraError = false;
  int _fallbackCountdown = _fallbackSeconds;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          minFaceSize: 0.15,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      _cameraController = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
      _cameraController!.startImageStream(_processFrame);
      _startFallbackTimer();
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
      _startFallbackTimer();
    }
  }

  void _startFallbackTimer() {
    _fallbackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _fallbackCountdown--);
      if (_fallbackCountdown <= 0) {
        _fallbackTimer?.cancel();
        if (!_passed) widget.onPassed();
      }
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || _passed) return;
    _isProcessing = true;
    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector!.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        _isProcessing = false;
        return;
      }

      final face = faces.first;
      final leftOpen = face.leftEyeOpenProbability ?? 0.0;
      final rightOpen = face.rightEyeOpenProbability ?? 0.0;
      final bothOpen =
          leftOpen >= _eyeOpenThreshold && rightOpen >= _eyeOpenThreshold;

      if (bothOpen) {
        _openFrameCount++;
        if (mounted) setState(() {});
        if (_openFrameCount >= _requiredFrames && !_passed) {
          _passed = true;
          _fallbackTimer?.cancel();
          widget.onPassed();
        }
      } else {
        if (_openFrameCount > 0 && mounted) {
          setState(() => _openFrameCount = 0);
        }
      }
    } catch (_) {
      // silently ignore per-frame errors
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) return null;
    final camera = controller.description;
    final rotation = InputImageRotationValue.fromRawValue(
          camera.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _cameraController?.stopImageStream().then((_) => _cameraController?.dispose());
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            top: 20, left: 20, right: 20,
            child: Row(children: [
              const Icon(Icons.remove_red_eye_rounded,
                  color: Color(0xFF818CF8), size: 22),
              const SizedBox(width: 8),
              const Text('Eyes Open',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const Spacer(),
              _FallbackChip(seconds: _fallbackCountdown),
            ]),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EyeProgressIndicator(
                    framesOpen: _openFrameCount,
                    required: _requiredFrames,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _cameraError
                        ? 'Camera unavailable — auto-dismissing in ${_fallbackCountdown}s'
                        : _openFrameCount == 0
                            ? 'Look at the camera with eyes wide open!'
                            : 'Keep your eyes open... $_openFrameCount/$_requiredFrames',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EyeProgressIndicator extends StatelessWidget {
  const _EyeProgressIndicator({
    required this.framesOpen,
    required this.required,
  });

  final int framesOpen;
  final int required;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(required, (i) {
        final done = i < framesOpen;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? const Color(0xFF818CF8)
                  : Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: done
                    ? const Color(0xFF818CF8)
                    : Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                done ? Icons.remove_red_eye_rounded : Icons.visibility_off_rounded,
                color: done ? Colors.white : Colors.white.withValues(alpha: 0.4),
                size: 22,
              ),
            ),
          ).animate(target: done ? 1 : 0).scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 200.ms,
              curve: Curves.elasticOut),
        );
      }),
    );
  }
}

class _FallbackChip extends StatelessWidget {
  const _FallbackChip({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.timer_rounded, size: 13, color: Colors.white70),
        const SizedBox(width: 4),
        Text('${seconds}s',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
