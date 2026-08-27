---
type: changed
bump: none
area: release-engineering
summary: Standardize commit history, push update notes, version bumps, and release notes.
---

## Details

- Added repository-local Git hooks and GitHub Actions checks for Conventional Commit subjects and structured change fragments.
- Added commands to create, validate, render, and release update notes without a third-party release dependency.

## Verification

- Ran the fragment and commit-policy validators against representative passing and failing inputs.
