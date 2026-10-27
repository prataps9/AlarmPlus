# Unresolved Issues & Improvements

This document tracks identified issues, deprecations, and potential logic bugs in the **AlarmPlus** project that need fixing.

## 🔴 High Priority
- **Needs on-device verification (2026-09-25 ring-flow fixes).** The Android code now *builds* (CI and the release workflow produce a real APK), and the APK is inspected automatically. But nothing has been **run** on a phone: this environment has no emulator or device. Install the release APK and test:
  - lock-screen notification (Open / Snooze buttons)
  - Hardcore mode swipe-away
  - a cold start caused by a ringing alarm
  - the Android 12+ animated splash (logo minute-hand sweep)
  - the Timer's "time's up" notification ringing with the app closed
  - Backup (share sheet) and Restore (file picker)
  - the "Upcoming alarm" notice and its **Dismiss now** button (app open and app closed)
  - the Home reliability banner after revoking notification / exact-alarm permission
  - long-press launcher shortcuts
  - the wake-up check re-ring after killing the app
  - a timezone change with the app closed (Settings → Date & time → pick another zone, then check the next alarm's time in Alarm+)
  - a location alarm arriving with the app swiped away, after tapping **Allow** on the Location Alarms banner ("all the time" access)
- **Pro has no server-side receipt check.** At startup the app now asks Google Play which purchases the account owns, which auto-restores Pro after a reinstall and locks it again after a refund. A rooted device could still fake the local flag; full protection needs server-side verification.

## 🟡 Medium Priority
- **Location alarms need "all the time" location access to work with the app closed.** Without it (Android 10+), only the in-app check runs, and the Location Alarms screen says so with an **Allow** button.
- **Wind-Down, Sleep Sounds and Breathing screens are dark navy** while the rest of the app is white. This was kept on purpose for night use (like the stock Clock's Bedtime mode); say if you want them white too.
- **Re-running `flutter_native_splash` overwrites the Android 12 animated icon.** Restore the `windowSplashScreen*` lines in `values-v31` / `values-night-v31` afterwards (noted in `pubspec.yaml`).

## ✅ Fixed
- **Background system events (2026-10-27):** two features only worked while the app was open.
  - **Timezone change with the app closed:** `TimeZoneChangeReceiver` now gets Android's `TIMEZONE_CHANGED` broadcast and moves every alarm, the bedtime reminder and the streak reminder to the new local time.
  - **Location alarms with the app swiped away:** each enabled location alarm is now registered with Android's geofencing service (`GeofenceManager`), re-registered after a reboot or update, and an arrival rings even when Alarm+ is closed. The in-app position check stays as a fallback, and an arrival reported by both rings only once.
  - Both run their Dart work in a short background Flutter engine (`BackgroundDartRunner` → `backgroundMain`) when the app isn't running, or hand it to the running app. They never run both at once, because Hive can't be opened by two isolates. The alarm plugin's single "alarm rang" callback is pointed back at the app's engine after each background run.
- **Third review round (2026-10-27)**: alarm editor, Android native code, and the remaining screens. Highlights:
  - **Silent alarms when the app was killed:** phone ringtones and the default tone were handed to the alarm plugin as a silent file and played by a service only the app could start. The plugin now plays the default tone itself, and a picked ringtone from a private copy. Per-alarm volume and the Gentle Wake fade are applied by the plugin too.
  - **Notification Snooze and volume-key snooze did nothing:** the widget code replaced the ring flow's native channel handler. One dispatcher now serves both.
  - **Android:** the ring service crashed on Android 7–8.1; a non-Hardcore alarm swiped away kept looping; the Quick Settings tile was always unavailable; widget taps were lost after backing out; the PIN pad covered the ring screen; any app could broadcast the notification's stop action.
  - **Editor:** a double tap on Set Alarm made two alarms; closing the sheet threw edits away silently; voice memo files were deleted before saving or leaked; editing a snoozed alarm cancelled the snooze; "Math (default)" gave a random challenge; Photo Proof could be chosen but never set up; the sound name and day-type chip were wrong when editing; the Settings sound was never used for new alarms.
  - **Screens:** a "wind-down" notice fired 30 minutes before the morning alarm; sleep sounds kept playing through and after the alarm; permission prompts reopened on every launch, even over a ringing alarm; Insights and Full history showed stale data; Guardian Alert accepted any text and always claimed the test worked; XP could be farmed by repeating wind-down, diary, check-in and routine; the check-in erased the diary's memo and details.
- **One-off alarm stopped by swiping the app away (2026-10-27)** stayed on and rang again every day. The app now remembers when each alarm was scheduled, and on restore a one-off whose moment has passed is switched off.
- **Wake-Up Check re-ring paid XP again (2026-10-27)** and scheduled yet another check. Dismissing it now just ends the morning that was already counted.
- **Dark mode (2026-10-22):** Settings → Theme offers Light, Dark or Match phone, saved and applied before the first frame. The hard-coded light colours were replaced with theme colours across the app: Home, the alarm list and editor, the ring screen and every wake challenge, Settings, Sleep, Missions, Onboarding and more. Each screen was rendered in light and dark and checked; two sheets that only appear mid-flow (the post-dismiss celebration and the Wake Routine completion sheet) were converted from the code without a screenshot. Wind-Down, Sleep Sounds, Nap and Morning Check-in stay dark on purpose, and the camera screens stay black.
- **Sleep Insights crashed with a partly filled diary (2026-10-22):** days without an entry were drawn as `FlSpot(x, NaN)`, which makes the chart fail ("Offset argument contained a NaN value"). They are now gaps. A test renders the screen with two of seven days logged.
- **Step-counter ring and Trivia loading card (2026-10-22):** the step ring drew as a 36px dot instead of filling its 160px circle, and while a trivia question loaded the card stretched to the full screen height.
- **Vibration switches did nothing (2026-10-22):**
  - the Settings "Vibration" switch was never saved and nothing read it. It is now saved, and it turns off vibration for every alarm;
  - an alarm whose own vibration was set to **Off** still vibrated, because the alarm plugin was always told `vibrate: true`.
- **Alarm editor time picker was always 12-hour (2026-10-21):** it now follows the phone's 24-hour setting.
- **New alarms defaulted to Tue–Sat, and quick add "tomorrow" made a weekly alarm (2026-10-21).** Both fixed.
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
- **Inspection of the shipped v1.2.0 APK (2026-10-21):** the release file was downloaded, checksummed against the release, and taken apart. It is structurally sound: all 44 manifest components have their classes in the code, the Flutter engine and compiled Dart are present for 3 CPU types, all assets are bundled, it is not debuggable, and it supports Android 7+. It also turned up two real problems, both fixed in 1.2.1:
  - **The four launcher-shortcut icons were stripped from the APK** by Android's resource shrinker, because they are looked up by name at runtime. `res/raw/keep.xml` now protects them.
  - **One failing plugin could keep the app from opening.** `main()` ran 13 awaited init steps before `runApp`, none individually protected. Each step now has its own error handling and a time limit (`runStartupStep`), so a failure costs one feature, never the whole app.
  - **Prevention:** `tool/check_apk.py` now runs on every pull request and before every release, against the APK that was actually built. It checks the manifest classes, the name-looked-up resources, the engine libraries, the assets, the debuggable flag and the version. It was run against the broken v1.2.0 APK and fails on exactly the four stripped icons.
- **Polish pass (2026-10-19):** every main screen was rendered and stress-tested at 412dp and at 320dp with 1.3× text (the combination many real users run).
  - **Layout overflows fixed:**
    - the alarm editor's day-of-week circles ran off the edge of a normal 412dp phone;
    - the editor's time picker and "Max snoozes" row, the Insights stat tiles and streak line, and Home's "Upcoming alarms / View all" header overflowed at small sizes or large text.
  - **Alarm cards:** "Weekdays" no longer breaks mid-word. The tag, repeat label and Skip next now flow onto a second line when space runs out.
  - **Labels:** a one-time alarm now says "Once" instead of "Custom", and custom days read "Mon, Wed, Fri". The Home "Today" tiles and the home-screen widget now follow the phone's 12/24-hour setting.
- **Completeness pass (2026-10-02):**
  - **Silent failure when permissions are revoked:** Home now shows a banner whenever notifications or exact alarms are off, with a one-tap fix. It rechecks on resume and reschedules every alarm once access returns.
  - **No upcoming-alarm notice:** each alarm now gets a 2-hours-ahead notice with **Dismiss now** (skips that occurrence, or turns off a one-off alarm). It can be switched off in Settings.
  - **24-hour setting ignored:** alarm cards and the ring screen now follow the phone's 12/24-hour setting, and show "6:30", not "06:30".
  - **Stale ring-screen time:** the ring screen shows the live time, which matters after a snooze.
  - **Dead ends:** Wind-Down and Sleep Sounds are reachable from Home, bedtime setup is linked from the bedtime card, and tapping "Time's up" opens the Timer tab.
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
*Updated on 2026-10-27*
