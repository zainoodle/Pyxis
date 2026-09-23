---
type: changed
bump: none
area: ci
summary: Prepare a checked, manual Xcode Cloud path for internal TestFlight builds.
---

## Details

- Add a post-clone version check for Xcode Cloud.
- Record the exact repository, signing, workflow, build-number, and release gates for a cloud-signed internal TestFlight candidate.
- Keep distribution manual and require approval for the exact candidate.

## Verification

- Local post-clone script, release-note validation, and static deployment preflight passed.
- Apple-side Xcode Cloud and App Store Connect connection cannot be verified without account access.
