#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'USAGE' >&2
usage:
  ./scripts/validate_update_notes.sh --all
  ./scripts/validate_update_notes.sh --base <git-ref> [--head <git-ref>]
USAGE
}

validate_fragment() {
  local path="$1"
  local content="${2:-$1}"
  local filename type bump area summary

  [[ -f "$content" ]] || fail "missing change fragment: $path"
  filename="${path##*/}"
  [[ "$filename" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] || fail "$path must use YYYY-MM-DD-kebab-case.md"
  [[ "$(sed -n '1p' "$content")" == '---' ]] || fail "$path must start with YAML front matter"
  [[ "$(sed -n '6p' "$content")" == '---' ]] || fail "$path front matter must contain exactly type, bump, area, and summary"

  type="$(sed -n 's/^type: //p' "$content" | head -n 1)"
  bump="$(sed -n 's/^bump: //p' "$content" | head -n 1)"
  area="$(sed -n 's/^area: //p' "$content" | head -n 1)"
  summary="$(sed -n 's/^summary: //p' "$content" | head -n 1)"

  [[ "$type" =~ ^(added|changed|deprecated|removed|fixed|security)$ ]] || fail "$path has invalid type '$type'"
  [[ "$bump" =~ ^(none|patch|minor|major)$ ]] || fail "$path has invalid bump '$bump'"
  [[ "$area" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "$path area must be kebab-case"
  [[ ${#summary} -ge 10 && ${#summary} -le 140 ]] || fail "$path summary must be 10-140 characters"
  grep -Eq '^## Details$' "$content" || fail "$path must include a Details section"
  grep -Eq '^## Verification$' "$content" || fail "$path must include a Verification section"
  grep -Eq '^- .+' "$content" || fail "$path must include at least one bullet"
}

MODE="${1:-}"
case "$MODE" in
  --all)
    fragments=()
    while IFS= read -r path; do fragments+=("$path"); done < <(
      find changes -maxdepth 1 -type f -name '*.md' ! -name README.md ! -name template.md -print | sort
    )
    ;;
  --base)
    [[ $# -ge 2 && $# -le 4 ]] || { usage; exit 2; }
    BASE="$2"
    HEAD="HEAD"
    if [[ $# -eq 4 && "$3" == '--head' ]]; then HEAD="$4"; elif [[ $# -ne 2 ]]; then usage; exit 2; fi
    git rev-parse --verify "$BASE^{commit}" >/dev/null 2>&1 || fail "unknown base ref: $BASE"
    git rev-parse --verify "$HEAD^{commit}" >/dev/null 2>&1 || fail "unknown head ref: $HEAD"

    fragments=()
    while IFS= read -r path; do
      [[ -n "$path" ]] && fragments+=("$path")
    done < <(git diff --name-only --diff-filter=AR "$BASE" "$HEAD" -- ':(top,glob)changes/*.md' ':(top,glob)changes/archive/**/*.md' | grep -Ev '^changes/(README|template)\.md$' || true)

    changed_files="$(git diff --name-only "$BASE" "$HEAD" | grep -Ev '^changes/(README|template)\.md$' || true)"
    if [[ -n "$changed_files" && ${#fragments[@]} -eq 0 ]]; then
      fail "this PR changes files but adds no new change fragment; run ./scripts/new_update_note.sh"
    fi
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ ${#fragments[@]} -gt 0 ]]; then
  if [[ "$MODE" == --base ]]; then
    CONTENT_FILE="$(mktemp)"
    trap 'rm -f "$CONTENT_FILE"' EXIT
    for path in "${fragments[@]}"; do
      git show "$HEAD:$path" > "$CONTENT_FILE" || fail "missing committed fragment: $path"
      validate_fragment "$path" "$CONTENT_FILE"
    done
  else
    for path in "${fragments[@]}"; do validate_fragment "$path"; done
  fi
fi
printf 'ok: validated %d change fragment(s)\n' "${#fragments[@]}"
