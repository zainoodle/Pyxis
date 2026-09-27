---
type: changed
bump: patch
area: design-system
summary: Translate the charcoal editorial design into the light palette so both appearances share one layout.
---

## Details

- Collapse the dark/light style forks across closet, search, fits, profile, item detail, and outfit views. Light mode now uses the same editorial typography, tracking, hierarchy, navigation, and layout as dark mode.
- Make `editorialGlow` and `editorialCanvas` adaptive: dark keeps the white rim-light effect; light uses a warm hairline halo and ink wash at matching strengths.
- Show the custom `EditorialTabBar` (sliding underline, tracked labels) in both appearances instead of falling back to the system tab bar in light.
- Unify Fits around the editorial gallery layout for both appearances: tracked PYXIS/FITS header, editorial search field, chip filters, underlined sort bar, canvas-plated flat-lay tiles, and the bottom Create Outfit action.
- Render garment and outfit compositions on the adaptive `imageCanvas`/`galleryCanvas` plates so light garments stay visible on light surfaces.
- Extend `PyxisPressableStyle` and selection animations to fit tiles, gallery chips, sort controls, carousel items, and appearance options.
- Simplify the Fits page: remove the header manifesto, the duplicate filter menu inside search, the duplicated FAVORITES sort action, suggested-look summary/tags copy, and verbose empty-state text so the gallery reads as a lookbook, not a manual.

## Verification

- `./scripts/test.sh`: 138 passed.
- Debug build: `xcodebuild -scheme Pyxis` succeeded for iPhone 17 Pro simulator.
- iPhone 17 Pro simulator: light and dark appearance screenshots verified — identical layout and editorial hierarchy in both.
