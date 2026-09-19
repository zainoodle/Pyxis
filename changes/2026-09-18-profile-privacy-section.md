---
type: removed
bump: patch
area: profile
summary: Remove redundant privacy and offline explanatory copy from Profile.
---

## Details

- Remove the About Pyxis heading and its Private by Default explanatory block from Profile.
- Remove the offline and AI Studio explanatory paragraph beneath Capabilities.
- Presentation-only change; local storage and photo-upload behavior are unchanged.

## Verification

- Passed: `./scripts/build_and_run.sh --verify` on iPhone 17 Pro, iOS 26.5.
- Passed: visual simulator check confirming Profile retains Organize and Capabilities without the privacy block or offline/AI explanatory footer; screenshot refreshed.
- Passed: privacy consistency, release-note validation, and `git diff --check`.
