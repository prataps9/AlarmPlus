import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Lets an alarm use a track from the user's own files, on both platforms.
///
/// Until now a custom tone was Android-only, through the system ringtone
/// picker ([RingtoneService]); iOS had nothing but the bundled sounds.
///
/// The picked file is copied into the app's documents directory rather than
/// referenced where it sits: the original may be behind a temporary content
/// URI, or on storage that has been unmounted by the time the alarm fires at
/// 6am. A silent alarm is the worst failure this app has, so it owns a copy.
/// The `alarm` package hands absolute paths straight to the platform player,
/// so that copy is what plays.
class CustomSoundService {
  CustomSoundService._();

  static const _folder = 'alarm_sounds';

  /// Whether [sound] refers to a file imported through this service.
  static bool isCustom(String sound) => sound.contains('/$_folder/');

  /// A display name for an imported sound, without the uniquifying prefix.
  static String titleFor(String path) {
    final name = path.split('/').last;
    final separator = name.indexOf('_');
    // Names are stored as "<millis>_<original name>".
    if (separator > 0 && int.tryParse(name.substring(0, separator)) != null) {
      return name.substring(separator + 1);
    }
    return name;
  }

  /// Opens the system file picker and imports the chosen audio file.
  ///
  /// Returns the stored path and a display title, or null when the user
  /// cancelled or the import failed.
  static Future<({String path, String title})?> pickAndImport() async {
    if (kIsWeb) return null;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        dialogTitle: 'Choose an alarm sound',
      );
      if (result == null || result.files.isEmpty) return null;

      final picked = result.files.first;
      final sourcePath = picked.path;
      if (sourcePath == null) return null;

      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory('${documents.path}/$_folder');
      await directory.create(recursive: true);

      final safeName = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final target = File('${directory.path}/${stamp}_$safeName');
      await File(sourcePath).copy(target.path);

      return (path: target.path, title: picked.name);
    } catch (e) {
      debugPrint('CustomSoundService.pickAndImport failed: $e');
      return null;
    }
  }
}
