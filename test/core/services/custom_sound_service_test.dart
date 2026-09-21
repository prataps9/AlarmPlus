import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/services/custom_sound_service.dart';

void main() {
  group('isCustom', () {
    test('recognises an imported file by its folder', () {
      expect(
        CustomSoundService.isCustom('/data/user/0/app/files/alarm_sounds/1_x.mp3'),
        isTrue,
      );
    });

    test('does not claim bundled assets, defaults or native URIs', () {
      expect(CustomSoundService.isCustom('assets/sounds/rain.mp3'), isFalse);
      expect(CustomSoundService.isCustom('default'), isFalse);
      expect(CustomSoundService.isCustom('rotate'), isFalse);
      expect(
        CustomSoundService.isCustom('content://media/internal/audio/media/7'),
        isFalse,
      );
    });
  });

  group('titleFor', () {
    test('strips the uniquifying timestamp prefix', () {
      expect(
        CustomSoundService.titleFor('/files/alarm_sounds/1773459200000_Song.mp3'),
        'Song.mp3',
      );
    });

    test('leaves a name with no timestamp prefix alone', () {
      expect(
        CustomSoundService.titleFor('/files/alarm_sounds/Song.mp3'),
        'Song.mp3',
      );
    });

    test('keeps underscores that are part of the original name', () {
      expect(
        CustomSoundService.titleFor('/files/alarm_sounds/1773459200000_my_song.mp3'),
        'my_song.mp3',
      );
    });

    test('handles a name that is only a number', () {
      // No separator, so nothing to strip.
      expect(CustomSoundService.titleFor('/files/alarm_sounds/12345.mp3'),
          '12345.mp3');
    });
  });
}
