import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/services/app_shortcuts_service.dart';

/// Android resources that Dart code or the system looks up *by name*. The
/// release shrinker can't see those uses and deletes the resource; the
/// v1.2.0 APK shipped without its shortcut icons for exactly that reason.
void main() {
  const res = 'android/app/src/main/res';

  test('every launcher-shortcut icon exists as a drawable', () {
    expect(AppShortcutsService.iconNames, isNotEmpty);
    for (final name in AppShortcutsService.iconNames) {
      expect(File('$res/drawable/$name.xml').existsSync(), isTrue,
          reason: '$name is used by a shortcut but has no drawable');
    }
  });

  test('keep.xml protects them from the resource shrinker', () {
    final keep = File('$res/raw/keep.xml').readAsStringSync();
    expect(keep, contains('tools:keep'));
    for (final name in AppShortcutsService.iconNames) {
      // Either listed by name or covered by a wildcard like ic_shortcut_*.
      final covered = keep.contains('@drawable/$name') ||
          RegExp(r'@drawable/([a-z_]*)\*')
              .allMatches(keep)
              .any((m) => name.startsWith(m.group(1)!));
      expect(covered, isTrue, reason: '$name would be stripped from release builds');
    }
  });

  test('the Android 12 splash points at drawables and colours that exist', () {
    for (final f in ['values-v31', 'values-night-v31']) {
      final styles = File('$res/$f/styles.xml').readAsStringSync();
      final icon = RegExp(r'windowSplashScreenAnimatedIcon">@drawable/(\w+)<')
          .firstMatch(styles)!
          .group(1)!;
      expect(File('$res/drawable/$icon.xml').existsSync(), isTrue, reason: '$f: $icon');
      final color = RegExp(r'windowSplashScreenBackground">@color/(\w+)<')
          .firstMatch(styles)!
          .group(1)!;
      expect(File('$res/values/colors.xml').readAsStringSync(), contains('name="$color"'));
    }
  });
}
