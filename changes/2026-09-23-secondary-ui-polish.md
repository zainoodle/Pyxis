---
type: changed
bump: patch
area: ui
summary: Make saved fits easier to scan and keep Add Item status concise.
---

## Details

- Use the available width in the Fits gallery while keeping compact cards in the Build strip.
- Keep the Add Item cleanup failure message readable without repeating the save action, and remove the unavailable AI Studio paragraph when the AI action is absent.
- Preserve existing navigation, stored outfits, image handling, and offline behavior.

## Verification

- iPhone 17 Pro simulator build and launch passed with the combined PR chain.
- Fits and Add Item were inspected at default text size; Fits also rendered at the largest accessibility text size.
- 110 Swift package tests, 25 workflow tests, and release-note validation passed.
