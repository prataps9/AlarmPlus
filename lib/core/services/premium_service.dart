import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/premium/screens/paywall_screen.dart';

/// Everything Alarm+ Pro unlocks. Only list things that actually ship — the
/// paywall renders this list verbatim, so an entry here is a promise.
enum PremiumFeature {
  mascotOutfits,
  doubleStreakFreezes,
  sleepCoachPro,
  smartDismissModes,
}

enum PurchaseOutcome { success, pending, cancelled, failed, unavailable }

class PremiumBenefit {
  const PremiumBenefit(this.feature, this.icon, this.title, this.description);

  final PremiumFeature feature;
  final IconData icon;
  final String title;
  final String description;
}

class PremiumService {
  PremiumService._();

  static const lifetimePriceInr = 299;
  static const fallbackPriceLabel = '₹$lifetimePriceInr';
  static const _premiumUnlockedKey = 'premium.lifetime.unlocked';
  static const _productId = 'alarm_plus_lifetime_premium';

  /// Live Pro state for widgets (`ValueListenableBuilder`) — so a purchase
  /// unlocks every open screen immediately instead of on next launch.
  static final ValueNotifier<bool> isPro = ValueNotifier(false);

  /// True while the store reports the purchase as pending (e.g. a UPI
  /// payment awaiting confirmation).
  static final ValueNotifier<bool> purchasePending = ValueNotifier(false);

  static StreamSubscription<List<PurchaseDetails>>? _storeSub;
  static Completer<PurchaseOutcome>? _purchaseCompleter;
  static Completer<bool>? _restoreCompleter;
  static String? _cachedPrice;

  // ─── Startup ────────────────────────────────────────────────────────────────

  /// Loads the saved Pro flag and starts listening to the store for the
  /// whole app lifetime. The store re-delivers purchases that finished while
  /// the app was closed (slow UPI/cards) on this stream at launch; they must
  /// be completed or Google Play auto-refunds them after three days.
  static Future<void> init() async {
    isPro.value = await isLifetimePremiumUnlocked();
    try {
      _storeSub ??= InAppPurchase.instance.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('IAP stream error: $e'),
      );
    } catch (e) {
      // No store on this platform (desktop, web, tests).
      debugPrint('IAP unavailable: $e');
    }
  }

  // ─── Local unlock state ──────────────────────────────────────────────────────

  static Future<bool> isLifetimePremiumUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumUnlockedKey) ?? false;
  }

  static Future<void> unlockLifetimePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumUnlockedKey, true);
    isPro.value = true;
  }

  static Future<void> lockLifetimePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumUnlockedKey, false);
    isPro.value = false;
  }

  static Future<bool> canUse(PremiumFeature feature) async {
    return isLifetimePremiumUnlocked();
  }

  // ─── Store ──────────────────────────────────────────────────────────────────

  static Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != _productId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasePending.value = true;
          _finishPurchase(PurchaseOutcome.pending);
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          purchasePending.value = false;
          await unlockLifetimePremium();
          _finishPurchase(PurchaseOutcome.success);
          _finishRestore(true);
        case PurchaseStatus.error:
          purchasePending.value = false;
          debugPrint('IAP error: ${purchase.error}');
          _finishPurchase(PurchaseOutcome.failed);
        case PurchaseStatus.canceled:
          purchasePending.value = false;
          _finishPurchase(PurchaseOutcome.cancelled);
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (e) {
          debugPrint('IAP completePurchase failed: $e');
        }
      }
    }
  }

  static void _finishPurchase(PurchaseOutcome outcome) {
    final c = _purchaseCompleter;
    if (c != null && !c.isCompleted) c.complete(outcome);
  }

  static void _finishRestore(bool restored) {
    final c = _restoreCompleter;
    if (c != null && !c.isCompleted) c.complete(restored);
  }

  /// The store's localized price (e.g. "$3.99" outside India), falling back
  /// to the INR list price when the store can't be reached.
  static Future<String> displayPrice() async {
    if (_cachedPrice != null) return _cachedPrice!;
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return fallbackPriceLabel;
      final response = await iap.queryProductDetails({_productId});
      if (response.productDetails.isEmpty) return fallbackPriceLabel;
      return _cachedPrice = response.productDetails.first.price;
    } catch (e) {
      debugPrint('IAP price lookup failed: $e');
      return fallbackPriceLabel;
    }
  }

  /// Starts a Google Play / App Store purchase. The outcome arrives through
  /// the global listener set up in [init].
  static Future<PurchaseOutcome> purchaseLifetimePremium() async {
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return PurchaseOutcome.unavailable;

      final response = await iap.queryProductDetails({_productId});
      if (response.productDetails.isEmpty) {
        debugPrint('IAP product not found: ${response.notFoundIDs}');
        return PurchaseOutcome.unavailable;
      }

      _purchaseCompleter = Completer<PurchaseOutcome>();
      final started = await iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
      );
      if (!started) return PurchaseOutcome.failed;

      return await _purchaseCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => PurchaseOutcome.failed,
      );
    } catch (e) {
      debugPrint('IAP purchase failed: $e');
      return PurchaseOutcome.failed;
    } finally {
      _purchaseCompleter = null;
    }
  }

  /// Restores a previous purchase (reinstall / new phone). Returns false
  /// when the store reports nothing to restore within a few seconds —
  /// Google Play emits nothing at all in that case.
  static Future<bool> restorePurchases() async {
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return false;
      _restoreCompleter = Completer<bool>();
      await iap.restorePurchases();
      return await _restoreCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('IAP restore failed: $e');
      return false;
    } finally {
      _restoreCompleter = null;
    }
  }

  // ─── Feature metadata ────────────────────────────────────────────────────────

  static const benefits = <PremiumBenefit>[
    PremiumBenefit(
      PremiumFeature.mascotOutfits,
      Icons.checkroom_rounded,
      "Pip's Wardrobe",
      'Dress Pip up: four exclusive outfits, from Royal Riser to Night Dreamer.',
    ),
    PremiumBenefit(
      PremiumFeature.doubleStreakFreezes,
      Icons.ac_unit_rounded,
      'Double Streak Freezes',
      'Earn 2 freezes at every streak milestone, so one bad morning never resets your streak.',
    ),
    PremiumBenefit(
      PremiumFeature.sleepCoachPro,
      Icons.insights_rounded,
      'Sleep Coach Pro',
      'Full sleep trends, a recovery plan after short nights, and weekend-drift warnings.',
    ),
    PremiumBenefit(
      PremiumFeature.smartDismissModes,
      Icons.psychology_rounded,
      'Always-On Wake Challenge',
      'Force a math, memory or shake challenge on every alarm, so no more half-asleep dismissals.',
    ),
  ];

  static PremiumBenefit benefitFor(PremiumFeature feature) =>
      benefits.firstWhere((b) => b.feature == feature);

  static String featureTitle(PremiumFeature feature) =>
      benefitFor(feature).title;

  static String featureDescription(PremiumFeature feature) =>
      benefitFor(feature).description;

  static List<PremiumFeature> bundleFeatures() =>
      benefits.map((b) => b.feature).toList(growable: false);

  static List<String> bundleLabels() =>
      benefits.map((b) => b.title).toList(growable: false);

  // ─── Paywall ────────────────────────────────────────────────────────────────

  /// Opens the full-screen paywall with [feature] highlighted.
  /// Returns true if the user is Pro when the paywall closes.
  static Future<bool> showLifetimePaywall(
    BuildContext context,
    PremiumFeature feature,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(highlight: feature),
      ),
    );
    return isPro.value;
  }
}
