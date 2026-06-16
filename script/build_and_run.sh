#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PROJECT="Pyxis.xcodeproj"
SCHEME="Pyxis"
BUNDLE_ID="com.zainoodle.pyxis"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/DerivedData"

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

run_on_booted_simulator() {
  local simulator_id
  simulator_id="$(booted_simulator_id)"
  if [[ -z "$simulator_id" ]]; then
    echo "No booted iOS Simulator found. Boot an iPhone simulator in Xcode, then rerun this script." >&2
    exit 2
  fi

  build_for_booted_simulator "$simulator_id"

  local app_path
  app_path="$(app_bundle_path)"
  if [[ -z "$app_path" ]]; then
    echo "Built app bundle was not found under DerivedData." >&2
    exit 1
  fi

  xcrun simctl install "$simulator_id" "$app_path"
  xcrun simctl launch "$simulator_id" "$BUNDLE_ID"
}

case "$MODE" in
  run)
    run_on_booted_simulator
    ;;
  --verify|verify)
    run_on_booted_simulator
    sleep 1
    xcrun simctl spawn booted launchctl print system >/dev/null
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
