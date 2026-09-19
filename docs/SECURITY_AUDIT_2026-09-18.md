# Pyxis security audit — 2026-09-18

## Executive summary

**Public AI Studio release is blocked by the extractable shared gateway credential.** The local-first architecture substantially limits remote access to closet data. The two paid AI endpoints are the main exposed service. This review found five security findings: **0 Critical, 1 High, 2 Medium, 2 Low**. Four have code remediations; the High authentication finding remains open. Native core tests and the iOS build pass in GitHub CI; local simulator/device verification remains blocked by Xcode setup. This is a source and local-test review, not a certification of the deployed infrastructure.

Reviewed baseline: `96d4318` on `codex/app-versioning`; remediation branch: `codex/security-audit`. This PR depends on versioning PR #4, which itself depends on the earlier repository/workflow work. No production service was deployed, no photos were uploaded, and no stored-data schema or app version was changed.

## Architecture and trust boundaries

| Surface | Source → validation → processing → storage/output |
| --- | --- |
| Photo imports | PhotosPicker, camera, file importer, drag-and-drop → platform image decoding/security-scoped access → local Vision/Core Image processing → UUID-named Application Support images and SwiftData metadata → downsampled native views |
| Local metadata | Native text/measurement controls → typed models, measurement parsing and local service checks → SwiftData and in-process filtering → native SwiftUI text; no HTML interpreter |
| AI cleanup | Explicit `AI DE-WRINKLE` action → metadata-free, 2048-pixel JPEG encoding → authenticated multipart `POST /v1/ai/garment-cleanup` → fixed xAI edit endpoint → bounded image response → local cutout storage |
| AI try-on | Explicit generation action → selected person and up to six garments → authenticated multipart `POST /v1/ai/virtual-try-on` → one to three sequential xAI edits → temporary local preview |
| Gateway | Shared bearer token → SHA-256 digest comparison and Cloudflare address limiter → bounded multipart schema and image signatures → fixed provider prompt/model → validated provider images; no KV/R2/D1 writes |
| Health | `GET /health` → static status/provider JSON; no secret or configuration values |
| Delivery | Xcode/SwiftPM, npm lockfile/Wrangler, shell/Python scripts, read-only GitHub Actions permissions → tests, policy validation and builds; production releases require maintainer action |

All current executable surfaces were inventoried: `src/`, Worker source/tests/config, Swift tests, package manifests, Xcode/config/privacy metadata, scripts/hooks/workflows, and operating/privacy/migration documentation. Reference PDFs/DOCX and design assets are not executable application inputs; their contents were not assessed as an application security boundary. Historical branches were included in the secret-pattern scan, not in the full functional code review.

