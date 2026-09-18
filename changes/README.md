# Change fragments

Create one fragment per PR, then update that same file as the PR evolves. A review push does not need a new fragment. Do not reuse a fragment from a merged PR for unrelated work.

```bash
./scripts/new_update_note.sh added closet-grid "Add a dotted outfit pinboard" minor
```

Use a unique `YYYY-MM-DD-kebab-case.md` filename, the front matter in `template.md`, and concrete Details and Verification sections. Record failures and blocked checks honestly.

Allowed types: `added`, `changed`, `deprecated`, `removed`, `fixed`, `security`.

Version impact:

- `none`: internal documentation or tooling with no release impact.
- `patch`: compatible fixes and small refinements.
- `minor`: backward-compatible features.
- `major`: incompatible changes.

Hooks validate the complete branch diff against its base; CI validates the complete PR diff. A changed PR must add a valid fragment. Existing multi-change migration PRs may contain multiple fragments. Release PRs instead move pending fragments into `changes/archive/<version>/` while updating the changelog and build metadata.

Fragments describe pending work; `CHANGELOG.md` records released history. An empty pending directory is valid immediately after release preparation.
