import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/core/services/app_settings.dart';
import 'package:alarm_plus/core/services/morning_briefing_service.dart';
import 'package:alarm_plus/features/settings/screens/alarm_health_screen.dart';
import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/screens/alarm_ring_screen.dart';
import 'package:alarm_plus/features/sleep/screens/bedtime_setup_screen.dart';
import 'package:alarm_plus/features/location/screens/location_alarm_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_diary_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_insights_screen.dart';
import 'package:alarm_plus/features/settings/screens/sound_settings_screen.dart';
import 'package:alarm_plus/core/services/backup_service.dart';
import 'package:alarm_plus/core/services/guardian_service.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/screens/wardrobe_screen.dart';
import 'package:alarm_plus/features/mascot/services/mascot_service.dart';
import 'package:alarm_plus/shared/widgets/alarm_logo.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Future<AlarmReliabilityStatus> _reliabilityFuture;
  late Future<DismissChallengeType> _dismissChallengeFuture;
  late Future<AlarmStats> _statsFuture;
  late Future<PackageInfo> _packageInfoFuture;
  late Future<String> _guardianWebhookFuture;
  late Future<bool> _upcomingNoticeFuture;
  late Future<bool> _briefingFuture;
  bool _restoringPurchase = false;

  static const _privacyPolicyUrl =
      'https://sites.google.com/view/alarmplus-privacy/home';

  @override
  void initState() {
    super.initState();
    _refreshAsyncTiles();
    PremiumService.isPro.addListener(_onProChanged);
  }

  @override
  void dispose() {
    PremiumService.isPro.removeListener(_onProChanged);
    super.dispose();
  }

  // The backup group lists "Restore Purchase" only while Pro is locked.
  void _onProChanged() {
    if (mounted) setState(() {});
  }

  void _refreshAsyncTiles() {
    _reliabilityFuture = SmartAlarmService.getReliabilityStatus();
    _dismissChallengeFuture = SmartAlarmService.getDismissChallenge();
    _statsFuture = SmartAlarmService.getStats();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _guardianWebhookFuture = GuardianService.getWebhookUrl();
    _upcomingNoticeFuture = AlarmService.upcomingNoticeEnabled();
    _briefingFuture = MorningBriefingService.isEnabled();
  }

  void _refreshAndRebuild() {
    setState(_refreshAsyncTiles);
  }

  String _query = '';

  // Accent per kind of setting, so a long list can be scanned by colour.
  static const _blue = Color(0xFF3B82F6);
  static const _orange = Color(0xFFF59E0B);
  static const _purple = Color(0xFF8B5CF6);
  static const _teal = Color(0xFF14B8A6);
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _indigo = Color(0xFF6366F1);
  static const _pink = Color(0xFFEC4899);
  static const _slate = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    // The tab stays alive while hidden: refresh what its tiles show (health,
    // streak, challenge) whenever it is opened.
    ref.listen<int>(currentTabIndexProvider, (prev, next) {
      if (next == AppTab.settings && prev != next) _refreshAndRebuild();
    });

    final vibrationEnabled = ref.watch(vibrationEnabledProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    Widget chevron() => Icon(Icons.chevron_right_rounded, color: muted, size: 22);

    final groups = <_Group>[
      _Group('ALARMS', [
        _Entry('Sound', 'tone ringtone volume music', () => _SettingTile(
              icon: Icons.volume_up_rounded,
              color: _blue,
              title: 'Sound',
              subtitle: 'Wake tone and ring volume',
              trailing: chevron(),
              onTap: () => Navigator.of(context)
                  .pushNamed(SoundSettingsScreen.routeName),
            )),
        _Entry('Wake Challenge', 'math dismiss puzzle quest', () =>
            ValueListenableBuilder<bool>(
              valueListenable: PremiumService.isPro,
              builder: (context, isPro, _) => FutureBuilder<DismissChallengeType>(
                future: _dismissChallengeFuture,
                builder: (context, snapshot) {
                  final challenge = effectiveChallenge(
                    snapshot.data ?? DismissChallengeType.math,
                    isPro: isPro,
                  );
                  return _SettingTile(
                    icon: Icons.psychology_rounded,
                    color: _orange,
                    title: 'Wake Challenge',
                    subtitle: challenge.name.toUpperCase(),
                    trailing: chevron(),
                    onTap: () => _showChallengePicker(context, challenge),
                  );
                },
              ),
            )),
        _Entry('Vibration', 'haptic buzz', () => _SettingTile(
              icon: Icons.vibration_rounded,
              color: _purple,
              title: 'Vibration',
              subtitle: 'Buzz while an alarm rings',
              trailing: _AnimatedToggle(
                value: vibrationEnabled,
                label: 'Vibration',
                onChanged: (v) => setVibrationEnabled(ref, v),
              ),
            )),
        _Entry('Live Alarm Countdown', 'capsule notification lock screen live update skip', () =>
            FutureBuilder<bool>(
              future: _upcomingNoticeFuture,
              builder: (context, snapshot) => _SettingTile(
                icon: Icons.pending_actions_rounded,
                color: _blue,
                title: 'Live Alarm Countdown',
                subtitle: 'Lock screen and status-bar capsule 2 h before, with Skip',
                trailing: _AnimatedToggle(
                  value: snapshot.data ?? true,
                  label: 'Live Alarm Countdown',
                  onChanged: (v) async {
                    await AlarmService.setUpcomingNoticeEnabled(v);
                    _refreshAndRebuild();
                  },
                ),
              ),
            )),
        _Entry('Morning Briefing', 'voice speak tts good morning', () =>
            FutureBuilder<bool>(
              future: _briefingFuture,
              builder: (context, snapshot) => _SettingTile(
                icon: Icons.record_voice_over_rounded,
                color: _teal,
                title: 'Morning Briefing',
                subtitle: 'Reads the time, your wake-up speed and streak aloud',
                trailing: _AnimatedToggle(
                  value: snapshot.data ?? false,
                  label: 'Morning Briefing',
                  onChanged: (v) async {
                    await MorningBriefingService.setEnabled(v);
                    _refreshAndRebuild();
                  },
                ),
              ),
            )),
        _Entry('Preview Alarm Screen', 'ring screen test', () => _SettingTile(
              icon: Icons.alarm_on_rounded,
              color: _red,
              title: 'Preview Alarm Screen',
              subtitle: 'See how a ringing alarm looks',
              trailing: chevron(),
              onTap: () =>
                  Navigator.of(context).pushNamed(AlarmRingScreen.routeName),
            )),
      ]),
      _Group('RELIABILITY & SAFETY', [
        _Entry('Alarm Health Check', 'reliability permissions battery test oppo xiaomi', () =>
            FutureBuilder<AlarmReliabilityStatus>(
              future: _reliabilityFuture,
              builder: (context, snapshot) {
                final status = snapshot.data;
                final ok = status?.notificationsGranted == true &&
                    status?.exactAlarmGranted == true;
                return _SettingTile(
                  icon: Icons.health_and_safety_rounded,
                  color: status == null || ok ? _green : _red,
                  title: 'Alarm Health Check',
                  subtitle: status == null
                      ? 'Checking…'
                      : ok
                          ? 'Test that alarms ring with the app closed'
                          : 'Action needed',
                  trailing: ok
                      ? chevron()
                      : const Icon(Icons.warning_amber_rounded,
                          color: _red, size: 22),
                  onTap: () async {
                    await Navigator.of(context)
                        .pushNamed(AlarmHealthScreen.routeName);
                    _refreshAndRebuild();
                  },
                );
              },
            )),
        _Entry('Guardian Alert', 'webhook notify contact heavy sleeper', () =>
            FutureBuilder<String>(
              future: _guardianWebhookFuture,
              builder: (context, snapshot) {
                final url = snapshot.data ?? '';
                return _SettingTile(
                  icon: Icons.shield_rounded,
                  color: _green,
                  title: 'Guardian Alert',
                  subtitle: url.isEmpty ? 'Not configured' : 'Webhook active',
                  trailing: chevron(),
                  onTap: () => _showGuardianDialog(context, url),
                );
              },
            )),
        _Entry('Location Alarms', 'arrive geofence place', () => _SettingTile(
              icon: Icons.location_on_rounded,
              color: _blue,
              title: 'Location Alarms',
              subtitle: 'Ring when you arrive somewhere',
              trailing: chevron(),
              onTap: () => Navigator.of(context)
                  .pushNamed(LocationAlarmScreen.routeName),
            )),
      ]),
      _Group('SLEEP', [
        _Entry('Sleep Insights', 'weekly score trends', () => _SettingTile(
              icon: Icons.bedtime_rounded,
              color: _indigo,
              title: 'Sleep Insights',
              subtitle: 'Weekly score and trends',
              trailing: chevron(),
              onTap: () => Navigator.of(context)
                  .pushNamed(SleepInsightsScreen.routeName),
            )),
        // The wind-down reminder lives with the bedtime schedule.
        _Entry('Wind Down / Bedtime', 'bedtime reminder goal', () => _SettingTile(
              icon: Icons.nights_stay_rounded,
              color: _purple,
              title: 'Wind Down / Bedtime',
              subtitle: 'Bedtime reminder & wind-down',
              trailing: chevron(),
              onTap: () => Navigator.of(context)
                  .pushNamed(BedtimeSetupScreen.routeName),
            )),
        _Entry('Sleep Diary', 'log quality journal', () => _SettingTile(
              icon: Icons.menu_book_rounded,
              color: _teal,
              title: 'Sleep Diary',
              subtitle: 'Log sleep quality daily',
              trailing: chevron(),
              onTap: () => Navigator.of(context)
                  .pushNamed(SleepDiaryScreen.routeName),
            )),
        _Entry('Streaks & Metrics', 'streak best xp', () =>
            FutureBuilder<AlarmStats>(
              future: _statsFuture,
              builder: (context, snapshot) {
                final stats = snapshot.data;
                return _SettingTile(
                  icon: Icons.local_fire_department_rounded,
                  color: _orange,
                  title: 'Streaks & Metrics',
                  subtitle: stats == null
                      ? '…'
                      : 'Streak ${stats.currentStreak} · best ${stats.bestStreak}',
                  trailing: const SizedBox.shrink(),
                );
              },
            )),
      ]),
      _Group('APPEARANCE', [
        _Entry('Theme', 'dark light mode night', () => _SettingTile(
              icon: Icons.contrast_rounded,
              color: _slate,
              title: 'Theme',
              subtitle:
                  AppSettings.themeModeLabel(ref.watch(themeModeProvider)),
              trailing: chevron(),
              onTap: () => _showThemePicker(context),
            )),
        _Entry("Pip's Wardrobe", 'mascot outfit pro', () =>
            ValueListenableBuilder<MascotOutfit>(
              valueListenable: MascotService.selectedOutfit,
              builder: (context, outfit, _) => _SettingTile(
                icon: Icons.checkroom_rounded,
                color: _pink,
                title: "Pip's Wardrobe",
                subtitle: outfit.label,
                trailing: chevron(),
                onTap: () =>
                    Navigator.of(context).pushNamed(WardrobeScreen.routeName),
              ),
            )),
      ]),
      _Group('BACKUP', [
        _Entry('Back Up Alarms & Settings', 'export save share file', () => _SettingTile(
              icon: Icons.cloud_upload_rounded,
              color: _blue,
              title: 'Back Up Alarms & Settings',
              subtitle: 'Save a file to Drive, email or anywhere',
              trailing: chevron(),
              onTap: () => _backup(context),
            )),
        _Entry('Restore From Backup', 'import file', () => _SettingTile(
              icon: Icons.settings_backup_restore_rounded,
              color: _teal,
              title: 'Restore From Backup',
              subtitle: 'Replace your alarms with a saved backup',
              trailing: chevron(),
              onTap: () => _restoreBackup(context),
            )),
        if (!PremiumService.isPro.value)
          _Entry('Restore Purchase', 'pro buy google play', () => _SettingTile(
                icon: Icons.restore_rounded,
                color: _orange,
                title: 'Restore Purchase',
                subtitle: 'Already bought Pro? Get it back here',
                trailing: chevron(),
                onTap: () => _restorePurchase(context),
              )),
      ]),
      _Group('ABOUT', [
        _Entry('About Alarm+', 'version info', () =>
            FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snapshot) {
                final info = snapshot.data;
                return _SettingTile(
                  icon: Icons.info_rounded,
                  color: _slate,
                  title: 'About Alarm+',
                  subtitle: info == null
                      ? ''
                      : 'v${info.version} (${info.buildNumber})',
                  trailing: chevron(),
                  onTap: () => _showAboutDialog(context, info),
                );
              },
            )),
        _Entry('Privacy Policy', 'terms data', () => _SettingTile(
              icon: Icons.privacy_tip_rounded,
              color: _slate,
              title: 'Privacy Policy',
              trailing: Icon(Icons.open_in_new_rounded, color: muted, size: 20),
              onTap: () => _openPrivacyPolicy(context),
            )),
      ]),
    ];

    final q = _query.trim().toLowerCase();
    bool matches(_Entry e) =>
        q.isEmpty || '${e.title} ${e.keywords}'.toLowerCase().contains(q);
    final visible = [
      for (final g in groups)
        if (g.entries.any(matches))
          _Group(g.label, g.entries.where(matches).toList()),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        // Keeps scrolling (and the filter below) smooth on long lists.
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text('Settings',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                  )),
          const SizedBox(height: 14),
          _SearchField(
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 18),
          if (q.isEmpty) ...[
            const _ProCard(),
            const SizedBox(height: 22),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: visible.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 44, color: muted),
                        const SizedBox(height: 10),
                        Text('No settings match "$_query"',
                            style: TextStyle(color: muted)),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final g in visible)
                        _SettingGroup(
                          label: g.label,
                          children: [for (final e in g.entries) e.builder()],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _backup(BuildContext context) async {
    try {
      await BackupService.export();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final current = ref.watch(themeModeProvider);
          return SafeArea(
            child: RadioGroup<ThemeMode>(
              groupValue: current,
              onChanged: (mode) {
                if (mode == null) return;
                ref.read(themeModeProvider.notifier).state = mode;
                AppSettings.setThemeMode(mode);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mode in const [
                    ThemeMode.light,
                    ThemeMode.dark,
                    ThemeMode.system,
                  ])
                    RadioListTile<ThemeMode>(
                      value: mode,
                      title: Text(AppSettings.themeModeLabel(mode)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final BackupData? data;
    try {
      data = await BackupService.pick();
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open file: $e')));
      return;
    }
    if (data == null || !context.mounted) return;

    final when = data.createdAt == null
        ? ''
        : ' from ${MaterialLocalizations.of(context).formatMediumDate(data.createdAt!)}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: Text(
          'This replaces all your current alarms with the '
          '${data!.alarms.length} alarm${data.alarms.length == 1 ? '' : 's'} '
          'in this backup$when, and restores its settings.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    await BackupService.restore(data);
    await MascotService.init();
    await AppSettings.load();
    ref.read(themeModeProvider.notifier).state = AppSettings.themeMode;
    ref.read(vibrationEnabledProvider.notifier).state =
        AppSettings.vibrationEnabled;
    ref.invalidate(alarmsMapProvider);
    _refreshAndRebuild();
    messenger.showSnackBar(const SnackBar(content: Text('Backup restored')));
  }

  Future<void> _restorePurchase(BuildContext context) async {
    // A second tap while the first restore is in flight used to report
    // "restored" and then "not found".
    if (_restoringPurchase) return;
    _restoringPurchase = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking your purchases…')),
    );
    final bool restored;
    try {
      restored = await PremiumService.restorePurchases();
    } finally {
      _restoringPurchase = false;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(restored
          ? 'Alarm+ Pro restored. Welcome back!'
          : 'No previous Pro purchase found on this account.'),
    ));
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(_privacyPolicyUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open privacy policy.')),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context, PackageInfo? info) {
    showAboutDialog(
      context: context,
      applicationName: 'Alarm+',
      applicationVersion: info != null
          ? 'v${info.version} (build ${info.buildNumber})'
          : '',
      applicationIcon: const AlarmLogo(size: 56),
      children: [
        const SizedBox(height: 8),
        const Text(
          'Smart alarm with wake-up challenges, sleep coaching, '
          'gamification and morning routines.',
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _openPrivacyPolicy(context);
          },
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }

  void _showChallengePicker(
    BuildContext context,
    DismissChallengeType current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => FutureBuilder<bool>(
        future: PremiumService.canUse(PremiumFeature.smartDismissModes),
        builder: (context, snapshot) {
          final unlocked = snapshot.data ?? PremiumService.isPro.value;
          // Never show a locked challenge as the selected one.
          final selected = effectiveChallenge(current, isPro: unlocked);
          return ListView(
            children: DismissChallengeType.values.map((type) {
              final needsPremium = challengeNeedsPro(type);
              return ListTile(
                title: Text(type.name.toUpperCase()),
                subtitle: needsPremium && !unlocked
                    ? const Text('Premium')
                    : null,
                trailing: selected == type ? const Icon(Icons.check) : null,
                onTap: () async {
                  if (needsPremium && !unlocked) {
                    await PremiumService.showLifetimePaywall(
                      context,
                      PremiumFeature.smartDismissModes,
                    );
                    if (context.mounted) Navigator.pop(context);
                    return;
                  }
                  await SmartAlarmService.setDismissChallenge(type);
                  if (context.mounted) Navigator.pop(context);
                  _refreshAndRebuild();
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Future<void> _showGuardianDialog(
      BuildContext context, String currentUrl) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _GuardianDialog(initialUrl: currentUrl),
    );
    if (saved == true) _refreshAndRebuild();
  }
}

/// Webhook editor. Only an https URL with a host is accepted, Test reports
/// whether the server really answered, and nothing is stored until Save
/// (Test used to save the URL even if the user then cancelled).
class _GuardianDialog extends StatefulWidget {
  const _GuardianDialog({required this.initialUrl});

  final String initialUrl;

  @override
  State<_GuardianDialog> createState() => _GuardianDialogState();
}

class _GuardianDialogState extends State<_GuardianDialog> {
  late final _controller = TextEditingController(text: widget.initialUrl);
  String? _error;
  String? _testResult;
  bool _testing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The trimmed URL, or null (with an error shown) when it isn't valid.
  /// An empty field is valid for Save only: it turns the alert off.
  String? _validUrl({required bool allowEmpty}) {
    final url = _controller.text.trim();
    if (url.isEmpty && allowEmpty) return url;
    if (!GuardianService.isValidWebhookUrl(url)) {
      setState(() => _error = 'Enter a full https:// URL');
      return null;
    }
    return url;
  }

  Future<void> _test() async {
    if (_testing) return;
    final url = _validUrl(allowEmpty: false);
    if (url == null) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final ok = await GuardianService.triggerAlert(-1, url: url, test: true);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = ok
          ? 'Test alert delivered.'
          : 'The webhook did not accept the test alert.';
    });
  }

  Future<void> _save() async {
    final url = _validUrl(allowEmpty: true);
    if (url == null) return;
    await GuardianService.setWebhookUrl(url);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AlertDialog(
      title: const Text('Guardian Alert Webhook'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'If your alarm rings for 10+ minutes without being dismissed, '
            'Alarm+ will POST a JSON alert to this URL.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Webhook URL',
              hintText: 'https://hooks.ifttt.com/…',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            keyboardType: TextInputType.url,
            maxLines: 2,
            onChanged: (_) {
              if (_error != null || _testResult != null) {
                setState(() {
                  _error = null;
                  _testResult = null;
                });
              }
            },
          ),
          if (_testing || _testResult != null) ...[
            const SizedBox(height: 12),
            Text(
              _testing ? 'Sending test alert…' : _testResult!,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _testing ? null : _test,
          child: const Text('Test'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// NONE and MATH are free; the other wake challenges are Pro.
@visibleForTesting
bool challengeNeedsPro(DismissChallengeType type) =>
    type != DismissChallengeType.none && type != DismissChallengeType.math;

/// The global challenge as it actually applies: a stored Pro challenge
/// (e.g. after a refund) falls back to MATH for a free user, matching what
/// the ring screen does, so Settings never shows a locked choice as active.
@visibleForTesting
DismissChallengeType effectiveChallenge(
  DismissChallengeType stored, {
  required bool isPro,
}) =>
    !isPro && challengeNeedsPro(stored) ? DismissChallengeType.math : stored;

/// Top-of-Settings upsell, or a "you're Pro" badge once unlocked.
class _ProCard extends StatefulWidget {
  const _ProCard();

  @override
  State<_ProCard> createState() => _ProCardState();
}

class _ProCardState extends State<_ProCard> {
  // The store's localized price, like the paywall shows (was a hard-coded
  // rupee price for everyone).
  late final Future<String> _price = PremiumService.displayPrice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const amber = Color(0xFFFBBF24);
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumService.isPro,
      builder: (context, isPro, _) => Material(
        color: isDark
            ? amber.withValues(alpha: 0.12)
            : const Color(0xFFFFFBEB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: isDark
                  ? amber.withValues(alpha: 0.35)
                  : const Color(0xFFFDE68A)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => isPro
              ? Navigator.of(context).pushNamed(WardrobeScreen.routeName)
              : PremiumService.showLifetimePaywall(
                  context, PremiumFeature.mascotOutfits),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBBF24),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Color(0xFF0F172A), size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPro ? 'Alarm+ Pro · Lifetime' : 'Upgrade to Alarm+ Pro',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<String>(
                        future: _price,
                        builder: (context, price) => Text(
                          isPro
                              ? 'Thanks for your support! All Pro features are unlocked.'
                              : 'Sleep Coach Pro, double streak freezes, always-on wake '
                                  'challenge. One payment'
                                  '${price.hasData ? ' of ${price.data}' : ''}.',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isPro ? Icons.verified_rounded : Icons.chevron_right_rounded,
                  color: isPro
                      ? (isDark ? amber : const Color(0xFFD97706))
                      : scheme.onSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Entry {
  const _Entry(this.title, this.keywords, this.builder);

  final String title;

  /// Extra words that find this setting in the search box.
  final String keywords;
  final Widget Function() builder;
}

class _Group {
  const _Group(this.label, this.entries);

  final String label;
  final List<_Entry> entries;
}

/// A titled card holding related rows, with hairlines between them.
class _SettingGroup extends StatelessWidget {
  const _SettingGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 66,
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search settings',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// A switch with a haptic tick and screen-reader state; same look as before.
class _AnimatedToggle extends StatelessWidget {
  const _AnimatedToggle({
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 30,
          decoration: BoxDecoration(
            color: value ? scheme.onSurface : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(15),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                // On the "on" track (onSurface) the thumb takes the surface
                // colour so it stays visible when the track inverts in dark.
                color: value ? scheme.surface : Colors.white,
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
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15.5,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}
