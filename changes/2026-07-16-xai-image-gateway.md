---
type: added
bump: minor
area: ai-studio
summary: Connect AI garment cleanup and try-on to a protected xAI image gateway.
---

## Details

- Added a Cloudflare Worker that validates and rate-limits Pyxis image requests, keeps the xAI provider key server-side, and handles multi-garment try-on in bounded xAI edit batches.
- Downsampled and re-encoded selected uploads to remove source metadata, and added an independently revocable gateway token.
- Updated in-app disclosures, privacy language, architecture notes, and deployment instructions for xAI's standard retention behavior.
- Updated the privacy manifest and release preflight to declare optional photo collection for app functionality as unlinked and non-tracking.
- The initial shared app token is suitable for a private prototype or limited TestFlight; App Attest or short-lived server tokens remain required before broad public distribution.

## Verification

- `cd backend/pyxis-ai-worker && npm test && npm run check`
- `swift test`
- `./script/deployment_preflight.sh local`
