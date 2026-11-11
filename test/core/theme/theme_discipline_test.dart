import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/theme/app_theme.dart';
import 'package:alarm_plus/core/theme/app_theme_ext.dart';

/// Keeps the app on ONE simple look. Screens read colours from the theme
/// (`scheme.primary`, `context.semantics.danger`, ...); they must not
/// hard-code their own. If this fails, use a theme role instead of a literal.
///
/// Files allowed to hold their own colours, because the colour is the content
/// or a fixed requirement:
const _allowed = <String>[
  'lib/core/theme/', // where the palette is defined
  'lib/features/mascot/', // Pip's outfits and drawing
  'lib/features/alarm/challenges/color_clash_challenge_widget.dart', // a game about colours
  'lib/features/alarm/challenges/memory_challenge_widget.dart', // four distinct pads
  'lib/features/alarm/challenges/eye_open_challenge_widget.dart', // camera preview
  'lib/features/alarm/challenges/barcode_challenge_widget.dart', // camera preview
  'lib/features/alarm/screens/qr_spot_setup_screen.dart', // camera preview
  'lib/features/home/screens/splash_screen.dart', // continues the native white splash
];

double _luminance(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('screens do not hard-code colours', () {
    // Pure-black alpha shadows (0x..000000) are neutral and allowed, as are
    // Colors.transparent and Colors.black.
    final literal = RegExp(r'Color\(0x(?![0-9A-Fa-f]{2}000000\))[0-9A-Fa-f]{8}\)');
    final named = RegExp(r'Colors\.(?!transparent\b|black\b)[a-zA-Z]+');
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll('\\', '/');
      if (_allowed.any(path.startsWith) || _allowed.any((a) => path == a)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (literal.hasMatch(code) || named.hasMatch(code)) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use theme colours (scheme.primary, context.semantics.danger, '
            '...), not literals:\n${offenders.join('\n')}');
  });

  for (final brightness in Brightness.values) {
    group('contrast (${brightness.name})', () {
      final theme = AppTheme.build(brightness, useGoogleFonts: false);
      final s = theme.colorScheme;
      final sem = theme.extension<AppSemantics>()!;

      void atLeast(String what, Color fg, Color bg, double min) {
        expect(_contrast(fg, bg), greaterThanOrEqualTo(min),
            reason: '$what: ${_contrast(fg, bg).toStringAsFixed(2)}:1 (needs $min)');
      }

      test('body and muted text are readable on the page and on cards', () {
        atLeast('text on page', s.onSurface, s.surface, 7);
        atLeast('text on card', s.onSurface, s.surfaceContainer, 7);
        atLeast('muted on page', s.onSurfaceVariant, s.surface, 4.5);
        atLeast('muted on card', s.onSurfaceVariant, s.surfaceContainer, 4.5);
      });

      test('the accent works as a button fill and as text', () {
        atLeast('button text', s.onPrimary, s.primary, 4.5);
        atLeast('accent text on page', s.primary, s.surface, 4.5);
        atLeast('accent text on card', s.primary, s.surfaceContainer, 4.5);
        atLeast('text on accent tint', s.onPrimaryContainer, s.primaryContainer, 4.5);
      });

      test('status colours are readable as text', () {
        atLeast('danger on page', sem.danger, s.surface, 4.5);
        atLeast('success on page', sem.success, s.surface, 4.5);
        atLeast('success on card', sem.success, s.surfaceContainer, 4.5);
      });
    });
  }
}
