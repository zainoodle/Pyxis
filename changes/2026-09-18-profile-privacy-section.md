---
type: removed
bump: patch
area: profile
summary: Remove redundant capability and privacy copy from Profile.
---

## Details

- Remove the Capabilities section, including the AI Studio build-status row and offline explanation.
- Remove the About Pyxis heading and its Private by Default explanatory block from Profile.
- Keep Manage Closets and Fit Passport as direct actions without redundant section and row descriptions.
- Presentation-only change; local storage and photo-upload behavior are unchanged.

## Verification

- Passed: `./scripts/build_and_run.sh --verify` on iPhone 17 Pro, iOS 26.5.
- Passed: visual simulator check confirming Profile contains only Manage Closets and Fit Passport; screenshot refreshed.
- Passed: privacy consistency, release-note validation, and `git diff --check`.
