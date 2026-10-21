#!/usr/bin/env bash
set -euo pipefail

PKG="com.hyouka56.blackofflinekeyboard"
IME_COMPONENT="$PKG/rkr.simplekeyboard.inputmethod.latin.LatinIME"
RESULTS="test-results"
mkdir -p "$RESULTS"

capture_diagnostics() {
  status=$?
  set +e
  timeout 15s adb logcat -d -v threadtime > "$RESULTS/ime-visibility-logcat.txt" 2>&1
  timeout 15s adb shell dumpsys input_method > "$RESULTS/ime-visibility-input-method.txt" 2>&1
  timeout 15s adb shell dumpsys window windows > "$RESULTS/ime-visibility-windows.txt" 2>&1
  timeout 15s adb shell settings get secure default_input_method > "$RESULTS/ime-visibility-active-ime.txt" 2>&1
  exit "$status"
}
trap capture_diagnostics EXIT

# This local emulator build uses x86_64 only for the runtime test. The
# production ARM64 APK is separately built, checked and uploaded by the main CI.
timeout 180s gradle --no-daemon --warning-mode=all -PkeyboardAbi=x86_64 \
  assembleDebug assembleDebugAndroidTest 2>&1 | tee "$RESULTS/ime-visibility-build.log"

timeout 30s adb install -r app/build/outputs/apk/debug/app-debug.apk \
  2>&1 | tee "$RESULTS/ime-visibility-install.log"
timeout 30s adb shell ime list -a > "$RESULTS/ime-visibility-ime-list.txt" 2>&1
if ! grep -Fq "$IME_COMPONENT" "$RESULTS/ime-visibility-ime-list.txt"; then
  echo "Target keyboard service is absent from the emulator IME registry." >&2
  cat "$RESULTS/ime-visibility-ime-list.txt" >&2
  exit 1
fi
timeout 30s adb shell settings put secure show_ime_with_hard_keyboard 1
timeout 30s adb shell ime enable "$IME_COMPONENT" 2>&1 \
  | tee "$RESULTS/ime-visibility-enable.log"
timeout 30s adb shell ime set "$IME_COMPONENT" 2>&1 \
  | tee "$RESULTS/ime-visibility-set.log"
ACTIVE_IME="$(timeout 30s adb shell settings get secure default_input_method | tr -d '\r')"
printf '%s\n' "$ACTIVE_IME" > "$RESULTS/ime-visibility-selected-ime.txt"
if [[ "$ACTIVE_IME" != "$IME_COMPONENT" ]]; then
  echo "Could not select target keyboard; active IME is '$ACTIVE_IME'." >&2
  exit 1
fi

timeout 300s gradle --no-daemon --warning-mode=all -PkeyboardAbi=x86_64 \
  connectedDebugAndroidTest 2>&1 | tee "$RESULTS/ime-visibility-test.log"
