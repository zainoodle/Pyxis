# Pyxis working agreements

- Be concise and high signal. State blockers plainly.
- Read `CONTRIBUTING.md` before changing code or preparing a PR.
- Keep one purpose per branch and PR; use `codex/<short-purpose>` branches.
- Codex owns descriptive Conventional Commit PR titles and keeps the PR description current.
- Before adding unrelated work, tell Isaiah: “This needs a separate PR: <proposed title>,” explain why, and keep it separate. Do not wait for him to remember.
- Check the current branch, diff, and PR before starting; preserve existing work. Use a separate worktree when tasks overlap. Explicitly identify dependent PRs.
- Keep app entry points in `src/main/`, business logic in `src/services/`, models in `src/models/`, and shared helpers in `src/utils/`. Follow the existing view and persistence structure.
- Preserve the local-first experience. Never commit secrets, silently add photo uploads, or change stored data without an upgrade/migration plan.
- Test changed behavior with relevant existing checks; add regression coverage for bugs. Check visible changes on a simulator or device.
- Maintain one release-note fragment per PR and update it during review. Keep docs aligned with the final change.
- Report checks as passed, failed, or blocked; never describe unrun checks as passing.
- Prepare draft PRs with the problem, resulting behavior, verification, and relevant risks. Isaiah decides when to merge or release; do not merge or publish without his instruction.
