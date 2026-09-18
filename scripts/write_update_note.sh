#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 5 ]] || { printf 'error: write_update_note.sh is an internal helper\n' >&2; exit 2; }

PATHNAME="$1"
TYPE="$2"
BUMP="$3"
AREA="$4"
SUMMARY="$5"

if [[ -e "$PATHNAME" ]]; then
  printf 'error: refusing to overwrite %s\n' "$PATHNAME" >&2
  exit 1
fi

printf '%s\n' \
  '---' \
  "type: $TYPE" \
  "bump: $BUMP" \
  "area: $AREA" \
  "summary: $SUMMARY" \
  '---' \
  '' \
  '## Details' \
  '' \
  '- Describe the behavior or process change.' \
  '' \
  '## Verification' \
  '' \
  '- Record the command or manual check used to verify the update.' > "$PATHNAME"
