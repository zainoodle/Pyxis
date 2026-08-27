# Change Fragments

Every push that changes the repository must add at least one new Markdown file in
this directory. These fragments are the source for push summaries and release
notes; released fragments are moved to `archive/<version>/`.

Create a fragment with:

```bash
./script/new_update_note.sh added closet-grid "Add a dotted outfit pinboard"
```

Allowed `type` values follow Keep a Changelog: `added`, `changed`, `deprecated`,
`removed`, `fixed`, and `security`.

Allowed `bump` values are `none`, `patch`, `minor`, and `major`. Use:

- `none` for internal documentation or tooling that does not affect a release.
- `patch` for compatible fixes and small refinements.
- `minor` for backward-compatible features.
- `major` for incompatible changes.

Do not reuse or edit an already-pushed fragment for unrelated work. Add a new
fragment so every pushed update has its own durable record.
