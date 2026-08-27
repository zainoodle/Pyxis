#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE' >&2
usage: ./script/new_update_note.sh <type> <area> <summary> [bump]

type     added|changed|deprecated|removed|fixed|security
area     short kebab-case area, used in the filename and metadata
summary  concise user-facing sentence
bump     none|patch|minor|major (default: patch)
USAGE
}

[[ $# -ge 3 && $# -le 4 ]] || { usage; exit 2; }

TYPE="$1"
AREA="$2"
SUMMARY="$3"
BUMP="${4:-patch}"

[[ "$TYPE" =~ ^(added|changed|deprecated|removed|fixed|security)$ ]] || { printf 'error: invalid type: %s\n' "$TYPE" >&2; exit 1; }
[[ "$BUMP" =~ ^(none|patch|minor|major)$ ]] || { printf 'error: invalid bump: %s\n' "$BUMP" >&2; exit 1; }
[[ "$AREA" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { printf 'error: area must be kebab-case\n' >&2; exit 1; }
[[ ${#SUMMARY} -ge 10 && ${#SUMMARY} -le 140 ]] || { printf 'error: summary must be 10-140 characters\n' >&2; exit 1; }

DATE="$(date +%F)"
BASE_PATH="$ROOT_DIR/changes/$DATE-$AREA.md"
PATHNAME="$BASE_PATH"
INDEX=2
while [[ -e "$PATHNAME" ]]; do
  PATHNAME="${BASE_PATH%.md}-$INDEX.md"
  INDEX=$((INDEX + 1))
done

apply_fragment() {
  local patch_file="$1"
  "$ROOT_DIR/script/write_update_note.sh" "$patch_file" "$TYPE" "$BUMP" "$AREA" "$SUMMARY"
}

apply_fragment "$PATHNAME"
printf 'created %s\n' "${PATHNAME#"$ROOT_DIR/"}"
