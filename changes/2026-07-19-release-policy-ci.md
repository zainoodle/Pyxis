---
type: fixed
bump: none
area: release-policy-ci
summary: Make release-policy checks portable and grandfather pre-policy commits.
---

## Details

- Start pull-request validation at the commit that introduced the release policy when the target branch predates that policy.
- Use portable `grep` matching in release-note scripts so validation does not depend on ripgrep being installed on the CI runner.
- Document how the one-time migration baseline differs from normal validation after the policy reaches the target branch.

## Verification

- Run the commit and update-fragment validators from the simulated pull-request policy base.
- Run the release-note renderers without ripgrep on `PATH`.
- Run the full local deployment preflight.
