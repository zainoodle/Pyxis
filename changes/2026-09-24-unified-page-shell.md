---
type: fixed
bump: patch
area: navigation
summary: Align the main screens and remove repeated section titles.
---

## Details

- Use one Pyxis header position for Closet, Build, Fits, and Profile; the tab bar names each destination.
- Use consistent inline navigation titles for Profile destinations and saved fit details.
- Simplify empty Closet and Build screens by hiding controls that have no content to act on.

## Verification

- iPhone 17 Pro Max simulator build and visual checks passed at standard and accessibility text sizes.
- Connected iPhone 17 Pro Max build, install, launch, and screenshot check passed.
- 133 Swift package tests, 25 workflow tests, and release-note validation passed.
