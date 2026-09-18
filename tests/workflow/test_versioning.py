"""Verify release preparation, build counters, and Xcode version consistency."""
import json
import plistlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
NOTE = """---
type: changed
bump: {bump}
area: example
summary: {summary}
---

## Details

- Describe the tested change.

## Verification

- Automated regression tests passed.
"""


class VersioningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        for path in ("scripts/version.py", "scripts/prepare_release.sh",
                     "scripts/validate_update_notes.sh", "scripts/render_update_notes.sh",
                     "config/Version.xcconfig", "config/Pyxis.xcconfig",
                     "Pyxis.xcodeproj/project.pbxproj"):
            target = self.repo / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, target)
        (self.repo / "changes").mkdir()
        (self.repo / "CHANGELOG.md").write_text("# Changelog\n\n## [Unreleased]\n")
        self.git("init", "-b", "codex/release-test")
        self.git("config", "user.name", "Version Test")
        self.git("config", "user.email", "version@example.invalid")
        self.git("config", "core.hooksPath", ".test-no-hooks")
        self.commit()
        self.base = self.git("rev-parse", "HEAD").stdout.strip()

    def command(self, *args, check=True):
        return subprocess.run(args, cwd=self.repo, text=True, capture_output=True, check=check)

    def git(self, *args):
        return self.command("git", *args)

    def commit(self):
        self.git("add", "-A")
        self.git("commit", "-m", "test: prepare fixture")

    def note(self, bump="patch", name="example", summary="Fix saved closet behavior."):
        path = self.repo / f"changes/2026-09-18-{name}.md"
        path.write_text(NOTE.format(bump=bump, summary=summary))
        return path

    def version(self, *args, ok=True):
        result = self.command("python3", "scripts/version.py", *args, check=False)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stderr

    def test_auto_uses_highest_bump_and_resets_lower_components(self):
        for bump, target in (("patch", "1.0.1"), ("minor", "1.1.0"), ("major", "2.0.0")):
            self.note(bump, bump)
            self.assertEqual(self.version("next")["next_version"], target)
        before = self.version("show")
        preview = self.version("prepare", "auto", "--dry-run")
        self.assertEqual((preview["version"], preview["build"]), ("2.0.0", 2))
        self.assertEqual(self.version("show"), before)

    def test_minor_and_major_reset_existing_lower_components(self):
        config = self.repo / "config/Version.xcconfig"
        config.write_text(config.read_text().replace("1.0.0", "1.2.3"))
        self.note("minor")
        self.assertEqual(self.version("next")["next_version"], "1.3.0")
        self.note("major")
        self.assertEqual(self.version("next")["next_version"], "2.0.0")

    def test_release_archives_notes_and_renders_only_user_changes(self):
        self.note("minor", "feature", "Add a new closet feature.")
        self.note("none", "internal", "Internal-only workflow cleanup.")
        self.commit()
        output = self.command("bash", "scripts/prepare_release.sh", "auto")
        self.assertEqual(json.loads(output.stdout)["version"], "1.1.0")
        self.assertEqual(self.version("show"), {"version": "1.1.0", "build": 2})
        self.assertEqual(len(list((self.repo / "changes/archive/1.1.0").glob("*.md"))), 2)
        self.assertEqual(list((self.repo / "changes").glob("*.md")), [])
        changelog = (self.repo / "CHANGELOG.md").read_text()
        self.assertIn("Add a new closet feature.", changelog)
        self.assertNotIn("Internal-only", changelog)
        self.version("check", "--base", self.base, "--tag", "v1.1.0")
        self.command("bash", "scripts/validate_update_notes.sh", "--all")

    def test_internal_only_notes_do_not_trigger_auto_release(self):
        self.note("none")
        self.commit()
        self.assertEqual(self.version("next")["next_version"], "1.0.0")
        self.assertIn("internal-only", self.version("prepare", "auto", ok=False))
        self.assertEqual(self.git("status", "--porcelain").stdout, "")

    def test_cannot_understate_required_release(self):
        self.note("major")
        self.commit()
        self.assertIn("at least 2.0.0", self.version("prepare", "patch", ok=False))
        self.assertEqual(self.git("status", "--porcelain").stdout, "")

    def test_build_only_keeps_version_notes_and_changelog(self):
        note = self.note("patch")
        self.commit()
        before = (self.repo / "CHANGELOG.md").read_text()
        self.assertEqual(self.version("build"), {"version": "1.0.0", "build": 2, "dry_run": False})
        self.assertTrue(note.exists())
        self.assertEqual((self.repo / "CHANGELOG.md").read_text(), before)
        self.version("check", "--base", self.base)

    def test_explicit_build_can_skip_already_uploaded_numbers(self):
        self.assertEqual(self.version("build", "20")["build"], 20)
        self.assertIn("must increase", self.version("build", "20", ok=False))

    def test_invalid_versions_and_builds_are_rejected(self):
        self.note("patch")
        self.commit()
        for value in ("1.1", "01.1.0", "1.1.0-beta.1", "1.1.0+2"):
            self.version("prepare", value, ok=False)
        for value in ("0", "-1", "10000"):
            self.version("build", value, ok=False)
        self.version("prepare", "1.1.0", "1", ok=False)
        self.assertEqual(self.git("status", "--porcelain").stdout, "")

    def test_dirty_tree_and_main_are_rejected(self):
        self.note()
        self.version("prepare", "patch", ok=False)
        self.version("build", ok=False)
        self.commit()
        self.git("switch", "-c", "main")
        self.version("prepare", "patch", ok=False)
        self.version("build", ok=False)

    def test_existing_tag_and_archive_are_rejected(self):
        self.note()
        self.commit()
        self.git("tag", "v1.0.1")
        self.version("prepare", "patch", ok=False)
        self.git("tag", "-d", "v1.0.1")
        (self.repo / "changes/archive/1.0.1").mkdir(parents=True)
        self.version("prepare", "patch", ok=False)
        self.assertEqual(self.version("show")["version"], "1.0.0")

    def test_broken_changelog_is_not_partially_written(self):
        self.note()
        (self.repo / "CHANGELOG.md").write_text("No Unreleased heading\n")
        self.commit()
        self.version("prepare", "patch", ok=False)
        self.assertEqual(self.git("status", "--porcelain").stdout, "")

    def test_version_progression_and_duplicate_overrides(self):
        config = self.repo / "config/Version.xcconfig"
        original = config.read_text()
        config.write_text(original.replace("1.0.0", "0.9.0"))
        self.version("check", "--base", self.base, ok=False)
        config.write_text(original.replace("1.0.0", "1.1.0"))
        self.version("check", "--base", self.base, ok=False)
        config.write_text(original.replace("CURRENT_PROJECT_VERSION = 1", "CURRENT_PROJECT_VERSION = 2"))
        self.version("check", "--base", self.base)
        project = self.repo / "Pyxis.xcodeproj/project.pbxproj"
        project.write_text(project.read_text() + "\nMARKETING_VERSION = 9.0.0;\n")
        self.version("check", ok=False)

    def test_release_tags_must_match_prepared_version(self):
        self.version("check", "--tag", "v1.0.0", ok=False)
        self.note()
        self.commit()
        self.version("prepare", "patch")
        self.version("check", "--tag", "v1.0.1")
        self.version("check", "--tag", "v9.0.0", ok=False)

    def test_built_app_version_matches_config(self):
        info = self.repo / "Info.plist"
        info.write_bytes(plistlib.dumps({"CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1"}))
        self.version("check", "--app-info", str(info))
        info.write_bytes(plistlib.dumps({"CFBundleShortVersionString": "1.0", "CFBundleVersion": "1"}))
        self.version("check", "--app-info", str(info), ok=False)
        info.write_bytes(plistlib.dumps({"CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "2"}))
        self.version("check", "--app-info", str(info), ok=False)

    def test_empty_release_is_rejected(self):
        self.version("prepare", "patch", ok=False)
        self.assertEqual(self.git("status", "--porcelain").stdout, "")


if __name__ == "__main__":
    unittest.main()
