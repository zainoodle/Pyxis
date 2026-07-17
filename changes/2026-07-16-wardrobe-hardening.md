---
type: changed
bump: minor
area: wardrobe-foundation
summary: Harden local storage, sizing, outfit building, saved-fit management, accessibility, and CI.
---

## Details

- Protected wardrobe files on iOS and cleaned up abandoned image-import drafts.
- Added one-piece fits, saved-fit duplicate/share/delete actions, and missing-item feedback.
- Made sizing fail closed outside retailer ranges, added footwear charts, and improved Fit Passport editing and deletion safety.
- Added scalable typography, stronger contrast, larger controls, richer accessibility state, and a CI build/test job.

## Verification

- Ran all 97 Swift package tests successfully.
- Built the Debug iOS app for a generic Simulator destination with signing disabled.
