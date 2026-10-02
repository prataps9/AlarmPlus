import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

/// What, if anything, stops alarms from ringing. Pure so it can be tested.
/// Returns null when everything needed is granted.
String? reliabilityProblem(AlarmReliabilityStatus s) {
  if (!s.notificationsGranted && !s.exactAlarmGranted) {
    return 'Notifications and exact alarms are off, so alarms won\'t ring.';
  }
  if (!s.notificationsGranted) {
    return 'Notifications are off, so alarms won\'t show or ring.';
  }
  if (!s.exactAlarmGranted) {
    return 'Exact alarms are off, so alarms may ring late or not at all.';
  }
  return null;
}

/// Shown at the top of the Alarm tab only when an alarm can't ring
/// properly — the failure users otherwise only discover by oversleeping.
/// Re-checks whenever the app comes back to the foreground (e.g. after the
/// user flips the permission in system Settings).
class ReliabilityBanner extends StatefulWidget {
  const ReliabilityBanner({super.key});

  @override
  State<ReliabilityBanner> createState() => _ReliabilityBannerState();
}

class _ReliabilityBannerState extends State<ReliabilityBanner>
    with WidgetsBindingObserver {
  AlarmReliabilityStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(force: true);
  }

  Future<void> _check({bool force = false}) async {
    final s = await SmartAlarmService.getReliabilityStatus(force: force);
    if (mounted) setState(() => _status = s);
  }

  Future<void> _fix() async {
    final s = _status;
    if (s == null) return;
    await AlarmService.requestPermissions();
    final after = await SmartAlarmService.getReliabilityStatus(force: true);
    // Once denied, Android stops showing the prompt; send the user to the
    // app's settings page instead.
    if (reliabilityProblem(after) != null) await openAppSettings();
    await _check(force: true);
    // Exact-alarm access may have just come back: put every alarm on an
    // exact schedule again.
    if (reliabilityProblem(after) == null) await AlarmService.restoreEnabledAlarms();
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final problem = s == null ? null : reliabilityProblem(s);
    if (problem == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Material(
        color: const Color(0xFFFEF2F2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: const BorderSide(color: Color(0xFFFECACA)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.sm, Spacing.md),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Palette.red500),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(problem,
                    style: const TextStyle(
                        color: Color(0xFF991B1B), fontWeight: FontWeight.w600)),
              ),
              TextButton(onPressed: _fix, child: const Text('Fix')),
            ],
          ),
        ),
      ),
    );
  }
}
