import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/core/services/app_settings.dart';
import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/screens/alarm_ring_screen.dart';
import 'package:alarm_plus/features/alarm/widgets/reliability_banner.dart';
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
  bool _restoringPurchase = false;

  static const _privacyPolicyUrl =
      'https://sites.google.com/view/alarmplus-privacy/home';

  @override
  void initState() {
    super.initState();
    _refreshAsyncTiles();
  }

  void _refreshAsyncTiles() {
    _reliabilityFuture = SmartAlarmService.getReliabilityStatus();
    _dismissChallengeFuture = SmartAlarmService.getDismissChallenge();
    _statsFuture = SmartAlarmService.getStats();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _guardianWebhookFuture = GuardianService.getWebhookUrl();
    _upcomingNoticeFuture = AlarmService.upcomingNoticeEnabled();
  }

  void _refreshAndRebuild() {
    setState(_refreshAsyncTiles);
  }

  @override
  Widget build(BuildContext context) {
    final vibrationEnabled = ref.watch(vibrationEnabledProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Text('Settings',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 24,
              )),
          const SizedBox(height: 20),
          const _ProCard(),
          const SizedBox(height: 20),

          // ── ALARM section ──────────────────────────────────────
          _SectionHeader(label: 'ALARM'),
          _SettingTile(
            title: 'Sound',
            subtitle: 'Wake tone and ring volume',
            trailing: Icon(Icons.chevron_right_rounded,
                color: muted, size: 20),
            onTap: () => Navigator.of(context)
                .pushNamed(SoundSettingsScreen.routeName),
          ),
          _SettingTile(
            title: 'Vibration',
            trailing: _AnimatedToggle(
              value: vibrationEnabled,
              onChanged: (v) =>
                  setVibrationEnabled(ref, v),
            ),
          ),
          FutureBuilder<bool>(
            future: _upcomingNoticeFuture,
            builder: (context, snapshot) {
              final on = snapshot.data ?? true;
              return _SettingTile(
                title: 'Upcoming Alarm Notice',
                subtitle: '2 hours before, with "Dismiss now"',
                trailing: _AnimatedToggle(
                  value: on,
                  onChanged: (v) async {
                    await AlarmService.setUpcomingNoticeEnabled(v);
                    _refreshAndRebuild();
                  },
                ),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: PremiumService.isPro,
            builder: (context, isPro, _) =>
                FutureBuilder<DismissChallengeType>(
                  future: _dismissChallengeFuture,
                  builder: (context, snapshot) {
                    final challenge = effectiveChallenge(
                      snapshot.data ?? DismissChallengeType.math,
                      isPro: isPro,
                    );
                    return _SettingTile(
                      title: 'Wake Challenge',
                      subtitle: challenge.name.toUpperCase(),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: muted, size: 20),
                      onTap: () => _showChallengePicker(context, challenge),
                    );
                  },
                ),
          ),
          FutureBuilder<AlarmReliabilityStatus>(
            future: _reliabilityFuture,
            builder: (context, snapshot) {
              final status = snapshot.data;
              final ok = status?.notificationsGranted == true &&
                  status?.exactAlarmGranted == true;
              return _SettingTile(
                title: 'Alarm Reliability',
                subtitle: status == null
                    ? 'Checking…'
                    : ok
                        ? 'All permissions granted'
                        : 'Action needed',
                trailing: Icon(
                  ok ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                  color: ok ? scheme.onSurface : muted,
                  size: 20,
                ),
                onTap: () => _showReliabilityDialog(context, status),
              );
            },
          ),
          _SettingTile(
            title: 'Preview Alarm Screen',
            trailing: Icon(Icons.chevron_right_rounded,
                color: muted, size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(AlarmRingScreen.routeName),
          ),
          const SizedBox(height: 8),

          // ── SLEEP section ───────────────────────────────────────
          _SectionHeader(label: 'SLEEP'),
          _SettingTile(
            title: 'Sleep Insights',
            subtitle: 'Weekly score and trends',
            trailing: Icon(Icons.chevron_right_rounded,
                color: muted, size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(SleepInsightsScreen.routeName),
          ),
          // The wind-down reminder lives with the bedtime schedule. The old
          // "Pre-Alarm Wind-Down" minutes picker here no longer drove any
          // notification, so it was removed rather than left doing nothing.
          _SettingTile(
            title: 'Wind Down / Bedtime',
            subtitle: 'Bedtime reminder & wind-down',
            trailing: Icon(Icons.chevron_right_rounded,
                color: muted, size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(BedtimeSetupScreen.routeName),
          ),
          _SettingTile(
            title: 'Sleep Diary',
            subtitle: 'Log sleep quality daily',
            trailing: Icon(Icons.chevron_right_rounded,
                color: muted, size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(SleepDiaryScreen.routeName),
          ),
          const SizedBox(height: 8),

          // ── SAFETY & AUTOMATION section ─────────────────────────
          _SectionHeader(label: 'SAFETY & AUTOMATION'),
          FutureBuilder<String>(
            future: _guardianWebhookFuture,
            builder: (context, snapshot) {
              final url = snapshot.data ?? '';
              return _SettingTile(
                title: 'Guardian Alert',
                subtitle: url.isEmpty ? 'Not configured' : 'Webhook active',
                trailing: Icon(Icons.chevron_right_rounded,
                    color: muted, size: 20),
                onTap: () => _showGuardianDialog(context, url),
              );
            },
          ),
          _SettingTile(
            title: 'Location Alarms',
            subtitle: 'Trigger on arrival',
            trailing: Icon(Icons.chevron_right_rounded,
                color: muted, size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(LocationAlarmScreen.routeName),
          ),
          FutureBuilder<AlarmStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              final stats = snapshot.data;
              return _SettingTile(
                title: 'Streaks & Metrics',
                subtitle: stats == null
                    ? '…'
                    : 'Streak ${stats.currentStreak} · best ${stats.bestStreak}',
                trailing: Icon(Icons.insights_outlined,
                    color: muted, size: 20),
              );
            },
          ),
          const SizedBox(height: 8),

          // ── APP section ────────────────────────────────────────
          _SectionHeader(label: 'APP'),
          _SettingTile(
            title: 'Theme',
            subtitle: AppSettings.themeModeLabel(ref.watch(themeModeProvider)),
            trailing: Icon(Icons.contrast_rounded,
                color: muted, size: 20),
            onTap: () => _showThemePicker(context),
          ),
          ValueListenableBuilder<MascotOutfit>(
            valueListenable: MascotService.selectedOutfit,
            builder: (context, outfit, _) => _SettingTile(
              title: "Pip's Wardrobe",
              subtitle: outfit.label,
              trailing: Icon(Icons.checkroom_rounded,
                  color: muted, size: 20),
              onTap: () =>
                  Navigator.of(context).pushNamed(WardrobeScreen.routeName),
            ),
          ),
          _SettingTile(
            title: 'Back Up Alarms & Settings',
            subtitle: 'Save a file to Drive, email or anywhere',
            trailing: Icon(Icons.cloud_upload_outlined,
                color: muted, size: 20),
            onTap: () => _backup(context),
          ),
          _SettingTile(
            title: 'Restore From Backup',
            subtitle: 'Replace your alarms with a saved backup',
            trailing: Icon(Icons.settings_backup_restore_rounded,
                color: muted, size: 20),
            onTap: () => _restoreBackup(context),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: PremiumService.isPro,
            builder: (context, isPro, _) => isPro
                ? const SizedBox.shrink()
                : _SettingTile(
                    title: 'Restore Purchase',
                    subtitle: 'Already bought Pro? Get it back here',
                    trailing: Icon(Icons.restore_rounded,
                        color: muted, size: 20),
                    onTap: () => _restorePurchase(context),
                  ),
          ),
          FutureBuilder<PackageInfo>(
            future: _packageInfoFuture,
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? ''
                  : 'v${info.version} (${info.buildNumber})';
              return _SettingTile(
                title: 'About Alarm+',
                subtitle: version,
                trailing: Icon(Icons.info_outline_rounded,
                    color: muted, size: 20),
                onTap: () => _showAboutDialog(context, info),
              );
            },
          ),
          _SettingTile(
            title: 'Privacy Policy',
            trailing: Icon(Icons.open_in_new_rounded,
                color: muted, size: 20),
            onTap: () => _openPrivacyPolicy(context),
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

  /// Same fix as the Home reliability banner: ask again, fall back to the
  /// app's system settings once Android stops showing the prompt, and put
  /// alarms back on an exact schedule when access returns.
  Future<void> _fixReliability() async {
    await AlarmService.requestPermissions();
    final after = await SmartAlarmService.getReliabilityStatus(force: true);
    if (reliabilityProblem(after) != null) {
      await openAppSettings();
    } else {
      await AlarmService.restoreEnabledAlarms();
    }
    if (mounted) _refreshAndRebuild();
  }

  void _showReliabilityDialog(
    BuildContext context,
    AlarmReliabilityStatus? status,
  ) {
    final needsFix = status != null && reliabilityProblem(status) != null;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alarm Reliability'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications: ${status?.notificationsGranted == true ? 'Granted' : 'Missing'}',
            ),
            Text(
              'Exact Alarm: ${status?.exactAlarmGranted == true ? 'Granted' : 'Missing'}',
            ),
            Text(
              'Battery Optimization: ${status?.batteryOptimizationIgnored == true ? 'Ignored' : 'Active'}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (needsFix)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _fixReliability();
              },
              child: const Text('Fix'),
            ),
        ],
      ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AnimatedToggle extends StatelessWidget {
  const _AnimatedToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: value ? scheme.onSurface : scheme.outlineVariant,
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
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: subtitle != null ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
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
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}
