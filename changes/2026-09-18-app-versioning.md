---
type: changed
bump: none
area: release
summary: Centralize app versions and prepare releases from the impact recorded in PR notes.
---

## Details

- Use major.minor.patch app versions and a separate increasing build counter in config/Version.xcconfig.
- Normalize the existing configured 1.0 to 1.0.0, retaining build 1 without publishing a release.
- Select the next version from pending release notes, support preview and build-only commands, and reject regressions and duplicate releases.
- Make Xcode and preflight read the same config, validate progression in PR CI, and verify release tags against version metadata and release notes.
- Keep internal-only notes out of public changelog entries while archiving them for traceability.

## Verification

- Isolated workflow/version regression tests, static preflight, Xcode project lint, and version preparation preview passed.
- CI builds the iOS app and checks its Info.plist against the shared version config even if the independent gateway audit fails.
- Local iOS build verification remains blocked by the unaccepted Xcode license.
- The parent workflow PR has a separate failing gateway dependency audit; this change does not alter gateway dependencies.
