import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:alarm_plus/core/services/alarm_health_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/alarm/widgets/reliability_banner.dart';

/// Alarm Health Check: everything that decides whether an alarm actually
/// rings, in one place, plus a real test alarm with the app closed.
class AlarmHealthScreen extends StatefulWidget {
  const AlarmHealthScreen({super.key});

  static const routeName = '/alarm-health';

  @override
  State<AlarmHealthScreen> createState() => _AlarmHealthScreenState();
}

class _AlarmHealthScreenState extends State<AlarmHealthScreen>
    with WidgetsBindingObserver {
  AlarmReliabilityStatus? _status;
  HealthTestOutcome _test = const HealthTestOutcome(HealthTestState.none);
  String? _maker;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AlarmHealthService.phoneMaker().then((m) {
      if (mounted) setState(() => _maker = m);
    }));
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  // Back from system settings, or from the lock screen after the test.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final status = await SmartAlarmService.getReliabilityStatus(force: true);
    final test = await AlarmHealthService.testOutcome();
    if (!mounted) return;
    setState(() {
      _status = status;
      _test = test;
    });
    // While waiting, re-check every few seconds so the result shows up
    // without leaving the screen.
    _tick?.cancel();
    if (test.state == HealthTestState.waiting) {
      _tick = Timer(const Duration(seconds: 5), () => unawaited(_refresh()));
    }
  }

  Future<void> _fixPermissions() async {
    await AlarmService.requestPermissions();
    final after = await SmartAlarmService.getReliabilityStatus(force: true);
    // Once denied, Android stops prompting; the app's settings page is the
    // only way back.
    if (reliabilityProblem(after) != null) await openAppSettings();
    if (reliabilityProblem(after) == null) await AlarmService.restoreEnabledAlarms();
    await _refresh();
  }

  Future<void> _fixBattery() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _refresh();
  }

  Future<void> _startTest() async {
    final due = await AlarmHealthService.startTest();
    if (!mounted) return;
    if (due == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Turn on exact alarms first, then run the test.')));
      return;
    }
    await _refresh();
  }

  int get _problems {
    final s = _status;
    var n = 0;
    if (s != null) {
      if (!s.notificationsGranted) n++;
      if (!s.exactAlarmGranted) n++;
      if (!s.batteryOptimizationIgnored) n++;
    }
    if (_test.state == HealthTestState.failed ||
        _test.state == HealthTestState.late) {
      n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _status;
    final advice = AlarmHealthService.makerAdvice(_maker);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'ALARM HEALTH',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: scheme.onSurfaceVariant),
        ),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _summary(scheme),
                const SizedBox(height: 20),
                _sectionLabel(scheme, 'PERMISSIONS'),
                _CheckRow(
                  ok: s.notificationsGranted,
                  title: 'Notifications',
                  detail: 'Needed to show and ring alarms.',
                  onFix: _fixPermissions,
                ),
                _CheckRow(
                  ok: s.exactAlarmGranted,
                  title: 'Exact alarms',
                  detail: 'Without it Android may ring alarms late.',
                  onFix: _fixPermissions,
                ),
                _CheckRow(
                  ok: s.batteryOptimizationIgnored,
                  title: 'Battery optimisation off',
                  detail: 'Stops Android putting Alarm+ to sleep overnight.',
                  onFix: _fixBattery,
                ),
                if (advice != null) ...[
                  const SizedBox(height: 20),
                  _sectionLabel(scheme, 'YOUR PHONE'),
                  _card(
                    scheme,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${advice.brand} phones can stop alarm apps',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface)),
                        const SizedBox(height: 6),
                        Text(advice.steps,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: AlarmHealthService.openAutostartSettings,
                            child: const Text('Open settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _sectionLabel(scheme, 'TEST WITH THE APP CLOSED'),
                _testCard(scheme),
              ],
            ),
    );
  }

  Widget _summary(ColorScheme scheme) {
    final tested = _test.state == HealthTestState.passed;
    final n = _problems;
    final (icon, color, title, body) = n > 0
        ? (
            Icons.warning_amber_rounded,
            const Color(0xFFEF4444),
            n == 1 ? '1 thing to fix' : '$n things to fix',
            'Fix these so your alarms ring.',
          )
        : tested
            ? (
                Icons.verified_rounded,
                const Color(0xFF22C55E),
                'Alarms will ring',
                'Everything is set up, and a test alarm rang with the app closed.',
              )
            : (
                Icons.help_outline_rounded,
                const Color(0xFFF59E0B),
                'Run the test to be sure',
                'Settings look right. Some phones still block alarms; a '
                    '1-minute test shows whether yours does.',
              );
    return _card(
      scheme,
      Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _testCard(ColorScheme scheme) {
    final t = _test;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final Widget body;
    var button = 'Run 1-minute test';
    switch (t.state) {
      case HealthTestState.none:
        body = Text(
            'Sets a test alarm for one minute from now. Then swipe Alarm+ '
            'away from your recent apps and lock the phone. A notification '
            'tells you it worked.',
            style: muted);
      case HealthTestState.waiting:
        final left = t.due!.difference(DateTime.now());
        body = Text(
            left.isNegative
                ? 'Due now — waiting for it to go off…'
                : 'Goes off in ${left.inSeconds + 1} s. Now swipe Alarm+ '
                    'away from recent apps and lock your phone.',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: scheme.onSurface));
        button = 'Start again';
      case HealthTestState.passed:
        body = Text(
            '✓ It went off with the app closed'
            '${t.lateBy!.inSeconds > 5 ? ' (${t.lateBy!.inSeconds} s late)' : ''}. '
            'Your alarms will ring.',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF16A34A)));
        button = 'Test again';
      case HealthTestState.late:
        body = Text(
            'It went off ${t.lateBy!.inMinutes} min late: your phone held it '
            'back to save battery. Turn battery optimisation off'
            '${_maker != null && AlarmHealthService.makerAdvice(_maker) != null ? ' and follow the steps above' : ''}, '
            'then test again.',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFFD97706)));
        button = 'Test again';
      case HealthTestState.failed:
        body = Text(
            "✗ It didn't go off. Your phone stopped Alarm+ from starting "
            'while closed, so real alarms would be silent too. Fix the items '
            'above, then test again.',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFFDC2626)));
        button = 'Test again';
    }
    return _card(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _startTest, child: Text(button)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ColorScheme scheme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: scheme.onSurfaceVariant)),
      );

  Widget _card(ColorScheme scheme, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: child,
      );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.ok,
    required this.title,
    required this.detail,
    required this.onFix,
  });

  final bool ok;
  final String title;
  final String detail;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                color: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: scheme.onSurface)),
                  Text(detail,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (!ok) TextButton(onPressed: onFix, child: const Text('Fix')),
          ],
        ),
      ),
    );
  }
}
