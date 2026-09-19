# Pyxis App Store Submission

Try-on addendum: 2026-09-18; earlier release evidence remains historical.

This checklist translates the current Xcode project and local-first product scope into App Store Connect fields. Use it after the physical-device QA gates in `docs/MANUAL_QA.md` pass.

## Build Facts

- App name: `Pyxis`
- Bundle ID: `com.zainoodle.pyxis`
- Version: `1.0`
- Build: `1`
- Platform: iOS
- Device family: iPhone only
- Minimum iOS version: 17.0
- Primary category: Lifestyle
- Signing style: Automatic
- Privacy manifest: `assets/PrivacyInfo.xcprivacy`
- App icon source: 1024 x 1024 opaque PNG with no alpha channel
- App Store export options template: `config/deployment/ExportOptions-AppStoreConnect.plist`
- Privacy label posture: photos are declared linked and non-tracking because paid try-on requests authenticate a subscription. Garment cleanup retains standard xAI retention up to 30 days; try-on requires zero-retention photos. Purchase history, subscription identifiers, and usage records are also linked and used only for app functionality. App-only consent preferences declare UserDefaults reason CA92.1. Reconcile final App Store Connect answers with the shipped configuration.

## App Store Connect Metadata Draft

- Name: `Pyxis`
- Subtitle: `Private closet & outfit log`
- SKU: `pyxis-ios-1`
- Keywords: `closet,wardrobe,outfits,clothing,style,organization,local-first`
- Promotional text: `A quiet, local-first closet log for saving clothes, cutouts, and fits on your iPhone.`
- Description:

```text
Pyxis is a local-first closet organizer for iPhone.

Save clothing photos, remove backgrounds on device, organize pieces into closets, and assemble saved fits. Core closet data, Fit Passport measurements, and on-device memory remain local. There are no accounts, analytics, ads, or cloud sync.
```

- Support URL: publish `docs/SUPPORT.md` at a stable public URL before submission
- Privacy Policy URL: publish `docs/PRIVACY_POLICY.md` at a stable public URL before submission
- Marketing URL: optional
- Copyright: external owner value required before submission
- Age rating: complete App Store Connect questionnaire. Expected result should be low age rating for a clothing organization utility with no user-generated public sharing, messaging, commerce, gambling, unrestricted web access, or mature content.
- Content rights: app should not contain third-party content unless screenshots include user-provided clothing photos. Use only owned or licensed screenshot images.

## App Privacy Answers

Draft privacy answers require review against the actual release configuration:

- Tracking: No.
- Photos or Videos: linked, non-tracking, App Functionality; existing standard-retention cleanup remains disclosed. Try-on uses explicit consent and xAI zero-retention processing.
- Purchase History, User ID (subscription transaction identifier), Product Interaction (allowance/generation records): linked, non-tracking, App Functionality.
- Required-reason API: UserDefaults, CA92.1, for app-only photo-processing consent.
- No advertising or analytics SDKs. Apple handles subscription payments. The backend uses Apple's verification library.

App Store subscription setup requires a monthly auto-renewable product, localized price/title, review information and screenshots, and the published privacy-policy URL. The paywall shows the StoreKit price, monthly allowance, auto-renewal language, restore, manage subscription, Apple standard EULA, and in-app privacy disclosure. Validate purchase, renewal, cancellation, expiration, refund, and restore in Apple Sandbox before submission. See [gateway setup](AI_GATEWAY.md).

If AI is unavailable in the submitted Release build, remove AI claims from all release metadata and reassess the answers from the actual artifact. Do not infer the final label from this draft alone.

## Screenshot Requirements

The app is configured as iPhone-only. Upload one to ten iPhone screenshots in `.png`, `.jpg`, or `.jpeg` format. Prefer current 6.9-inch portrait screenshots accepted by App Store Connect:

- 1260 x 2736
- 1290 x 2796
- 1320 x 2868

Required screenshot set:

- Empty closet state
- Add item flow with a representative clothing photo
- Saved item detail with cutout
- Search/filtered closet grid
- Outfit builder or saved fit detail

Do not use private personal photos in public screenshots. Use owned/licensed clothing images or intentionally staged sample images.

## External Gates Before Upload

- Publish `docs/SUPPORT.md` and `docs/PRIVACY_POLICY.md` at stable public URLs.
- Confirm both public pages use the same support contact configured in App Store Connect.
- Confirm Apple Developer Team and App Store Connect app record.
- Confirm Bundle ID in App Store Connect exactly matches `com.zainoodle.pyxis`.
- Confirm version/build are not already used for an uploaded build.
- For physical device testing, trust the developer profile/signature for team `2AW3C9R4CX` on the connected iPhone before launch.
- Sign in to the correct App Store Connect provider in Xcode or configure an App Store Connect API key for command-line export/upload.
- Create or download the App Store distribution certificate/profile for `com.zainoodle.pyxis`.
- Complete age rating, content rights, pricing/availability, DSA/trader status, export compliance, and any region-specific compliance fields.
- Run physical iPhone QA with real clothing images.
- If AI is enabled or mentioned in metadata, verify a production HTTPS gateway, production authorization stronger than the prototype shared token, provider retention, and the exact App Store privacy answers. Otherwise keep AI unavailable and unadvertised.
- Run `./scripts/deployment_preflight.sh distribution` and resolve any signing/export failure.
- Create a distribution-signed Release archive with the intended App Store distribution profile/certificate, then export it with `config/deployment/ExportOptions-AppStoreConnect.plist`.
- Upload the signed build and wait for App Store Connect processing.

## Apple References

- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [App information fields](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Required properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
