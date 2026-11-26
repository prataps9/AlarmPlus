import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/native_controls.dart';

/// Reads a short spoken good-morning once an alarm is dismissed: the time,
/// the day, how fast the user got up and their streak. Spoken by Android's
/// own text-to-speech engine (MainActivity "speak"), so no extra plugin.
///
/// Off by default: a voice at 6 am can wake a partner.
class MorningBriefingService {
  MorningBriefingService._();

  static const enabledKey = 'alarm.morning_briefing';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, on);
  }

  /// What is read out. Kept short: it plays over the celebration sheet.
  @visibleForTesting
  static String compose({
    required DateTime now,
    required int dismissSeconds,
    required int streakDays,
    required int wakeScore,
  }) {
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final parts = <String>[
      '$greeting. It is ${DateFormat.jm().format(now)}, '
          '${DateFormat('EEEE d MMMM').format(now)}.',
      if (dismissSeconds > 0)
        'You were up in ${_duration(dismissSeconds)}.',
      if (streakDays >= 2) 'That is a $streakDays day streak.',
      'Your wake score is $wakeScore.',
      "Let's make it a good day.",
    ];
    return parts.join(' ');
  }

  static String _duration(int seconds) {
    if (seconds < 60) return '$seconds second${seconds == 1 ? '' : 's'}';
    final minutes = (seconds / 60).round();
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }

  /// Speaks the briefing if it is switched on. Never throws: a phone
  /// without a speech engine just stays quiet.
  static Future<void> playIfEnabled({
    required int dismissSeconds,
    required int streakDays,
    required int wakeScore,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (!await isEnabled()) return;
      await NativeControls.channel.invokeMethod<void>('speak', {
        'text': compose(
          now: DateTime.now(),
          dismissSeconds: dismissSeconds,
          streakDays: streakDays,
          wakeScore: wakeScore,
        ),
      });
    } catch (e) {
      debugPrint('Morning briefing failed: $e');
    }
  }
}
