# Contributing to Pyxis

## Branches and pull requests

Keep `main` releasable. Continue related work on the current task branch. For separate or overlapping work, use a local `codex/<purpose>` branch or worktree after checking existing changes. Do not create, push, or update a PR unless Isaiah explicitly requests that action.

When Isaiah requests a PR, keep it focused on one problem. Keep features, unrelated fixes, structural refactors, and release preparation separate. Small follow-up corrections belong in the same PR. When work introduces another purpose, explain the boundary and keep the changes separate locally; do not open another PR automatically.

Work and verify locally by default. If Isaiah requests a PR, open it as a draft and maintain its title and description. Titles and commits use Conventional Commits, for example `fix(outfits): preserve saved outfit images`. Include the problem, resulting behavior, test evidence, and relevant data/privacy/compatibility risks. Add screenshots for visible changes.

If a requested PR depends on an open PR, explicitly name that dependency and target its branch. Configure the local hook with `git config branch.<branch-name>.pyxisBase origin/<base-branch>`. After the parent merges, rebase the child onto `origin/main`, retarget the PR, update this setting, and rerun checks. Inspect the diff to ensure parent changes are absent before merging. Branch protection applies to `main`; dependent PRs must ultimately target `main`.

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

For each requested PR, create one `changes/YYYY-MM-DD-area.md` fragment, then update it as that PR evolves. Do not create a new fragment for each review push or reuse a fragment from a merged PR. Use `bump: none` for internal-only changes. See `changes/README.md` and `docs/RELEASE_PROCESS.md`.

The pre-push hook compares the whole branch with its base, not just the latest push. Fetch the current base before pushing. CI validates the PR's complete diff, title, commits, release notes, and quality checks.

Protect `main` with required PRs, passing `validate` and `quality` checks, resolved conversations, linear history, and no force pushes or deletion. Require zero external approvals while Isaiah is the sole maintainer; he reviews the result and authorizes merging. Use squash merges with the PR title as the commit subject. Codex does not merge or publish without an explicit instruction.

Keep app version/build values in `config/Version.xcconfig`; use `python3 scripts/version.py next` and `./scripts/prepare_release.sh auto`. Routine PRs add a release note without bumping the app version.

Prepare releases locally and open a separate release PR only when Isaiah requests it. After that PR passes checks and merges, tag the merged commit, test the candidate through TestFlight, and submit to the App Store only with Isaiah's approval. See `docs/RELEASE_PROCESS.md` for commands.
