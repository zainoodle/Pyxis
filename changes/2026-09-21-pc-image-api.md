---
type: added
bump: minor
area: ai
summary: Add a private PC model API and a separate Debug try-on connection over Tailscale.
---

## Details

- Add an authenticated loopback API that binds selected person/garment images into operator-reviewed ComfyUI image-edit workflows.
- Add Debug-only PC routing, supported garment counts, and a separate consent disclosure for temporary PC files. Existing xAI consent cannot authorize PC uploads.
- Serialize GPU requests, strip metadata, bound transfers, clean completed job files, and journal job IDs to prevent duplicate work after restarts.
- Fix generated app configuration with explicit Debug/Release Info.plist inputs, and verify Debug settings in CI.
- Keep production purchase verification and the existing cleanup app route unchanged. No stored closet migration or version bump.
- Depends on draft PR #7. One synthetic PC job is verified; real photo quality and the iPhone flow remain unverified.

## Verification

- Passed: 133 Swift tests; 12 API tests including HTTP adapter integration with synthetic images; 25 workflow tests; static deployment preflight.
- Passed: iOS Debug and unsigned Release builds; Debug includes configured API values, and Release excludes private PC URL/token sentinels.
- Passed: iPhone 17 Pro simulator coming-soon state, private-PC controls, and PC privacy disclosure using a temporary mock configuration. Mock source removed after verification; screenshots are labeled fixtures.
- Passed on the PC: one synthetic person-plus-garment API job against local Qwen Image 2.1, wrong-token refusal, and removal of that job's files. Tailscale Serve port 8443 answered health from the Mac. The existing port 443 mapping was not changed.
- Blocked: real photo fidelity, garment counts above one, cleanup workflow, and physical-device QA.
