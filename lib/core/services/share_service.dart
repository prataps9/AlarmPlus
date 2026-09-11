import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders an off-screen widget (typically a [ShareCardWidget]) and opens
/// the OS share sheet with it as a PNG image. Capture is done via a
/// [RepaintBoundary] inserted into the root [Overlay] well outside the
/// visible viewport, rather than a live on-screen widget, so the shared
/// image always matches a clean, fixed layout regardless of the screen
/// it's triggered from.
class ShareService {
  ShareService._();

  static Future<void> shareCard(
    BuildContext context, {
    required Widget card,
    String? text,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: 0,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(key: boundaryKey, child: card),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      // Two frames: the first lays out and paints the off-screen subtree,
      // the second lets any widget that renders differently on its very
      // first frame (e.g. MascotWidget's initial animation tick) settle.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/alarmplus_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: text ?? "I'm building my morning streak with Alarm+! 🔥",
        ),
      );
    } finally {
      entry.remove();
    }
  }
}
