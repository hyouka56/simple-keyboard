#!/usr/bin/env bash
set -euo pipefail

PKG=com.hyouka56.blackofflinekeyboard
COMPONENT="$PKG/rkr.simplekeyboard.inputmethod.latin.settings.SettingsActivity"
IME_COMPONENT="$PKG/rkr.simplekeyboard.inputmethod.latin.LatinIME"
mkdir -p test-results

# Never let a broken ADB/emulator transport hang this job indefinitely.
ADB_TIMEOUT_SECONDS="${ADB_TIMEOUT_SECONDS:-15}"
adb_safe() {
  timeout "${ADB_TIMEOUT_SECONDS}s" adb "$@"
}
adb_safe install -r app/build/outputs/apk/debug/app-debug.apk

# PackageManager may take a short time to register the freshly installed IME.
# Retry in a bounded loop and save diagnostics if registration never completes.
IME_ENABLED=0
for attempt in {1..10}; do
  if adb_safe shell ime enable "$IME_COMPONENT" >"test-results/ime-enable.log" 2>&1; then
    IME_ENABLED=1
    break
  fi
  echo "Waiting for IME registration after install (${attempt}/10)..." >&2
  sleep 1
done
if [[ "$IME_ENABLED" != "1" ]]; then
  adb_safe shell ime list -a >"test-results/ime-list.txt" 2>&1 || true
  adb_safe shell dumpsys package "$PKG" >"test-results/package-dump.txt" 2>&1 || true
  cat test-results/ime-enable.log >&2 || true
  echo "Simple Keyboard IME did not become available after installation." >&2
  exit 1
fi

IME_SELECTED=0
for attempt in {1..5}; do
  if adb_safe shell ime set "$IME_COMPONENT" >"test-results/ime-set.log" 2>&1; then
    IME_SELECTED=1
    break
  fi
  echo "Waiting for IME selection (${attempt}/5)..." >&2
  sleep 1
done
if [[ "$IME_SELECTED" != "1" ]]; then
  adb_safe shell ime list -a >"test-results/ime-list.txt" 2>&1 || true
  adb_safe shell dumpsys package "$PKG" >"test-results/package-dump.txt" 2>&1 || true
  cat test-results/ime-set.log >&2 || true
  echo "Simple Keyboard IME could not be selected as default." >&2
  exit 1
fi
ACTIVE_IME="$(adb_safe shell settings get secure default_input_method | tr -d '')"
if [[ "$ACTIVE_IME" != "$IME_COMPONENT" ]]; then
  echo "Failed to select Simple Keyboard. Active IME: $ACTIVE_IME" >&2
  adb_safe shell ime list -a >"test-results/ime-list.txt" 2>&1 || true
  exit 1
fi

test_screen() {
  local name="$1"
  local fragment="$2"
  adb_safe shell am force-stop "$PKG" || true
  adb_safe logcat -c
  if [[ "$fragment" == "default" ]]; then
    adb_safe shell am start -W -n "$COMPONENT"
  else
    adb_safe shell am start -W -n "$COMPONENT" --es :android:show_fragment "$fragment"
  fi
  sleep 2
  adb_safe logcat -d -b crash -v time > "test-results/${name}-crash.log" || true
  adb_safe logcat -d -s AndroidRuntime:E -v time >> "test-results/${name}-crash.log" || true
  if grep -Eq 'FATAL EXCEPTION|Unable to start activity|Process: com\\.hyouka56\\.blackofflinekeyboard' "test-results/${name}-crash.log"; then
    adb_safe logcat -d -v time > "test-results/${name}-full-logcat.txt" || true
    echo "Crash detected while opening ${name}; logcat saved." >&2
    exit 1
  fi
  adb_safe shell uiautomator dump "/sdcard/${name}-window.xml" >/dev/null
  adb_safe pull "/sdcard/${name}-window.xml" "test-results/${name}-window.xml" >/dev/null
  if grep -Fq 'Simple Keyboard is not enabled' "test-results/${name}-window.xml"; then
    echo "Settings gate is still visible during ${name}; actual settings were not tested." >&2
    exit 1
  fi
  grep -q "$PKG" "test-results/${name}-window.xml"
  python3 - "$name" "test-results/${name}-window.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

screen, path = sys.argv[1:3]
nodes = list(ET.parse(path).getroot().iter())
def matching_text(label):
    return [n for n in nodes if (n.attrib.get("text") or "").strip() == label]
def require_title(label, enabled):
    found = matching_text(label)
    assert found, f"{screen}: missing visible setting {label!r}"
    expected = str(enabled).lower()
    assert any(n.attrib.get("enabled") == expected for n in found), f"{screen}: {label!r} expected enabled={enabled}"
def interactive_controls():
    kinds = {"android.widget.Switch", "android.widget.SeekBar", "android.widget.CheckBox", "android.widget.RadioButton", "android.widget.ToggleButton"}
    return [n for n in nodes if n.attrib.get("class") in kinds or n.attrib.get("checkable") == "true"]

if screen == "keypress":
    for label in ["Sound on keypress", "Keypress sound volume", "Popup on keypress", "Key long press delay"]:
        require_title(label, False)
    controls = interactive_controls()
    assert controls, "keypress: no interactive settings controls were found"
    assert all(n.attrib.get("enabled") == "false" for n in controls), "keypress: a keypress control is enabled"
elif screen == "preferences":
    disabled = ["Auto-capitalization", "Show separate number row", "Show special characters", "Show on-screen keyboard", "Switch to other keyboards", "Space swipe cursor move", "Delete swipe"]
    for label in disabled:
        require_title(label, False)
    require_title("Show language switch key", True)
    controls = interactive_controls()
    enabled = [n for n in controls if n.attrib.get("enabled") == "true"]
    assert len(enabled) == 1, f"preferences: expected exactly one enabled interactive control, found {len(enabled)}"
    assert enabled[0].attrib.get("checked") == "true", "preferences: language-switch control must stay enabled and checked"
elif screen == "settings":
    for label in ["Languages", "Preferences", "Key press", "Appearance", "Privacy Policy", "License"]:
        require_title(label, True)
elif screen == "appearance":
    for label in ["Theme", "Set custom keyboard color", "Keyboard height", "Bottom offset"]:
        require_title(label, True)
else:
    raise AssertionError(f"Unknown settings screen {screen!r}")
print(f"PASS: {screen} runtime UI state matches the enabled/disabled policy.")
PY
  echo "PASS: ${name} settings UI opened without the IME gate or an AndroidRuntime crash."
}

test_screen settings default
test_screen keypress rkr.simplekeyboard.inputmethod.latin.settings.KeyPressSettingsFragment
test_screen preferences rkr.simplekeyboard.inputmethod.latin.settings.PreferencesSettingsFragment
test_screen appearance rkr.simplekeyboard.inputmethod.latin.settings.AppearanceSettingsFragment
