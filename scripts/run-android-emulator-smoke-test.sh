#!/usr/bin/env bash
set -euo pipefail

SERIAL="emulator-5554"
AVD_NAME="keyboard-smoke"
SYSTEM_IMAGE="system-images;android-36;google_apis;x86_64"
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
EMULATOR="$ANDROID_HOME/emulator/emulator"
ADB="${ANDROID_HOME}/platform-tools/adb"
mkdir -p test-results

for tool in "$SDKMANAGER" "$AVDMANAGER" "$EMULATOR" "$ADB"; do
  if [[ ! -x "$tool" ]]; then
    echo "Required Android SDK tool not executable: $tool" >&2
    exit 1
  fi
done

# Keep SDK/emulator diagnostics in the uploaded test artifact instead of interleaving
# them with the app's assertions. On failure, the relevant logs are printed below.
if ! "$SDKMANAGER" --install emulator "$SYSTEM_IMAGE" \
    > test-results/sdkmanager-install.log 2>&1; then
  cat test-results/sdkmanager-install.log >&2
  exit 1
fi

export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
mkdir -p "$ANDROID_AVD_HOME"
printf 'no\n' | "$AVDMANAGER" create avd --force -n "$AVD_NAME" \
  --package "$SYSTEM_IMAGE" --device pixel_2 \
  > test-results/avd-create.log 2>&1 || {
    cat test-results/avd-create.log >&2
    exit 1
  }
AVD_CONFIG="$ANDROID_AVD_HOME/${AVD_NAME}.avd/config.ini"
if [[ ! -f "$AVD_CONFIG" ]]; then
  find "$ANDROID_AVD_HOME" -maxdepth 4 -type f -print \
    > test-results/avd-created-files.txt 2>&1 || true
  echo "avdmanager did not create expected config file: $AVD_CONFIG" >&2
  cat test-results/avd-create.log >&2
  cat test-results/avd-created-files.txt >&2 || true
  exit 1
fi
printf 'hw.cpu.ncore=2\n' >> "$AVD_CONFIG"

"$ADB" start-server > test-results/adb-server-start.log 2>&1
"$EMULATOR" -port 5554 -avd "$AVD_NAME" \
  -no-window -gpu off -no-snapshot -noaudio -no-boot-anim \
  -camera-back none -no-metrics \
  > test-results/emulator.log 2>&1 &
EMULATOR_PID=$!

cleanup() {
  status=$?
  trap - EXIT
  if [[ -n "${EMULATOR_PID:-}" ]] && kill -0 "$EMULATOR_PID" 2>/dev/null; then
    "$ADB" -s "$SERIAL" emu kill > test-results/emulator-shutdown.log 2>&1 || true
    for _ in {1..10}; do
      if ! kill -0 "$EMULATOR_PID" 2>/dev/null; then break; fi
      sleep 1
    done
    if kill -0 "$EMULATOR_PID" 2>/dev/null; then
      kill -TERM "$EMULATOR_PID" 2>/dev/null || true
    fi
    wait "$EMULATOR_PID" 2>/dev/null || true
  fi
  if [[ "$status" -ne 0 ]]; then
    echo "Android emulator smoke test failed (exit $status). Last emulator diagnostics:" >&2
    tail -n 100 test-results/emulator.log >&2 2>/dev/null || true
    for f in test-results/adb-device-wait.log test-results/adb-boot-wait.log; do
      if [[ -s "$f" ]]; then echo "--- $f ---" >&2; tail -n 60 "$f" >&2; fi
    done
  fi
  exit "$status"
}
trap cleanup EXIT

# adb reports 'offline' during normal guest boot. Preserve each transient probe result
# in artifacts, but report an error only if the bounded startup deadline is exceeded.
DEVICE_READY=0
: > test-results/adb-device-wait.log
for attempt in {1..120}; do
  if "$ADB" -s "$SERIAL" get-state > test-results/adb-device-state-current.txt 2>&1 \
      && grep -qx 'device' test-results/adb-device-state-current.txt; then
    DEVICE_READY=1
    break
  fi
  printf 'attempt=%s ' "$attempt" >> test-results/adb-device-wait.log
  cat test-results/adb-device-state-current.txt >> test-results/adb-device-wait.log || true
  sleep 2
done
if [[ "$DEVICE_READY" != "1" ]]; then
  echo "Emulator did not reach adb state 'device' within 240 seconds." >&2
  cat test-results/adb-device-wait.log >&2
  exit 1
fi

BOOT_COMPLETED=0
: > test-results/adb-boot-wait.log
for attempt in {1..120}; do
  if "$ADB" -s "$SERIAL" shell getprop sys.boot_completed \
      > test-results/boot-status-current.txt 2> test-results/boot-stderr-current.txt; then
    boot_state="$(tr -d '\r\n' < test-results/boot-status-current.txt)"
    if [[ "$boot_state" == "1" ]]; then
      BOOT_COMPLETED=1
      break
    fi
  else
    boot_state="adb-command-failed"
  fi
  printf 'attempt=%s boot_state=%s\n' "$attempt" "${boot_state:-empty}" >> test-results/adb-boot-wait.log
  cat test-results/boot-stderr-current.txt >> test-results/adb-boot-wait.log 2>/dev/null || true
  sleep 2
done
if [[ "$BOOT_COMPLETED" != "1" ]]; then
  echo "Emulator did not report sys.boot_completed=1 within 240 seconds." >&2
  cat test-results/adb-boot-wait.log >&2
  exit 1
fi

echo "Emulator booted and ADB is online."
export ANDROID_SERIAL="$SERIAL"
"$ADB" -s "$SERIAL" devices -l > test-results/adb-devices.txt
for setting in window_animation_scale transition_animation_scale animator_duration_scale; do
  "$ADB" -s "$SERIAL" shell settings put global "$setting" 0
 done
bash scripts/keyboard-smoke-test.sh
