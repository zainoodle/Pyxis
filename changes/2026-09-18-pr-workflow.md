---
type: changed
bump: none
area: workflow
summary: Adopt focused PRs with Codex-owned titles, scope reminders, and one release note per PR.
---

## Details

- Add concise agent instructions and contributor guidance for branch scope, code standards, verification, and release approval.
- Validate release notes across the whole PR, including follow-up pushes; read committed fragment content and allow an empty pending directory after release preparation.
- Enforce Conventional Commit PR titles in CI and preserve legacy commit-policy boundaries in local hooks.
- Install ripgrep in the CI runner so the required static preflight can execute.
- Keep release preparation separate and tag the merged release commit.

## Verification

- Workflow regression tests cover follow-up pushes, missing/invalid notes, committed content, dependent branches, direct-main rejection, and release archival.
- Workflow tests, shell syntax checks, and static deployment preflight passed.
- Application build and Swift tests remain blocked locally by the unaccepted Xcode license.
