---
type: fixed
bump: patch
area: closet
summary: Automatically review and frame garment cutouts so closet items appear at a consistent size.
---

## Details

- Review foreground masks and rendered alpha automatically; keep the original image when the cutout is implausible.
- Trim transparent space with a small margin before saving new cutouts and thumbnails.
- Frame older cutouts when displayed in Closet and Fits without rewriting stored images or changing the SwiftData schema.
- Keep automatic processing on device. Optional AI garment cleanup is unchanged.

## Verification

- `./scripts/test.sh`: 142 passed, including framing and mask-quality regression tests.
- iOS Simulator Debug build: passed.
- iPhone 17 Pro Max simulator: visually checked Closet, Fits, and Create Outfit with existing seeded cutouts.
