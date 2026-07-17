# Version Control And Release Process

Pyxis uses Conventional Commit subjects, one structured change fragment per
push, Keep a Changelog release notes, semantic marketing versions, and
monotonically increasing iOS build numbers.

## One-Time Setup

Install the repository-local hooks after cloning:

```bash
./script/install_git_hooks.sh
```

The `commit-msg` hook validates commit subjects. The `pre-push` hook verifies
that every pushed update includes a new valid fragment. GitHub Actions runs the
same checks, so bypassing a local hook does not bypass repository policy.

Configure the `Release notes policy / validate` check as required in the
GitHub `main` branch ruleset.

## Every Update

1. Make one coherent change.
2. Add an update fragment:

   ```bash
   ./script/new_update_note.sh added outfits "Add a dotted outfit pinboard" minor
   ```

3. Replace the generated placeholder bullets with the actual change and its
   verification evidence.
4. Commit with a Conventional Commit subject:

   ```text
   feat(outfits): add dotted pinboard canvas
   ```

5. Push normally. The pre-push hook and GitHub check validate the update, and
   the GitHub check summary displays the fragments attached to that push.

Use `feat` for a feature, `fix` for a bug, `perf` for performance, `refactor`
for behavior-preserving code changes, `docs`, `test`, `build`, `ci`, `chore`,
or `release` for their corresponding work. Add `!` before the colon for a
breaking change.

## Preparing A Release

Start from committed tracked changes with valid pending fragments, then run:

```bash
./script/prepare_release.sh 1.1.0 2
```

The command:

- renders pending fragments into a dated `CHANGELOG.md` section;
- updates `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project;
- synchronizes the deployment preflight's expected version values; and
- archives the consumed fragments under `changes/archive/<version>/`.

Review the generated diff, run the local deployment preflight, and commit:

```bash
./script/deployment_preflight.sh local
git add CHANGELOG.md Pyxis.xcodeproj/project.pbxproj script/deployment_preflight.sh changes/
git commit -m "release: 1.1.0"
git tag -a v1.1.0 -m "Pyxis 1.1.0"
```

Push the release commit and tag only after the preflight passes. App Store
build numbers must always increase, even when a marketing version is unchanged.

## Source Of Truth

- `changes/*.md`: pending, per-push update records.
- `CHANGELOG.md`: released user-facing history.
- Git commit subjects: searchable engineering history.
- `MARKETING_VERSION`: public App Store version.
- `CURRENT_PROJECT_VERSION`: unique App Store build number.
- `docs/UPDATE_LOG.md`: historical engineering narrative retained from before
  this workflow; new release entries should come from change fragments.
