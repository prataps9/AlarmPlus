import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';

/// Persists which outfit Pip is wearing.
///
/// The *chosen* outfit and the outfit Pip actually *wears* are different:
/// if Pro lapses (refund, restore on a new device that hasn't finished yet)
/// a premium pick falls back to [MascotOutfit.classic] without losing the
/// user's choice.
class MascotService {
  MascotService._();

  static const _outfitKey = 'mascot.outfit';

  static final ValueNotifier<MascotOutfit> selectedOutfit =
      ValueNotifier(MascotOutfit.classic);

  /// Fires when either the pick or the Pro state changes.
  static final Listenable changes =
      Listenable.merge([selectedOutfit, PremiumService.isPro]);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    selectedOutfit.value = MascotOutfit.fromName(prefs.getString(_outfitKey));
  }

  static MascotOutfit get wornOutfit => resolveWorn(
        selectedOutfit.value,
        isPro: PremiumService.isPro.value,
      );

  @visibleForTesting
  static MascotOutfit resolveWorn(MascotOutfit picked, {required bool isPro}) =>
      picked.isPremium && !isPro ? MascotOutfit.classic : picked;

  static Future<void> selectOutfit(MascotOutfit outfit) async {
    selectedOutfit.value = outfit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_outfitKey, outfit.name);
  }
}
