# Alarm+

Alarm+ is a Flutter alarm and sleep-wellness app that turns waking up into a
game: XP and levels, badges, streaks, morning missions, a wake-quality score,
wake challenges, sleep coaching, quest-mode alarms (chained challenges),
guardian alerts, and an optional hardcore anti-cheat mode for heavy sleepers.

## Features

- **Smart alarms** — repeatable alarms with gentle-wake ramp, custom sounds,
  personalities, and per-alarm dismiss challenges (math, memory pattern,
  shake-to-wake, typing, barcode/QR scan, trivia, word scramble, step counter,
  eye-open detection, squats, photo proof, read-aloud, and Color Clash, a
  Stroop test where you tap the ink colour, not the word). Pip rings on
  the alarm screen and reacts as you swipe.
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
- **Pip, the mascot** — a code-drawn, animated alarm-clock buddy (no image
  assets). Pip has seven moods with their own motion: waving, a cheering
  jump with ringing bells, a sleepy "z"-float, a worried shiver, a proud
  sparkle. Pip also blinks, bobs, and wiggles when tapped. Pip greets you on
  Home with a contextual line (streak at risk, bedtime, next alarm), and
  appears on splash, onboarding, the celebration banner and the dismiss
  sheet. Code lives in `lib/features/mascot/`.
- **Animated launch** — on Android 12+ the system splash is an
  animated-vector Pip, asleep while the alarm bells ring
  (`res/drawable/splash_pip_animated.xml`). The Flutter splash continues
  from that exact frame: Pip wakes up and jumps, the night sky turns into
  a sunrise, and the wordmark bounces in. Tap to skip; reduce-motion is
  respected.
- **Native Android touches** — predictive-back page animations (Android
  14+), launcher long-press shortcuts (New alarm, Power nap, Sleep sounds,
  Focus timer), a Quick Settings tile, a home-screen widget, and volume-key
  snooze.
- **Alarm+ Pro** — a one-time lifetime unlock (₹299 or the store's local
  price, no subscription). It includes Pip's Wardrobe (4 outfits), double
  streak freezes, Sleep Coach Pro, and an always-on wake challenge. It
  has a full-screen paywall (`lib/features/premium/`), and the purchase
  listener runs for the whole app lifetime so pending payments aren't lost.
- **Sleep tools** — sleep diary, sleep insights, wind-down mode, bedtime
  setup, sleep sounds, location-based alarms, nap timer, focus timer.

See `COMPETITIVE_ANALYSIS.md` for market positioning and the feature
roadmap, and `IMPLEMENTATION_PLAN.md` for in-progress work.

## Tech stack

- **Flutter / Dart** (Flutter 3.47.5 in CI)
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

1. Install Flutter 3.47.5 (the version CI pins; dependencies need
   Flutter ≥ 3.44) and set up an Android/iOS toolchain.
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

Release builds require a real signing key. Generate one (once) with:

```bash
./android/generate_release_key.sh
```

This creates `android/app/upload-keystore.jks` and `android/key.properties`
interactively — it prompts you for passwords rather than generating any
secrets on its own, and both output files are already gitignored. Back up
the `.jks` file somewhere safe: losing it means you can never publish an
update to an app already live under that key. (`android/key.properties.example`
documents the file format if you'd rather set it up by hand, e.g. from an
existing keystore.)

Then build:

```bash
flutter build apk --release
```

Without `android/key.properties`, release builds fall back to the debug
signing key (with a Gradle warning) — fine for local testing, but not
suitable for distribution.

## Continuous integration & releases

Two workflows live in `.github/workflows/`:

- **`ci.yml`** — runs `flutter analyze` + `flutter test` on every push to
  `main` and every pull request. Doesn't build or publish anything.
- **`release.yml`** — cuts an actual release. It triggers on a pushed tag
  matching `vX.Y.Z`, or can be run manually from the Actions tab. It
  analyzes, tests, builds a release APK + AAB, and publishes them to a
  GitHub Release named after that version.

To cut a release:

```bash
git tag v1.2.0
git push origin v1.2.0
```

By default the CI build is signed with the debug key (same fallback as a
local build without `android/key.properties`) — fine for internal testing,
but not for the Play Store. To get a properly signed release out of CI,
add these repo secrets (Settings → Secrets and variables → Actions), taken
from a keystore generated via `./android/generate_release_key.sh`:

- `ANDROID_KEYSTORE_BASE64` — `base64 -i android/app/upload-keystore.jks`
- `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` —
  the same values written into `android/key.properties`

Once all four are set, `release.yml` picks them up automatically and
produces a real, Play-Store-ready signed build.
