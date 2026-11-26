import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GuardianService {
  static const _webhookKey = 'guardian_webhook_url';

  static Future<String> getWebhookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_webhookKey) ?? '';
  }

  static Future<void> setWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webhookKey, url);
  }

  /// A webhook must be an https URL with a host; anything else would either
  /// fail silently or send the alert in clear text.
  static bool isValidWebhookUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  /// Posts the alert to [url] (default: the saved webhook). Returns true
  /// only when the server answered 2xx, so the Settings test reports what
  /// really happened instead of always saying "sent".
  static Future<bool> triggerAlert(
    int alarmId, {
    String? url,
    bool test = false,
  }) async {
    final target = (url ?? await getWebhookUrl()).trim();
    if (target.isEmpty) return false;

    if (!isValidWebhookUrl(target)) {
      debugPrint('GuardianService: invalid webhook URL');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse(target),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': test
                  ? 'Alarm+ Guardian Alert test. No action needed.'
                  : 'Alarm+ has been ringing for 10+ minutes without a response!',
              'alarmId': alarmId,
              'timestamp': DateTime.now().toIso8601String(),
              if (test) 'test': true,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      debugPrint('GuardianService: alert for alarm $alarmId -> '
          '${response.statusCode}');
      return ok;
    } catch (e) {
      debugPrint('GuardianService: failed to send alert: $e');
      return false;
    }
  }
}
