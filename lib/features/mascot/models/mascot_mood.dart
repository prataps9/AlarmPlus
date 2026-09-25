import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';

/// Pip's expressions. Each one has its own face and its own one-shot
/// "entrance" move when Pip switches into it (see `PipMascot`).
enum MascotMood {
  /// Default resting face with a gentle breathing bob.
  idle,

  /// Smiling; a small hop on entry.
  happy,

  /// Big open-mouthed cheer, arms up, bells ringing, a jump on entry.
  cheering,

  /// One arm waving hello, used for greetings and onboarding.
  waving,

  /// Droopy eyes and floating "z"s — bedtime and late-night states.
  sleepy,

  /// Worried brows and a nervous shiver — streak at risk, errors.
  worried,

  /// Confident smirk with sparkles — milestones and Pro.
  proud,
}

/// What Pip wears on top of their body color.
enum MascotAccessory { none, crown, shades, nightcap, headphones }

/// Pip's wardrobe. [classic] is free; the rest are Alarm+ Pro rewards, the
/// same way Duolingo sells outfits for its owl.
enum MascotOutfit {
  classic(
    label: 'Classic',
    body: Palette.green500,
    accessory: MascotAccessory.none,
    isPremium: false,
  ),
  sunrise(
    label: 'Sunrise Shades',
    body: Palette.orange500,
    accessory: MascotAccessory.shades,
    isPremium: true,
  ),
  royal(
    label: 'Royal Riser',
    body: Palette.indigo500,
    accessory: MascotAccessory.crown,
    isPremium: true,
  ),
  dreamer(
    label: 'Night Dreamer',
    body: Color(0xFF3B82F6),
    accessory: MascotAccessory.nightcap,
    isPremium: true,
  ),
  groove(
    label: 'Morning Groove',
    body: Palette.pink500,
    accessory: MascotAccessory.headphones,
    isPremium: true,
  );

  const MascotOutfit({
    required this.label,
    required this.body,
    required this.accessory,
    required this.isPremium,
  });

  final String label;
  final Color body;
  final MascotAccessory accessory;
  final bool isPremium;

  static MascotOutfit fromName(String? name) {
    for (final o in values) {
      if (o.name == name) return o;
    }
    return classic;
  }
}
