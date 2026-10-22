#!/usr/bin/env python3
"""Sanity-checks a built release APK. Run by CI on every pull request.

Nothing here can prove the app *behaves* correctly on a phone, but each check
guards a way a release build has been (or easily could be) broken while the
Dart tests stay green:

  * a component named in the manifest whose class isn't in the dex
    (launch crash: ClassNotFoundException),
  * resources looked up by name at runtime that the shrinker deleted
    (v1.2.0 shipped without its launcher-shortcut icons),
  * a missing Flutter engine / compiled Dart for a CPU type,
  * missing bundled assets, a debuggable build, or a wrong version.

Usage:  python tool/check_apk.py [--skip-version] build/app/outputs/flutter-apk/app-release.apk
Needs:  pip install androguard

--skip-version: don't compare the APK's version with pubspec.yaml (the release
workflow overrides the build name from the tag, so they can legitimately differ).
"""
import logging
import pathlib
import re
import sys
import zipfile

logging.disable(logging.CRITICAL)
from loguru import logger  # noqa: E402  (installed with androguard)

logger.remove()
from androguard.core.apk import APK  # noqa: E402
from androguard.core.dex import DEX  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXPECTED_PACKAGE = "com.alarmplus.app"
REQUIRED_ASSETS = [
    "assets/sounds/celebration.wav",
    "assets/data/word_list.json",
    "assets/data/trivia_fallback.json",
    "assets/data/read_aloud_sentences.json",
    "assets/icon/app_icon.png",
]
# Resources the app or system finds by name (not statically referenced).
NAMED_RESOURCES = [("drawable", "splash_logo_animated"), ("color", "splash_background"),
                   ("mipmap", "ic_launcher")]


def shortcut_icons():
    """Icon names the launcher shortcuts use, read from the Dart source."""
    src = (ROOT / "lib/core/services/app_shortcuts_service.dart").read_text()
    return re.findall(r"icon:\s*'([a-z0-9_]+)'", src)


def pubspec_version():
    m = re.search(r"^version:\s*([\d.]+)\+(\d+)", (ROOT / "pubspec.yaml").read_text(), re.M)
    return m.group(1), int(m.group(2))


def main(path, skip_version=False):
    problems = []
    apk = APK(path)
    zf = zipfile.ZipFile(path)
    names = set(zf.namelist())

    if apk.get_package() != EXPECTED_PACKAGE:
        problems.append(f"package is {apk.get_package()}, expected {EXPECTED_PACKAGE}")
    want_name, want_code = pubspec_version()
    if not skip_version and (apk.get_androidversion_name() != want_name
                             or int(apk.get_androidversion_code()) != want_code):
        problems.append(
            f"version is {apk.get_androidversion_name()}+{apk.get_androidversion_code()}, "
            f"pubspec says {want_name}+{want_code}")
    if "android:debuggable=\"true\"" in str(apk.get_android_manifest_axml().get_xml()):
        problems.append("the release APK is marked debuggable")

    # Every component in the manifest must exist in the dex.
    classes = set()
    for name in sorted(n for n in names if re.fullmatch(r"classes\d*\.dex", n)):
        for c in DEX(zf.read(name)).get_classes():
            classes.add(c.get_name())
    components = [("activity", n) for n in apk.get_activities()] + \
                 [("service", n) for n in apk.get_services()] + \
                 [("receiver", n) for n in apk.get_receivers()] + \
                 [("provider", n) for n in apk.get_providers()]
    for kind, n in components:
        if "L" + n.replace(".", "/") + ";" not in classes:
            problems.append(f"{kind} {n} is in the manifest but not in the app code")

    # The Flutter engine and compiled Dart must be there for the main CPU.
    for abi in ("arm64-v8a", "armeabi-v7a"):
        for lib in ("libflutter.so", "libapp.so"):
            if f"lib/{abi}/{lib}" not in names:
                problems.append(f"lib/{abi}/{lib} is missing")

    for asset in REQUIRED_ASSETS:
        if f"assets/flutter_assets/{asset}" not in names:
            problems.append(f"asset {asset} is missing")

    res = apk.get_android_resources()
    pkg = apk.get_package()

    def has(kind, name):
        try:
            return bool(res.get_resolved_res_configs(res.get_res_id_by_key(pkg, kind, name)))
        except Exception:
            return False

    wanted = [("drawable", n) for n in shortcut_icons()] + NAMED_RESOURCES
    if not shortcut_icons():
        problems.append("could not read the shortcut icon names from the Dart source")
    for kind, name in wanted:
        if not has(kind, name):
            problems.append(f"resource {kind}/{name} was stripped from the APK "
                            f"(add it to android/app/src/main/res/raw/keep.xml)")

    print(f"{path}: {len(components)} components, {len(classes)} classes, "
          f"{len(wanted)} named resources checked")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for p in problems:
            print("  -", p)
        return 1
    print("APK looks sane.")
    return 0


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--skip-version"]
    if len(args) != 1:
        sys.exit(__doc__)
    sys.exit(main(args[0], skip_version="--skip-version" in sys.argv))
