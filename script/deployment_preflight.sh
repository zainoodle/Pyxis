#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-local}"
PROJECT="Pyxis.xcodeproj"
SCHEME="Pyxis"
BUNDLE_ID="com.zainoodle.pyxis"
VERSION="1.0"
BUILD_NUMBER="1"
SUPPORT_EMAIL="zainoodle@gmail.com"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/DerivedDataPreflight"
UNSIGNED_ARCHIVE="/private/tmp/PyxisPreflightUnsigned.xcarchive"
SIGNED_ARCHIVE="/private/tmp/PyxisPreflightSigned.xcarchive"
EXPORT_PATH="/private/tmp/PyxisPreflightExport"
LOG_DIR="${TMPDIR:-/tmp}/pyxis-preflight-$(date +%Y%m%d-%H%M%S)"

cd "$ROOT_DIR"

cleanup() {
  rm -rf "$DERIVED_DATA" "$UNSIGNED_ARCHIVE" "$SIGNED_ARCHIVE" "$EXPORT_PATH"
}
trap cleanup EXIT

usage() {
  cat <<'USAGE' >&2
usage: ./script/deployment_preflight.sh [static|local|distribution]

static        Lint metadata and run source/documentation policy scans.
local         static checks, Swift tests, unsigned Release build, and unsigned archive.
distribution local checks plus signed archive inspection and App Store export attempt.

distribution requires App Store Connect provider access and an App Store distribution profile.
USAGE
}

step() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

run_logged() {
  local label="$1"
  local log_file="$2"
  shift 2

  step "$label"
  if "$@" >"$log_file" 2>&1; then
    printf 'ok: %s (log: %s)\n' "$label" "$log_file"
  else
    printf 'failed: %s (log: %s)\n' "$label" "$log_file" >&2
    tail -n 100 "$log_file" >&2 || true
    exit 1
  fi
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $2" "$1"
}

assert_plist_value() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local actual
  actual="$(plist_value "$plist" "$key")"
  [[ "$actual" == "$expected" ]] || fail "$plist $key expected '$expected' but found '$actual'"
}

assert_plist_key_absent() {
  local plist="$1"
  local key="$2"

  if plist_value "$plist" "$key" >/dev/null 2>&1; then
    fail "$plist $key should not be present"
  fi
}

expect_no_matches() {
  local label="$1"
  shift

  step "$label"
  if rg -n "$@"; then
    fail "$label found matches"
  fi
  printf 'ok: %s\n' "$label"
}

lint_metadata() {
  step "lint plists and asset JSON"
  plutil -lint deployment/ExportOptions-AppStoreConnect.plist Pyxis/PrivacyInfo.xcprivacy
  python3 -c 'import plistlib, sys
path = "Pyxis/PrivacyInfo.xcprivacy"
with open(path, "rb") as handle:
    manifest = plistlib.load(handle)
expected_empty_arrays = [
    "NSPrivacyAccessedAPITypes",
    "NSPrivacyTrackingDomains",
]
expected_collection = [{
    "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypePhotosorVideos",
    "NSPrivacyCollectedDataTypeLinked": False,
    "NSPrivacyCollectedDataTypeTracking": False,
    "NSPrivacyCollectedDataTypePurposes": ["NSPrivacyCollectedDataTypePurposeAppFunctionality"],
}]
errors = []
if manifest.get("NSPrivacyTracking") is not False:
    errors.append("NSPrivacyTracking must be false")
for key in expected_empty_arrays:
    if manifest.get(key) != []:
        errors.append(f"{key} must be an empty array")
if manifest.get("NSPrivacyCollectedDataTypes") != expected_collection:
    errors.append("NSPrivacyCollectedDataTypes must declare unlinked, non-tracking photos for app functionality")
if errors:
    print("; ".join(errors), file=sys.stderr)
    sys.exit(1)' || fail "privacy manifest does not match the local-core and opt-in AI posture"
  while IFS= read -r -d '' json_file; do
    python3 -m json.tool "$json_file" >/dev/null || fail "invalid asset catalog JSON: $json_file"
  done < <(find Pyxis/Assets.xcassets -name Contents.json -print0)

  local icon_path="Pyxis/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
  [[ -f "$icon_path" ]] || fail "missing 1024px App Store icon source"

  local icon_info icon_width icon_height icon_alpha
  icon_info="$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$icon_path")"
  icon_width="$(awk -F': ' '/pixelWidth:/ { print $2 }' <<<"$icon_info")"
  icon_height="$(awk -F': ' '/pixelHeight:/ { print $2 }' <<<"$icon_info")"
  icon_alpha="$(awk -F': ' '/hasAlpha:/ { print $2 }' <<<"$icon_info")"
  [[ "$icon_width" == "1024" && "$icon_height" == "1024" ]] || fail "App Store icon must be 1024x1024 pixels"
  [[ "$icon_alpha" == "no" ]] || fail "App Store icon must not include an alpha channel"
}

