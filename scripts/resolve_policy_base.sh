#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 2
base="$1"
head="$2"
git rev-parse --verify "$base^{commit}" >/dev/null
git rev-parse --verify "$head^{commit}" >/dev/null

# Legacy commits predate Conventional Commits enforcement. Preserve that
# boundary across the script/ -> scripts/ directory migration.
if ! git cat-file -e "$base:scripts/validate_commit_messages.sh" 2>/dev/null && \
   ! git cat-file -e "$base:script/validate_commit_messages.sh" 2>/dev/null; then
  policy_commit="$(git log --reverse --format=%H "$base..$head" -- script/validate_commit_messages.sh scripts/validate_commit_messages.sh | sed -n '1p')"
  if [[ -n "$policy_commit" ]] && git rev-parse --verify "$policy_commit^" >/dev/null 2>&1; then
    base="$(git rev-parse "$policy_commit^")"
  fi
fi
printf '%s\n' "$base"
