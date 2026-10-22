import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/app_settings.dart';
import 'package:alarm_plus/core/services/backup_service.dart';

void main() {
  test('theme defaults to light and survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.load();
    expect(AppSettings.themeMode, ThemeMode.light);

    await AppSettings.setThemeMode(ThemeMode.dark);
    await AppSettings.load();
    expect(AppSettings.themeMode, ThemeMode.dark);
  });

  test('an unknown stored theme falls back to light', () {
    expect(AppSettings.parseThemeMode('sepia'), ThemeMode.light);
    expect(AppSettings.parseThemeMode(null), ThemeMode.light);
    expect(AppSettings.parseThemeMode('system'), ThemeMode.system);
  });

  test('vibration switch is saved, defaulting to on', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.load();
    expect(AppSettings.vibrationEnabled, isTrue);

    await AppSettings.setVibrationEnabled(false);
    expect(await AppSettings.readVibrationEnabled(), isFalse);
    await AppSettings.load();
    expect(AppSettings.vibrationEnabled, isFalse);
  });

  test('both travel in backups', () {
    expect(BackupCodec.isPortable(AppSettings.themeModeKey), isTrue);
    expect(BackupCodec.isPortable(AppSettings.vibrationKey), isTrue);
  });
}
