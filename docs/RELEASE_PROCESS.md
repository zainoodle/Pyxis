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

## Version rules

Use `MAJOR.MINOR.PATCH`, applying [Semantic Versioning](https://semver.org/) to the app's user-facing compatibility:

| Change | Example | Fragment bump |
| --- | --- | --- |
| Compatible bug fix | `1.2.0` → `1.2.1` | `patch` |
| Compatible new feature | `1.2.1` → `1.3.0` | `minor` |
| Intentional incompatible change | `1.3.0` → `2.0.0` | `major` |
| Internal docs/tooling only | No public version change | `none` |

An incompatible change can affect supported platforms, data compatibility, or a documented app/gateway contract. A safe, transparent data migration does not automatically require a major bump. This numbering describes changes; it does not replace migration testing.

`config/Version.xcconfig` is the single source for the app version and build counter. Both Xcode configurations inherit it, and preflight reads it. The previous configured `1.0` is normalized to `1.0.0`, build `1`; that is not a newly published release.

The build counter increases for every uploaded candidate and never resets, including across public versions. Local builds and routine PRs do not increase it. Keep the last allocated number committed, coordinate uploads serially, and check App Store Connect before assigning the next one. The script can skip ahead if a number was already used elsewhere. Our integer counter accepts 1–9999; reaching that ceiling requires a deliberate format migration, not a reset.

Apple distinguishes the public version from the build identifier in its [bundle version documentation](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html). TestFlight candidates use the same numeric public version and successive builds, not a `-beta` suffix.

## Preparing a release

Start a release branch from current `main` with a clean working tree, fetch tags, and inspect the proposed release:

```bash
git fetch origin --tags
git switch main
git pull --ff-only
git switch -c codex/release-next
python3 scripts/version.py next
./scripts/prepare_release.sh auto --dry-run
./scripts/prepare_release.sh auto
./scripts/deployment_preflight.sh local
```

`auto` chooses the highest pending fragment bump and increments the build by one. It rejects an internal-only release. Explicit `patch`, `minor`, `major`, or `X.Y.Z` values are allowed, but cannot understate the pending changes. The existing `./scripts/prepare_release.sh 1.1.0 2` form also works when both numbers are valid increases.

Preparation updates the version config, writes the dated changelog, and archives all pending fragments under `changes/archive/<version>/`. Internal-only notes are archived but omitted from public changelog entries. The command does not commit, tag, upload, or publish anything. Validation and collision checks run before file changes. CI rejects malformed values, duplicate Xcode overrides, and version/build regressions.

Review and commit the diff, then open a `release: X.Y.Z` PR. Record validation and migration/recovery details. Archived notes satisfy this PR's fragment requirement, and an empty pending directory is valid. Corrections to the same release candidate should update its archived notes and changelog in that release PR.

For another TestFlight candidate of the same version:

```bash
python3 scripts/version.py build --dry-run
python3 scripts/version.py build
# Or explicitly skip past an already uploaded build:
python3 scripts/version.py build 20
```

The build command requires a clean branch and changes only the build counter. Commit it before building/uploading; update the existing release PR's note or add a `bump: none` note for a separate build PR. Use the next public patch version after a released version needs a user-facing fix.

After Isaiah approves and the release PR is squash-merged, tag the exact merged release commit:

```bash
git fetch origin
git tag -a v1.1.0 <merged-release-commit-sha> -m "Pyxis 1.1.0"
git push origin v1.1.0
```

`vX.Y.Z` tags are permanent release records: never reuse or move them. The tag workflow verifies the tag matches the version config and has a dated changelog and archived notes. It does not publish. Validate through TestFlight, including an existing closet upgrade, complete `docs/MANUAL_QA.md` and distribution preflight, then submit only with Isaiah's instruction.

## Source of truth

- `changes/*.md`: pending per-PR release notes.
- `CHANGELOG.md`: released user-facing history.
- Git commits: searchable engineering history.
- `config/Version.xcconfig`: public `MARKETING_VERSION` and unique upload `CURRENT_PROJECT_VERSION`.
- `vX.Y.Z` tags: exact merged release commits.
- `docs/UPDATE_LOG.md`: historical engineering narrative.
