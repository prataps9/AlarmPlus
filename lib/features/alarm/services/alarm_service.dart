import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import 'package:shared_preferences/shared_preferences.dart' as sp;

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/shared/models/vibration_pattern_type.dart';
import 'package:alarm_plus/shared/models/challenge_type.dart';
import 'package:alarm_plus/core/services/app_settings.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/core/services/storage_service.dart';
import 'package:alarm_plus/core/services/streak_reminder_service.dart';
import 'package:alarm_plus/core/services/widget_sync_service.dart';

const _nativeRingtoneKeyPrefix = 'alarm.native_ringtone';

/// Android's "default alarm tone" setting (Settings.System.DEFAULT_ALARM_ALERT_URI).
const _androidDefaultAlarmUri = 'content://settings/system/alarm_alert';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final Uuid _uuid = const Uuid();
  static final StreamController<int> _ringIntents =
      StreamController<int>.broadcast();

  static Stream<int> get ringIntents => _ringIntents.stream;

  /// Fires when alarms change outside the UI (a notification action, a
  /// restored backup), so the alarm list can reload from storage.
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();
  static Stream<void> get changes => _changes.stream;
  static void notifyChanged() => _changes.add(null);

  /// Bottom-nav tab requests from notifications (e.g. "Time's up" → Timer).
  static final StreamController<String> _openRequests =
      StreamController<String>.broadcast();
  static Stream<String> get openRequests => _openRequests.stream;

  static const _upcomingNoticeKey = 'alarm.upcoming_notice';

  /// How long before an alarm its "Upcoming alarm" notice appears.
  static const upcomingNoticeLead = Duration(hours: 2);

  static Future<bool> upcomingNoticeEnabled() async {
    final prefs = await sp.SharedPreferences.getInstance();
    return prefs.getBool(_upcomingNoticeKey) ?? true;
  }

  static Future<void> setUpcomingNoticeEnabled(bool on) async {
    final prefs = await sp.SharedPreferences.getInstance();
    await prefs.setBool(_upcomingNoticeKey, on);
    await restoreEnabledAlarms();
  }

  // Registered by AlarmRingFlow to handle wake-check notification taps
  static void Function(int alarmId)? _onWakeCheckTapped;
  static void registerWakeCheckHandler(void Function(int alarmId) handler) {
    _onWakeCheckTapped = handler;
  }

  static bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _supportsNativeAlarmOps => _isMobilePlatform;

  /// A notification tap that launched the app from a terminated state.
  /// Held until [AlarmRingFlow] has its listeners bound, because a response
  /// emitted before that would be dropped.
  static NotificationResponse? _launchResponse;

  static NotificationResponse? takeLaunchResponse() {
    final r = _launchResponse;
    _launchResponse = null;
    return r;
  }

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    await _setLocalTimezone();
    if (_supportsNativeAlarmOps) {
      await Alarm.init();
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await AndroidAlarmManager.initialize();
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    ).catchError((e) {
      debugPrint('Error initializing notifications: $e');
      return false;
    });
    try {
      final launch = await _notifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _launchResponse = launch!.notificationResponse;
      }
    } catch (e) {
      debugPrint('Notification launch details unavailable: $e');
    }
    // Permissions are requested from UI (onboarding's permissions page, or
    // the splash for returning users), not here: this runs before runApp,
    // so the prompts appeared over a blank screen with no explanation.
  }

  /// Without this `tz.local` is UTC, so notifications that repeat by wall
  /// clock (`matchDateTimeComponents`) fire at UTC times.
  static String? _zoneName;

  static Future<void> _setLocalTimezone() async {
    if (kIsWeb) return;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      _zoneName = info.identifier;
    } catch (e) {
      debugPrint('Could not resolve local timezone, staying on UTC: $e');
    }
  }

  /// Alarms are scheduled as absolute instants, so after flying from New
  /// York to London a 07:00 alarm would ring at 12:00. Called whenever the
  /// app comes to the foreground: if the phone's zone changed, every alarm
  /// is rescheduled for the new local time. Returns true when it did.
  static Future<bool> rescheduleIfTimezoneChanged() async {
    if (kIsWeb || _zoneName == null) return false;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      if (info.identifier == _zoneName) return false;
      debugPrint('Timezone changed $_zoneName -> ${info.identifier}; rescheduling');
      await _setLocalTimezone();
      await restoreEnabledAlarms();
      return true;
    } catch (e) {
      debugPrint('Timezone check failed: $e');
      return false;
    }
  }

  /// Routes a notification tap or action. Also used to replay the tap that
  /// launched the app (see [takeLaunchResponse]).
  static void handleNotificationResponse(NotificationResponse response) =>
      _onNotificationResponse(response);

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload?.trim() ?? '';

    if (payload.startsWith('upcoming:')) {
      final alarmId = int.tryParse(payload.substring('upcoming:'.length));
      if (alarmId != null && response.actionId == 'dismiss_now') {
        unawaited(dismissUpcoming(alarmId));
      }
      return;
    }

    if (payload == 'timer') {
      _openRequests.add('timer');
      return;
    }

    // Wake-up check notification: user confirmed they're awake — cancel re-ring
    if (payload.startsWith('wakecheck:')) {
      final idStr = payload.substring('wakecheck:'.length);
      final alarmId = int.tryParse(idStr);
      if (alarmId != null) {
        _onWakeCheckTapped?.call(alarmId);
      }
      return;
    }

    final alarmId = int.tryParse(payload);
    if (alarmId == null) return;
    _ringIntents.add(alarmId);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    _onNotificationResponse(response);
  }

  static Future<void> requestPermissions() async {
    if (!_isMobilePlatform) return;

    try {
      await Permission.notification.request();

      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.scheduleExactAlarm.request();
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  static Future<void> saveAlarm(AlarmModel alarm) async {
    await StorageService.saveAlarm(alarm);
  }

  /// The alarm plugin stops any other alarm due in the same second
  /// (`Alarm.set`), and every alarm here is due at :00, so two alarms at
  /// 07:00 (or an alarm and its fresh duplicate) silently unscheduled each
  /// other. Each one is nudged a second later until its second is free.
  static Future<DateTime> _uniqueRingTime(int alarmId, DateTime target) async {
    try {
      final taken = {
        for (final a in await Alarm.getAlarms())
          if (a.id != alarmId) a.dateTime.millisecondsSinceEpoch ~/ 1000,
      };
      return uniqueSecond(target, taken);
    } catch (e) {
      debugPrint('Could not read scheduled alarms: $e');
      return target;
    }
  }

  @visibleForTesting
  static DateTime uniqueSecond(DateTime target, Set<int> takenEpochSeconds) {
    var when = target;
    while (takenEpochSeconds.contains(when.millisecondsSinceEpoch ~/ 1000)) {
      when = when.add(const Duration(seconds: 1));
    }
    return when;
  }

  // A snooze or wake-check re-ring is scheduled for an exact instant that
  // isn't the alarm's own time. It is remembered here so that restoring
  // alarms (every app start, settings changes, a timezone change) keeps it
  // instead of moving the alarm to its next normal occurrence.
  static String _overrideKey(int alarmId) => 'alarm.ring_override.$alarmId';

  static Future<DateTime?> _pendingOverride(int alarmId) async {
    final prefs = await sp.SharedPreferences.getInstance();
    final ms = prefs.getInt(_overrideKey(alarmId));
    if (ms == null) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(ms);
    return at.isAfter(DateTime.now()) ? at : null;
  }

  /// Schedules [alarm] at its next occurrence — or exactly at [at] when
  /// given (snooze, wake-up-check re-ring). Pass [at] rather than rewriting
  /// `alarm.time`: a [TimeOfDay] drops the seconds, so "now + 5 s" rounds
  /// into the past and `nextDateTimeFrom` pushes it to tomorrow.
  static Future<void> scheduleAlarm(
    AlarmModel alarm, {
    bool persist = true,
    DateTime? at,
  }) async {
    await _cancelScheduledArtifacts(alarm.id);

    // A dated one-off whose day has gone (phone was off, restored from a
    // backup): the plugin would ring a past time at once, so switch it off.
    if (at == null && alarm.isExpiredAt(DateTime.now())) {
      await saveAlarm(alarm.copyWith(isEnabled: false));
      notifyChanged();
      unawaited(WidgetSyncService.refresh());
      unawaited(StreakReminderService.refresh());
      return;
    }

    if (!_supportsNativeAlarmOps) {
      if (persist) {
        await saveAlarm(alarm.copyWith(isEnabled: true));
      }
      unawaited(WidgetSyncService.refresh());
      unawaited(StreakReminderService.refresh());
      return;
    }

    final targetTime = at ?? alarm.nextDateTimeFrom(DateTime.now());
    final alarmId = alarmIntId(alarm.id);
    final prefs = await sp.SharedPreferences.getInstance();
    if (at != null && !alarm.isSystem) {
      await prefs.setInt(_overrideKey(alarmId), at.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_overrideKey(alarmId));
    }
    var selectedSound = SmartAlarmService.rotateSoundForDate(
      targetTime,
      alarm.sound,
    );
    // "default" used to be sent to the alarm plugin as '', which it resolves
    // to a directory path that fails to load, so the alarm rang silently.
    // On Android, route it through the native ringtone path below using
    // the system's default-alarm URI instead.
    if ((selectedSound == 'default' || selectedSound.isEmpty) &&
        defaultTargetPlatform == TargetPlatform.android) {
      selectedSound = _androidDefaultAlarmUri;
    }

    // Determine audio path for the alarm package.
    // content:// URIs can't be loaded as Flutter assets — we store them in prefs
    // and let AlarmForegroundService play them via RingtoneManager instead.
    final String audioPath;
    if (selectedSound.startsWith('content://')) {
      final prefs = await sp.SharedPreferences.getInstance();
      await prefs.setString('$_nativeRingtoneKeyPrefix.$alarmId', selectedSound);
      audioPath = 'assets/sounds/silent.wav';
    } else if (selectedSound == 'default' || selectedSound.isEmpty) {
      audioPath = '';
    } else {
      audioPath = selectedSound;
    }

    final settings = AlarmSettings(
      id: alarmId,
      dateTime: await _uniqueRingTime(alarmId, targetTime),
      assetAudioPath: audioPath,
      volumeSettings: VolumeSettings.fade(fadeDuration: Duration(seconds: 8)),
      notificationSettings: NotificationSettings(
        title: alarm.label.isEmpty ? 'Alarm+' : alarm.label,
        body: alarm.tag,
      ),
      loopAudio: true,
      // The alarm's own pattern and the global switch both have to allow
      // it; this used to be always true, so "Off" still vibrated.
      vibrate: alarm.vibrationPattern != VibrationPatternType.off &&
          await AppSettings.readVibrationEnabled(),
      warningNotificationOnKill:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      androidFullScreenIntent: true,
      // Hardcore alarms keep ringing when the app is swiped away; the
      // plugin's default stops the audio on task removal.
      androidStopAlarmOnTermination: !alarm.hardcoreMode,
      // A second alarm due while another still rings (7:00 and 7:05 for a
      // heavy sleeper mid-challenge) used to be dropped by the plugin, and
      // its next occurrence was never scheduled. Both ring; the ring screen
      // takes them one at a time.
      allowAlarmOverlap: true,
    );

    try {
      await Alarm.set(alarmSettings: settings);
      await SmartAlarmService.checkNightOwlBadge(alarm.time);
    } catch (error) {
      // Some devices deny exact alarms; keep notification fallback alive.
      debugPrint('Alarm.set failed for ${alarm.id}: $error');
    }

    final location = tz.local;
    final zoned = tz.TZDateTime.from(targetTime, location);
    final scheduleMode = await exactScheduleMode();

    await _notifications.zonedSchedule(
      alarmId,
      alarm.label.isEmpty ? 'Alarm+' : alarm.label,
      alarm.tag,
      zoned,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_plus_alarms',
          'Alarm+ Alarms',
          channelDescription: 'Daily and weekly smart alarm reminders',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          ticker: 'Alarm+ is ringing',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      // One-shot at the next occurrence. A daily `DateTimeComponents.time`
      // repeat fired on every day, including a weekday alarm's weekends;
      // the next occurrence is rescheduled on every dismiss and app start.
      payload: '$alarmId',
    );

    // Naps and location triggers get no bedtime-style notices: a 90-minute
    // nap used to get "Wind-down reminder" a half hour before waking.
    final windDownMinutes = await SmartAlarmService.getWindDownMinutes();
    final windDownTime = targetTime.subtract(
      Duration(minutes: windDownMinutes),
    );
    if (!alarm.isSystem && windDownTime.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        _windDownNotificationId(alarm.id),
        'Wind-down reminder',
        'Alarm in $windDownMinutes min. ${SmartAlarmService.windDownChecklist().join(' • ')}',
        tz.TZDateTime.from(windDownTime, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_plus_winddown',
            'Alarm+ Wind-down',
            channelDescription: 'Pre-alarm sleep prep reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: scheduleMode,
      );
    }

    final noticeAt = targetTime.subtract(upcomingNoticeLead);
    if (!alarm.isSystem &&
        noticeAt.isAfter(DateTime.now()) &&
        await upcomingNoticeEnabled()) {
      await _notifications.zonedSchedule(
        _upcomingNotificationId(alarm.id),
        'Upcoming alarm',
        [
          DateFormat.jm().format(targetTime),
          if (alarm.label.isNotEmpty) alarm.label,
        ].join(' · '),
        tz.TZDateTime.from(noticeAt, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_plus_upcoming',
            'Upcoming alarms',
            channelDescription:
                'A heads-up before each alarm, with a Dismiss now button',
            importance: Importance.low,
            priority: Priority.low,
            category: AndroidNotificationCategory.reminder,
            actions: [
              AndroidNotificationAction(
                'dismiss_now',
                'Dismiss now',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: scheduleMode,
        payload: 'upcoming:$alarmId',
      );
    }

    if (persist) {
      await saveAlarm(alarm.copyWith(isEnabled: true));
    }
    unawaited(WidgetSyncService.refresh());
    unawaited(StreakReminderService.refresh());
  }

  /// "Dismiss now" on the upcoming-alarm notice: already up, so don't ring.
  /// A repeating alarm skips just this occurrence; a one-off is switched off.
  static Future<void> dismissUpcoming(int alarmIntId) async {
    final alarm = findByIntId(alarmIntId);
    if (alarm == null) return;
    // A stale notice tapped while the alarm rings would skip tomorrow and
    // silence today's ring without its challenge. Ringing alarms are
    // dismissed on the ring screen only.
    if (_supportsNativeAlarmOps &&
        await Alarm.isRinging(alarmIntId).catchError((_) => false)) {
      return;
    }
    if (alarm.repeatDays.isNotEmpty) {
      await setSkipNext(alarm.id, skip: true);
    } else {
      await toggleAlarm(alarm.id, false);
    }
    notifyChanged();
  }

  /// Exact scheduling when the user granted it, otherwise the inexact
  /// fallback Android allows without the permission.
  static Future<AndroidScheduleMode> exactScheduleMode() async {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    try {
      return (await Permission.scheduleExactAlarm.status).isGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  static Future<void> cancelAlarm(String id) async {
    await _cancelScheduledArtifacts(id);
    unawaited(WidgetSyncService.refresh());
    unawaited(StreakReminderService.refresh());
  }

  /// A fresh id for a new alarm.
  static String newAlarmId() => _uuid.v4();

  static Future<void> deleteAlarm(String id) async {
    await _cancelScheduledArtifacts(id);
    await StorageService.deleteAlarm(id);
    unawaited(WidgetSyncService.refresh());
    unawaited(StreakReminderService.refresh());
  }

  static Future<void> restoreEnabledAlarms() async {
    // Nap and arrival alarms were set for an exact instant (seconds
    // included) that the alarm plugin keeps on its own; rebuilding them from
    // HH:mm could ring them early or, inside their last minute, mark them
    // expired and switch them off.
    final alarms =
        getAllAlarms().where((alarm) => alarm.isEnabled && !alarm.isSystem);
    for (final alarm in alarms) {
      // Rescheduling starts with Alarm.stop(), so restoring an alarm that is
      // ringing right now (the app was cold-started by that very alarm)
      // would silence it.
      if (_supportsNativeAlarmOps &&
          await Alarm.isRinging(alarmIntId(alarm.id))
              .catchError((_) => false)) {
        continue;
      }
      await scheduleAlarm(
        alarm,
        persist: false,
        at: await _pendingOverride(alarmIntId(alarm.id)),
      );
    }
  }

  static Future<void> _cancelScheduledArtifacts(String id) async {
    if (!_supportsNativeAlarmOps) {
      return;
    }

    final alarmId = alarmIntId(id);
    await Alarm.stop(alarmId);
    await _notifications.cancel(alarmId);
    await _notifications.cancel(_windDownNotificationId(id));
    await _notifications.cancel(_upcomingNotificationId(id));
    final prefs = await sp.SharedPreferences.getInstance();
    await prefs.remove('$_nativeRingtoneKeyPrefix.$alarmId');
  }

  static Future<void> toggleAlarm(String id, bool on) async {
    final alarm = StorageService.getAlarm(id);
    if (alarm == null) {
      return;
    }

    final updated = alarm.copyWith(isEnabled: on);
    await saveAlarm(updated);

    if (on) {
      await scheduleAlarm(updated);
    } else {
      await cancelAlarm(id);
    }
  }

  /// Skips (or, with [skip] false, un-skips) the next occurrence of a
  /// repeating alarm and reschedules it.
  static Future<void> setSkipNext(String id, {required bool skip}) async {
    final alarm = StorageService.getAlarm(id);
    if (alarm == null || alarm.repeatDays.isEmpty) return;
    final updated =
        skip ? alarm.skipNext(DateTime.now()) : alarm.copyWith(skipDate: null);
    await saveAlarm(updated);
    if (updated.isEnabled) await scheduleAlarm(updated);
  }

  /// Vacation mode: holds every repeating alarm until [until] (a date), or
  /// lifts the pause when [until] is null. One-off alarms are left alone;
  /// switch those off instead.
  static Future<void> pauseRepeatingUntil(DateTime? until) async {
    final day = until == null ? null : DateTime(until.year, until.month, until.day);
    for (final alarm in getAllAlarms().where((a) => a.repeatDays.isNotEmpty)) {
      if (alarm.pausedUntil == day) continue;
      final updated = alarm.copyWith(pausedUntil: day);
      await saveAlarm(updated);
      if (updated.isEnabled) await scheduleAlarm(updated);
    }
  }

  static List<AlarmModel> getAllAlarms() {
    return StorageService.getAllAlarms();
  }

  static AlarmModel createAlarm({
    required TimeOfDay time,
    required String label,
    required List<int> repeatDays,
    required bool isEnabled,
    required String tag,
    String sound = 'default',
    String personality = 'gentle',
    bool gentleWake = false,
    int gentleWakeDurationSeconds = 60,
    ChallengeType? challengeType,
    String? voiceMemoPath,
    int stepGoal = 20,
    int squatReps = 10,
    int snoozeMinutes = 5,
    int maxSnoozes = 0,
    double alarmVolume = 1.0,
    VibrationPatternType vibrationPattern = VibrationPatternType.standard,
    String? savedQrCode,
    bool questMode = false,
    List<ChallengeType>? questSteps,
    bool wakeUpCheckEnabled = false,
    int wakeUpCheckMinutes = 10,
    bool hardcoreMode = false,
    DateTime? date,
  }) {
    return AlarmModel(
      id: _uuid.v4(),
      date: repeatDays.isEmpty ? date : null,
      time: time,
      label: label,
      repeatDays: repeatDays,
      isEnabled: isEnabled,
      tag: tag,
      sound: sound,
      personality: personality,
      gentleWake: gentleWake,
      gentleWakeDurationSeconds: gentleWakeDurationSeconds,
      challengeType: challengeType,
      voiceMemoPath: voiceMemoPath,
      stepGoal: stepGoal,
      squatReps: squatReps,
      snoozeMinutes: snoozeMinutes,
      maxSnoozes: maxSnoozes,
      alarmVolume: alarmVolume,
      vibrationPattern: vibrationPattern,
      savedQrCode: savedQrCode,
      questMode: questMode,
      questSteps: questSteps,
      wakeUpCheckEnabled: wakeUpCheckEnabled,
      wakeUpCheckMinutes: wakeUpCheckMinutes,
      hardcoreMode: hardcoreMode,
    );
  }

  static String formatTimeLabel(DateTime value) {
    return DateFormat('hh:mm a').format(value);
  }

  static int _idToInt(String id) {
    final sanitized = id.replaceAll('-', '');

    // Build a stable positive 31-bit value so Android-side int IDs never overflow.
    var hash = 0;
    for (final codeUnit in sanitized.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    if (hash == 0) {
      hash = id.hashCode & 0x7fffffff;
    }

    // Avoid zero and keep headroom for derived notification IDs.
    return (hash % 1000000000) + 1;
  }

  static int alarmIntId(String id) => _idToInt(id);

  static int _upcomingNotificationId(String id) {
    final base = alarmIntId(id);
    return ((base + 700000) % 1000000000) + 1;
  }

  /// Clears the "Upcoming alarm" notice; called when the alarm starts
  /// ringing so its Dismiss now button can't outlive the occurrence.
  static Future<void> cancelUpcomingNotice(int alarmIntId) async {
    final alarm = findByIntId(alarmIntId);
    if (alarm == null) return;
    try {
      await _notifications.cancel(_upcomingNotificationId(alarm.id));
    } catch (e) {
      debugPrint('cancelUpcomingNotice failed: $e');
    }
  }

  /// "You slept through your alarm" gets its own id: it shared the alarm's
  /// id, so the next reschedule of that alarm cancelled it.
  static int missedNoticeId(int alarmIntId) =>
      ((alarmIntId + 3000000) % 1000000000) + 1;

  static int _windDownNotificationId(String id) {
    final base = alarmIntId(id);
    return ((base + 900000) % 1000000000) + 1;
  }

  static AlarmModel? findByIntId(int alarmId) {
    for (final alarm in getAllAlarms()) {
      if (alarmIntId(alarm.id) == alarmId) {
        return alarm;
      }
    }
    return null;
  }

  /// Rings a one-off alarm the app sets for itself, at exactly [at]
  /// (seconds included), under a fixed [id] so a second nap or a second
  /// arrival replaces the first instead of piling up. It never touches the
  /// user's alarms, and is deleted after it rings (see AlarmModel.isSystem).
  static Future<void> ringSystemAlarm({
    required String id,
    required String label,
    required String tag,
    required DateTime at,
  }) async {
    final alarm = AlarmModel(
      id: id,
      time: TimeOfDay.fromDateTime(at),
      label: label,
      tag: tag,
      sound: 'default',
      isEnabled: true,
      repeatDays: const [],
      date: DateTime(at.year, at.month, at.day),
    );
    assert(alarm.isSystem, 'ringSystemAlarm needs a system tag');
    await saveAlarm(alarm);
    await scheduleAlarm(alarm, at: at);
  }

  static const napAlarmId = 'system-nap';

  static Future<void> scheduleNapAlarm(DateTime wakeTime) => ringSystemAlarm(
        id: napAlarmId,
        label: 'Nap Over! 😴',
        tag: AlarmModel.napTag,
        at: wakeTime,
      );

  /// Deletes every nap alarm. It used to delete the first `nap_timer` alarm
  /// found, and finished naps stayed in storage, so cancelling often removed
  /// an old one and the live nap rang anyway.
  static Future<void> cancelNapAlarm() async {
    for (final nap in getAllAlarms().where((a) => a.tag == AlarmModel.napTag)) {
      await deleteAlarm(nap.id);
    }
  }

  static Future<bool> autoAdjustNextAlarmFromMood({
    required int energy,
    required int sleepQuality,
  }) async {
    final alarms = getAllAlarms().where((alarm) => alarm.isEnabled).toList();
    if (alarms.isEmpty) {
      return false;
    }

    alarms.sort(
      (a, b) => a
          .nextDateTimeFrom(DateTime.now())
          .compareTo(b.nextDateTimeFrom(DateTime.now())),
    );
    final target = alarms.first;

    var deltaMinutes = 0;
    if (sleepQuality <= 2 || energy <= 2) {
      deltaMinutes = 15;
    } else if (sleepQuality >= 4 && energy >= 4) {
      deltaMinutes = -10;
    }

    if (deltaMinutes == 0) {
      return false;
    }

    final current = (target.time.hour * 60) + target.time.minute;
    final shifted = (current + deltaMinutes).clamp(0, (24 * 60) - 1);
    final updated = target.copyWith(
      time: TimeOfDay(hour: shifted ~/ 60, minute: shifted % 60),
      tag: 'Mood-adjusted',
    );

    await scheduleAlarm(updated);
    return true;
  }
}
