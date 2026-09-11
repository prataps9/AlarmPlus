# Alarm+

Alarm+ is a Flutter alarm and sleep-wellness app that turns waking up into a
game: XP and levels, badges, streaks, morning missions, a wake-quality score,
wake challenges, sleep coaching, quest-mode alarms (chained challenges),
guardian alerts, and an optional hardcore anti-cheat mode for heavy sleepers.

## Features

- **Smart alarms** — repeatable alarms with gentle-wake ramp, custom sounds,
  personalities, and per-alarm dismiss challenges (math, memory pattern,
  shake-to-wake, typing, barcode/QR scan, trivia, word scramble, step counter,
  eye-open detection).
- **Gamification** — XP, levels ("Sleeper" → "Early Bird" → "Dawn Warrior" →
  "Circadian Master" → "Flow Legend"), unlockable badges, and streaks with
  streak freezes and comeback bonuses.
- **Wake Quality Score** — a score computed from dismiss speed, challenge
  accuracy, snooze count, and a daily mood check-in.
- **Morning Missions** — small daily habits (drink water, stretch, gratitude
  note, etc.) tied into the XP system.
- **Quest Mode** — chain multiple challenges together before an alarm can be
  dismissed.
- **Guardian Alerts** — sends a webhook notification if an alarm rings
  unattended for an extended period.
- **Hardcore Mode** — anti-cheat lockout (blocks back-navigation, keeps the
  foreground alarm service alive) for heavy sleepers.
- **Sleep tools** — sleep diary, sleep insights, wind-down mode, bedtime
  setup, sleep sounds, location-based alarms, nap timer, focus timer.

See `COMPETITIVE_ANALYSIS.md` for market positioning and the feature
roadmap, and `IMPLEMENTATION_PLAN.md` for in-progress work.

## Tech stack

- **Flutter / Dart** (Dart SDK `^3.7.0`)
- **State management:** Riverpod (`flutter_riverpod`) for app-level/theme
  state, plus `provider`-style singleton services for alarm/storage logic.
  Consolidating this mix is a known, deferred cleanup — see
  `ISSUES_TO_FIX.md`.
- **Local storage:** Hive (`hive`, `hive_flutter`) and `SharedPreferences`
  for alarms, XP/badges, and wake-score history.
- **Alarms/notifications:** `alarm`, `android_alarm_manager_plus`,
  `flutter_local_notifications`, `timezone`.
- **Other notable packages:** `fl_chart` (insights charts), `google_fonts`,
  `flutter_animate`, `sensors_plus`/`pedometer` (step-counter challenge),
  `mobile_scanner` (QR/barcode challenge), `google_mlkit_face_detection`/
  `camera` (eye-open challenge), `geolocator`/`flutter_map` (location
  alarms), `audioplayers`/`just_audio`/`flutter_sound` (alarm/sleep sounds),
  `in_app_purchase`.

## Getting started

1. Install Flutter (matching the SDK constraint in `pubspec.yaml`,
   currently Dart `^3.7.0`) and set up an Android/iOS toolchain.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```
4. Run tests:
   ```bash
   flutter test
   ```

No environment variables, API keys, or `.env` file are required to run the
app — Alarm+ does not call any external AI service.

## Building a release Android APK

Release builds require a real signing key. Copy
`android/key.properties.example` to `android/key.properties`, fill in your
keystore details, and run:

```bash
flutter build apk --release
```

Without `android/key.properties`, release builds fall back to the debug
signing key (with a Gradle warning) — fine for local testing, but not
suitable for distribution.