scan_policy() {
  expect_no_matches \
    "scan for prohibited analytics and embedded AI secrets" \
    "analytics|telemetry|Firebase|Amplitude|Mixpanel|sk-[A-Za-z0-9_-]{20,}|OPENAI_API_KEY|XAI_API_KEY" \
    Pyxis Package.swift -g '!PrivacyInfo.xcprivacy'

  expect_no_matches \
    "scan for required-reason API usage missing from privacy manifest" \
    "UserDefaults|NSUbiquitousKeyValueStore|creationDate|contentModificationDate|contentModificationDateKey|fileModificationDate|modificationDate|volumeAvailableCapacity|volumeAvailableCapacityForImportantUsage|volumeAvailableCapacityForOpportunisticUsage|volumeTotalCapacity|systemFreeSize|systemSize|statfs|statvfs|mach_absolute_time|systemUptime|CACurrentMediaTime" \
    Pyxis Package.swift -g '!PrivacyInfo.xcprivacy'

  expect_no_matches \
    "scan publishable deployment docs for placeholders" \
    "TODO|FIXME|PLACEHOLDER|TBD|XXX|TODO:|localhost|example\\.com|YOUR_|INSERT|placeholder" \
    docs/APP_STORE_SUBMISSION.md docs/SUPPORT.md docs/PRIVACY_POLICY.md README.md docs/DEPLOYMENT_READINESS.md

  step "check support contact consistency"
  rg -q "$SUPPORT_EMAIL" docs/SUPPORT.md || fail "docs/SUPPORT.md must include $SUPPORT_EMAIL"
  rg -q "$SUPPORT_EMAIL" docs/PRIVACY_POLICY.md || fail "docs/PRIVACY_POLICY.md must include $SUPPORT_EMAIL"
  printf 'ok: support contact consistency\n'
}

check_git_whitespace() {
  step "check diff whitespace"
  git diff --check
  printf 'ok: diff whitespace\n'
}

assert_app_metadata() {
  local app_path="$1"
  local info_plist="$app_path/Info.plist"

  [[ -d "$app_path" ]] || fail "missing app bundle: $app_path"
  [[ -f "$app_path/PrivacyInfo.xcprivacy" ]] || fail "missing bundled PrivacyInfo.xcprivacy"
  find "$app_path" -maxdepth 1 -name 'AppIcon*' -print -quit | grep -q . || fail "missing compiled app icon files in $app_path"

  assert_plist_value "$info_plist" ":CFBundleIdentifier" "$BUNDLE_ID"
  assert_plist_value "$info_plist" ":CFBundleDisplayName" "Pyxis"
  assert_plist_value "$info_plist" ":CFBundleShortVersionString" "$VERSION"
  assert_plist_value "$info_plist" ":CFBundleVersion" "$BUILD_NUMBER"
  assert_plist_value "$info_plist" ":LSApplicationCategoryType" "public.app-category.lifestyle"
  assert_plist_value "$info_plist" ":NSCameraUsageDescription" "Take photos of clothing items to save locally in Pyxis."
  assert_plist_value "$info_plist" ":NSPhotoLibraryUsageDescription" "Select clothing photos to save locally in Pyxis."
  assert_plist_value "$info_plist" ":CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName" "AppIcon"
  assert_plist_value "$info_plist" ":UIDeviceFamily:0" "1"
  assert_plist_key_absent "$info_plist" ":UIDeviceFamily:1"
  assert_plist_value "$info_plist" ":MinimumOSVersion" "17.0"
}

