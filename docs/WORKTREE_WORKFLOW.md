# Concurrent Pyxis work

Use `/Users/isaiahjohnson/Documents/ChatGPT/Pyxis` as the primary checkout and source of approved work. Keep independent or overlapping implementation in a local `codex/<purpose>` branch/worktree. Give each active feature one owner. Share source changes through an explicit reviewed patch or commit; do not copy one feature's entire checkout over another.

## Current lanes

| Lane | Checkout | Purpose |
| --- | --- | --- |
| Image refinement | Primary Pyxis checkout, `codex/editorial-archive` | Image scaling, extraction, local smoothing, light palette |
| Rack and combined preview | `.codex/worktrees/closet-rack/Pyxis`, `codex/closet-rack` | Current image baseline plus native rack motion |
| Earlier single-card alternative | `.codex/worktrees/closet-single-card/Pyxis` | Preserved alternative; do not combine its gallery replacement with the rack |
| Category-menu alternative | `.codex/worktrees/editorial-closet/Pyxis` | Preserved independent category work |
| Earlier editorial checkout | `.codex/worktrees/editorial-archive/Pyxis` | Detached at the current primary commit; one local project-file change remains |

The combined preview is currently built from the rack checkout. It inherits the current image-refinement inputs and adds only the rack changes. Once the combined result is accepted for consolidation, apply its rack-only patch to the primary checkout, inspect the diff, and verify there. Preserve local edits and recoverable alternatives. A PR, push, release, and worktree removal each need the corresponding user request.

## Concurrent checks

The runner discovers worktrees linked to the current Git repository, skips missing/prunable directories, and keeps each checkout's SwiftPM cache and logs outside the source tree. A lock prevents two invocations from building the same cache simultaneously. It performs `git diff --check` and the core Swift package suite, with up to two workers by default.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 scripts/test_worktrees.py --all --jobs 2 --output /tmp/pyxis-worktree-results.json
```

For only the active image and rack lanes:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 scripts/test_worktrees.py \
  --worktree /Users/isaiahjohnson/Documents/ChatGPT/Pyxis \
  --worktree /Users/isaiahjohnson/.codex/worktrees/closet-rack/Pyxis \
  --jobs 2 --output /tmp/pyxis-active-worktree-results.json
```

Give every simultaneous Xcode build its own `-derivedDataPath`. Use a different simulator for independent app installations: the same bundle ID on one simulator can only run one checkout's build at a time. Keep one named combined preview for user review. Serialize physical-iPhone installs and verify the foreground app after each install.

Core checks are one verification layer. Changed UI also needs a simulator/device build and rendered interaction checks; device behavior, storage upgrades, and release checks remain separate requirements. Record passed, failed, skipped, and blocked results explicitly.

## Older CloudDocs checkouts

Eight clean checkouts remain linked to the older CloudDocs repository: dark-editorial-ui, outfit-appearance, outfit-gallery, outfit-suggestions, outfit-try-on, pc-image-api, profile-privacy-section, and security-audit. Their HEAD commits were verified as ancestors of the primary checkout on October 1, 2026. Their committed work is already in primary history. Preserve them until cleanup is requested; do not re-import them into the current preview. The runner's `--all` option is scoped to the current repository, not every directory named Pyxis on disk.
