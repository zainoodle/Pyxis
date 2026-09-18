---
type: changed
bump: patch
area: repository
summary: Organize application code, tests, scripts, assets, and configuration into dedicated folders.
---

## Details

- Move iOS code into `src/`, Swift tests into `tests/`, and developer commands into `scripts/`.
- Keep bundled resources in `assets/`, build/export settings in `config/`, and original reference documents in `docs/references/`.
- Update Xcode synchronized groups, SwiftPM paths, Git hooks, CI, the Codex Run action, and documentation.
- Preserve the gateway's independent package under `backend/pyxis-ai-worker/` and recognize both historical script paths in CI policy checks.
- Preserve application code, tests, and resource contents.

## Verification

- `./scripts/deployment_preflight.sh static` passed.
- `bash -n` passed for all shell scripts and Git hooks.
- Gateway tests passed (6 tests), and `npm run check` passed.
- Swift tests and the unsigned iOS Simulator build were attempted but blocked by the machine's unaccepted Xcode license.
