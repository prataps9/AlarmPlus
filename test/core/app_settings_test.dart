import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/app_settings.dart';
import 'package:alarm_plus/core/services/backup_service.dart';

void main() {
  test('vibration switch is saved, defaulting to on', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.load();
    expect(AppSettings.vibrationEnabled, isTrue);

    await AppSettings.setVibrationEnabled(false);
    expect(await AppSettings.readVibrationEnabled(), isFalse);
    await AppSettings.load();
    expect(AppSettings.vibrationEnabled, isFalse);
  });

  test('the vibration switch travels in backups; the retired theme key does not', () {
    expect(BackupCodec.isPortable(AppSettings.vibrationKey), isTrue);
    expect(BackupCodec.isPortable('appearance.theme_mode'), isFalse);
  });
}
