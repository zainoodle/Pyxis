#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pyxis-swift-test.XXXXXX")"

cleanup() {
  case "$SCRATCH_DIR" in
    "${TMPDIR:-/tmp}"/pyxis-swift-test.*)
      find "$SCRATCH_DIR" -depth -delete 2>/dev/null || true
      ;;
    *)
      printf 'warning: refusing to clean unexpected scratch path: %s\n' "$SCRATCH_DIR" >&2
      ;;
  esac
}
trap cleanup EXIT

cd "$ROOT_DIR"
printf 'Running Swift tests with scratch directory: %s\n' "$SCRATCH_DIR"
swift test --scratch-path "$SCRATCH_DIR"
