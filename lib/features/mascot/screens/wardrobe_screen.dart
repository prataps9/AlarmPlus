import 'package:flutter/material.dart';

import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/mascot/models/mascot_line.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/services/mascot_service.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_mascot.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_says.dart';

/// Pick Pip's outfit. Premium outfits show a lock and open the paywall.
class WardrobeScreen extends StatelessWidget {
  const WardrobeScreen({super.key});

  static const routeName = '/wardrobe';

  Future<void> _onPick(BuildContext context, MascotOutfit outfit) async {
    if (outfit.isPremium && !PremiumService.isPro.value) {
      final unlocked = await PremiumService.showLifetimePaywall(
          context, PremiumFeature.mascotOutfits);
      if (!unlocked) return;
    }
    await MascotService.selectOutfit(outfit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pip's Wardrobe")),
      body: ListenableBuilder(
        listenable: MascotService.changes,
        builder: (context, _) {
          final isPro = PremiumService.isPro.value;
          final picked = MascotService.selectedOutfit.value;
          return ListView(
            padding: const EdgeInsets.all(Spacing.xl),
            children: [
              PipSays(
                size: 110,
                line: MascotLine(
                  MascotMood.proud,
                  picked == MascotOutfit.classic
                      ? 'Classic me! Want to try something new?'
                      : 'Looking sharp in ${picked.label}!',
                ),
              ),
              const SizedBox(height: Spacing.xxl),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Spacing.md,
                crossAxisSpacing: Spacing.md,
                childAspectRatio: 0.9,
                children: [
                  for (final o in MascotOutfit.values)
                    _OutfitTile(
                      outfit: o,
                      selected: o == picked,
                      locked: o.isPremium && !isPro,
                      onTap: () => _onPick(context, o),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OutfitTile extends StatelessWidget {
  const _OutfitTile({
    required this.outfit,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final MascotOutfit outfit;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(
          color: selected ? Palette.green500 : scheme.outlineVariant,
          width: selected ? 2.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // IgnorePointer so taps select the tile instead of
                  // poking Pip.
                  IgnorePointer(
                    child: Opacity(
                      opacity: locked ? 0.55 : 1,
                      child: PipMascot(
                        mood: selected ? MascotMood.waving : MascotMood.idle,
                        outfit: outfit,
                        size: 96,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(outfit.label,
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            if (locked || selected)
              Positioned(
                top: Spacing.sm,
                right: Spacing.sm,
                child: Icon(
                  locked ? Icons.lock_rounded : Icons.check_circle_rounded,
                  size: 20,
                  color: locked ? scheme.onSurfaceVariant : Palette.green500,
                ),
              ),
            if (locked)
              Positioned(
                top: Spacing.sm,
                left: Spacing.sm,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Palette.amber400,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Palette.slate900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
