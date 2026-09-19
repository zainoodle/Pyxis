#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'error: privacy consistency: %s\n' "$1" >&2
  exit 1
}

for file in \
  docs/PRIVACY_POLICY.md \
  docs/SUPPORT.md \
  docs/APP_STORE_SUBMISSION.md \
  docs/DEPLOYMENT_READINESS.md \
  docs/AI_GATEWAY.md; do
  rg -qi 'xAI' "$file" || fail "$file must identify xAI as the optional AI provider"
  rg -qi '30 days' "$file" || fail "$file must state the active standard provider-retention window"
done

if rg -ni 'Data Not Collected|No data collected' docs/APP_STORE_SUBMISSION.md; then
  fail "App Store notes cannot claim no collection while standard xAI retention is enabled"
fi

rg -q 'NSPrivacyCollectedDataTypePhotosorVideos' assets/PrivacyInfo.xcprivacy \
  || fail "privacy manifest must declare photos or videos for optional AI functionality"
rg -q 'NSPrivacyCollectedDataTypePurposeAppFunctionality' assets/PrivacyInfo.xcprivacy \
  || fail "privacy manifest must limit declared photo use to app functionality"
rg -q 'UP TO 30 DAYS' src/views/AddItem/AddItemFlow.swift \
  || fail "garment AI disclosure is missing the retention statement"
rg -q 'zero-retention processing' src/models/TryOn.swift \
  || fail "try-on disclosure must require zero-retention processing"
rg -q 'not a size or fit guarantee' src/models/TryOn.swift \
  || fail "try-on disclosure is missing the fit disclaimer"
rg -q 'TryOnPrivacy.disclosure' src/views/OutfitBuilder/TryOnSupportingViews.swift \
  || fail "try-on privacy sheet must display the shared disclosure"
rg -q 'X-Pyxis-Consent' backend/pyxis-ai-worker/src/try-on.js \
  || fail "try-on must enforce explicit consent"

printf 'Privacy and AI disclosure surfaces are consistent.\n'
