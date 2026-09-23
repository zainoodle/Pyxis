#!/usr/bin/env bash
set -euo pipefail

repository="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repository"

python3 scripts/version.py check
