---
name: verify
description: How to smoke-test this app end-to-end on the Android emulator — build/launch/drive recipe and gotchas.
---

# Verifying mtg_life_tracker on a device

Android is the primary surface (no windows/ or web/ targets). Real surface =
Android emulator.

## Launch

```
flutter emulators --launch Pixel_3a_API_34_extension_level_7_x86_64
# wait for: adb shell getprop sys.boot_completed -> 1
flutter run -d emulator-5554 --debug
```

adb lives at `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` (not on PATH).
Package id: `com.nicksullivan.mtg_life_tracker`.

An emulator is usually already running. Check `adb devices` via that full
path before launching one, and never conclude "no emulator" from a bare `adb`
or from `flutter emulators`.

Install a build with `flutter build apk --debug` then
`adb install -r build/app/outputs/flutter-apk/app-debug.apk`; `-r` keeps app
data, so this is also how to test upgrading from an older build.

## Drive & observe

- Screenshot: `adb exec-out screencap -p > shot.png`
- Tap: `adb shell input tap X Y` (Pixel 3a: 1080x2220)
- Prefs: `adb shell run-as <pkg> cat shared_prefs/FlutterSharedPreferences.xml`
  (keys prefixed `flutter.`)
- Relaunch: `adb shell am force-stop <pkg> && adb shell am start -n <pkg>/.MainActivity`

## Gotchas

- PowerShell tool transport sometimes strips double quotes in multi-line
  commands — use the Bash tool for adb work.
- Git Bash mangles `/data/...` into `C:/Program Files/Git/data/...`;
  `export MSYS_NO_PATHCONV=1` first.
- The user also uses the emulator between runs — save
  `FlutterSharedPreferences.xml` before driving the UI and restore anything you
  changed afterwards.
- Before tapping, confirm the app is in front:
  `adb shell dumpsys activity activities | grep -m1 topResumedActivity`.
- `adb shell input text` goes through the device shell: `>`, `<`, `|`, `(`,
  quotes etc. get interpreted.
