import 'package:flutter/material.dart';

/// Raw design values. Nothing in here knows about light/dark — these are the
/// pigments, and [AppTheme] decides how they're used in each brightness.
///
/// Screens should almost never reference this file directly: read roles from
/// `Theme.of(context).colorScheme` or `AppSemantics` instead, so dark mode
/// keeps working. The exceptions are [Spacing], [Radii] and [Motion], which
/// are brightness-independent and safe to use anywhere.
class Palette {
  const Palette._();

  // Slate ramp — the app's neutral scale.
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  // Brand + semantic hues.
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const orange500 = Color(0xFFF97316);
  static const red500 = Color(0xFFEF4444);
  static const indigo500 = Color(0xFF6366F1);
  static const pink500 = Color(0xFFEC4899);
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