The baseline uses [OWASP Top 10:2025](https://top10.owasp.org/2025/0x00_2025-Introduction/), [API Security Top 10:2023](https://owasp.org/projects/api-security-project), and [ASVS 5.0](https://owasp.org/projects/asvs), applied to the native app and actual API boundaries. No ASVS conformance level is claimed.

## Findings

### SEC-01 — High: distributed shared bearer token permits paid API abuse — OPEN

- **Locations:** `config/Pyxis.xcconfig`, `Pyxis.xcodeproj/project.pbxproj` (`INFOPLIST_KEY_PYXIS_AI_ACCESS_TOKEN`), `src/services/AIGarmentStudioService.swift` (`configuredAccessToken`), Worker `authorize` and `applyRateLimit`.
- **Root cause:** the same reusable gateway token is embedded in configured app bundles and grants both paid operations. There is no device/user identity, token expiry, per-principal quota, or replay accounting. The six-requests-per-minute limiter is keyed by address, not by a verified installation, and a six-garment request makes three paid edits.
- **Scenario:** a recipient extracts the token from their configured build and calls the Worker outside the app. Multiple source addresses increase consumption and can exhaust the owner's provider budget. This grants generation access, not access to other users' locally stored wardrobes. No real credential was extracted or exercised.
- **Evidence:** build configuration and server authorization data flow; tests confirm a caller possessing the test token can reach the mocked provider. The limitation was already documented in `docs/AI_GATEWAY.md`.
- **Required remediation:** verified App Attest enrollment/assertions with server challenges and replay protection, or an authenticated issuance service with short-lived scoped tokens and enforceable per-principal quotas. A provider-side spending cap is also needed. Apple documents the [server validation design](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server).
- **Status:** not fixed. Moving this value to Keychain or obscuring it would not resolve the trust problem. An actual fix needs Apple app identity/entitlements, persistent server state and a coordinated deployment/migration for existing beta clients. The current private-beta behavior remains intact; do not treat it as production authentication.

### SEC-02 — Medium: multipart upload limit bypass/resource exhaustion — FIXED

- **Location:** Worker `validateRequestHeaders`, `handleRequest`, `readBoundedBody`, `validateFields`.
- **Root cause:** `Content-Length` was the only aggregate limit before `request.formData()` buffered the body. Unknown fields were ignored; per-image limits ran after parsing.
- **Scenario:** an authorized or extracted-token caller sends a chunked body without a length, including oversized unused fields. The parser consumes it before rejecting individual images, potentially exhausting the Worker isolate. A forged small length reproduces the same application-level flaw; whether the edge accepts a mismatched HTTP length depends on transport framing.
- **Remediation:** cap actual received bytes at 32 MiB before multipart parsing, cancel on overflow, bound transfer duration, reject malformed lengths and unexpected field names, and require canonical garment fields. A growing contiguous buffer avoids unlimited per-chunk bookkeeping. PNG validation now checks its full eight-byte signature.
- **Verification:** finite oversized stream tests with absent/understated lengths fail on the baseline and return `413` with cancellation after remediation. Schema, duplicates, malformed MIME/length, oversized images and partial PNG tests pass. Signatures identify formats; they are not a complete image-decoder validation.

### SEC-03 — Medium: provider-response trust failures — FIXED

- **Locations:** Worker `editImages`, `fetchOutput`, try-on loop.
- **Root cause:** only the final provider URL was checked. Earlier URLs went straight into subsequent edits. Output downloads followed redirects after a hostname check; provider JSON/base64/downloads lacked byte limits, and upstream response headers were copied to clients.
- **Scenario:** a compromised or malfunctioning provider response supplies an untrusted intermediate URL, a redirect off the allowed domain, or an excessive response. This can cause unintended fetches or resource exhaustion. **A direct user-controlled SSRF against the live provider was not demonstrated**; the adversary must influence the provider response or an allowed host's redirect. The regression harness simulates that boundary explicitly.
- **Remediation:** validate and download every result before reuse; send image data rather than provider URLs into later batches. Require HTTPS on the existing x.ai domain allowlist, reject embedded credentials/nonstandard ports, reject redirects on provider calls and downloads, cap provider JSON at 28 MiB and images at 20 MiB, set deadlines, validate signatures, and return only application-owned headers.
- **Verification:** tests cover private/link-local/file/HTTP destinations, deceptive hostname suffixes, credentials/ports, invalid intermediate locations, redirect refusal, oversized provider streams, malformed JSON/base64/images, header isolation, inline output, and six garments across three edits. Production DNS/CDN behavior was not exercised.

### SEC-04 — Low: native response limits applied after buffering; redirect exposure — FIXED

- **Location:** `src/services/AIGarmentStudioService.swift`, `generate`, `AITransferDelegate`.
- **Root cause:** `URLSession.data(for:)` buffered the complete response before checking its 20 MiB limit, and error responses were decoded before that check. Default redirect handling could repost a selected-photo upload after a 307/308 response.
- **Scenario:** a faulty or compromised configured gateway returns an unbounded body and terminates the app through memory pressure, or redirects an upload to a different destination. A normal outside API caller cannot directly set another device's gateway response.
- **Remediation:** consume `URLSession.AsyncBytes`, enforce headers and actual bytes before decoding, cancel the task on exit, and reject every redirect. Apply HTTPS/credential/query/fragment checks to injected as well as bundled gateway configuration; reject more than six garments before encoding.
- **Verification:** regression cases added for oversized success/error bodies, redirect delegate refusal, unsafe configurations, and excessive garment counts. Existing route/authentication/image tests retained. All nine AI service tests pass within the 115-test Swift core suite on GitHub CI, and the iOS Simulator target builds successfully. Local launch and real URLSession redirect integration remain blocked by local Xcode setup. Delegate-only coverage is not claimed as an end-to-end redirect test.

### SEC-05 — Low in this deployment: vulnerable development-tool dependency — FIXED

- **Locations:** `backend/pyxis-ai-worker/package.json` and `package-lock.json`.
- **Evidence:** npm audit reported three High package entries (`wrangler` → `miniflare` → `sharp`) for **one underlying advisory**, [GHSA-rgj7-g3m4-5g8c](https://github.com/advisories/GHSA-rgj7-g3m4-5g8c). The upstream issue affects untrusted HEIF processing in sharp versions before 0.35.4.
- **Scenario/qualification:** exploiting the native decoder requires affected development tooling to decode an attacker-controlled image. This Worker does not import sharp or configure an Images binding; the deployed bundle has no such runtime dependency. No reachable production RCE was identified. Project risk is Low; the advisory's upstream High rating is preserved here rather than counted as three independent vulnerabilities.
- **Remediation:** exact Wrangler pin changed from 4.127.0 to 4.131.0, the first version beyond the audit's affected range, resolving sharp to 0.35.4. No major Wrangler upgrade or blanket force-fix.
- **Verification:** npm clean install, tests, syntax check, dependency tree, zero-vulnerability npm audit, and Wrangler dry-run bundling. Lockfile registry URLs and integrity entries reviewed; installed hooks are standard tooling hooks, not app runtime dependencies.

## Security controls confirmed

- Both paid endpoints authenticate and rate-limit before reading image bodies or calling xAI; missing secrets/limiter fail closed. Error output is generic and no request/photo/token logging was found in app/Worker code.
- Fixed provider endpoint, prompts and model configuration; request fields do not select a URL, provider key, prompt, filename, command, table, or role. Uploaded filenames are never used as server paths. No backend filesystem or archive extraction exists.
- No raw SQL/NoSQL, LDAP, XPath, shell execution, templates, dynamic JavaScript evaluation, or prototype-merging of request objects in runtime paths. SwiftData data remains in process and in the local sandbox. Release scripts use argument arrays or quoted variables rather than shell-evaluating PR titles/content.
- No HTML frontend, WebView, DOM sinks, postMessage, localStorage, browser sessions, cookie authentication, password/reset/account flows, or remote per-user records. XSS, browser CSRF, BOLA/IDOR, session fixation, and account enumeration do not have corresponding application surfaces here. The Worker does not enable CORS or accept ambient cookies.
- API JSON/image responses use `no-store` and `nosniff`. CSP, frame policy and Permissions-Policy are not controls for a native client consuming JSON/image bytes; edge HTTPS/HSTS must be checked on deployment.
- Selected-photo uploads are explicit, and ImageIO re-encoding strips source metadata. Body measurements and local memory summaries are not included in requests. No silent upload, account, analytics, or remote persistence code was found.
- Managed image lookup/delete rejects absolute paths, dot components, backslashes and symlink escapes beyond the storage root. Generated names use UUIDs and allowlisted extensions. Existing tests cover path traversal. No remote entry point for rewriting stored paths was found.
- Managed photos use iOS complete file protection. SwiftData schema/migration wiring preserves existing data on startup failure. No storage migration was introduced.
- No custom encryption or password hashing. SHA-256 is used for bearer comparison; the deterministic local embedding hash is non-security feature extraction, not a credential primitive.
- GitHub Actions use read-only repository permissions and normal pull-request events, not privileged `pull_request_target` execution. PR title/tag values pass through environment variables. Debug seed/demo features are compilation-guarded. Production signing inspection remains unverified.
- A redacted pattern scan of 493 reachable Git blobs across 23 local-history commits found only the known test token; tracked config defaults are blank and local secret files are ignored. This bounded pattern scan is not equivalent to all-provider entropy scanning or a guarantee about unreachable/deleted remote history.

## Verification ledger

| Check | Result |
| --- | --- |
| Worker `npm test` | PASS — 18 tests; same suite on baseline: 8 pass, 10 fail |
| Worker `npm run check` | PASS — Node syntax check; no separate TypeScript/linter configured |
| `npm audit --audit-level=low` | PASS — 0 vulnerabilities after dependency fix |
| Wrangler `deploy --dry-run` | PASS — bundle produced locally, no deployment |
| Local workerd startup/HTTP smoke | PASS — health 200, both paid routes 401, method 405, unknown route 404, authenticated invalid MIME 415; no-store/nosniff verified; fake credentials only |
| Workflow unittest suite | PASS — 25 tests |
| `deployment_preflight.sh static` | PASS — metadata/privacy/policy/whitespace checks |
| Targeted redacted repository/history secret scan | PASS — no confirmed credential found |
| Swift core suite | PASS in GitHub CI — 115 tests, 0 failures; local run remains blocked by the Xcode license |
| iOS Simulator target build | PASS in GitHub CI — Debug build and app version verification |
| Local simulator startup | BLOCKED — Xcode setup/license; simulator tool initially used Command Line Tools |
| Live Cloudflare/xAI, real device, signing | NOT RUN — no production actions or real-photo/provider calls |

CI evidence: [successful run for code commit 46aed5b](https://github.com/zainoodle/Pyxis/actions/runs/35408348412). The subsequent report update changes documentation only.

## Remaining risks and release requirements

1. Resolve SEC-01 before public AI distribution. Verify deployed rate-limit bindings, source-IP provenance, secret rotation, hard provider budget controls, TLS/HSTS and access logs. The configured Cloudflare address limit is not a global financial quota.
2. Complete local simulator/device verification after Xcode setup, including actual 307/308 refusal, cancellation during a large chunked response, normal cleanup and one/two/three/six-garment flows. Signed-device/App Attest validation requires real app identity and provisioning.
3. Exercise the revised provider-download flow against a staging deployment with approved test images. It adds intermediate downloads and buffers bounded images before returning them; that increases latency/memory versus the old final-only stream. Measure worst-case concurrent requests under Worker memory limits. The x.ai allowlist trusts provider DNS; provider-domain compromise remains outside this patch.
4. Image signatures and compressed-byte limits do not prove safe decoded dimensions or cover platform image-decoder flaws. Local import/background removal still accepts large user-selected originals. Image-bomb/fuzz testing and current device OS validation remain necessary; no reproducible native decoder exploit was demonstrated.
5. Try-on person/output files remain in the app temporary directory until OS cleanup, and imported originals can retain metadata locally. Device-lock protection for temporary files and SwiftData sidecars, backup behavior, retention cleanup, and device forensics were not validated. No claim of zero on-device retention or protection from a compromised device is made.
6. Per-generation consent is present; concurrent local edit/generation operations can still produce stale previews or orphan files. No cross-user access or privilege boundary exists in that workflow. Stress-test cancellation/lifecycle behavior before release.
7. Full provider retention terms, production observability settings, deployed code equivalence, remote branch protection and private infrastructure were not independently attested. Repository scans cannot certify them.
