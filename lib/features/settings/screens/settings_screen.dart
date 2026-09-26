import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
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
  late Future<int> _windDownFuture;
  late Future<AlarmStats> _statsFuture;
  late Future<PackageInfo> _packageInfoFuture;
  late Future<String> _guardianWebhookFuture;

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
    _windDownFuture = SmartAlarmService.getWindDownMinutes();
    _statsFuture = SmartAlarmService.getStats();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _guardianWebhookFuture = GuardianService.getWebhookUrl();
  }

  void _refreshAndRebuild() {
    setState(_refreshAsyncTiles);
  }

  @override
  Widget build(BuildContext context) {
    final vibrationEnabled = ref.watch(vibrationEnabledProvider);

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
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFAAAAAA), size: 20),
            onTap: () => Navigator.of(context)
                .pushNamed(SoundSettingsScreen.routeName),
          ),
          _SettingTile(
            title: 'Vibration',
            trailing: _AnimatedToggle(
              value: vibrationEnabled,
              onChanged: (v) =>
                  ref.read(vibrationEnabledProvider.notifier).state = v,
            ),
          ),
          FutureBuilder<DismissChallengeType>(
            future: _dismissChallengeFuture,
            builder: (context, snapshot) {
              final challenge =
                  snapshot.data ?? DismissChallengeType.none;
              return _SettingTile(
                title: 'Wake Challenge',
                subtitle: challenge.name.toUpperCase(),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFAAAAAA), size: 20),
                onTap: () => _showChallengePicker(context, challenge),
              );
            },
          ),
          FutureBuilder<int>(
            future: _windDownFuture,
            builder: (context, snapshot) {
              final minutes = snapshot.data ?? 30;
              return _SettingTile(
                title: 'Pre-Alarm Wind-Down',
                subtitle: '$minutes min before sleep',
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFAAAAAA), size: 20),
                onTap: () => _showWindDownPicker(context, minutes),
              );
            },
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
                  color: ok ? const Color(0xFF111111) : const Color(0xFF888888),
                  size: 20,
                ),
                onTap: () => _showReliabilityDialog(context, status),
              );
            },
          ),
          _SettingTile(
            title: 'Preview Alarm Screen',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFAAAAAA), size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(AlarmRingScreen.routeName),
          ),
          const SizedBox(height: 8),

          // ── SLEEP section ───────────────────────────────────────
          _SectionHeader(label: 'SLEEP'),
          _SettingTile(
            title: 'Sleep Insights',
            subtitle: 'Weekly score and trends',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFAAAAAA), size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(SleepInsightsScreen.routeName),
          ),
          _SettingTile(
            title: 'Wind Down / Bedtime',
            subtitle: 'Bedtime and wind-down reminders',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFAAAAAA), size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(BedtimeSetupScreen.routeName),
          ),
          _SettingTile(
            title: 'Sleep Diary',
            subtitle: 'Log sleep quality daily',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFAAAAAA), size: 20),
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
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFAAAAAA), size: 20),
                onTap: () => _showGuardianDialog(context, url),
              );
            },
          ),
          _SettingTile(
            title: 'Location Alarms',
            subtitle: 'Trigger on arrival',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFAAAAAA), size: 20),
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
                trailing: const Icon(Icons.insights_outlined,
                    color: Color(0xFFAAAAAA), size: 20),
              );
            },
          ),
          const SizedBox(height: 8),

          // ── APP section ────────────────────────────────────────
          _SectionHeader(label: 'APP'),
          ValueListenableBuilder<MascotOutfit>(
            valueListenable: MascotService.selectedOutfit,
            builder: (context, outfit, _) => _SettingTile(
              title: "Pip's Wardrobe",
              subtitle: outfit.label,
              trailing: const Icon(Icons.checkroom_rounded,
                  color: Color(0xFFAAAAAA), size: 20),
              onTap: () =>
                  Navigator.of(context).pushNamed(WardrobeScreen.routeName),
            ),
          ),
          _SettingTile(
            title: 'Back Up Alarms & Settings',
            subtitle: 'Save a file to Drive, email or anywhere',
            trailing: const Icon(Icons.cloud_upload_outlined,
                color: Color(0xFFAAAAAA), size: 20),
            onTap: () => _backup(context),
          ),
          _SettingTile(
            title: 'Restore From Backup',
            subtitle: 'Replace your alarms with a saved backup',
            trailing: const Icon(Icons.settings_backup_restore_rounded,
                color: Color(0xFFAAAAAA), size: 20),
            onTap: () => _restoreBackup(context),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: PremiumService.isPro,
            builder: (context, isPro, _) => isPro
                ? const SizedBox.shrink()
                : _SettingTile(
                    title: 'Restore Purchase',
                    subtitle: 'Already bought Pro? Get it back here',
                    trailing: const Icon(Icons.restore_rounded,
                        color: Color(0xFFAAAAAA), size: 20),
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
                trailing: const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFAAAAAA), size: 20),
                onTap: () => _showAboutDialog(context, info),
              );
            },
          ),
          _SettingTile(
            title: 'Privacy Policy',
            trailing: const Icon(Icons.open_in_new_rounded,
                color: Color(0xFFAAAAAA), size: 20),
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
    ref.invalidate(alarmsMapProvider);
    _refreshAndRebuild();
    messenger.showSnackBar(const SnackBar(content: Text('Backup restored')));
  }

  Future<void> _restorePurchase(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking your purchases…')),
    );
    final restored = await PremiumService.restorePurchases();
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

  void _showReliabilityDialog(
    BuildContext context,
    AlarmReliabilityStatus? status,
  ) {
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
          final unlocked = snapshot.data ?? false;
          return ListView(
            children: DismissChallengeType.values.map((type) {
              final needsPremium = type != DismissChallengeType.none;
              return ListTile(
                title: Text(type.name.toUpperCase()),
                subtitle: needsPremium && !unlocked
                    ? const Text('Premium')
                    : null,
                trailing: current == type ? const Icon(Icons.check) : null,
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

  void _showWindDownPicker(BuildContext context, int current) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final minutes in const [30, 45, 60])
            ListTile(
              title: Text('$minutes minutes'),
              trailing: current == minutes ? const Icon(Icons.check) : null,
              onTap: () async {
                await SmartAlarmService.setWindDownMinutes(minutes);
                if (context.mounted) Navigator.pop(context);
                _refreshAndRebuild();
              },
            ),
        ],
      ),
    );
  }

  void _showGuardianDialog(BuildContext context, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardian Alert Webhook'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If your alarm rings for 10+ minutes without being dismissed, '
              'Alarm+ will POST a JSON alert to this URL.',
              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Webhook URL',
                hintText: 'https://hooks.ifttt.com/…',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              await GuardianService.setWebhookUrl(url);
              await GuardianService.triggerAlert(-1);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Test alert sent to webhook.')),
                );
              }
            },
            child: const Text('Test'),
          ),
          TextButton(
            onPressed: () async {
              await GuardianService.setWebhookUrl(controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              _refreshAndRebuild();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Top-of-Settings upsell, or a "you're Pro" badge once unlocked.
class _ProCard extends StatelessWidget {
  const _ProCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumService.isPro,
      builder: (context, isPro, _) => Material(
        color: const Color(0xFFFFFBEB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFDE68A)),
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
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPro
                            ? 'Thanks for your support! All Pro features are unlocked.'
                            : 'Sleep Coach Pro, double streak freezes, always-on wake '
                                'challenge. One payment of ${PremiumService.fallbackPriceLabel}.',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isPro ? Icons.verified_rounded : Icons.chevron_right_rounded,
                  color: isPro ? const Color(0xFFD97706) : const Color(0xFF0F172A),
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          color: Color(0xFF888888),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF111111),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF888888),
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
