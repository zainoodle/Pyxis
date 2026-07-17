#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[[ $# -eq 2 ]] || { printf 'usage: ./script/render_push_notes.sh <base-ref> <head-ref>\n' >&2; exit 2; }
BASE="$1"
HEAD="$2"

./script/validate_update_notes.sh --base "$BASE" --head "$HEAD" >/dev/null

fragments=()
while IFS= read -r path; do
  [[ -n "$path" ]] && fragments+=("$path")
done < <(git diff --name-only --diff-filter=AR "$BASE" "$HEAD" -- 'changes/*.md' 'changes/archive/**/*.md' | rg -v '^changes/(README|template)\.md$' || true)

printf '## Push update notes\n\n'
if [[ ${#fragments[@]} -eq 0 ]]; then
  printf 'No repository content changed in this ref update.\n'
  exit 0
fi

for type in added changed deprecated removed fixed security; do
  case "$type" in
    added) heading="Added" ;;
    changed) heading="Changed" ;;
    deprecated) heading="Deprecated" ;;
    removed) heading="Removed" ;;
    fixed) heading="Fixed" ;;
    security) heading="Security" ;;
  esac
  matching=()
  for path in "${fragments[@]}"; do
    rg -q "^type: $type$" "$path" && matching+=("$path")
  done
  [[ ${#matching[@]} -gt 0 ]] || continue
  printf '### %s\n\n' "$heading"
  for path in "${matching[@]}"; do
    summary="$(sed -n 's/^summary: //p' "$path" | head -n 1)"
    area="$(sed -n 's/^area: //p' "$path" | head -n 1)"
    bump="$(sed -n 's/^bump: //p' "$path" | head -n 1)"
    printf -- '- %s (`%s`, `%s`)\n' "$summary" "$area" "$bump"
  done
  printf '\n'
done
