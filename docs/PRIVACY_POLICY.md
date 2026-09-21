# Pyxis Privacy Policy

Effective date: 2026-09-18

## Summary

Pyxis is a local-first closet app with optional AI image features. Pyxis does not create user accounts, run ads or analytics, sell data, or share data with data brokers.

## On-device information

Clothing photos, cutouts, thumbnails, item details, closets, saved fits, wear counts, Fit Passport measurements, and on-device memory records stay in the app's local container. Your measurements and unrelated closet contents are never included in try-on requests.

Outfit on you uses a full-body reference and clothing images you select. Remembering the reference is optional. Saved references and previews stay in protected local files excluded from device backups. Unsaved try-on photos are removed when the screen closes; interrupted sessions are cleaned the next time you open try-on. The app remembers your photo-processing consent locally, and you can revoke it from the try-on privacy screen.

## Optional photo processing

Choosing photos does not upload them. Pyxis re-encodes selected images to remove source metadata before transmission. Generation requires a deliberate action and disclosure of who processes the photos.

**Outfit on you:** after you agree, your reference and selected clothing images pass through the Pyxis Cloudflare gateway to xAI to generate a preview. This feature requires zero-retention processing: photo inputs and outputs are not persistently stored by xAI, and Pyxis does not authorize their use for model training. The gateway does not persist photos. A completed result may remain briefly in gateway memory for up to 60 seconds to recover a repeated request. Previews are visual illustrations, not size or fit guarantees.

**AI garment cleanup:** this separate optional action uses xAI's standard data controls, under which requests and responses may be retained for up to 30 days. Its disclosure is shown before you generate. Pyxis cannot selectively delete data held under that provider retention process.

## Purchases and usage records

Apple processes subscription payments; Pyxis does not receive card details. To verify access and enforce your allowance, the gateway verifies signed purchase information with Apple and stores billing-period, successful-generation counts, and generation identifiers associated with your subscription's transaction identifier. These records are used for app functionality, never advertising or analytics. Records are removed 35 days after the recorded billing period ends unless continued use updates the period. Deleting the app does not cancel an Apple subscription or immediately erase these server records. You can manage or cancel subscriptions in Apple's subscription settings.

## Deleting data

Remove a remembered reference using the photo's remove control or turn off “Remember my photo on this device.” Delete saved previews from Saved Previews. Delete closet items and fits through their normal app controls. Deleting the app removes its local data from the device. Copies you explicitly share outside Pyxis are controlled by the destination you choose.

## Changes and contact

Privacy changes are reflected here before an app update is submitted. For support, privacy questions, or requests concerning purchase/usage records, contact zainoodle@gmail.com.

### Personal development connection to a PC

Debug builds may optionally use a private Tailscale connection for try-on processing on a configured PC. This requires separate permission from xAI processing. ComfyUI writes temporary selected photos and results on the PC, where its owner can access them. Completed API jobs remove their own files; interrupted jobs may leave files requiring manual cleanup. Reviewed local workflows must not upload photos to cloud providers. This mode does not use App Store purchases and is not enabled in Release builds. See [PC image API](PC_IMAGE_API.md).
