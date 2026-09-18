# Version control and releases

Use one focused PR per change, Conventional Commit titles, one release-note fragment per PR, semantic marketing versions, and increasing iOS build numbers. `CONTRIBUTING.md` defines code review and branch rules.

## Setup

```bash
./scripts/install_git_hooks.sh
git fetch origin
```

The commit hook validates subjects. The pre-push hook blocks direct pushes to `main`, validates branch commits, and checks for a release note across the whole branch. It uses the merge base with `origin/main`, or `branch.<branch-name>.pyxisBase` for an explicitly dependent PR. Fetch the current base before pushing.

GitHub requires PRs, passing `validate` and `quality` checks, and resolved conversations on `main`. Squash merging uses the PR title as the commit subject. Isaiah authorizes merges and releases. Legacy migration commits preceding policy introduction retain their existing titles.

## Each PR

1. Start a short-lived `codex/<purpose>` branch from current `main` (or explicitly declare a dependent PR).
2. Make one coherent change and create a draft PR with a Conventional Commit title.
3. Create one note and update it throughout review:

   ```bash
   ./scripts/new_update_note.sh added outfits "Add a dotted outfit pinboard" minor
   ```

4. Replace placeholder Details and Verification bullets with actual behavior and evidence.
5. Run relevant checks, resolve review findings, and mark the PR ready when verification is complete. State blocked checks explicitly.
6. Squash merge only after Isaiah authorizes it and required checks pass.

Use `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `revert`, or `release` as appropriate. Add `!` before the colon for a breaking change. Internal-only work uses `bump: none` in its note.

## Preparing a release

Start a separate release branch from current `main` with a clean working tree and valid pending fragments:

```bash
git switch main
git pull --ff-only
git switch -c codex/release-1-1-0
./scripts/prepare_release.sh 1.1.0 2
./scripts/deployment_preflight.sh local
```

The preparation command renders notes into `CHANGELOG.md`, updates the Xcode version and build number, updates preflight expectations, and archives consumed fragments under `changes/archive/<version>/`. Those archived notes satisfy the release PR's fragment requirement; an empty pending directory is valid.

Review and commit the resulting diff, then open `release: 1.1.0` as a PR. Record validation, migration risks, and the recovery plan. Version and build numbers above are examples; choose values newer than the last release/build.

After approval and squash merge, fetch `main` and tag the exact merged release commit, rather than the pre-merge branch commit:

```bash
git fetch origin
git tag -a v1.1.0 <merged-release-commit-sha> -m "Pyxis 1.1.0"
git push origin v1.1.0
```

Validate the release candidate through TestFlight, including upgrading an existing closet with photos and saved outfits. Complete `docs/MANUAL_QA.md` and the distribution preflight before App Store submission. Publishing requires Isaiah's instruction. Every uploaded iOS build must use a higher build number.

## Source of truth

- `changes/*.md`: pending per-PR release notes.
- `CHANGELOG.md`: released user-facing history.
- Git commits: searchable engineering history.
- `MARKETING_VERSION`: public App Store version.
- `CURRENT_PROJECT_VERSION`: unique iOS build number.
- `docs/UPDATE_LOG.md`: historical engineering narrative.
