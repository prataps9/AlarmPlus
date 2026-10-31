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
  Stroop test where you tap the ink colour, not the word).
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
- **Clean white UI** — a plain, standard alarm-app look built around the
  Alarm+ line-clock logo (`lib/shared/widgets/alarm_logo.dart`, the same mark
  as the launcher icon). On Android 12+ the system splash shows the logo with
  its minute hand sweeping once (`res/drawable/splash_logo_animated.xml`), and
  the Flutter splash continues from that exact frame.
- **Four tabs** — Alarm, Clock (world clock with city search), Insights
  and Settings, a bottom-bar tab with grouped, searchable settings. Tabs
  are built the first time they are opened and fade in. (The timer and
  stopwatch were removed; a "time's up" left scheduled by an older version
  is cleaned up on the first start.)
- **Reliability guardrails** — the Alarm tab warns, with a one-tap fix,
  whenever notifications or exact alarms are off. Every alarm gets a
  2-hours-ahead "Upcoming alarm" notice with **Dismiss now**. Times follow
  the phone's 12/24-hour setting.
- **Bedtime + sleep goal** — the Alarm tab works your bedtime back from the
  next alarm ("Go to bed by 10:30 PM for 8 h of sleep"), with an optional
  nightly reminder.
- **Skip next** — skip one occurrence of a repeating alarm (a holiday, a day
  off) without switching it off.
- **One-off alarms on a date** — with no repeat days, pick the day it rings
  ("Thu, 30 Oct"). A dated alarm whose moment has passed is switched off
  instead of ringing late.
- **Sleep-cycle wake times** — in the alarm editor, "Sleeping now?" offers
  wake times at the end of a 90-minute sleep cycle (6, 7.5 or 9 h); tap one
  to set it.
- **Next 7 days** — Alarms tab → ⋮ lists every ring in the coming week, with
  skips, pauses and dates applied.
- **Pause until a date** — vacation mode: hold every repeating alarm until a
  chosen date (Alarms tab → ⋮), with a banner and one-tap Resume.
- **Dark mode** — Settings → Theme: Light, Dark or Match phone.
- **Undo & duplicate** — swiping an alarm away deletes it with an Undo
  snackbar; long-press an alarm to duplicate it (voice memo included).
- **24-hour editor** — the alarm time picker follows the phone's 24-hour
  setting, like the rest of the app.
- **Backup & restore** — export all alarms and settings to a JSON file via
  the share sheet, and restore it later. Backups never carry the Pro unlock.
- **Live alarm capsule (Android)** — 2 hours before an alarm Alarm+ posts a live countdown with a **Skip** button. On
  Android 16+ (ColorOS 16 / OxygenOS 16 / One UI 8 …) it is a *Live Update*
  and is promoted to the status-bar capsule, the slot food-delivery
  trackers use; older phones show it as an ongoing notification with the
  same ticking countdown. A snooze shows "Snoozed" with its countdown, and
  the ringing alarm gets a red "Ringing" capsule. Scheduled natively, so it
  appears with the app closed. Settings → Live Alarm Countdown.
- **Next-alarm capsule card** — the top of the Alarm tab is the in-app twin
  of the status-bar capsule: a dark pill whose ring fills over the last two
  hours, a countdown that rolls like an odometer (and shows seconds inside
  the last hour), and an amber-to-red glow in the final five minutes. A
  snooze shows as "Snoozed". Respects the system's reduce-motion setting.
- **Alarm Health Check** — Settings → Alarm Health Check: one checklist for
  notifications, exact alarms and battery optimisation; steps and a direct
  link for phone makers known to stop alarm apps in the background (Xiaomi,
  Oppo/Realme, Vivo, Huawei, OnePlus, Samsung, Asus); and a real 1-minute
  test alarm with the app swiped away, using the same Android call as the
  alarm plugin. A failed or late test shows a banner on the Alarm tab.
- **Morning Briefing** — optional (Settings → Morning Briefing): after a
  dismiss, the phone's own text-to-speech reads the time, the day, how fast
  you got up, your streak and wake score.
- **Works with the app closed** — a timezone change moves every alarm to
  the new local time, and location alarms use Android's geofencing service,
  so an arrival rings even with Alarm+ swiped away ("all the time" location
  access needed).
- **Native Android touches** — predictive-back page animations (Android
  14+), launcher long-press shortcuts (New alarm, Power nap, Sleep sounds,
  Focus timer), a Quick Settings tile, a home-screen widget, and volume-key
  snooze.
- **Pip, the mascot** — a code-drawn, animated alarm-clock character that
  appears only in celebrations (level-ups, badges, the post-alarm sheet) and
  in the Pro wardrobe. Code lives in `lib/features/mascot/`.
- **Alarm+ Pro** — a one-time lifetime unlock (₹299 or the store's local
  price, no subscription). It includes Pip's Wardrobe (4 outfits), double
  streak freezes, Sleep Coach Pro, and an always-on wake challenge. It
  has a full-screen paywall (`lib/features/premium/`), and the purchase
  listener runs for the whole app lifetime so pending payments aren't lost.
  At startup it checks which purchases Google Play says the account owns,
  so Pro restores itself after a reinstall and locks again after a refund.
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

### APK sanity check

`tool/check_apk.py` inspects a built release APK (manifest classes, resources
that are looked up by name, engine libraries, assets, version). CI runs it on
every pull request and `release.yml` runs it before publishing. To run it
yourself: `pip install androguard`, then
`python tool/check_apk.py build/app/outputs/flutter-apk/app-release.apk`.

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
