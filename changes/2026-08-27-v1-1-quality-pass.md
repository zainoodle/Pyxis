---
type: changed
bump: minor
area: product-foundation
summary: Make closet capture, navigation, filtering, persistence, and optional AI behavior clearer and safer.
---

## Details

- Added stable Closet, Build, Fits, and Profile navigation with native detail routes and focused Add Item presentation.
- Added a staged, cancellable Add Item workflow, complete subtype filtering and reset behavior, explicit AI capability state, and safer bounded AI responses.
- Added an explicit SwiftData schema baseline, clean test tooling, privacy consistency checks, and a reviewed Worker dependency update.
- Made the Closet header, search controls, and filter grid adapt at accessibility text sizes, including a single-column filter layout.
- Moved simulator DerivedData out of iCloud-synced source directories and made launch verification compatible with current simulator runtimes.

## Verification

- Run `./script/test.sh`, the full iOS source type-check, Worker tests/check/audit, and static deployment preflight.
- Current iPhone 17e and iPhone 17 Pro Max Simulator builds and launches pass, as do focused Add, filter, navigation, persistence, AI-unavailable, AX5, and Increased Contrast smoke checks.
- Physical-device installation remains gated on enabling Developer Mode on the connected iPhone.
