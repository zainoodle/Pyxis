# Pyxis working agreements

- Be concise and high signal. State blockers plainly.
- Read `CONTRIBUTING.md` before changing code or preparing a PR.
- Keep one purpose per branch and PR; use `codex/<short-purpose>` branches.
- Codex owns descriptive Conventional Commit PR titles and keeps the PR description current.
- Before adding unrelated work, tell Isaiah: “This needs a separate PR: <proposed title>,” explain why, and keep it separate. Do not wait for him to remember.
- Check the current branch, diff, and PR before starting; preserve existing work. Use a separate worktree when tasks overlap. Explicitly identify dependent PRs.
- Keep app entry points in `src/main/`, business logic in `src/services/`, models in `src/models/`, and shared helpers in `src/utils/`. Follow the existing view and persistence structure.
- Preserve the local-first experience. Never commit secrets, silently add photo uploads, or change stored data without an upgrade/migration plan.
- Test changed behavior with relevant existing checks; add regression coverage for bugs. Check visible changes on a simulator or device.
- Use `major.minor.patch` app versions and an increasing build counter from `config/Version.xcconfig`; prepare changes with `scripts/version.py`, never bump versions for each PR.
- Maintain one release-note fragment per PR and update it during review. Keep docs aligned with the final change.
- Report checks as passed, failed, or blocked; never describe unrun checks as passing.
- Prepare draft PRs with the problem, resulting behavior, verification, and relevant risks. Isaiah decides when to merge or release; do not merge or publish without his instruction.

## UI/UX skills are the default

- Treat Pyxis as a design-led app project. Automatically use the relevant available UI/UX skills for interface work, including advice, critiques, typography, colors, layouts, navigation, interaction, accessibility, mockups, and implementation. Isaiah should not need to request skills each time.
- At the start of UI/UX work, read and apply `ios-design` for native iPhone behavior and `minimalist-ui` for the established editorial direction. Read each skill once per conversation and reuse it; consult additional references as the task requires. User-approved choices take precedence over skill defaults.
- Route additional skills by task: `product-design:audit` for reviewing existing screens and flows; `product-design:ideate` for visual alternatives and mockups; `build-ios-apps:swiftui-ui-patterns` for native UI implementation; and `emil-design-eng` for interaction and motion polish. Discover the current skill locations from the available-skills catalog rather than hardcoding machine paths. If a required skill is unavailable, state that briefly and use the closest available guidance.
- Keep one cohesive design system across screens: typography roles, color and surface depth, spacing, component states, labels, and navigation. Preserve garment identification codes and respect the latest approved design direction. Evaluate a local change against the surrounding flow, not just the isolated component.
- Use design judgment: give a clear recommendation and explain the relevant tradeoff. When comparing fonts, layouts, or visual directions, show them in the actual Pyxis context where practical. Honor requests for mockups before implementation; do not introduce an extra approval step when implementation is already authorized.
- Verify visible changes in the rendered app, including relevant empty/error states, accessibility text sizes, and dark/light appearances. When Isaiah asks to see work on his phone, use the connected physical device. Report any verification limits accurately.
- Briefly name the skills being applied when first using them in a conversation. Keep skill mechanics out of the product UI and keep user-facing updates concise.
- Apply this design workflow to user-facing work; choose task-relevant engineering skills for purely backend, build, or repository maintenance work.
