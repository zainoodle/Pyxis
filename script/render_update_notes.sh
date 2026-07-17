#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-Unreleased}"
DATE="$(date +%F)"

./script/validate_update_notes.sh --all >/dev/null

if [[ "$VERSION" == "Unreleased" ]]; then
  printf '## Unreleased\n\n'
else
  printf '## [%s] - %s\n\n' "$VERSION" "$DATE"
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
  entries=()
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    rg -q "^type: $type$" "$path" && entries+=("$path")
  done < <(find changes -maxdepth 1 -type f -name '*.md' ! -name README.md ! -name template.md -print | sort)
  [[ ${#entries[@]} -gt 0 ]] || continue
  printf '### %s\n\n' "$heading"
  for path in "${entries[@]}"; do
    summary="$(sed -n 's/^summary: //p' "$path" | head -n 1)"
    area="$(sed -n 's/^area: //p' "$path" | head -n 1)"
    printf -- '- %s (`%s`)\n' "$summary" "$area"
  done
  printf '\n'
done
