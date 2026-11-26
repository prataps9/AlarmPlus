import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The theme asks google_fonts for these. It looks for `Family-Weight.ttf`
/// in the app's assets first and only then downloads the font, which on a
/// phone meant fallback text at first launch and no custom font offline.
void main() {
  const files = [
    'SpaceGrotesk-SemiBold',
    'SpaceGrotesk-Bold',
    'DMSans-Regular',
    'DMSans-Medium',
    'DMSans-SemiBold',
    'DMSans-Bold',
  ];

  test('the theme fonts ship with the app', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/google_fonts/'));
    for (final name in files) {
      final file = File('assets/google_fonts/$name.ttf');
      expect(file.existsSync(), isTrue, reason: '$name.ttf is missing');
      // A real font, not an error page saved by a failed download.
      expect(file.lengthSync(), greaterThan(20 * 1024), reason: name);
    }
  });

  test('their licences are bundled with them', () {
    expect(File('assets/google_fonts/OFL-SpaceGrotesk.txt').existsSync(), isTrue);
    expect(File('assets/google_fonts/OFL-DMSans.txt').existsSync(), isTrue);
  });
}
