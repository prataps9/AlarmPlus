import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/storage_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

/// What a backup file holds.
class BackupData {
  const BackupData({required this.alarms, required this.settings, this.createdAt});

  final List<AlarmModel> alarms;

  /// SharedPreferences values: bool, int, double, String or `List<String>`.
  final Map<String, Object> settings;
  final DateTime? createdAt;
}

/// Versioned JSON format for backups. Pure, so it can be unit-tested.
class BackupCodec {
  const BackupCodec._();

  static const app = 'alarm_plus';
  static const version = 1;

  /// Settings that must never travel in a backup:
  /// - the Pro unlock (a shared file must not grant Pro — purchases restore
  ///   from the store instead),
  /// - device-specific ringtone URIs (re-created when alarms are scheduled),
  /// - in-flight stopwatch/timer state.
  static bool isPortable(String key) =>
      !key.startsWith('premium.') &&
      !key.startsWith('alarm.native_ringtone') &&
      key != 'clock.stopwatch' &&
      key != 'clock.timer';

  static String encode(BackupData data, {DateTime? now}) {
    final settings = <String, Object>{};
    data.settings.forEach((k, v) {
      if (isPortable(k)) settings[k] = v is List ? List<String>.from(v) : v;
    });
    return const JsonEncoder.withIndent('  ').convert({
      'app': app,
      'version': version,
      'createdAt': (now ?? DateTime.now()).toIso8601String(),
      'alarms': [for (final a in data.alarms) a.toMap()],
      'settings': settings,
    });
  }

  /// Throws [FormatException] for anything that isn't an Alarm+ backup this
  /// version can read. Unreadable individual alarms are skipped.
  static BackupData decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('This file is not a valid backup.');
    }
    if (json is! Map || json['app'] != app) {
      throw const FormatException('This file is not an Alarm+ backup.');
    }
    final v = json['version'];
    if (v is! int || v > version) {
      throw const FormatException(
          'This backup was made by a newer version of Alarm+. Update the app first.');
    }
    final alarms = <AlarmModel>[];
    for (final m in (json['alarms'] as List? ?? const [])) {
      if (m is! Map) continue;
      try {
        alarms.add(AlarmModel.fromMap(m));
      } catch (e) {
        debugPrint('Skipping unreadable alarm in backup: $e');
      }
    }
    final settings = <String, Object>{};
    (json['settings'] as Map? ?? const {}).forEach((k, value) {
      if (k is! String || !isPortable(k)) return;
      if (value is bool || value is int || value is double || value is String) {
        settings[k] = value as Object;
      } else if (value is List && value.every((e) => e is String)) {
        settings[k] = List<String>.from(value);
      }
    });
    return BackupData(
      alarms: alarms,
      settings: settings,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

/// Exports to a JSON file handed to the Android share sheet (save to Drive,
/// send to yourself…) and restores from a picked file.
class BackupService {
  BackupService._();

  static Future<BackupData> _collect() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, Object>{};
    for (final k in prefs.getKeys()) {
      final v = prefs.get(k);
      if (v != null) settings[k] = v;
    }
    return BackupData(alarms: StorageService.getAllAlarms(), settings: settings);
  }

  static Future<void> export() async {
    final json = BackupCodec.encode(await _collect());
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final name =
        'alarmplus-backup-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(json);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'Alarm+ backup',
    ));
  }

  /// Lets the user pick a backup file. Returns null if they cancel.
  static Future<BackupData?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return null;
    return BackupCodec.decode(utf8.decode(bytes));
  }

  /// Replaces all alarms and portable settings with [data] and reschedules.
  static Future<void> restore(BackupData data) async {
    for (final a in AlarmService.getAllAlarms()) {
      await AlarmService.deleteAlarm(a.id);
    }
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.settings.entries) {
      final v = entry.value;
      if (v is bool) {
        await prefs.setBool(entry.key, v);
      } else if (v is int) {
        await prefs.setInt(entry.key, v);
      } else if (v is double) {
        await prefs.setDouble(entry.key, v);
      } else if (v is String) {
        await prefs.setString(entry.key, v);
      } else if (v is List<String>) {
        await prefs.setStringList(entry.key, v);
      }
    }
    for (final a in data.alarms) {
      await AlarmService.saveAlarm(a);
      if (a.isEnabled) await AlarmService.scheduleAlarm(a, persist: false);
    }
  }
}
