---
type: added
bump: minor
area: appearance
summary: Add coordinated light and dark appearances across Pyxis.
---

## Details

- Use the same minimal monospaced layout in both appearances, with warm white surfaces in light mode and charcoal surfaces in dark mode.
- Add a System, Light, and Dark appearance control in Profile. The choice is stored on this device and does not change closet data or photos.
- Give garment imagery a neutral display surface in Closet, item detail, and Build so black and white pieces remain visible in either appearance.

## Verification

- iPhone 17 Pro simulator build passed with `xcodebuild`.
- Light and dark closet screens were checked on the iPhone 17 Pro simulator; screenshots are in `docs/screenshots/`.
