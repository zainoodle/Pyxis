#!/usr/bin/env python3
"""Version and release preparation for Pyxis; no third-party dependencies."""
import argparse
import json
import plistlib
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG = Path("config/Version.xcconfig")
PROJECT = Path("Pyxis.xcodeproj/project.pbxproj")
LEVELS = {"none": 0, "patch": 1, "minor": 2, "major": 3}
VERSION_RE = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, text=True,
                          capture_output=True).stdout.strip()


def version_tuple(value):
    if not re.fullmatch(VERSION_RE, value):
        raise ValueError("version must be major.minor.patch without leading zeros or suffixes")
    return tuple(map(int, value.split(".")))


def build_number(value):
    if not re.fullmatch(r"[1-9][0-9]{0,3}", str(value)):
        raise ValueError("build must be an integer from 1 to 9999")
    return int(value)


def parse_config(text):
    values = {}
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        matches = re.findall(rf"^{key}\s*=\s*(\S+)\s*$", text, re.M)
        if len(matches) != 1:
            raise ValueError(f"{CONFIG} must define {key} exactly once")
        values[key] = matches[0]
    version_tuple(values["MARKETING_VERSION"])
    return values["MARKETING_VERSION"], build_number(values["CURRENT_PROJECT_VERSION"])


def current():
    return parse_config((ROOT / CONFIG).read_text())


def config_text(version, build):
    return ("// Single source of truth; update through scripts/version.py.\n"
            f"MARKETING_VERSION = {version}\nCURRENT_PROJECT_VERSION = {build}\n")


def next_version(version, bump):
    major, minor, patch = version_tuple(version)
    if bump == "major":
        return f"{major + 1}.0.0"
    if bump == "minor":
        return f"{major}.{minor + 1}.0"
    if bump == "patch":
        return f"{major}.{minor}.{patch + 1}"
    return version


def pending_notes():
    subprocess.run(["bash", "scripts/validate_update_notes.sh", "--all"],
                   cwd=ROOT, check=True, capture_output=True, text=True)
    notes = sorted(p for p in (ROOT / "changes").glob("*.md")
                   if p.name not in ("README.md", "template.md"))
    bumps = [re.search(r"^bump: (\w+)$", p.read_text(), re.M).group(1) for p in notes]
    return notes, max(bumps, key=LEVELS.get, default="none")


