#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PROJECT="Pyxis.xcodeproj"
SCHEME="Pyxis"
BUNDLE_ID="com.zainoodle.pyxis"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/pyxis-derived-data.XXXXXX")"
LAUNCHED_PID=""

cleanup() {
  case "$DERIVED_DATA" in
    "${TMPDIR:-/tmp}"/pyxis-derived-data.*)
      find "$DERIVED_DATA" -depth -delete 2>/dev/null || true
      ;;
    *)
      printf 'warning: refusing to clean unexpected DerivedData path: %s\n' "$DERIVED_DATA" >&2
      ;;
  esac
}
trap cleanup EXIT

resolve_developer_dir() {
  local selected="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}"

  if [[ "$selected" == */CommandLineTools ]]; then
    if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
      selected="/Applications/Xcode.app/Contents/Developer"
      printf 'Using Xcode at %s (Command Line Tools are globally selected).\n' "$selected" >&2
    else
      printf '%s\n' \
        'error: Full Xcode is required. Install Xcode or set DEVELOPER_DIR to its Contents/Developer directory.' >&2
      exit 2
    fi
  fi

  if [[ ! -x "$selected/usr/bin/xcodebuild" ]]; then
    printf 'error: DEVELOPER_DIR does not point to a full Xcode installation: %s\n' "$selected" >&2
    exit 2
  fi

  printf '%s' "$selected"
}

DEVELOPER_DIR="$(resolve_developer_dir)"
export DEVELOPER_DIR

cd "$ROOT_DIR"

booted_simulator_id() {
  xcrun simctl list devices booted | awk -F '[()]' '/Booted/{print $2; exit}'
}

build_for_booted_simulator() {
  local simulator_id="$1"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "id=$simulator_id" \
    -derivedDataPath "$DERIVED_DATA" \
    build
}

app_bundle_path() {
  find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -maxdepth 2 -name "$SCHEME.app" -type d | head -n 1
}

terminate_existing_app() {
  local simulator_id="$1"
  xcrun simctl terminate "$simulator_id" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

run_on_booted_simulator() {
  local simulator_id
  simulator_id="$(booted_simulator_id)"
  if [[ -z "$simulator_id" ]]; then
    if ! xcrun simctl list runtimes available | grep -q 'iOS'; then
      echo "No available iOS Simulator runtime is installed. Install one from Xcode > Settings > Components, create and boot an iPhone simulator, then rerun this script." >&2
    else
      echo "No booted iOS Simulator found. Boot an iPhone simulator in Xcode, then rerun this script." >&2
    fi
    exit 2
  fi

  build_for_booted_simulator "$simulator_id"

  local app_path
  app_path="$(app_bundle_path)"
  if [[ -z "$app_path" ]]; then
    echo "Built app bundle was not found under DerivedData." >&2
    exit 1
  fi

  terminate_existing_app "$simulator_id"
  xcrun simctl install "$simulator_id" "$app_path"
  local launch_output
  launch_output="$(xcrun simctl launch "$simulator_id" "$BUNDLE_ID")"
  echo "$launch_output"

  LAUNCHED_PID="${launch_output##*: }"
  if [[ ! "$LAUNCHED_PID" =~ ^[0-9]+$ ]]; then
    echo "Could not parse launched app pid from simctl output: $launch_output" >&2
    exit 1
  fi
}

verify_launched_app() {
  if [[ -z "$LAUNCHED_PID" ]]; then
    echo "No launched app pid was captured." >&2
    exit 1
  fi

  # Simulator app processes are host processes. Checking the host PID works
  # across runtimes where `simctl spawn ... /bin/ps` is unavailable.
  if ! kill -0 "$LAUNCHED_PID" 2>/dev/null; then
    echo "Launched app process $LAUNCHED_PID is no longer running." >&2
    exit 1
  fi
}

case "$MODE" in
  run)
    run_on_booted_simulator
    ;;
  --verify|verify)
    run_on_booted_simulator
    sleep 1
    verify_launched_app
    ;;
  --logs|logs)
    run_on_booted_simulator
    xcrun simctl spawn booted log stream --info --style compact --predicate "process == \"$SCHEME\""
    ;;
  --debug|debug)
    echo "Open $PROJECT in Xcode, select the $SCHEME scheme and a device/simulator, then run with the debugger." >&2
    exit 2
    ;;
  *)
    echo "usage: $0 [run|--verify|--logs|--debug]" >&2
    exit 2
    ;;
esac
