import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/models/alarm_personality.dart';
import 'package:alarm_plus/shared/widgets/mascot_widget.dart';
import 'package:alarm_plus/shared/widgets/skeleton.dart';
import 'package:alarm_plus/shared/models/challenge_type.dart';
import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/features/alarm/services/challenge_service.dart';
import 'package:alarm_plus/features/alarm/screens/quest_builder_screen.dart';
import 'package:alarm_plus/features/alarm/screens/qr_spot_setup_screen.dart';
import 'package:alarm_plus/core/services/ringtone_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/shared/widgets/alarm_card.dart';
import 'package:alarm_plus/features/sleep/widgets/voice_memo_recorder.dart';

class AlarmsScreen extends ConsumerWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmsAsync = ref.watch(alarmsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alarms')),
      body: alarmsAsync.when(
        data: (alarms) {
          if (alarms.isEmpty) return _EmptyAlarms(ref: ref);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl,
              Spacing.sm,
              Spacing.xl,
              // Clears the FAB.
              Spacing.xxxl * 2.5,
            ),
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return AlarmCard(
                key: ValueKey(alarm.id),
                alarm: alarm,
                onTap: () => _showAlarmSheet(context, ref, initial: alarm),
                onToggle: (enabled) {
                  ref
                      .read(alarmsMapProvider.notifier)
                      .toggleAlarm(alarm.id, enabled);
                },
                onDelete: () {
                  ref.read(alarmsMapProvider.notifier).cancelAlarm(alarm.id);
                },
              );
            },
          );
        },
        loading: () => const _AlarmsSkeleton(),
        error: (err, stack) => _AlarmsError(
          onRetry: () => ref.invalidate(alarmsListProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAlarmSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New alarm'),
      ),
    );
  }

  static void _showAlarmSheet(
    BuildContext context,
    WidgetRef ref, {
    AlarmModel? initial,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddAlarmSheet(ref: ref, initial: initial),
    );
  }
}

class _EmptyAlarms extends StatelessWidget {
  const _EmptyAlarms({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotWidget(mood: MascotMood.sleepy, size: 140),
            const SizedBox(height: Spacing.xl),
            Text('No alarms yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: Spacing.sm),
            Text(
              'Set one and start building your wake-up streak.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.xl),
            FilledButton.icon(
              onPressed: () => AlarmsScreen._showAlarmSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Set your first alarm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmsSkeleton extends StatelessWidget {
  const _AlarmsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.sm,
        Spacing.xl,
        Spacing.xxl,
      ),
      children: const [
        Skeleton(height: 132, radius: Radii.xl),
        SizedBox(height: Spacing.md),
        Skeleton(height: 132, radius: Radii.xl),
        SizedBox(height: Spacing.md),
        Skeleton(height: 132, radius: Radii.xl),
      ],
    );
  }
}

class _AlarmsError extends StatelessWidget {
  const _AlarmsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotWidget(mood: MascotMood.worried, size: 120),
            const SizedBox(height: Spacing.xl),
            Text("Couldn't load your alarms", style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.xl),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _AddAlarmSheet extends ConsumerStatefulWidget {
  const _AddAlarmSheet({required this.ref, this.initial});

  final WidgetRef ref;

  /// When set, the sheet edits this alarm instead of creating a new one.
  final AlarmModel? initial;

  @override
  ConsumerState<_AddAlarmSheet> createState() => _AddAlarmSheetState();
}

class _AddAlarmSheetState extends ConsumerState<_AddAlarmSheet> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _voiceQuickAddController =
      TextEditingController();

  int _hour = 7;
  int _minute = 30;
  bool _isAm = true;
  bool _setAlarm = true;
  String _tag = 'Steady wake';
  String _sound = 'default';
  String _soundTitle = 'Default Alarm';
  String _personality = 'gentle';
  final Set<int> _repeatDays = {2, 3, 4, 5, 6};
  bool _gentleWake = false;
  int _gentleWakeDuration = 60;
  ChallengeType? _challengeType;
  String? _voiceMemoPath;
  bool _questMode = false;
  List<ChallengeType> _questSteps = [];
  String? _savedQrCode;
  int _stepGoal = 20;
  int _squatReps = 10;
  bool _wakeUpCheck = false;
  int _wakeUpCheckMinutes = 10;
  bool _hardcoreMode = false;

  DayTypeProfile _profile = DayTypeProfile.workday;
  double _sleepGoalHours = 7.5;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _hydrateFromInitial();
    _loadTeenSleepProfile();
  }

  /// Pre-fills every control from the alarm being edited.
  void _hydrateFromInitial() {
    final alarm = widget.initial;
    if (alarm == null) return;

    final hour24 = alarm.time.hour;
    _isAm = hour24 < 12;
    _hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    _minute = alarm.time.minute;

    _labelController.text = alarm.label;
    _setAlarm = alarm.isEnabled;
    _tag = alarm.tag;
    _sound = alarm.sound;
    _personality = alarm.personality;
    _repeatDays
      ..clear()
      ..addAll(alarm.repeatDays);
    _gentleWake = alarm.gentleWake;
    _gentleWakeDuration = alarm.gentleWakeDurationSeconds;
    _challengeType = alarm.challengeType;
    _voiceMemoPath = alarm.voiceMemoPath;
    _questMode = alarm.questMode;
    _questSteps = List.of(alarm.questSteps ?? const []);
    _savedQrCode = alarm.savedQrCode;
    _stepGoal = alarm.stepGoal;
    _squatReps = alarm.squatReps;
    _wakeUpCheck = alarm.wakeUpCheckEnabled;
    _wakeUpCheckMinutes = alarm.wakeUpCheckMinutes;
    _hardcoreMode = alarm.hardcoreMode;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _voiceQuickAddController.dispose();
    super.dispose();
  }

  Future<void> _openSoundPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SoundPickerSheet(
        currentSound: _sound,
        currentTitle: _soundTitle,
        onSelected: (sound, title) {
          setState(() {
            _sound = sound;
            _soundTitle = title;
          });
        },
      ),
    );
  }

