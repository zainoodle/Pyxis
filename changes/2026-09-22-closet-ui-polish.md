---
type: changed
bump: patch
area: closet
summary: Give closet search more room and keep controls and item names readable at larger text sizes.
---

## Details

- Make closet search full width, with sort and favorites grouped below it.
- Give compact navigation and active-filter controls larger hit regions, and allow favorites and garment names to wrap.
- Keep the existing white, monospaced catalog style and local data behavior.

## Verification

- `./scripts/build_and_run.sh --verify` passed on iPhone 17 Pro simulator (iOS 26.5).
- `./scripts/test.sh` passed: 110 tests.
- `python3 -m unittest discover -s tests/workflow -v` passed: 25 tests.
- Compared baseline and refined Closet screenshots at default and largest accessibility text size; checked a narrower iPhone 17e render.
- Interactive controls, VoiceOver, keyboard, and filter-sheet navigation remain unverified because the available simulator UI control interface could not operate the app.
