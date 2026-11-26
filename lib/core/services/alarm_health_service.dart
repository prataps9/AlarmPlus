import 'package:flutter/foundation.dart';

import 'package:alarm_plus/core/services/native_controls.dart';

/// Where the Alarm Health Check's test alarm stands.
enum HealthTestState {
  /// Never run (or cleared).
  none,

  /// Scheduled and not yet due (or only just due).
  waiting,

  /// Went off within a minute of when it was due.
  passed,

  /// Went off, but more than a minute late: the phone deferred it.
  late,

  /// Was due minutes ago and never went off: the phone kept Alarm+ from
  /// starting in the background. Real alarms would be silent too.
  failed,
}

class HealthTestOutcome {
  const HealthTestOutcome(this.state, {this.due, this.lateBy});

  final HealthTestState state;
  final DateTime? due;
  final Duration? lateBy;
}

/// The Alarm Health Check (see ReliabilityTest.kt). Permission checks can't
/// see a phone maker's background limits; a real test alarm can.
class AlarmHealthService {
  AlarmHealthService._();

  static const testDelay = Duration(seconds: 60);

  /// How long past due a test may stay silent before it counts as failed.
  static const failAfter = Duration(minutes: 3);

  static const lateAfter = Duration(seconds: 60);

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Pure: reads the native {due, fired} record at [now].
  static HealthTestOutcome evaluate({int? dueMs, int? firedMs, required DateTime now}) {
    if (dueMs == null) return const HealthTestOutcome(HealthTestState.none);
    final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
    if (firedMs != null) {
      var lateBy = DateTime.fromMillisecondsSinceEpoch(firedMs).difference(due);
      if (lateBy.isNegative) lateBy = Duration.zero;
      return HealthTestOutcome(
        lateBy > lateAfter ? HealthTestState.late : HealthTestState.passed,
        due: due,
        lateBy: lateBy,
      );
    }
    return HealthTestOutcome(
      now.isAfter(due.add(failAfter)) ? HealthTestState.failed : HealthTestState.waiting,
      due: due,
    );
  }

  static Future<HealthTestOutcome> testOutcome() async {
    if (!_isAndroid) return const HealthTestOutcome(HealthTestState.none);
    try {
      final raw = await NativeControls.channel
          .invokeMapMethod<String, Object?>('healthTestResult');
      return evaluate(
        dueMs: (raw?['due'] as num?)?.toInt(),
        firedMs: (raw?['fired'] as num?)?.toInt(),
        now: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Health test result unavailable: $e');
      return const HealthTestOutcome(HealthTestState.none);
    }
  }

  /// Schedules the test alarm. Returns when it is due, or null when exact
  /// alarms are off (the checklist shows that as the thing to fix).
  static Future<DateTime?> startTest() async {
    if (!_isAndroid) return null;
    try {
      final ms = await NativeControls.channel.invokeMethod<int>(
        'startHealthTest',
        {'delaySeconds': testDelay.inSeconds},
      );
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (e) {
      debugPrint('Health test could not start: $e');
      return null;
    }
  }

  static Future<void> cancelTest() async {
    if (!_isAndroid) return;
    try {
      await NativeControls.channel.invokeMethod<void>('cancelHealthTest');
    } catch (e) {
      debugPrint('Health test cancel failed: $e');
    }
  }

  /// "xiaomi", "oppo", "samsung"… (sub-brands folded in), or null.
  static Future<String?> phoneMaker() async {
    if (!_isAndroid) return null;
    try {
      return await NativeControls.channel.invokeMethod<String>('phoneMaker');
    } catch (e) {
      debugPrint('Phone maker unavailable: $e');
      return null;
    }
  }

  /// Opens the phone maker's background-start screen (or the app's system
  /// settings when the phone has none).
  static Future<void> openAutostartSettings() async {
    if (!_isAndroid) return;
    try {
      await NativeControls.channel.invokeMethod<String>('openAutostartSettings');
    } catch (e) {
      debugPrint('Autostart settings unavailable: $e');
    }
  }

  /// What a phone maker's own background limit is called and where to turn
  /// it off, for the makers known to stop alarm apps (dontkillmyapp.com).
  /// Null for phones that don't add one.
  static ({String brand, String steps})? makerAdvice(String? maker) =>
      switch (maker) {
        'xiaomi' => (
            brand: 'Xiaomi, Redmi and POCO',
            steps: 'Turn on Autostart for Alarm+, and set its Battery saver '
                'to "No restrictions".',
          ),
        'oppo' => (
            brand: 'Oppo and Realme',
            steps: 'Allow Alarm+ to auto-launch and to run in the background '
                '(App info → Battery usage).',
          ),
        'vivo' => (
            brand: 'Vivo and iQOO',
            steps: 'Allow Alarm+ to start in the background and turn on '
                '"Allow high background power consumption".',
          ),
        'huawei' => (
            brand: 'Huawei and Honor',
            steps: 'In App launch, set Alarm+ to "Manage manually" and allow '
                'auto-launch and running in the background.',
          ),
        'oneplus' => (
            brand: 'OnePlus',
            steps: 'Turn off Battery optimisation for Alarm+ and allow it to '
                'run in the background.',
          ),
        'samsung' => (
            brand: 'Samsung',
            steps: 'Add Alarm+ to "Never sleeping apps" (Battery → Background '
                'usage limits).',
          ),
        'asus' => (
            brand: 'Asus',
            steps: 'Allow Alarm+ to auto-start in Mobile Manager.',
          ),
        _ => null,
      };
}
