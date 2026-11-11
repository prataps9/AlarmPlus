import 'package:flutter/material.dart';

/// The app's whole palette: warm stone neutrals, ONE accent (orange), and two
/// status colours (red for danger, green for "OK"). Nothing else is allowed in
/// UI code; `test/core/theme/theme_discipline_test.dart` fails the build if a
/// screen reaches for another colour.
///
/// Nothing in here knows about light/dark: [AppTheme] decides how each is used
/// per brightness. Screens should read roles from
/// `Theme.of(context).colorScheme` (or `context.semantics`) rather than this
/// file, so the light and dark looks stay in step. The exceptions are
/// [Spacing], [Radii] and [Motion], which are safe to use anywhere.
class Palette {
  const Palette._();

  // Warm neutrals, light to dark.
  static const stone50 = Color(0xFFFAFAF9);
  static const stone100 = Color(0xFFF5F5F4);
  static const stone200 = Color(0xFFE7E5E4);
  static const stone300 = Color(0xFFD6D3D1);
  static const stone400 = Color(0xFFA8A29E);
  static const stone500 = Color(0xFF78716C);
  static const stone600 = Color(0xFF57534E);
  static const stone900 = Color(0xFF1C1917);

  // Dark theme surfaces (warm near-black, in three steps).
  static const night = Color(0xFF141211);
  static const nightRaised = Color(0xFF1F1B19);
  static const nightHigh = Color(0xFF2A2522);
  static const nightLine = Color(0xFF3A3430);

  // The single accent. [orange700] is the light-theme accent: the lightest
  // orange that still reads at 4.5:1 with white text. [orange400] is the dark
  // theme accent, with near-black text on it.
  static const orange100 = Color(0xFFFFEDD5);
  static const orange200 = Color(0xFFFED7AA);
  static const orange400 = Color(0xFFFB923C);
  static const orange700 = Color(0xFFC2410C);
  static const orange900 = Color(0xFF7C2D12);
  static const orangeDeep = Color(0xFF3B1A0A);

  // Status colours: the only other hues in the app.
  static const red600 = Color(0xFFDC2626);
  static const red400 = Color(0xFFF87171);
  static const green600 = Color(0xFF16A34A);
  static const green400 = Color(0xFF4ADE80);
}

/// 4pt spacing scale. Use these instead of literal EdgeInsets numbers so
/// rhythm stays consistent between screens.
class Spacing {
  const Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class Radii {
  const Radii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheetRadius =
      BorderRadius.vertical(top: Radius.circular(xl));
}

class Motion {
  const Motion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 450);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}

/// Letter spacing for the small tracked "eyebrow" labels used above sections.
class Tracking {
  const Tracking._();

  static const double eyebrow = 3;
  static const double label = 1.1;
}
