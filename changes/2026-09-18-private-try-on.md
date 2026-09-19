---
type: added
bump: minor
area: try-on
summary: Add private paid outfit previews with photo references, garment selection, and monthly allowances.
---

## Details

- Add an image-only Outfit on you flow from Build and saved fits, including closet/Photos input, on-device garment suggestions, editable types, original/preview comparison, and local saved previews.
- Keep API settings, model selection, and provider credentials on the backend. Unconfigured builds expose preparation and saved previews without uploading photos.
- Require explicit versioned consent and verified xAI zero-retention processing. Reference saving is opt-in; protected try-on files are excluded from backups and abandoned sessions are removed on next launch.
- Add StoreKit monthly subscription purchase/restore and server-verified entitlement, durable allowance, idempotency, concurrent-job protection, and refund-on-failure behavior. Initial configurable allowance is 20 successful previews.
- Add staging-only Debug test access; production rejects test credentials and Release strips the token. Retire the former try-on endpoint to prevent bypassing paid limits.
- Storage is additive with a versioned local manifest; existing SwiftData/closet records are unchanged. Future manifest versions fail closed. Purchase/usage metadata is declared in the privacy manifest and expires 35 days after the recorded billing period unless renewed usage updates it.
- Depends on security hardening PR #5, which depends on versioning PR #4. Existing garment cleanup remains standard-retention (up to 30 days) and retains its separate shared-token release blocker.

## Verification

- Passed: 129 Swift tests, 26 Worker tests, 25 workflow tests, JavaScript checks, dependency audit (zero vulnerabilities), Worker dry-run bundle, and static privacy/deployment preflight.
- Passed: iOS Simulator Debug and unsigned iOS Release builds; Release artifact excludes an intentionally supplied staging-token sentinel.
- Passed: local workerd HTTP configuration/usage, invalid photo rejection without allowance consumption, and malformed StoreKit proof rejection.
- Passed: iPhone 17 Pro simulator Build entry, empty try-on layout, coming-soon state, privacy sheet, closet picker, and native photo picker; screenshots in docs/screenshots/try-on-start.png and docs/screenshots/try-on-privacy.png.
- Blocked pending external setup: real xAI output quality/ZDR account configuration, real Apple Sandbox purchase/renewal/refund flows, deployed Worker checks, physical-device/accessibility QA, and final pricing. No live provider requests, purchases, deployment, merge, or release performed.
