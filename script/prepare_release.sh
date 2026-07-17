#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  printf 'usage: ./script/prepare_release.sh <major.minor.patch> <build-number>\n' >&2
}

[[ $# -eq 2 ]] || { usage; exit 2; }
VERSION="$1"
BUILD_NUMBER="$2"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'error: version must be major.minor.patch\n' >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { printf 'error: build number must be a positive integer\n' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { printf 'error: commit or remove working-tree changes before preparing a release\n' >&2; exit 1; }

CURRENT_VERSION="$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' Pyxis.xcodeproj/project.pbxproj | head -n 1)"
CURRENT_BUILD="$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);/\1/p' Pyxis.xcodeproj/project.pbxproj | head -n 1)"
python3 - "$CURRENT_VERSION" "$VERSION" "$CURRENT_BUILD" "$BUILD_NUMBER" <<'PY'
import sys

current_version, next_version, current_build, next_build = sys.argv[1:]
if tuple(map(int, next_version.split("."))) <= tuple(map(int, current_version.split("."))):
    raise SystemExit(f"error: version {next_version} must be newer than {current_version}")
if int(next_build) <= int(current_build):
    raise SystemExit(f"error: build {next_build} must be greater than {current_build}")
PY

./script/validate_update_notes.sh --all
NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
./script/render_update_notes.sh "$VERSION" > "$NOTES_FILE"

python3 - "$VERSION" "$BUILD_NUMBER" "$NOTES_FILE" <<'PY'
from pathlib import Path
import re
import sys

version, build, notes_path = sys.argv[1:]
root = Path.cwd()

project = root / "Pyxis.xcodeproj/project.pbxproj"
text = project.read_text()
text = re.sub(r"MARKETING_VERSION = [^;]+;", f"MARKETING_VERSION = {version};", text)
text = re.sub(r"CURRENT_PROJECT_VERSION = [^;]+;", f"CURRENT_PROJECT_VERSION = {build};", text)
project.write_text(text)

preflight = root / "script/deployment_preflight.sh"
text = preflight.read_text()
text = re.sub(r'^VERSION="[^"]+"$', f'VERSION="{version}"', text, flags=re.MULTILINE)
text = re.sub(r'^BUILD_NUMBER="[^"]+"$', f'BUILD_NUMBER="{build}"', text, flags=re.MULTILINE)
preflight.write_text(text)

changelog = root / "CHANGELOG.md"
text = changelog.read_text()
marker = "## [Unreleased]\n"
if marker not in text:
    raise SystemExit("CHANGELOG.md is missing the Unreleased heading")
notes = Path(notes_path).read_text().rstrip()
changelog.write_text(text.replace(marker, f"{marker}\n{notes}\n", 1))
PY

mkdir -p "changes/archive/$VERSION"
find changes -maxdepth 1 -type f -name '*.md' ! -name README.md ! -name template.md -exec mv {} "changes/archive/$VERSION/" \;

printf 'prepared Pyxis %s build %s\n' "$VERSION" "$BUILD_NUMBER"
printf 'next: review the diff, run ./script/deployment_preflight.sh local, stage it, then commit as release: %s\n' "$VERSION"
