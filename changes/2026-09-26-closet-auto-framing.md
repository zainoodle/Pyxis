---
type: fixed
bump: patch
area: closet
summary: Isolate garments with offline SAM cutouts, automatic quality checks, and consistent framing.
---

## Details

- Replace the final Vision foreground mask with bundled SAM 2 Tiny segmentation, using automatic interior prompts to isolate garments from flat-lay and hanger photos.
- Remove isolated mask scraps, retain substantial paired pieces, fill tiny pinholes, and interpolate mask logits before rendering full-resolution edges.
- Review masks and rendered alpha automatically; retain the original when processing fails or the cutout is implausible.
- Trim transparent space with a small margin before saving cutouts and thumbnails. Frame older cutouts for display without rewriting stored images or changing the SwiftData schema.
- Apply the same pipeline to Improve Cutout in Add Item and saved details. Rejected improvements retain the current cutout and thumbnail; repeated improvements use the original and refresh the preview.
- Bundle approximately 80 MB of models for offline processing. Optional AI garment cleanup is unchanged.

## Verification

- Swift suite: 149 passed, one optional private-fixture integration test skipped; local run with the actual failing photo: 150 passed.
- Workflow suite: 25 passed.
- Signed iPhone Debug build, install, and launch: passed.
- Production cutout on the connected iPhone: passed in 8.48 seconds on the failing shirt photo. Inspected the output; table, hanger, and surrounding objects removed. Private source and output stay local.
- Earlier Simulator visual checks: Closet, Fits, and Create Outfit with existing seed images. Interactive retry behavior is covered by regression tests; hardware diagnostic does not exercise button taps.
- Wider garment/hand/background accuracy remains a manual QA item; one successful photo is not a broad benchmark.
