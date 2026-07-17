#!/usr/bin/env bash
set -euo pipefail

PATTERN='^(feat|fix|perf|refactor|docs|test|build|ci|chore|revert|release)(\([a-z0-9][a-z0-9._-]*\))?(!)?: .{3,}$'

validate_subject() {
  local subject="$1"
  [[ "$subject" =~ $PATTERN ]] || {
    printf 'error: commit subject must follow Conventional Commits:\n  %s\n' "$subject" >&2
    printf 'example: feat(outfits): add dotted pinboard canvas\n' >&2
    return 1
  }
}

case "${1:-}" in
  --message-file)
    [[ $# -eq 2 ]] || exit 2
    validate_subject "$(sed -n '1p' "$2")"
    ;;
  --base)
    [[ $# -ge 2 && $# -le 4 ]] || exit 2
    BASE="$2"
    HEAD="HEAD"
    if [[ $# -eq 4 && "$3" == '--head' ]]; then HEAD="$4"; elif [[ $# -ne 2 ]]; then exit 2; fi
    count=0
    while IFS= read -r subject; do
      [[ -z "$subject" ]] && continue
      validate_subject "$subject"
      count=$((count + 1))
    done < <(git log --no-merges --format=%s "$BASE..$HEAD")
    printf 'ok: validated %d commit subject(s)\n' "$count"
    ;;
  *)
    printf 'usage: %s --message-file <path> | --base <ref> [--head <ref>]\n' "$0" >&2
    exit 2
    ;;
esac
