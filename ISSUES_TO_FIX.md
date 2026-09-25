# Unresolved Issues & Improvements

This document tracks identified issues, deprecations, and potential logic bugs in the **AlarmPlus** project that need fixing.

## 🔴 High Priority
- **Needs on-device verification (2026-09-25 ring-flow fixes).** The Kotlin and Android resource changes below were only checked for syntax, not built: there was no Android SDK in the environment. Run `flutter build apk` and test on a phone:
  - lock-screen notification (Open / Snooze buttons)
  - Hardcore mode swipe-away
  - a cold start caused by a ringing alarm
  - the Android 12+ animated splash
  - long-press launcher shortcuts
  - the wake-up check re-ring after killing the app
- **Premium is a local SharedPreferences flag** with no receipt verification, and refunds never lock it again. Consider server-side verification or re-querying purchases at startup.

## 🟡 Medium Priority
- **Dark mode can't be turned on.** `themeDarkProvider` is never written, and around 400 hard-coded `Color(0x…)` values remain (mostly the ring screen, `alarms_screen`, Settings tiles).
- **Wind-Down can't be reached from the main UI**: nothing pushes `/wind-down`. Sleep Sounds is now reachable through the launcher shortcut, but not from Home.
- **Re-running `flutter_native_splash` overwrites the Android 12 animated icon.** Restore the two `windowSplashScreen*` lines in `values-v31` / `values-night-v31` afterwards (noted in `pubspec.yaml`). The web and iOS launch screens are still the old white ones.

## ✅ Fixed
- **Silent Failures (catch blocks):** All empty `catch (_) {}` blocks now log via `debugPrint`.
- **Hardcoded Package Name:** Application ID changed from `com.example.lumio` → `com.alarmplus.app`; Kotlin source files moved to matching package directory.
- **Flutter Deprecations:** All `MaterialStatePropertyAll`, `MaterialStateProperty`, `MaterialState` and `DropdownButtonFormField.value` usages replaced with `WidgetState*` / `initialValue` equivalents.
- **Unused Field:** `_settingsKey` in `storage_service.dart` was already absent in current code (stale issue).
- **Test coverage / release signing:** now covered by the test suite and `android/key.properties` (see README), so these are no longer open.
- **Default alarm sound was silent (2026-09-25):** `'default'` mapped to `assetAudioPath: ''`, which the alarm plugin resolves to a directory and fails to play. It now passes `null`, which means the device's default alarm tone.
- **Cold start silenced a ringing alarm (2026-09-25):** `restoreEnabledAlarms` rescheduled, and so called `Alarm.stop` on, the alarm that had just launched the app. It now skips alarms that are ringing.
- **Scheduled notifications never fired (2026-09-25):** added the three `flutter_local_notifications` receivers to `AndroidManifest.xml`.
- **DST drift (2026-09-25):** `nextDateTimeFrom` added 24 h per day, which is off by an hour across a DST switch. It now builds the next calendar day explicitly.
- **Streaks counted dismissals, not days, and freezes were never used (2026-09-25):**
  - A second alarm on the same day no longer extends the streak.
  - A miss now spends an owned freeze (at most one per day) instead of resetting the streak.
  - A later miss no longer erases a day the user did wake up.
- **Purchases could be lost (2026-09-25):** `purchaseStream` was only listened to during a purchase, so pending or late UPI purchases were never completed and were auto-refunded. A global listener now starts in `main()`.
- **Ring-flow reliability (2026-09-25, second pass):**
  - **Notification "Stop" skipped every challenge** (and still paid XP). The native notification now has **Open** (to the ring screen) instead, and a stray stop call opens the ring screen rather than dismissing.
  - **Snooze:** the notification's snooze shows the alarm's real snooze length and is hidden in Hardcore; volume-key snooze is ignored for Hardcore alarms.
  - **Hardcore anti-swipe:** now sets `androidStopAlarmOnTermination: false`. The native service's `onTaskRemoved` restart only applies to Hardcore alarms.
  - **2-minute "missed recovery":** it overwrote the user's alarm time, stopped alarms mid-challenge, and reset the guardian timer. It is replaced by a 30-minute auto-silence (`autoSilenceAfter`) that records one miss, keeps the next occurrence, and posts a "you slept through it" notification.
  - **Guardian Alert** now counts from the first ring of the session.
  - **Wake-Up Check:** the notification and the re-ring are both OS-scheduled at exact times (`wakeCheckTimes`), so they survive the process dying. Tapping the check restores the normal schedule.
  - **Snooze time** is scheduled as an absolute `DateTime`. It used to go through `TimeOfDay`, which dropped seconds and could let a repeating alarm's snooze slip to another day.
  - **Timezone:** set from the device with `flutter_timezone`, so daily notifications no longer fire at UTC times.
  - **Backup notification** is now a one-shot at the next occurrence. It had repeated daily, including a weekday alarm's weekends.
  - **Media volume** is restored after the ring screen closes.
  - **Cold start from a ringing alarm:**
    - the ring screen now waits for the navigator (it used to be dropped before `runApp`);
    - the splash replaces itself in place instead of replacing the ring screen on top of it;
    - a notification tap that launched the app is replayed once listeners are bound.
  - **Permission prompts** no longer fire before the first frame. They moved to onboarding, and to the splash for returning users.
- **Paywall advertised unimplemented features (2026-09-25):** the bundle is now only what ships. The paywall is a full screen, there is a Pro card and Restore in Settings, and locked Insights cards have an unlock button and refresh after purchase.

## ✅ Phase 1 Heavy Sleeper Features (Implemented 2026-05-17)
- **Wake-Up Check:** AlarmModel gains `wakeUpCheckEnabled` + `wakeUpCheckMinutes` (5/10/15). After dismiss, a local notification fires; if not tapped within 60 s the alarm re-rings. Toggle in alarm creation sheet.
- **Mission Chaining / Quest Mode:** Already existed in the data model and ring screen (`questMode`, `questSteps`). Now wired end-to-end in creation UI.
- **Guardian Alert System:** `GuardianService` sends an HTTP POST to a user-configured webhook URL after 10 continuous minutes of un-dismissed ringing. Settings tile in Settings screen.
- **Hardcore Anti-Cheat Mode:** AlarmModel gains `hardcoreMode` bool. When enabled: (a) `PopScope(canPop: false)` blocks back-navigation in `AlarmRingScreen`; (b) `AlarmForegroundService` changed to `START_STICKY` + `onTaskRemoved` restarts the service if the app is swiped away.

---
*Updated on 2026-09-25*
