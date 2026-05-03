#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${REPO_DIR}"

IOS_INTEGRATION_DEVICE="${IOS_INTEGRATION_DEVICE:-}"
ANDROID_DEVICE="${ANDROID_DEVICE:-}"
PATROL_TARGET="${PATROL_TARGET:-patrol_test/smoke_test.dart}"
INTEGRATION_TARGET="${INTEGRATION_TARGET:-integration_test/app_flow_test.dart}"
PATROL_DEVICES_TIMEOUT_SECONDS="${PATROL_DEVICES_TIMEOUT_SECONDS:-15}"

# If true, missing integration/patrol targets are errors instead of skips.
REQUIRE_INTEGRATION_TARGET="${REQUIRE_INTEGRATION_TARGET:-false}"
REQUIRE_PATROL_TARGET="${REQUIRE_PATROL_TARGET:-false}"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
}

detect_android_device() {
  local device
  device="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
  if [[ -z "$device" ]]; then
    echo "No attached Android device found." >&2
    exit 1
  fi
  printf '%s\n' "$device"
}

detect_ios_simulator() {
  local device
  device="$(python3 - <<'PY'
import json
import subprocess
import sys

result = subprocess.run(
    ["flutter", "devices", "--machine"],
    capture_output=True,
    text=True,
    check=False,
)
if result.returncode != 0:
    sys.exit(1)

try:
    devices = json.loads(result.stdout)
except json.JSONDecodeError:
    sys.exit(1)

for d in devices:
    if d.get("targetPlatform") == "ios" and d.get("emulator") is True:
        print(d.get("id", ""))
        sys.exit(0)

sys.exit(1)
PY
)"
  if [[ -z "$device" ]]; then
    echo "No available iOS simulator found via 'flutter devices'." >&2
    exit 1
  fi
  printf '%s\n' "$device"
}

patrol_devices_with_timeout() {
  python3 - <<'PY'
import os
import subprocess
import sys

timeout = int(os.environ.get("PATROL_DEVICES_TIMEOUT_SECONDS", "15"))
try:
    result = subprocess.run(
        ["patrol", "devices"],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
except subprocess.TimeoutExpired:
    sys.stderr.write(f"patrol devices timed out after {timeout}s\\n")
    sys.exit(124)

if result.stdout:
    sys.stdout.write(result.stdout)
if result.stderr:
    sys.stderr.write(result.stderr)
sys.exit(result.returncode)
PY
}

wait_for_patrol_device() {
  local device_id="$1"
  local attempts=30
  local devices_output

  for ((i = 1; i <= attempts; i += 1)); do
    devices_output="$(patrol_devices_with_timeout || true)"
    if grep -Fq "$device_id" <<<"$devices_output"; then
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for Patrol device: $device_id" >&2
  patrol_devices_with_timeout || true
  exit 1
}

run_step() {
  local description="$1"
  shift
  printf '\n==> %s\n' "$description"
  "$@"
}

run_optional_repo_check() {
  local rel_script="$1"
  local arg="$2"
  local abs_script="${REPO_DIR}/${rel_script}"

  if [[ -x "$abs_script" ]]; then
    run_step "${rel_script} ${arg}" "$abs_script" "$arg"
  else
    echo "==> skipping ${rel_script} (not found/executable)"
  fi
}

require_command flutter
require_command dart
require_command adb
require_command pod
require_command python3

if [[ -z "$ANDROID_DEVICE" ]]; then
  ANDROID_DEVICE="$(detect_android_device)"
fi

if [[ -z "$IOS_INTEGRATION_DEVICE" ]]; then
  IOS_INTEGRATION_DEVICE="$(detect_ios_simulator)"
fi

printf '==> using Android device: %s\n' "$ANDROID_DEVICE"
printf '==> using iOS integration simulator: %s\n' "$IOS_INTEGRATION_DEVICE"

cd "$REPO_DIR"
run_optional_repo_check "scripts/check_file_sizes.sh" "."
echo "==> skipping scripts/check_premium_policy_usage.sh (disabled for now)"

cd "$APP_DIR"
run_step "flutter clean" flutter clean
run_step "flutter pub get" flutter pub get
run_step "pod install" bash -lc 'cd ios && pod install'
run_step "flutter test" flutter test

if [[ -f "$INTEGRATION_TARGET" ]]; then
  run_step "flutter integration test on Android (${ANDROID_DEVICE})" \
    flutter test "$INTEGRATION_TARGET" -d "$ANDROID_DEVICE"
  run_step "flutter integration test on iOS (${IOS_INTEGRATION_DEVICE})" \
    flutter test "$INTEGRATION_TARGET" -d "$IOS_INTEGRATION_DEVICE"
else
  if [[ "$REQUIRE_INTEGRATION_TARGET" == "true" ]]; then
    echo "Integration target not found: $INTEGRATION_TARGET" >&2
    exit 1
  fi
  echo "==> skipping integration tests (target not found: $INTEGRATION_TARGET)"
fi

if [[ -f "$PATROL_TARGET" ]]; then
  require_command patrol
  wait_for_patrol_device "$ANDROID_DEVICE"
  run_step "patrol test ${PATROL_TARGET} on Android (${ANDROID_DEVICE})" \
    patrol test --target "$PATROL_TARGET" --device "$ANDROID_DEVICE"
else
  if [[ "$REQUIRE_PATROL_TARGET" == "true" ]]; then
    echo "Patrol target not found: $PATROL_TARGET" >&2
    exit 1
  fi
  echo "==> skipping patrol tests (target not found: $PATROL_TARGET)"
fi
