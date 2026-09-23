---
type: fixed
bump: patch
area: build
summary: Keep Build readiness and save controls readable at large text sizes.
---

## Details

- Wrap category counts into an adaptive grid and use full-width count rows at accessibility text sizes.
- Keep Fit Notes in the scrollable content at accessibility text sizes so the save rail stays compact.
- Remove carousel rotation and selection animation when Reduce Motion is enabled.
- Preserve the existing selection, save, and try-on behavior.

## Verification

- iPhone 17 Pro simulator build and launch passed with the combined PR chain.
- Build was inspected at default and largest accessibility text sizes.
- 133 Swift package tests, 25 workflow tests, and release-note validation passed. Reduce Motion was source-checked and compiled; its runtime setting was not toggled in the simulator.
