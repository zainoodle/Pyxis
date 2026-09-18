# Contributing to Pyxis

## Branches and pull requests

Keep `main` releasable. Start each coherent change from current `main` on a short-lived `codex/<purpose>` branch. Check existing work before switching branches; use a separate worktree for overlapping tasks.

One PR should solve one problem. Keep features, unrelated fixes, structural refactors, and release preparation separate. Small follow-up corrections belong in the same PR. When work introduces another purpose, Codex must tell Isaiah that a new PR is needed, explain the boundary, and choose its title.

Use a draft PR while work is underway. Codex maintains the title and description. Titles and commits use Conventional Commits, for example `fix(outfits): preserve saved outfit images`. Include the problem, resulting behavior, test evidence, and relevant data/privacy/compatibility risks. Add screenshots for visible changes.

If a change depends on an open PR, explicitly name that dependency and target its branch. Configure the local hook with `git config branch.<branch-name>.pyxisBase origin/<base-branch>`. After the parent merges, rebase the child onto `origin/main`, retarget the PR, update this setting, and rerun checks. Inspect the diff to ensure parent changes are absent before merging. Branch protection applies to `main`; dependent PRs must ultimately target `main`.

## Code and verification

- Follow the structure in `README.md`; keep business logic in services and presentation in views/view models.
- Preserve local storage, offline core features, and explicit consent for AI photo uploads. Keep credentials out of source and logs.
- Storage changes need an upgrade plan and tests using existing closet records, outfits, and photos.
- Run checks relevant to the change. Add regression coverage for behavioral fixes; do not add tests that merely restate implementation details.
- Report failed or blocked checks explicitly. UI changes need simulator/device verification and screenshots; release candidates need an existing-data upgrade check.

Common checks:

```bash
./scripts/install_git_hooks.sh
./scripts/test.sh
python3 -m unittest discover -s tests/workflow -v
npm test --prefix backend/pyxis-ai-worker
npm run check --prefix backend/pyxis-ai-worker
./scripts/deployment_preflight.sh static
```

## Release notes and merging

Create one `changes/YYYY-MM-DD-area.md` fragment for each PR, then update it as that PR evolves. Do not create a new fragment for each review push or reuse a fragment from a merged PR. Use `bump: none` for internal-only changes. See `changes/README.md` and `docs/RELEASE_PROCESS.md`.

The pre-push hook compares the whole branch with its base, not just the latest push. Fetch the current base before pushing. CI validates the PR's complete diff, title, commits, release notes, and quality checks.

Protect `main` with required PRs, passing `validate` and `quality` checks, resolved conversations, linear history, and no force pushes or deletion. Require zero external approvals while Isaiah is the sole maintainer; he reviews the result and authorizes merging. Use squash merges with the PR title as the commit subject. Codex does not merge or publish without an explicit instruction.

Keep app version/build values in `config/Version.xcconfig`; use `python3 scripts/version.py next` and `./scripts/prepare_release.sh auto`. Routine PRs add a release note without bumping the app version.

Prepare releases in a separate PR. After that PR passes checks and merges, tag the merged commit, test the candidate through TestFlight, and submit to the App Store only with Isaiah's approval. See `docs/RELEASE_PROCESS.md` for commands.
