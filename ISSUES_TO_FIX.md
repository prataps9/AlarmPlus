# Unresolved Issues & Improvements

This document tracks identified issues, deprecations, and potential logic bugs in the **AlarmPlus** project that need fixing.

## 🔴 High Priority: Open reliability bugs (audit 2026-09-25)
These were verified by reading the code, but are **not fixed yet**. Each one
touches the native ring flow and needs on-device testing.
- **Notification "Stop" skips every challenge, even in Hardcore mode** (`AlarmForegroundService.kt` stop action → `alarm_ring_flow.dart` `_stopFromNotification`). It still awards XP and streak. The action should open the ring screen instead.
- **Hardcore anti-swipe doesn't work.** `AlarmSettings` never sets `androidStopAlarmOnTermination: false`, so swiping the app away stops the audio. `onTaskRemoved` also restarts the service for every alarm, not just Hardcore ones.
- **The 2-minute "missed recovery" misbehaves** (`alarm_ring_flow.dart`):
  - it stops a ringing alarm even while the user is mid-challenge;
  - it saves the backup time over the user's real alarm (`persist` defaults to true);
  - it resets the guardian timer on every re-ring, so **Guardian Alert can never fire**.
- **The Wake-Up Check re-ring rarely fires.** `TimeOfDay.fromDateTime(now + 5s)` rounds down to the minute, so `nextDateTimeFrom` moves it to tomorrow. It also relies on in-memory `Timer`s that are lost if the process dies.
- **Timezone is never set.** `tz.setLocalLocation` is never called, so `tz.local` is UTC and daily `matchDateTimeComponents` notifications fire at UTC times. Add `flutter_timezone`.
- **The backup notification repeats daily even for weekday-only alarms.** It uses `DateTimeComponents.time` instead of `dayOfWeekAndTime`.
- **Media volume is left at the alarm level after every alarm.** `alarm_ring_screen.dart` sets it with `VolumeController` and never restores it.
- **Premium is a local SharedPreferences flag** with no receipt verification, and refunds never lock it again. Consider server-side verification or re-querying purchases at startup.

## 🟡 Medium Priority
- **Dark mode can't be turned on.** `themeDarkProvider` is never written, and around 400 hard-coded `Color(0x…)` values remain (mostly the ring screen, `alarms_screen`, Settings tiles).
- **Wind-Down and Sleep Sounds can't be reached from the main UI**: nothing pushes `/wind-down`.
- **Three system permission prompts appear before any UI** (`SplashScreen` → `AlarmService.requestPermissions`). They should move into the onboarding permissions page.

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
- **Paywall advertised unimplemented features (2026-09-25):** the bundle is now only what ships. The paywall is a full screen, there is a Pro card and Restore in Settings, and locked Insights cards have an unlock button and refresh after purchase.

## ✅ Phase 1 Heavy Sleeper Features (Implemented 2026-05-17)
- **Wake-Up Check:** AlarmModel gains `wakeUpCheckEnabled` + `wakeUpCheckMinutes` (5/10/15). After dismiss, a local notification fires; if not tapped within 60 s the alarm re-rings. Toggle in alarm creation sheet.
- **Mission Chaining / Quest Mode:** Already existed in the data model and ring screen (`questMode`, `questSteps`). Now wired end-to-end in creation UI.
- **Guardian Alert System:** `GuardianService` sends an HTTP POST to a user-configured webhook URL after 10 continuous minutes of un-dismissed ringing. Settings tile in Settings screen.
- **Hardcore Anti-Cheat Mode:** AlarmModel gains `hardcoreMode` bool. When enabled: (a) `PopScope(canPop: false)` blocks back-navigation in `AlarmRingScreen`; (b) `AlarmForegroundService` changed to `START_STICKY` + `onTaskRemoved` restarts the service if the app is swiped away.

---
*Updated on 2026-09-25*
