#!/usr/bin/env bash
set -euo pipefail

PKG="com.hyouka56.blackofflinekeyboard"
IME_COMPONENT="$PKG/rkr.simplekeyboard.inputmethod.latin.LatinIME"
SETTINGS_COMPONENT="$PKG/rkr.simplekeyboard.inputmethod.latin.settings.SettingsActivity"
APK="app/build/outputs/apk/debug/app-debug.apk"
ADB_TIMEOUT_SECONDS="${ADB_TIMEOUT_SECONDS:-30}"
mkdir -p test-results

# Bound ADB calls so a broken emulator transport cannot hang the job indefinitely.
adb_safe() {
  timeout "${ADB_TIMEOUT_SECONDS}s" adb "$@"
}

adb_safe install -r "$APK" | tee test-results/install.log
adb_safe shell ime list -a > test-results/ime-list.txt
grep -Fq "$IME_COMPONENT" test-results/ime-list.txt || {
  echo "The installed keyboard service is missing from Android's IME registry." >&2
  cat test-results/ime-list.txt >&2
  exit 1
}
echo "PASS: keyboard input-method service is registered."

IME_ENABLED=0
for attempt in {1..10}; do
  if adb_safe shell ime enable "$IME_COMPONENT" > test-results/ime-enable.log 2>&1; then
    IME_ENABLED=1
    break
  fi
  sleep 1
done
if [[ "$IME_ENABLED" != "1" ]]; then
  cat test-results/ime-enable.log >&2
  echo "Failed to enable the keyboard input method." >&2
  exit 1
fi

IME_SELECTED=0
for attempt in {1..10}; do
  if adb_safe shell ime set "$IME_COMPONENT" > test-results/ime-set.log 2>&1; then
    IME_SELECTED=1
    break
  fi
  sleep 1
done
if [[ "$IME_SELECTED" != "1" ]]; then
  cat test-results/ime-set.log >&2
  echo "Failed to select the keyboard input method." >&2
  exit 1
fi

ACTIVE_IME="$(adb_safe shell settings get secure default_input_method | tr -d '\r')"
printf '%s\n' "$ACTIVE_IME" > test-results/active-ime.txt
[[ "$ACTIVE_IME" == "$IME_COMPONENT" ]] || {
  echo "Expected active IME '$IME_COMPONENT'; received '$ACTIVE_IME'." >&2
  exit 1
}
echo "PASS: Android can enable and select the keyboard-only IME."

# The settings Activity is intentionally no longer declared in the manifest.
adb_safe shell am start -W -n "$SETTINGS_COMPONENT" > test-results/removed-settings-activity.txt 2>&1 || true
if ! grep -Eiq 'Error type 3|Activity class .* does not exist|No activity found' test-results/removed-settings-activity.txt; then
  cat test-results/removed-settings-activity.txt >&2
  echo "The removed settings Activity still appears to be launchable." >&2
  exit 1
fi
echo "PASS: no in-app Settings Activity is registered or launchable."
