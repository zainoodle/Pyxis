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
- Apply the same automatic review and framing to Improve Cutout in Add Item and saved item details. Rejected improvements retain the current cutout and thumbnail; repeated improvements use the stored original and refresh the preview.
- Keep automatic processing on device. Optional AI garment cleanup is unchanged.

## Verification

- `./scripts/test.sh`: 145 passed, including framing, mask quality, rejected improvement preservation, and repeated retry regression tests.
- iOS Simulator Debug build: passed.
- iPhone 17 Pro Max simulator: visually checked Closet, Fits, and Create Outfit with existing seeded cutouts.

- Follow-up Simulator build and launch: passed. Interactive retry verification blocked by Simulator control timeouts; retry behavior verified by regression tests.
