---
type: removed
bump: patch
area: profile
summary: Remove the redundant Private by Default section from Profile.
---

## Details

- Remove the About Pyxis heading and its Private by Default explanatory block from Profile.
- Presentation-only change; local storage and photo-upload behavior are unchanged.

## Verification

- Passed: `./scripts/build_and_run.sh --verify` on iPhone 17 Pro, iOS 26.5.
- Passed: visual simulator check confirming Profile retains Organize and Capabilities and no longer shows About Pyxis or Private by Default.
- Passed: privacy consistency, release-note validation, and `git diff --check`.
