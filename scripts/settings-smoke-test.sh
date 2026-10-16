#!/usr/bin/env bash
set -euo pipefail

PKG=com.hyouka56.blackofflinekeyboard
COMPONENT="$PKG/rkr.simplekeyboard.inputmethod.latin.settings.SettingsActivity"
mkdir -p test-results
adb install -r app/build/outputs/apk/debug/app-debug.apk

test_screen() {
  local name="$1"
  local fragment="$2"
  adb shell am force-stop "$PKG" || true
  adb logcat -c
  if [[ "$fragment" == "default" ]]; then
    adb shell am start -W -n "$COMPONENT"
  else
    adb shell am start -W -n "$COMPONENT" --es :android:show_fragment "$fragment"
  fi
  sleep 2
  adb logcat -d -b crash -v time > "test-results/${name}-crash.log" || true
  adb logcat -d -s AndroidRuntime:E -v time >> "test-results/${name}-crash.log" || true
  if grep -Eq 'FATAL EXCEPTION|Unable to start activity|Process: com\.hyouka56\.blackofflinekeyboard' "test-results/${name}-crash.log"; then
    adb logcat -d -v time > "test-results/${name}-full-logcat.txt" || true
    echo "Crash detected while opening ${name}; logcat saved." >&2
    exit 1
  fi
  adb shell uiautomator dump "/sdcard/${name}-window.xml" >/dev/null
  adb pull "/sdcard/${name}-window.xml" "test-results/${name}-window.xml" >/dev/null
  grep -q "$PKG" "test-results/${name}-window.xml"
  echo "PASS: ${name} opened without AndroidRuntime crash."
}

test_screen settings default
test_screen keypress rkr.simplekeyboard.inputmethod.latin.settings.KeyPressSettingsFragment
test_screen preferences rkr.simplekeyboard.inputmethod.latin.settings.PreferencesSettingsFragment
test_screen appearance rkr.simplekeyboard.inputmethod.latin.settings.AppearanceSettingsFragment