assert_no_release_debug_content() {
  local app_path="$1"
  local matches

  matches="$(
    find "$app_path" -type f -print0 \
      | xargs -0 strings 2>/dev/null \
      | rg -n "SEED CLOSET|DEMO IMAGE|Debug seed item|DEMO-[A-Z]{2}-[0-9]{3}|Pyxis-black-shirt-demo|Sample closet already seeded|Seeded [0-9]+ items" || true
  )"

  if [[ -n "$matches" ]]; then
    printf '%s\n' "$matches" >&2
    fail "release app contains debug-only sample content"
  fi
}

run_static_checks() {
  mkdir -p "$LOG_DIR"
  require_command rg
  require_command plutil
  require_command python3
  require_command git
  require_command sips
  require_command strings

  ./script/validate_update_notes.sh --all
  lint_metadata
  scan_policy
  check_git_whitespace
}

run_local_checks() {
  require_command swift
  require_command xcodebuild

  run_static_checks

  run_logged "swift test" "$LOG_DIR/swift-test.log" swift test

  run_logged \
    "generic Release iOS build" \
    "$LOG_DIR/release-build.log" \
    xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration Release \
      -destination generic/platform=iOS \
      -derivedDataPath "$DERIVED_DATA" \
      CODE_SIGNING_ALLOWED=NO \
      build

  assert_app_metadata "$DERIVED_DATA/Build/Products/Release-iphoneos/$SCHEME.app"
  assert_no_release_debug_content "$DERIVED_DATA/Build/Products/Release-iphoneos/$SCHEME.app"

  run_logged \
    "unsigned Release archive" \
    "$LOG_DIR/unsigned-archive.log" \
    xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration Release \
      -destination generic/platform=iOS \
      -archivePath "$UNSIGNED_ARCHIVE" \
      CODE_SIGNING_ALLOWED=NO \
      archive

  assert_app_metadata "$UNSIGNED_ARCHIVE/Products/Applications/$SCHEME.app"
  assert_no_release_debug_content "$UNSIGNED_ARCHIVE/Products/Applications/$SCHEME.app"
}

run_distribution_checks() {
  run_local_checks

  run_logged \
    "signed Release archive" \
    "$LOG_DIR/signed-archive.log" \
    xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration Release \
      -destination generic/platform=iOS \
      -archivePath "$SIGNED_ARCHIVE" \
      archive

  assert_app_metadata "$SIGNED_ARCHIVE/Products/Applications/$SCHEME.app"
  assert_no_release_debug_content "$SIGNED_ARCHIVE/Products/Applications/$SCHEME.app"

  local entitlements="$LOG_DIR/signed-entitlements.plist"
  codesign -d --entitlements :- "$SIGNED_ARCHIVE/Products/Applications/$SCHEME.app" >"$entitlements" 2>/dev/null
  if [[ "$(plist_value "$entitlements" ":get-task-allow" 2>/dev/null || true)" == "true" ]]; then
    fail "signed archive is development-signed with get-task-allow=true; create an App Store distribution profile/certificate before export"
  fi

  run_logged \
    "App Store Connect export" \
    "$LOG_DIR/app-store-export.log" \
    xcodebuild \
      -exportArchive \
      -archivePath "$SIGNED_ARCHIVE" \
      -exportPath "$EXPORT_PATH" \
      -exportOptionsPlist deployment/ExportOptions-AppStoreConnect.plist
}

case "$MODE" in
  static)
    run_static_checks
    ;;
  local)
    run_local_checks
    ;;
  distribution)
    run_distribution_checks
    ;;
  --help|-h|help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

printf '\nDeployment preflight (%s) passed. Logs: %s\n' "$MODE" "$LOG_DIR"
