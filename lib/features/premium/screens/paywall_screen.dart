import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_mascot.dart';

/// Full-screen Alarm+ Pro offer. Opened via
/// [PremiumService.showLifetimePaywall] from any locked feature, with that
/// feature pinned to the top of the benefit list.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.highlight});

  final PremiumFeature? highlight;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final Future<String> _price = PremiumService.displayPrice();
  bool _busy = false;
  String? _message;

  List<PremiumBenefit> get _orderedBenefits {
    final all = [...PremiumService.benefits];
    final h = widget.highlight;
    if (h != null) {
      all.sort((a, b) => (a.feature == h ? 0 : 1) - (b.feature == h ? 0 : 1));
    }
    return all;
  }

  Future<void> _buy() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final outcome = await PremiumService.purchaseLifetimePremium();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (outcome) {
        PurchaseOutcome.success => null,
        PurchaseOutcome.pending =>
          "Payment is processing. Pro unlocks automatically once it's confirmed.",
        PurchaseOutcome.cancelled => null,
        PurchaseOutcome.failed => 'Purchase did not go through. Please try again.',
        PurchaseOutcome.unavailable =>
          'The store is not available right now. Check your connection.',
      };
    });
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final restored = await PremiumService.restorePurchases();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = restored ? null : 'No previous Pro purchase found on this account.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumService.isPro,
      builder: (context, isPro, _) => Scaffold(
        body: SafeArea(
          child: isPro ? _buildUnlocked(context) : _buildOffer(context),
        ),
      ),
    );
  }

  Widget _buildOffer(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            children: [
              const Center(
                child: PipMascot(
                  mood: MascotMood.proud,
                  outfit: MascotOutfit.royal,
                  size: 132,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'Alarm+ Pro',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Pay once. Wake up better for good.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: Spacing.xxl),
              for (final (i, b) in _orderedBenefits.indexed)
                _BenefitRow(
                  benefit: b,
                  highlighted: b.feature == widget.highlight,
                )
                    .animate(delay: (80 * i).ms)
                    .fadeIn(duration: 250.ms)
                    .slideX(begin: 0.08, end: 0),
              const SizedBox(height: Spacing.lg),
              const _OutfitStrip(),
              const SizedBox(height: Spacing.lg),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.xl, Spacing.sm, Spacing.xl, Spacing.lg),
          child: Column(
            children: [
              if (_message != null) ...[
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: Spacing.sm),
              ],
              ValueListenableBuilder<bool>(
                valueListenable: PremiumService.purchasePending,
                builder: (context, pending, _) => FutureBuilder<String>(
                  future: _price,
                  builder: (context, snap) {
                    final price = snap.data ?? PremiumService.fallbackPriceLabel;
                    return FilledButton(
                      onPressed: _busy || pending ? null : _buy,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: Palette.green500,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(pending
                              ? 'Waiting for payment…'
                              : 'Unlock Pro for $price'),
                    );
                  },
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'One-time payment · no subscription · yours forever',
                style: theme.textTheme.bodySmall,
              ),
              TextButton(
                onPressed: _busy ? null : _restore,
                child: const Text('Restore purchase'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnlocked(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PipMascot(
            mood: MascotMood.cheering,
            outfit: MascotOutfit.royal,
            size: 160,
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            "You're Pro!",
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ).animate().scale(
                begin: const Offset(0.6, 0.6),
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: Spacing.sm),
          Text(
            "Thanks for supporting Alarm+. Pip's wardrobe is open. Pick an outfit in Settings.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Spacing.xxxl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            child: const Text("Let's go"),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit, required this.highlighted});

  final PremiumBenefit benefit;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: highlighted
            ? Palette.green500.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: highlighted ? Palette.green500 : scheme.outlineVariant,
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Palette.green500.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(benefit.icon, color: Palette.green600, size: 22),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(benefit.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(benefit.description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Every premium outfit waving at once: the most direct "look what you get".
class _OutfitStrip extends StatelessWidget {
  const _OutfitStrip();

  @override
  Widget build(BuildContext context) {
    final outfits = MascotOutfit.values.where((o) => o.isPremium);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final o in outfits)
          Column(
            children: [
              PipMascot(mood: MascotMood.waving, outfit: o, size: 64),
              const SizedBox(height: Spacing.xs),
              Text(
                o.label.split(' ').first,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
      ],
    );
  }
}
