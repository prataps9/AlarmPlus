import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:alarm_plus/features/sleep/models/sleep_sound.dart';
import 'package:alarm_plus/features/sleep/services/sleep_sound_service.dart';
import 'package:alarm_plus/core/theme/app_theme_ext.dart';

class SleepSoundsScreen extends StatefulWidget {
  const SleepSoundsScreen({super.key});

  static const routeName = '/sleep-sounds';

  @override
  State<SleepSoundsScreen> createState() => _SleepSoundsScreenState();
}

class _SleepSoundsScreenState extends State<SleepSoundsScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  Timer? _uiTimer;
  int _autoStopMinutes = 0; // 0 = play until alarm

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _uiTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _uiTimer?.cancel();
    super.dispose();
  }

  void _onCardTap(SleepSound sound) {
    if (SleepSoundService.getCurrentSound() == sound && SleepSoundService.isPlaying()) {
      SleepSoundService.stop();
      setState(() {});
      return;
    }
    _showSoundSheet(sound);
  }

  void _showSoundSheet(SleepSound sound) {
    var volume = SleepSoundService.getVolume();
    var selectedTimer = _autoStopMinutes;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.colors.outline,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: [
                Text(sound.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Text(sound.displayName,
                    style: TextStyle(
                        color: context.colors.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 22)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Icon(Icons.volume_up_rounded, color: context.colors.onSurfaceVariant, size: 20),
                Expanded(
                  child: Slider(
                    value: volume,
                    onChanged: (v) {
                      setSheetState(() => volume = v);
                      SleepSoundService.setVolume(v);
                    },
                    activeColor: context.colors.primary,
                    inactiveColor: context.colors.outlineVariant,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Auto-stop',
                      style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.w600))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final mins in [0, 15, 30, 45, 60])
                    ChoiceChip(
                      label: Text(mins == 0 ? '∞' : '${mins}m'),
                      selected: selectedTimer == mins,
                      onSelected: (_) => setSheetState(() => selectedTimer = mins),
                      selectedColor: context.colors.primary,
                      backgroundColor: context.colors.outlineVariant,
                      labelStyle: TextStyle(
                          color: selectedTimer == mins ? context.colors.onSurface : context.colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _autoStopMinutes = selectedTimer;
                    SleepSoundService.play(sound);
                    SleepSoundService.scheduleAutoStop(selectedTimer);
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: context.colors.onPrimary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40)),
                  ),
                  child: const Text('Play',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = SleepSoundService.getCurrentSound();
    final playing = SleepSoundService.isPlaying();

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colors.onSurface.withValues(alpha: 0.7)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SLEEP SOUNDS',
          style: TextStyle(
              color: context.colors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3),
        ),
      ),
      floatingActionButton: playing
          ? FloatingActionButton.extended(
              onPressed: () {
                SleepSoundService.stop();
                setState(() {});
              },
              backgroundColor: context.semantics.danger,
              icon: Icon(Icons.stop_rounded, color: context.colors.onSurface),
              label: Text('Stop',
                  style: TextStyle(color: context.colors.onSurface, fontWeight: FontWeight.w700)),
            )
          : null,
      body: Column(
        children: [
          if (playing && current != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Text(current.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Now playing: ${current.displayName}',
                            style: TextStyle(
                                color: context.colors.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                          Text('Looping · Tap stop to end',
                              style: TextStyle(
                                  color: context.colors.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                    _WaveBars(controller: _waveController),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.1,
              ),
              itemCount: SleepSound.values.length,
              itemBuilder: (context, i) {
                final sound = SleepSound.values[i];
                final isActive = current == sound && playing;
                return GestureDetector(
                  onTap: () => _onCardTap(sound),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final borderColor = isActive
                          ? Color.lerp(
                              context.colors.primary,
                              context.colors.primary,
                              _pulseController.value)!
                          : context.colors.surfaceContainer;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isActive
                              ? context.colors.primary.withValues(alpha: 0.15)
                              : context.colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: borderColor,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(sound.icon,
                            style: const TextStyle(fontSize: 40)),
                        const SizedBox(height: 10),
                        Text(
                          sound.displayName,
                          style: TextStyle(
                            color: isActive
                                ? context.colors.primary
                                : context.colors.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (isActive)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Playing',
                                style: TextStyle(
                                    color: context.colors.primary,
                                    fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveBars extends StatelessWidget {
  const _WaveBars({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          children: List.generate(5, (i) {
            final height = 8 +
                16 *
                    math.sin(
                        (controller.value * 2 * math.pi) + (i * math.pi / 2.5))
                        .abs();
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
