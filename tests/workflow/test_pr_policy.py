"""Exercise PR policy scripts against isolated Git histories."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
NOTE = """---
type: changed
bump: none
area: workflow
summary: Keep one release note throughout PR review.
---

## Details

- Update workflow behavior.

## Verification

- Run workflow regression tests.
"""


class PRPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        (self.repo / "scripts").mkdir()
        (self.repo / ".githooks").mkdir()
        (self.repo / "changes").mkdir()
        for name in ("validate_update_notes.sh", "validate_commit_messages.sh",
                     "resolve_policy_base.sh", "render_push_notes.sh"):
            shutil.copy2(ROOT / "scripts" / name, self.repo / "scripts" / name)
        shutil.copy2(ROOT / ".githooks/pre-push", self.repo / ".githooks/pre-push")
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Policy Test")
        self.git("config", "user.email", "policy@example.invalid")
        self.git("config", "core.hooksPath", ".githooks")
        self.write("app.txt", "initial\n")
        self.commit("chore: initialize fixture")
        self.base = self.git("rev-parse", "HEAD").stdout.strip()
        self.git("update-ref", "refs/remotes/origin/main", self.base)
        self.git("switch", "-c", "codex/example")
        self.note = "changes/2026-09-18-example.md"

    def run_command(self, *args, check=True, input=None):
        env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1")
        # Avoid inheriting the invoking repository's hook environment.
        for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
            env.pop(name, None)
        return subprocess.run(args, cwd=self.repo, env=env, text=True,
                              input=input, capture_output=True, check=check)

    def git(self, *args):
        return self.run_command("git", *args)

    def write(self, path, content):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

    def commit(self, subject):
        self.git("add", "-A")
        self.git("commit", "-m", subject)

    def validate(self, expected=0):
        result = self.run_command("bash", "scripts/validate_update_notes.sh",
                                  "--base", self.base, "--head", "HEAD", check=False)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

    def push_hook(self, remote_sha=None, branch="codex/example", expected=0):
        head = self.git("rev-parse", "HEAD").stdout.strip()
        line = f"refs/heads/{branch} {head} refs/heads/{branch} {remote_sha or '0' * 40}\n"
        result = self.run_command("bash", ".githooks/pre-push", input=line, check=False)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

    def test_followup_push_reuses_pr_note(self):
        self.write(self.note, NOTE)
        self.commit("chore: add release note")
        first_push = self.git("rev-parse", "HEAD").stdout.strip()
        self.push_hook()
        self.write("app.txt", "review correction\n")
        self.write(self.note, NOTE.replace("Update workflow behavior.", "Include review corrections."))
        self.commit("fix: address review feedback")
        self.push_hook(first_push)
        self.validate()

    def test_missing_note_fails(self):
        self.write("app.txt", "changed\n")
        self.commit("fix: change behavior")
        self.validate(expected=1)
        self.push_hook(expected=1)

    def test_previous_pr_note_cannot_be_reused(self):
        self.write(self.note, NOTE)
        self.commit("chore: previous PR note")
        self.base = self.git("rev-parse", "HEAD").stdout.strip()
        self.write(self.note, NOTE.replace("Update workflow behavior.", "Unrelated work."))
        self.write("app.txt", "changed\n")
        self.commit("fix: unrelated behavior")
        self.validate(expected=1)

    def test_dirty_valid_note_cannot_hide_invalid_commit(self):
        self.write(self.note, NOTE.replace("bump: none", "bump: invalid"))
        self.commit("chore: invalid committed note")
        self.write(self.note, NOTE)
        self.validate(expected=1)

    def test_dirty_note_does_not_invalidate_committed_note(self):
        self.write(self.note, NOTE)
        self.commit("chore: valid committed note")
        self.write(self.note, "unfinished local edits")
        self.validate()
        result = self.run_command("bash", "scripts/render_push_notes.sh", self.base, "HEAD")
        self.assertIn("Keep one release note", result.stdout)

    def test_release_archive_and_empty_pending_directory(self):
        self.write(self.note, NOTE)
        self.commit("chore: pending release note")
        self.base = self.git("rev-parse", "HEAD").stdout.strip()
        archive = self.repo / "changes/archive/1.1.0"
        archive.mkdir(parents=True)
        (self.repo / self.note).rename(archive / Path(self.note).name)
        self.write("CHANGELOG.md", "Released 1.1.0\n")
        self.commit("release: 1.1.0")
        self.validate()
        result = self.run_command("bash", "scripts/validate_update_notes.sh", "--all")
        self.assertIn("validated 0", result.stdout)

    def test_dependent_branch_uses_its_own_base(self):
        self.write(self.note, NOTE)
        self.commit("chore: parent note")
        parent = self.git("rev-parse", "HEAD").stdout.strip()
        self.git("update-ref", "refs/remotes/origin/parent", parent)
        self.git("config", "branch.codex/example.pyxisBase", "origin/parent")
        self.write("app.txt", "child change\n")
        self.commit("fix: child behavior")
        self.push_hook(expected=1)
        self.write("changes/2026-09-18-child.md", NOTE)
        self.commit("chore: child release note")
        self.push_hook()

    def test_direct_main_push_is_rejected(self):
        self.push_hook(branch="main", expected=1)

    def test_pr_title_validation(self):
        self.run_command("bash", "scripts/validate_commit_messages.sh", "--subject",
                         "fix(outfits): preserve saved images")
        result = self.run_command("bash", "scripts/validate_commit_messages.sh", "--subject",
                                  "misc changes", check=False)
        self.assertNotEqual(result.returncode, 0)

    def test_legacy_policy_boundary_survives_script_rename(self):
        self.git("rm", "scripts/validate_commit_messages.sh")
        self.commit("chore: fixture before policy")
        legacy_base = self.git("rev-parse", "HEAD").stdout.strip()
        self.write("app.txt", "legacy edit\n")
        self.commit("Legacy subject before policy")
        legacy_head = self.git("rev-parse", "HEAD").stdout.strip()
        (self.repo / "script").mkdir()
        shutil.copy2(ROOT / "scripts/validate_commit_messages.sh",
                     self.repo / "script/validate_commit_messages.sh")
        self.commit("chore: introduce policy")
        self.git("mv", "script/validate_commit_messages.sh", "scripts/validate_commit_messages.sh")
        self.commit("refactor: rename script folder")
        result = self.run_command("bash", "scripts/resolve_policy_base.sh", legacy_base, "HEAD")
        self.assertEqual(result.stdout.strip(), legacy_head)
        self.run_command("bash", "scripts/validate_commit_messages.sh", "--base", legacy_head)


if __name__ == "__main__":
    unittest.main()
