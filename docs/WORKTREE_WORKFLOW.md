# Concurrent Pyxis work

The integrated source of truth is `/Users/isaiahjohnson/Documents/ChatGPT/Pyxis`, branch `codex/editorial-archive`. Build and review the combined result from this checkout. Preserve unrelated local edits. No PR, push, publication, or release is implied by local implementation.

## Current review lanes — October 2, 2026

| Owner | Checkout | Responsibility |
| --- | --- | --- |
| Integration | Primary Pyxis checkout | Image inference/framing, storage correctness, release checks, final combined build |
| Rack quality | `.codex/worktrees/rack-quality/Pyxis` | Support validation, rigid motion, tap/drag arbitration, image-cache refresh |
| Flow quality | `.codex/worktrees/flow-quality/Pyxis` | Import, Fits, Measurements, Profile, closet management |

Both review lanes began from a copy of the same allowlisted dirty baseline. Their delivered patches contain only changes against that baseline; do not apply each lane's full Git diff, which includes earlier shared work. Each lane uses its own derived-data directory and simulator. The integration owner checks and applies each delta, resolves overlap, then rebuilds and verifies the primary checkout.

Earlier `closet-rack`, `closet-single-card`, `editorial-archive`, and `editorial-closet` worktrees remain recoverable alternatives. Their builds are not the current integrated preview. Do not overwrite primary with an older checkout or reapply the original rack patch. Worktree removal requires the corresponding user request.

## Concurrent checks

The runner discovers this repository's worktrees, skips missing/prunable directories, gives each checkout a separate SwiftPM cache/log, and locks each cache against concurrent invocation. It runs `git diff --check` and the core package suite. This does not establish rendered-app quality.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 scripts/test_worktrees.py --all --jobs 2 --output /tmp/pyxis-worktree-results.json
```

Give simultaneous Xcode builds unique `-derivedDataPath` values and separate simulators. One bundle ID on one simulator can only represent one checkout at a time. Serialize physical-phone installations and verify the foreground build. Final evidence must identify the integrated checkout/build; individual lane results are preliminary.

Eight older CloudDocs checkouts were previously verified as ancestors of primary. They remain preserved; do not re-import their committed work. The runner is scoped to this repository, not every folder named Pyxis.
