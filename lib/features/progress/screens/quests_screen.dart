import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alarm_plus/core/services/celebration_event.dart';
import 'package:alarm_plus/core/services/progression_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/core/theme/app_theme_ext.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';

/// Daily goal, daily quests and the gem shop on one screen.
class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  static const routeName = '/quests';

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  DailyProgress? _progress;
  int _freezes = 0;
  LostStreak? _lostStreak;
  StreamSubscription<CelebrationEvent>? _events;
  Timer? _boostTicker;

  @override
  void initState() {
    super.initState();
    _load();
    _events = SmartAlarmService.celebrationEvents.listen((_) => _load());
    // Keeps the boost countdown honest and flips it off when it runs out.
    _boostTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_progress?.boostActive ?? false) _load();
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _boostTicker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([
      ProgressionService.getDailyProgress(),
      SmartAlarmService.getStreakFreezesOwned(),
      SmartAlarmService.getRepairableStreak(),
    ]);
    if (!mounted) return;
    setState(() {
      _progress = results[0] as DailyProgress;
      _freezes = results[1] as int;
      _lostStreak = results[2] as LostStreak?;
    });
  }

  Future<void> _buy(ShopItem item) async {
    final result = await ProgressionService.purchase(item);
    if (!mounted) return;
    final message = switch (result) {
      PurchaseResult.ok => switch (item) {
          ShopItem.streakFreeze => 'Streak Freeze equipped ❄️',
          ShopItem.xpBoost => 'Double XP is on for 30 minutes ⚡',
          ShopItem.streakRepair => 'Streak repaired 🔥',
        },
      PurchaseResult.notEnoughGems => 'Not enough gems yet — finish some quests',
      PurchaseResult.maxOwned =>
        'You can hold ${ProgressionService.maxStreakFreezes} freezes at a time',
      PurchaseResult.unavailable => 'Nothing to repair right now',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    await _load();
  }

  Future<void> _pickGoal() async {
    final current = _progress?.goal;
    final picked = await showModalBottomSheet<DailyGoal>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.sm),
              child: Text('Daily XP goal', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final goal in DailyGoal.values)
              ListTile(
                title: Text(goal.label),
                subtitle: Text('${goal.xp} XP a day'),
                trailing: goal == current ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, goal),
              ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await ProgressionService.setDailyGoal(picked);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        actions: [
          if (progress != null)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.lg),
              child: Center(child: GemCount(gems: progress.gems)),
            ),
        ],
      ),
      body: progress == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxxl),
                children: [
                  if (progress.boostUntil != null) ...[
                    _BoostBanner(until: progress.boostUntil!),
                    const SizedBox(height: Spacing.md),
                  ],
                  if (_lostStreak != null) ...[
                    _RepairBanner(
                      lost: _lostStreak!,
                      onRepair: () => _buy(ShopItem.streakRepair),
                    ),
                    const SizedBox(height: Spacing.md),
                  ],
                  _DailyGoalCard(progress: progress, onChangeGoal: _pickGoal),
                  const SizedBox(height: Spacing.xxl),
                  const _Eyebrow('DAILY QUESTS'),
                  const SizedBox(height: Spacing.md),
                  for (final q in progress.quests) _QuestTile(quest: q),
                  Text(
                    progress.questsCompleted == progress.quests.length
                        ? 'All done — new quests at midnight'
                        : 'Finish all three for a +${ProgressionService.allQuestsBonusGems} 💎 bonus',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: Spacing.xxl),
                  const _Eyebrow('SHOP'),
                  const SizedBox(height: Spacing.md),
                  _ShopTile(
                    item: ShopItem.streakFreeze,
                    icon: Icons.ac_unit_rounded,
                    note: '$_freezes/${ProgressionService.maxStreakFreezes} equipped',
                    enabled: _freezes < ProgressionService.maxStreakFreezes,
                    gems: progress.gems,
                    onBuy: () => _buy(ShopItem.streakFreeze),
                  ),
                  _ShopTile(
                    item: ShopItem.xpBoost,
                    icon: Icons.bolt_rounded,
                    note: progress.boostActive ? 'Buying again adds 30 min' : null,
                    enabled: true,
                    gems: progress.gems,
                    onBuy: () => _buy(ShopItem.xpBoost),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Gem balance chip, shared with Home.
class GemCount extends StatelessWidget {
  const GemCount({super.key, required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.diamond_rounded, size: 18, color: Palette.indigo500),
        const SizedBox(width: Spacing.xs),
        Text(
          '$gems',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: Tracking.eyebrow),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color, this.borderColor});

  final Widget child;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: color ?? context.colors.surfaceContainerHighest,
        borderRadius: Radii.cardRadius,
        border: Border.all(color: borderColor ?? context.colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.progress, required this.onChangeGoal});

  final DailyProgress progress;
  final VoidCallback onChangeGoal;

  @override
  Widget build(BuildContext context) {
    final success = context.semantics.success;
    final today = DateTime.now();
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              DailyGoalRing(progress: progress, size: 64),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.goalMet ? 'Daily goal reached' : 'Daily goal',
                      style: context.texts.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${progress.xpToday} / ${progress.goal.xp} XP · ${progress.goal.label}',
                      style: context.texts.bodyMedium,
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onChangeGoal, child: const Text('Change')),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < progress.weekXp.length; i++)
                _WeekDot(
                  label: DateFormat.E().format(
                    DateTime(today.year, today.month, today.day - (progress.weekXp.length - 1 - i)),
                  )[0],
                  met: progress.weekXp[i] >= progress.goal.xp,
                  isToday: i == progress.weekXp.length - 1,
                  color: success,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.label, required this.met, required this.isToday, required this.color});

  final String label;
  final bool met;
  final bool isToday;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: met ? color : Colors.transparent,
            border: Border.all(
              color: met ? color : context.colors.outlineVariant,
              width: isToday ? 2 : 1,
            ),
          ),
          child: met ? Icon(Icons.check_rounded, size: 18, color: context.colors.surface) : null,
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          label,
          style: context.texts.bodySmall?.copyWith(
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Circular daily-goal progress, shared with Home.
class DailyGoalRing extends StatelessWidget {
  const DailyGoalRing({super.key, required this.progress, this.size = 48});

  final DailyProgress progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = progress.goalMet ? context.semantics.success : context.colors.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress.goalFraction,
            strokeWidth: size / 9,
            backgroundColor: context.colors.outlineVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: progress.goalMet
                ? Icon(Icons.check_rounded, color: color, size: size * 0.45)
                : Text(
                    '${(progress.goalFraction * 100).round()}%',
                    style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest});

  final QuestProgress quest;

  @override
  Widget build(BuildContext context) {
    final success = context.semantics.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: _Card(
        borderColor: quest.completed ? success : null,
        child: Row(
          children: [
            Text(quest.quest.icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.quest.title,
                    style: context.texts.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          child: LinearProgressIndicator(
                            value: quest.fraction,
                            minHeight: 8,
                            backgroundColor: context.colors.outlineVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              quest.completed ? success : context.colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Text('${quest.progress}/${quest.quest.target}', style: context.texts.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            quest.completed
                ? Icon(Icons.check_circle_rounded, color: success)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('+${quest.quest.gems}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Icon(Icons.diamond_rounded, size: 16, color: Palette.indigo500),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.item,
    required this.icon,
    required this.enabled,
    required this.gems,
    required this.onBuy,
    this.note,
  });

  final ShopItem item;
  final IconData icon;
  final String? note;
  final bool enabled;
  final int gems;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final affordable = gems >= item.price;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: _Card(
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.texts.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(item.description, style: context.texts.bodySmall),
                  if (note != null)
                    Text(note!, style: context.texts.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            FilledButton.tonal(
              onPressed: enabled ? onBuy : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.diamond_rounded,
                    size: 16,
                    color: affordable && enabled ? Palette.indigo500 : null,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text('${item.price}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoostBanner extends StatelessWidget {
  const _BoostBanner({required this.until});

  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final left = until.difference(DateTime.now());
    final minutes = left.inMinutes.clamp(1, 9999);
    final warning = context.semantics.warning;
    return _Card(
      color: warning.withValues(alpha: 0.12),
      borderColor: warning,
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: warning),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'Double XP active · $minutes min left',
              style: context.texts.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepairBanner extends StatelessWidget {
  const _RepairBanner({required this.lost, required this.onRepair});

  final LostStreak lost;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final danger = context.semantics.danger;
    final hoursLeft = SmartAlarmService.streakRepairWindow.inHours -
        DateTime.now().difference(lost.lostAt).inHours;
    return _Card(
      color: danger.withValues(alpha: 0.08),
      borderColor: danger,
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded, color: danger),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your ${lost.days}-day streak ended',
                  style: context.texts.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text('Repair it in the next ${hoursLeft.clamp(1, 48)}h', style: context.texts.bodySmall),
              ],
            ),
          ),
          FilledButton(
            onPressed: onRepair,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_rounded, size: 16),
                const SizedBox(width: Spacing.xs),
                Text('${ShopItem.streakRepair.price}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
