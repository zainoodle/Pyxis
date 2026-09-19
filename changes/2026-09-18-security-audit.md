---
type: security
bump: patch
area: security
summary: Bound AI transfers, validate provider images and redirects, and patch gateway development dependencies.
---

## Details

- Enforce multipart limits on received bytes, validate allowed fields, and bound provider JSON/image responses.
- Validate intermediate try-on images before reuse and reject redirected provider downloads and native uploads.
- Upgrade Wrangler to 4.131.0 to resolve its vulnerable sharp dependency.
- Record the full audit and unresolved shared-token public-release blocker in docs/SECURITY_AUDIT_2026-09-18.md.
- No stored-data changes or app version bump; depends on versioning PR #4.

## Verification

- Passed: 18 Worker tests; 10 security regression tests fail against the original Worker.
- Passed: Worker syntax check, npm audit (zero findings), local Wrangler bundle and HTTP smoke checks, 25 workflow tests, static deployment preflight.
- Blocked: native tests/build/simulator until Xcode license/setup completes. No production deployment.