  Future<void> _loadTeenSleepProfile() async {
    final profile = await SmartAlarmService.getTeenSleepProfile();
    if (!mounted) {
      return;
    }

    setState(() {
      _sleepGoalHours = profile.targetSleepHours;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildTimePicker(context),
              const SizedBox(height: 18),
              TextField(
                controller: _labelController,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Alarm label...',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF94A3B8),
                    fontSize: 20,
                  ),
                  contentPadding: EdgeInsets.zero,
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Day Type Profile',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DayTypeProfile.values
                    .map(
                      (profile) => ChoiceChip(
                        label: Text(_profileLabel(profile)),
                        selected: _profile == profile,
                        onSelected: (selected) {
                          if (!selected) return;
                          _applyProfile(profile);
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text(
                'Smart Sleep Window',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep Goal: ${_sleepGoalHours.toStringAsFixed(1)}h',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Slider(
                      value: _sleepGoalHours,
                      min: 6.0,
                      max: 9.0,
                      divisions: 12,
                      onChanged: (value) =>
                          setState(() => _sleepGoalHours = value),
                    ),
                    Text(
                      'Suggested bedtime: ${_suggestedBedtimeLabel()}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Repeat',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(7, (index) {
                  final weekday = index + 1;
                  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final selected = _repeatDays.contains(weekday);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _repeatDays.remove(weekday);
                          } else {
                            _repeatDays.add(weekday);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF111111)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF111111)
                                : const Color(0xFFD4D7DD),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF888888),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: _openSoundPicker,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Text(
                      'Sound',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _soundLabel(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Alarm Personality',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AlarmPersonality.values.map((p) {
                    final config = PersonalityConfig.all[p]!;
                    final selected = _personality == p.name;
                    return GestureDetector(
                      onTap: () => setState(() => _personality = p.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? config.primaryColor : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? config.primaryColor : const Color(0xFFE2E8F0),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(config.emoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              config.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              // Gentle Wake toggle
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gentle Wake', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
                        Text('Gradually ramp volume over ${_gentleWakeDuration}s', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  _AnimatedToggle(
                    value: _gentleWake,
                    onChanged: (v) => setState(() => _gentleWake = v),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _gentleWake
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 8,
                          children: [30, 60, 120].map((s) {
                            final selected = _gentleWakeDuration == s;
                            return ChoiceChip(
                              label: Text('${s}s'),
                              selected: selected,
                              selectedColor: const Color(0xFF111111),
                              labelStyle: TextStyle(
                                  color: selected ? Colors.white : const Color(0xFF111111),
                                  fontWeight: FontWeight.w600),
                              onSelected: (_) =>
                                  setState(() => _gentleWakeDuration = s),
                            );
                          }).toList(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              // Wake Challenge picker
              Text('Wake Challenge', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 10),
              DropdownButtonFormField<ChallengeType?>(
                initialValue: _challengeType,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Math (default)')),
                  ...ChallengeType.values.map((t) => DropdownMenuItem(value: t, child: Text(ChallengeService.label(t)))),
                ],
                onChanged: (v) => setState(() => _challengeType = v),
              ),
              const SizedBox(height: 20),

              // ── Quest Mode toggle ──────────────────────────────────────
              Row(children: [
                const Icon(Icons.rocket_launch_rounded,
                    color: Color(0xFF444444), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wake Quest Mode',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Text('Chain multiple challenges in order',
                        style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                  ],
                )),
                _AnimatedToggle(
                  value: _questMode,
                  onChanged: (v) => setState(() {
                    _questMode = v;
                    if (v && _questSteps.isEmpty) {
                      _questSteps = [
                        ChallengeType.shakeToWake,
                        ChallengeType.trivia,
                      ];
                    }
                  }),
                ),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _questMode
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result =
                                await Navigator.of(context).push<List<ChallengeType>>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    QuestBuilderScreen(initialSteps: _questSteps),
                              ),
                            );
                            if (result != null && mounted) {
                              setState(() => _questSteps = result);
                            }
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(_questSteps.isEmpty
                              ? 'Build Quest'
                              : _questSteps
                                  .map((t) => ChallengeService.label(t))
                                  .join(' → ')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111111),
                            side: const BorderSide(color: Color(0xFF444444)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── QR Spot (shown when barcodeScan is selected or in quest) ──
              if (_challengeType == ChallengeType.barcodeScan ||
                  (_questMode &&
                      _questSteps.contains(ChallengeType.barcodeScan))) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final code =
                        await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                          builder: (_) => const QrSpotSetupScreen()),
                    );
                    if (code != null && mounted) {
                      setState(() => _savedQrCode = code);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Row(children: [
                    const Icon(Icons.qr_code_rounded,
                        color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dismiss Spot',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          _savedQrCode != null
                              ? 'QR spot registered'
                              : 'Scan a sticker to lock the dismiss spot',
                          style: TextStyle(
                            fontSize: 13,
                            color: _savedQrCode != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    )),
                    Icon(
                      _savedQrCode != null
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded,
                      color: _savedQrCode != null
                          ? const Color(0xFF10B981)
                          : const Color(0xFFCBD5E1),
                    ),
                  ]),
                ),
              ],

              // ── Step goal (shown when stepCounter is selected or in quest) ──
              if (_challengeType == ChallengeType.stepCounter ||
                  (_questMode &&
                      _questSteps.contains(ChallengeType.stepCounter))) ...[
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.directions_walk_rounded,
                      color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Text('Steps to dismiss: $_stepGoal',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                Slider(
                  value: _stepGoal.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '$_stepGoal steps',
                  activeColor: const Color(0xFF10B981),
                  onChanged: (v) => setState(() => _stepGoal = v.round()),
                ),
              ],

              if (_challengeType == ChallengeType.squatReps) ...[
                const SizedBox(height: Spacing.lg),
                Row(children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    'Squats to dismiss: $_squatReps',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ]),
                Slider(
                  value: _squatReps.toDouble(),
                  min: 3,
                  max: 30,
                  divisions: 27,
                  label: '$_squatReps squats',
                  onChanged: (v) => setState(() => _squatReps = v.round()),
                ),
              ],

              const SizedBox(height: 24),
              // Voice Memo
              VoiceMemoRecorder(
                initialPath: _voiceMemoPath,
                onMemoSaved: (path) => setState(() => _voiceMemoPath = path),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _voiceQuickAddController,
                decoration: InputDecoration(
                  hintText:
                      'Voice Quick Add text, e.g. wake me at 6:20 for gym tomorrow',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: TextButton(
                    onPressed: _applyVoiceQuickAdd,
                    child: const Text('Apply'),
                  ),
                ),
              ),
              // ── Heavy Sleeper section ─────────────────────────────────────
              const SizedBox(height: 28),
              Text(
                'Heavy Sleeper',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              // Wake-Up Check toggle
              Row(children: [
                const Icon(Icons.alarm_on_rounded, color: Color(0xFF444444), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wake-Up Check',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Text('Re-rings if you don\'t confirm you\'re awake',
                        style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                  ],
                )),
                _AnimatedToggle(
                  value: _wakeUpCheck,
                  onChanged: (v) => setState(() => _wakeUpCheck = v),
                ),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _wakeUpCheck
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 8,
                          children: [5, 10, 15].map((min) {
                            final sel = _wakeUpCheckMinutes == min;
                            return ChoiceChip(
                              label: Text('$min min'),
                              selected: sel,
                              selectedColor: const Color(0xFF111111),
                              labelStyle: TextStyle(
                                color: sel ? Colors.white : const Color(0xFF111111),
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) =>
                                  setState(() => _wakeUpCheckMinutes = min),
                            );
                          }).toList(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              // Hardcore Mode toggle
              Row(children: [
                const Icon(Icons.lock_rounded, color: Color(0xFF444444), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hardcore Mode',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Text('Disables back button while alarm is ringing',
                        style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                  ],
                )),
                _AnimatedToggle(
                  value: _hardcoreMode,
                  onChanged: (v) => setState(() => _hardcoreMode = v),
                ),
              ]),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Enable Alarm',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _AnimatedToggle(
                    value: _setAlarm,
                    onChanged: (value) => setState(() => _setAlarm = value),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF020617),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 62),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    'Set Alarm',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _profileLabel(DayTypeProfile profile) {
    switch (profile) {
      case DayTypeProfile.workday:
        return 'Workday';
      case DayTypeProfile.gym:
        return 'Gym';
      case DayTypeProfile.weekend:
        return 'Weekend';
      case DayTypeProfile.travel:
        return 'Travel';
    }
  }

  void _applyProfile(DayTypeProfile profile) {
    final defaults = SmartAlarmService.defaultsForProfile(profile);
    setState(() {
      _profile = profile;
      _hour = _formatHour(defaults.time.hour);
      _minute = defaults.time.minute;
      _isAm = defaults.time.hour < 12;
      _repeatDays
        ..clear()
        ..addAll(defaults.repeatDays);
      _labelController.text = defaults.label;
      _tag = defaults.tag;
    });
  }

  String _suggestedBedtimeLabel() {
    final hour24 = _isAm ? (_hour % 12) : (_hour % 12) + 12;
    final bedtime = SmartAlarmService.suggestBedtime(
      wakeTime: TimeOfDay(hour: hour24, minute: _minute),
      sleepHours: _sleepGoalHours,
    );
    return '${_formatHour(bedtime.hour)}:${bedtime.minute.toString().padLeft(2, '0')} ${bedtime.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _soundLabel() => _soundTitle;

  void _applyVoiceQuickAdd() {
    final parsed = SmartAlarmService.parseQuickAdd(
      _voiceQuickAddController.text,
    );
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse quick add text.')),
      );
      return;
    }

    setState(() {
      _hour = _formatHour(parsed.hour24);
      _minute = parsed.minute;
      _isAm = parsed.hour24 < 12;
      _labelController.text = parsed.label;
      _tag = parsed.dayOffset > 0
          ? 'Quick add for tomorrow'
          : 'Quick add for today';
      if (parsed.dayOffset > 0) {
        final tomorrow = DateTime.now().add(const Duration(days: 1)).weekday;
        _repeatDays
          ..clear()
          ..add(tomorrow);
      }
    });
  }

  int _formatHour(int hour24) {
    final normalized = hour24 % 12;
    return normalized == 0 ? 12 : normalized;
  }

  Widget _buildTimePicker(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pickerNumber(
          value: _hour,
          min: 1,
          max: 12,
          onChanged: (value) => setState(() => _hour = value),
        ),
        const SizedBox(width: 16),
        Text(
          ':',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 78,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 16),
        _pickerNumber(
          value: _minute,
          min: 0,
          max: 59,
          onChanged: (value) => setState(() => _minute = value),
        ),
        const SizedBox(width: 20),
        Column(
          children: [
            _periodButton(
              label: 'AM',
              active: _isAm,
              onTap: () => setState(() => _isAm = true),
            ),
            const SizedBox(height: 8),
            _periodButton(
              label: 'PM',
              active: !_isAm,
              onTap: () => setState(() => _isAm = false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pickerNumber({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: () {
            final next = value + 1 > max ? min : value + 1;
            onChanged(next);
          },
          icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 28),
        ),
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(fontSize: 66, fontWeight: FontWeight.w700),
        ),
        IconButton(
          onPressed: () {
            final next = value - 1 < min ? max : value - 1;
            onChanged(next);
          },
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
        ),
      ],
    );
  }

  Widget _periodButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: active ? Colors.black : const Color(0xFFB0B0B0),
        ),
      ),
    );
  }

  /// "Alarm set for 6:30 AM · in 8h 12m" — so saving confirms something
  /// concrete rather than just closing the sheet.
  String _confirmationText(TimeOfDay time, List<int> repeatDays) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    if (repeatDays.isNotEmpty) {
      while (!repeatDays.contains(next.weekday)) {
        next = next.add(const Duration(days: 1));
      }
    }

    final until = next.difference(now);
    final hours = until.inHours;
    final minutes = until.inMinutes % 60;
    final away = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final hh = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final mm = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return 'Alarm set for $hh:$mm $period · in $away';
  }

  Future<void> _saveAlarm() async {
    try {
      final hour24 = _isAm ? (_hour % 12) : (_hour % 12) + 12;

      await SmartAlarmService.saveTeenSleepProfile(
        targetSleepHours: _sleepGoalHours,
      );

      final time = TimeOfDay(hour: hour24, minute: _minute);
      final label = _labelController.text.trim().isEmpty
          ? 'Work Morning'
          : _labelController.text.trim();
      final repeatDays = _repeatDays.toList()..sort();
      final notifier = ref.read(alarmsMapProvider.notifier);

      if (_isEditing) {
        await notifier.updateAlarm(
          widget.initial!.copyWith(
            time: time,
            label: label,
            repeatDays: repeatDays,
            isEnabled: _setAlarm,
            tag: _tag,
            sound: _sound,
            personality: _personality,
            gentleWake: _gentleWake,
            gentleWakeDurationSeconds: _gentleWakeDuration,
            challengeType: _challengeType,
            voiceMemoPath: _voiceMemoPath,
            stepGoal: _stepGoal,
            squatReps: _squatReps,
            savedQrCode: _savedQrCode,
            questMode: _questMode,
            questSteps: _questMode ? _questSteps : null,
            wakeUpCheckEnabled: _wakeUpCheck,
            wakeUpCheckMinutes: _wakeUpCheckMinutes,
            hardcoreMode: _hardcoreMode,
          ),
        );
      } else {
        await notifier.addAlarm(
          time: time,
          label: label,
          repeatDays: repeatDays,
          isEnabled: _setAlarm,
          tag: _tag,
          sound: _sound,
          personality: _personality,
          gentleWake: _gentleWake,
          gentleWakeDurationSeconds: _gentleWakeDuration,
          challengeType: _challengeType,
          voiceMemoPath: _voiceMemoPath,
          stepGoal: _stepGoal,
          squatReps: _squatReps,
          savedQrCode: _savedQrCode,
          questMode: _questMode,
          questSteps: _questMode ? _questSteps : null,
          wakeUpCheckEnabled: _wakeUpCheck,
          wakeUpCheckMinutes: _wakeUpCheckMinutes,
          hardcoreMode: _hardcoreMode,
        );
      }

      if (!mounted) {
        return;
      }

      // Captured before pop — this sheet's context is gone afterwards.
      final messenger = ScaffoldMessenger.of(context);

      HapticFeedback.mediumImpact();
      Navigator.pop(context);

      if (_setAlarm) {
        messenger.showSnackBar(
          SnackBar(content: Text(_confirmationText(time, repeatDays))),
        );
      }
    } catch (e) {
      debugPrint('Error saving alarm: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save alarm: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

}

// ── Sound Picker ─────────────────────────────────────────────────────────────

class _SoundPickerSheet extends StatefulWidget {
  const _SoundPickerSheet({
    required this.currentSound,
    required this.currentTitle,
    required this.onSelected,
  });
  final String currentSound;
  final String currentTitle;
  final void Function(String sound, String title) onSelected;

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  final _player = AudioPlayer();
  String? _previewingKey;
  bool _pickingNative = false;
  late String _selected;
  late String _selectedTitle;

  static const _bundled = <String, String>{
    'assets/sounds/rain.mp3': 'Rain',
    'assets/sounds/ocean.mp3': 'Ocean',
    'assets/sounds/forest.mp3': 'Forest',
    'assets/sounds/white_noise.mp3': 'White Noise',
    'assets/sounds/brown_noise.mp3': 'Brown Noise',
    'assets/sounds/crickets.mp3': 'Crickets',
    'assets/sounds/fan.mp3': 'Fan',
    'assets/sounds/thunder.mp3': 'Thunder',
  };

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentSound;
    _selectedTitle = widget.currentTitle;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _select(String key, String title) async {
    await _player.stop();
    setState(() {
      _selected = key;
      _selectedTitle = title;
      _previewingKey = null;
    });
    widget.onSelected(key, title);
  }

  Future<void> _togglePreview(String assetKey) async {
    await _player.stop();
    if (_previewingKey == assetKey) {
      setState(() => _previewingKey = null);
      return;
    }
    setState(() => _previewingKey = assetKey);
    await _player.play(AssetSource(assetKey.replaceFirst('assets/', '')));
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewingKey = null);
    });
  }

  Future<void> _pickNative() async {
    if (_pickingNative) return;
    setState(() => _pickingNative = true);
    final currentUri =
        RingtoneService.isNativeUri(_selected) ? _selected : null;
    final uri = await RingtoneService.pickRingtone(currentUri: currentUri);
    if (!mounted) return;
    setState(() => _pickingNative = false);
    if (uri != null) {
      final title = await RingtoneService.getTitleForUri(uri);
      if (mounted) await _select(uri, title);
    }
  }

  IconData _iconFor(String key) {
    if (key.contains('rain')) return Icons.water_drop_rounded;
    if (key.contains('ocean')) return Icons.waves_rounded;
    if (key.contains('forest')) return Icons.forest_rounded;
    if (key.contains('white') || key.contains('brown')) return Icons.blur_on_rounded;
    if (key.contains('fan')) return Icons.air_rounded;
    if (key.contains('thunder')) return Icons.bolt_rounded;
    if (key.contains('crickets')) return Icons.grass_rounded;
    return Icons.music_note_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Choose Sound',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Default system tone
            _SoundRow(
              icon: Icons.alarm_rounded,
              label: 'Default Alarm',
              subtitle: 'System alarm tone',
              isSelected: _selected == 'default',
              onTap: () => _select('default', 'Default Alarm'),
            ),

            // Android-only native ringtone picker
            if (_isAndroid) ...[
              const SizedBox(height: 4),
              _SoundRow(
                icon: Icons.library_music_rounded,
                label: 'Phone Ringtones',
                subtitle: RingtoneService.isNativeUri(_selected)
                    ? _selectedTitle
                    : 'Pick from device alarm tones',
                isSelected: RingtoneService.isNativeUri(_selected),
                trailing: _pickingNative
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFAAAAAA), size: 20),
                onTap: _pickNative,
              ),
            ],

            const SizedBox(height: 16),
            const Text('AMBIENT SOUNDS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: Color(0xFF888888))),
            const SizedBox(height: 10),

            // Bundled sounds with preview
            ..._bundled.entries.map((e) {
              final isSelected = _selected == e.key;
              final isPreviewing = _previewingKey == e.key;
              return _SoundRow(
                icon: _iconFor(e.key),
                label: e.value,
                isSelected: isSelected,
                trailing: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _togglePreview(e.key),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: isPreviewing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF111111)),
                          )
                        : Icon(
                            Icons.play_circle_outline_rounded,
                            color: isSelected
                                ? const Color(0xFF111111)
                                : const Color(0xFFAAAAAA),
                            size: 24,
                          ),
                  ),
                ),
                onTap: () => _select(e.key, e.value),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.isSelected,
    this.trailing,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isSelected;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F0F0) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF111111) : const Color(0xFFE8E8E8),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isSelected
                    ? const Color(0xFF111111)
                    : const Color(0xFF888888)),
            const SizedBox(width: 12),
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
                          color: const Color(0xFF111111))),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888888))),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (isSelected)
              const Icon(Icons.check_rounded,
                  color: Color(0xFF111111), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Animated Toggle ───────────────────────────────────────────────────────────

class _AnimatedToggle extends StatelessWidget {
  const _AnimatedToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF111111) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
