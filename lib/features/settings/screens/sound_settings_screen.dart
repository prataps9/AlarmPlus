import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/core/services/ringtone_service.dart';

class SoundSettingsScreen extends ConsumerStatefulWidget {
  const SoundSettingsScreen({super.key});

  static const routeName = '/sound-settings';

  @override
  ConsumerState<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends ConsumerState<SoundSettingsScreen> {
  static const _volumeKey = 'sound.alarm.volume';

  final _player = AudioPlayer();

  double _volume = 0.8;
  String _selectedSound = 'default';
  String _nativeTitle = 'Default Alarm';
  bool _loading = true;
  bool _previewing = false;
  bool _pickingRingtone = false;

  static const _bundledSounds = <String, String>{
    'assets/sounds/rain.mp3': 'Rain',
    'assets/sounds/ocean.mp3': 'Ocean',
    'assets/sounds/forest.mp3': 'Forest',
    'assets/sounds/white_noise.mp3': 'White Noise',
    'assets/sounds/brown_noise.mp3': 'Brown Noise',
  };

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final sound = await RingtoneService.getSavedSound();
    final title = await RingtoneService.getSavedTitle();
    if (!mounted) return;
    setState(() {
      _volume = (prefs.getDouble(_volumeKey) ?? 0.8).clamp(0.0, 1.0);
      _selectedSound = sound;
      _nativeTitle = title;
      _loading = false;
    });
  }

  Future<void> _saveVolume(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, v);
  }

  Future<void> _selectSound(String key, String title) async {
    await _player.stop();
    setState(() {
      _selectedSound = key;
      _nativeTitle = title;
      _previewing = false;
    });
    await RingtoneService.saveSound(key, title);
  }

  Future<void> _previewBundled(String assetKey) async {
    await _player.stop();
    if (_previewing && _selectedSound == assetKey) {
      setState(() => _previewing = false);
      return;
    }
    setState(() => _previewing = true);
    await _player.setVolume(_volume);
    await _player.play(AssetSource(assetKey.replaceFirst('assets/', '')));
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewing = false);
    });
  }

  Future<void> _openNativePicker() async {
    if (_pickingRingtone) return;
    setState(() => _pickingRingtone = true);
    final currentUri = RingtoneService.isNativeUri(_selectedSound)
        ? _selectedSound
        : null;
    final uri = await RingtoneService.pickRingtone(currentUri: currentUri);
    if (!mounted) return;
    setState(() => _pickingRingtone = false);
    if (uri != null) {
      final title = await RingtoneService.getTitleForUri(uri);
      if (mounted) await _selectSound(uri, title);
    }
  }

  String _displayTitle() {
    if (_selectedSound == 'default') return 'Default Alarm';
    if (RingtoneService.isNativeUri(_selectedSound)) return _nativeTitle;
    return _bundledSounds[_selectedSound] ?? _selectedSound;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibrationEnabled = ref.watch(vibrationEnabledProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound & Vibration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
              children: [
                _SectionHeader('ALARM VOLUME'),
                const SizedBox(height: 8),
                _Card(
                  child: Row(
                    children: [
                      Icon(Icons.volume_down_rounded, color: scheme.onSurfaceVariant),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          min: 0,
                          max: 1,
                          activeColor: const Color(0xFF22C55E),
                          onChanged: (v) => setState(() => _volume = v),
                          onChangeEnd: _saveVolume,
                        ),
                      ),
                      Icon(Icons.volume_up_rounded, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionHeader('ALARM SOUND'),
                const SizedBox(height: 8),

                // ── Native ringtone picker (Android only) ────────────────
                if (_isAndroid) ...[
                  _Card(
                    onTap: _openNativePicker,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.library_music_rounded,
                              color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Phone Ringtones',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: scheme.onSurface)),
                              Text(
                                RingtoneService.isNativeUri(_selectedSound)
                                    ? _nativeTitle
                                    : 'Pick from device alarm tones',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: RingtoneService.isNativeUri(_selectedSound)
                                      ? const Color(0xFF22C55E)
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_pickingRingtone)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF6366F1)),
                          )
                        else
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (RingtoneService.isNativeUri(_selectedSound))
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF22C55E)),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right_rounded,
                                color: scheme.outline),
                          ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // ── Default system tone ──────────────────────────────────
                _SoundTile(
                  label: 'Default Alarm',
                  subtitle: 'System default alarm tone',
                  icon: Icons.alarm_rounded,
                  iconColor: const Color(0xFF10B981),
                  isSelected: _selectedSound == 'default',
                  showPreview: false,
                  isPreviewing: false,
                  onTap: () => _selectSound('default', 'Default Alarm'),
                ),

                // ── Bundled ambient sounds ───────────────────────────────
                const SizedBox(height: 8),
                _SectionHeader('AMBIENT SOUNDS'),
                const SizedBox(height: 8),
                ..._bundledSounds.entries.map((entry) {
                  final selected = _selectedSound == entry.key;
                  return _SoundTile(
                    label: entry.value,
                    icon: _iconForSound(entry.key),
                    iconColor: scheme.onSurfaceVariant,
                    isSelected: selected,
                    showPreview: true,
                    isPreviewing: selected && _previewing,
                    onTap: () async {
                      await _selectSound(entry.key, entry.value);
                      await _previewBundled(entry.key);
                    },
                  );
                }),

                const SizedBox(height: 20),
                _SectionHeader('VIBRATION'),
                const SizedBox(height: 8),
                _Card(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vibrate on alarm ring',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Haptic feedback when alarm rings',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationEnabled,
                        onChanged: (v) =>
                            setVibrationEnabled(ref, v),
                        thumbColor: const WidgetStatePropertyAll(Colors.white),
                        trackColor: WidgetStateProperty.resolveWith<Color?>(
                          (s) => s.contains(WidgetState.selected)
                              ? const Color(0xFF22C55E)
                              : scheme.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selected sound summary chip
                if (_selectedSound != 'default') ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.music_note_rounded,
                            color: Color(0xFF22C55E), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Active: ${_displayTitle()}',
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  IconData _iconForSound(String key) {
    if (key.contains('rain')) return Icons.water_drop_rounded;
    if (key.contains('ocean')) return Icons.waves_rounded;
    if (key.contains('forest')) return Icons.forest_rounded;
    if (key.contains('white') || key.contains('brown')) return Icons.blur_on_rounded;
    if (key.contains('fan')) return Icons.air_rounded;
    if (key.contains('thunder')) return Icons.bolt_rounded;
    return Icons.music_note_rounded;
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.showPreview,
    required this.isPreviewing,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final bool showPreview;
  final bool isPreviewing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: isSelected ? const Color(0xFF22C55E) : iconColor,
                size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 15,
                        color: scheme.onSurface)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (showPreview)
            isPreviewing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF22C55E)),
                  )
                : Icon(Icons.play_circle_outline_rounded,
                    color: isSelected
                        ? const Color(0xFF22C55E)
                        : scheme.outline),
          const SizedBox(width: 8),
          if (isSelected)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: child,
      ),
    );
  }
}
