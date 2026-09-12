import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/challenges/photo_hash.dart';

/// Point the phone at a place you registered earlier (the sink, the kettle)
/// to dismiss — it makes you physically leave the bed.
///
/// Matching is perceptual, not exact, and deliberately forgiving: a false
/// negative here means someone is stuck in their bedroom with an alarm going
/// off. If it can't match within [giveUpSeconds] it gives up and calls
/// [onUnmatched] so the caller can fall back to another challenge.
class PhotoProofChallengeWidget extends StatefulWidget {
  const PhotoProofChallengeWidget({
    super.key,
    required this.onPassed,
    required this.referenceHashes,
    this.onUnmatched,
    this.maxDistance = 16,
    this.requiredConsecutiveFrames = 3,
    this.giveUpSeconds = 60,
  });

  final VoidCallback onPassed;

  /// Called when we've looked for a while and can't find the scene, so the
  /// caller can offer something else rather than trapping the user.
  final VoidCallback? onUnmatched;

  final List<int> referenceHashes;

  /// Hamming distance (out of 64) still considered the same scene.
  final int maxDistance;

  /// Frames that must match in a row, to avoid passing on a lucky blur.
  final int requiredConsecutiveFrames;

  final int giveUpSeconds;

  @override
  State<PhotoProofChallengeWidget> createState() =>
      _PhotoProofChallengeWidgetState();
}

class _PhotoProofChallengeWidgetState extends State<PhotoProofChallengeWidget> {
  CameraController? _controller;
  bool _streaming = false;
  bool _done = false;
  int _consecutiveMatches = 0;
  int _bestDistance = 64;
  int _secondsLeft = 0;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.giveUpSeconds;
    _start();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _giveUp('No camera available');
        return;
      }

      // Rear camera: you're pointing it at the room, not yourself.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() => _controller = controller);
      await controller.startImageStream(_onFrame);
      _streaming = true;

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) {
          t.cancel();
          _giveUp('Can\'t find that spot');
        }
      });
    } catch (e) {
      _giveUp('Camera unavailable');
    }
  }

  void _onFrame(CameraImage image) {
    if (_done || image.planes.isEmpty) return;

    // Plane 0 of YUV420 is luminance, which is all a dHash needs.
    final plane = image.planes.first;
    final hash = PhotoHash.fromLuminance(
      plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
    );

    final distance = PhotoHash.bestDistance(hash, widget.referenceHashes);
    if (distance <= widget.maxDistance) {
      _consecutiveMatches++;
    } else {
      _consecutiveMatches = 0;
    }

    if (mounted && distance < _bestDistance) {
      setState(() => _bestDistance = distance);
    }

    if (_consecutiveMatches >= widget.requiredConsecutiveFrames) {
      _pass();
    }
  }

  void _pass() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    _stopStream();
    widget.onPassed();
  }

  void _giveUp(String reason) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    _stopStream();
    if (mounted) setState(() => _error = reason);

    // Brief pause so the message is readable before handing over.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) widget.onUnmatched?.call();
    });
  }

  Future<void> _stopStream() async {
    if (_streaming) {
      _streaming = false;
      try {
        await _controller?.stopImageStream();
      } catch (_) {
        // Controller may already be tearing down.
      }
    }
  }

  @override
  void dispose() {
    _stopStream();
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;

    // How close we are, as a 0..1 bar — gives feedback while hunting.
    final closeness =
        (1 - (_bestDistance / 64)).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Find your spot', style: theme.textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: controller != null && controller.value.isInitialized
                  ? CameraPreview(controller)
                  : ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          if (_error != null)
            Text(
              '$_error — switching challenge',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: LinearProgressIndicator(
                value: closeness,
                minHeight: 10,
                backgroundColor: theme.colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              _consecutiveMatches > 0 ? 'Hold it there…' : 'Getting warmer…',
              style: theme.textTheme.bodyMedium,
            ),
            Text('${_secondsLeft}s', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
