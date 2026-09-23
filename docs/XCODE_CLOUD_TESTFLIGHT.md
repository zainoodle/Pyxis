# Xcode Cloud and internal TestFlight

Xcode Cloud can sign and deliver Pyxis without using the Mac's login keychain. This is an alternative to a cable-installed development build. It needs an Apple Developer Program account, an App Store Connect app record, and GitHub access granted to Xcode Cloud. Apple-side access has not been configured or verified from this repository.

## Repository settings

| Setting | Value |
| --- | --- |
| GitHub repository | `zainoodle/Pyxis` |
| Xcode project and shared scheme | `Pyxis.xcodeproj`, `Pyxis` |
| Bundle ID | `com.zainoodle.pyxis` |
| Development team | `2AW3C9R4CX` |
| First workflow | Manual build, no distribution, from the approved release branch |
| TestFlight workflow | Manual archive and internal TestFlight distribution after release approval |

The executable `ci_scripts/ci_post_clone.sh` checks the committed version configuration on each Xcode Cloud checkout. It does not access credentials, change the version, or start distribution.

## Apple-side setup

1. In Xcode's Cloud report navigator, start Xcode Cloud setup for Pyxis. Use the existing `com.zainoodle.pyxis` App Store Connect record if one exists; otherwise an Account Holder, Admin, or App Manager must create it.
2. Grant Xcode Cloud access to **only** `zainoodle/Pyxis` on GitHub. Confirm the team and bundle ID before accepting the connection.
3. Create a **manual** build workflow using the shared `Pyxis` scheme. Leave TestFlight distribution off for the first build. Choose the approved release branch once its dependent PRs have merged. A workflow that builds one open PR branch will omit changes from the other PR chain.
4. After the release PR is reviewed and merged, add an Archive action with internal TestFlight distribution and an internal tester group. Keep its start condition manual so a push cannot distribute a build. Review the branch, version, build number, and tester group before starting it.

Xcode Cloud assigns and increments its own build number. Before the first distribution build, compare the next Cloud number with `config/Version.xcconfig` and the builds already used in App Store Connect. Coordinate any adjustment with `scripts/version.py` in the release PR. Do not assume the current `1.0.0 (1)` local setting is a new uploadable candidate. The current combined PR set dry-runs as `1.1.0 (2)`, subject to an App Store Connect collision check.

## Release gates

- Merge the dependent feature/fix PRs only with Isaiah's approval; then prepare the separate release PR using `./scripts/prepare_release.sh auto` and its existing-data upgrade plan.
- Pass `./scripts/deployment_preflight.sh local` before the first internal TestFlight build. Use that build to complete `docs/MANUAL_QA.md` and the existing-closet upgrade check on a real iPhone before any wider distribution.
- Review the shipped AI configuration and App Store Connect privacy answers. Confirm support and privacy URLs, app metadata, and any subscription setup required by the release build.
- Get Isaiah's approval for the exact candidate before starting the internal TestFlight workflow. TestFlight installation does not require Developer Mode on the iPhone.

Apple references: [Xcode Cloud setup](https://developer.apple.com/documentation/xcode/getting-started-with-xcode-cloud), [GitHub connection](https://developer.apple.com/documentation/xcode/connecting-xcode-cloud-to-github), [internal TestFlight workflow](https://developer.apple.com/documentation/xcode/distributing-your-xcode-cloud-builds-through-testflight), [Cloud build numbering](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds/), and [custom build scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts).