def check(base=None, tag=None, app_info=None):
    version, build = current()
    project = (ROOT / PROJECT).read_text()
    if re.search(r"\b(MARKETING_VERSION|CURRENT_PROJECT_VERSION)\s*=", project):
        raise ValueError("remove Xcode project version overrides; use config/Version.xcconfig")
    app_config = (ROOT / "config/Pyxis.xcconfig").read_text()
    if app_config.rstrip().splitlines()[-1] != '#include "Version.xcconfig"':
        raise ValueError("Pyxis.xcconfig must include Version.xcconfig last")
    if project.count("baseConfigurationReference = 1A0000010000000000000010") != 2:
        raise ValueError("Debug and Release must both use Pyxis.xcconfig")
    if base:
        # Allow the one-time migration from the old two-part project version.
        if subprocess.run(["git", "cat-file", "-e", f"{base}:{CONFIG}"], cwd=ROOT,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            old_version, old_build = parse_config(git("show", f"{base}:{CONFIG}"))
        else:
            old_project = git("show", f"{base}:{PROJECT}")
            versions = set(re.findall(r"MARKETING_VERSION = ([0-9.]+);", old_project))
            builds = set(re.findall(r"CURRENT_PROJECT_VERSION = ([0-9]+);", old_project))
            if len(versions) != 1 or len(builds) != 1:
                raise ValueError("cannot determine the base version/build")
            old_version = versions.pop()
            if old_version.count(".") == 1:
                old_version += ".0"
            old_build = int(builds.pop())
        if version_tuple(version) < version_tuple(old_version) or build < old_build:
            raise ValueError("version and build numbers must not decrease")
        if version != old_version and build <= old_build:
            raise ValueError("a new version must also increase the build number")
    if tag:
        if tag != f"v{version}":
            raise ValueError(f"release tag must match v{version}")
        if not re.search(rf"^## \[{re.escape(version)}\] - \d{{4}}-\d{{2}}-\d{{2}}$",
                         (ROOT / "CHANGELOG.md").read_text(), re.M):
            raise ValueError("release tag requires a matching dated changelog entry")
        if not (ROOT / "changes/archive" / version).is_dir():
            raise ValueError("release tag requires archived release notes")
    if app_info:
        with Path(app_info).open("rb") as handle:
            info = plistlib.load(handle)
        if info.get("CFBundleShortVersionString") != version or info.get("CFBundleVersion") != str(build):
            raise ValueError("built app version/build does not match config/Version.xcconfig")
    return version, build


def require_clean_branch():
    if git("status", "--porcelain"):
        raise ValueError("commit working-tree changes before preparing a release/build")
    branch = git("branch", "--show-current")
    if not branch or branch == "main":
        raise ValueError("prepare changes on a feature/release branch, not main or detached HEAD")


def prepare(release, requested_build=None, dry_run=False):
    version, build = check()
    notes, required = pending_notes()
    if not notes:
        raise ValueError("no pending release notes; use the build command for another beta upload")
    if release == "auto":
        if required == "none":
            raise ValueError("internal-only notes do not require a release; use the build command if needed")
        target = next_version(version, required)
    elif release in LEVELS and release != "none":
        target = next_version(version, release)
    else:
        version_tuple(release)
        target = release
    if version_tuple(target) <= version_tuple(version):
        raise ValueError("release version must increase")
    minimum = next_version(version, required)
    if version_tuple(target) < version_tuple(minimum):
        raise ValueError(f"release notes require at least {minimum} ({required})")
    target_build = build_number(requested_build if requested_build is not None else build + 1)
    if target_build <= build:
        raise ValueError("build number must increase")
    archive = ROOT / "changes/archive" / target
    if archive.exists() or git("tag", "--list", f"v{target}"):
        raise ValueError(f"release {target} already has an archive or local tag")
    changelog = ROOT / "CHANGELOG.md"
    original = changelog.read_text()
    marker = "## [Unreleased]\n"
    if original.count(marker) != 1 or f"## [{target}]" in original:
        raise ValueError("changelog needs one Unreleased heading and no existing target version")
    rendered = subprocess.run(["bash", "scripts/render_update_notes.sh", target], cwd=ROOT,
                              check=True, capture_output=True, text=True).stdout.rstrip()
    result = {"version": target, "build": target_build, "tag": f"v{target}",
              "required_bump": required, "fragments": len(notes), "dry_run": dry_run}
    if not dry_run:
        require_clean_branch()
        # Resolve validation and collisions before modifying any files.
        archive.mkdir(parents=True)
        try:
            (ROOT / CONFIG).write_text(config_text(target, target_build))
            changelog.write_text(original.replace(marker, f"{marker}\n{rendered}\n", 1))
            for note in notes:
                note.rename(archive / note.name)
        except OSError:
            (ROOT / CONFIG).write_text(config_text(version, build))
            changelog.write_text(original)
            for note in notes:
                moved = archive / note.name
                if moved.exists():
                    moved.rename(note)
            archive.rmdir()
            raise
    return result


def bump_build(requested=None, dry_run=False):
    version, build = check()
    target = build_number(requested if requested is not None else build + 1)
    if target <= build:
        raise ValueError("build number must increase")
    if not dry_run:
        require_clean_branch()
        (ROOT / CONFIG).write_text(config_text(version, target))
    return {"version": version, "build": target, "dry_run": dry_run}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("show", help="show the version and build")
    commands.add_parser("next", help="preview the release implied by pending notes")
    check_parser = commands.add_parser("check", help="validate configuration and optional base/tag")
    check_parser.add_argument("--base")
    check_parser.add_argument("--tag")
    check_parser.add_argument("--app-info", help="verify the built app Info.plist")
    prepare_parser = commands.add_parser("prepare", help="prepare a release without committing or publishing")
    prepare_parser.add_argument("release", nargs="?", default="auto", help="auto, patch, minor, major, or X.Y.Z")
    prepare_parser.add_argument("build", nargs="?", type=int, help="optional explicit build counter")
    prepare_parser.add_argument("--dry-run", action="store_true")
    build_parser = commands.add_parser("build", help="increase only the beta/upload build counter")
    build_parser.add_argument("number", nargs="?", type=int)
    build_parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "show":
            version, build = current()
            result = {"version": version, "build": build}
        elif args.command == "check":
            version, build = check(args.base, args.tag, args.app_info)
            result = {"version": version, "build": build, "valid": True}
        elif args.command == "next":
            version, build = check()
            notes, bump = pending_notes()
            result = {"version": version, "build": build, "required_bump": bump,
                      "next_version": next_version(version, bump), "fragments": len(notes)}
        elif args.command == "prepare":
            result = prepare(args.release, args.build, args.dry_run)
        else:
            result = bump_build(args.number, args.dry_run)
        print(json.dumps(result, indent=2))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) and error.stderr else str(error)
        print(f"error: {detail}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
