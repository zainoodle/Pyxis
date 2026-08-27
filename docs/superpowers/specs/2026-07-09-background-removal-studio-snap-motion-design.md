# Background Removal Studio Snap Motion Design

## Summary

Use the **Studio Snap** motion direction for Pyxis background removal. This direction evolved from the liked D3 Editorial Pop, M Editorial Card, R shadow treatment, and Z3 metadata treatment.

The motion should make background removal feel like Pyxis is turning a messy phone photo into a clean product image for the user's closet. It should not feel like a generic loading spinner, a lab scanner, or a flashy AI effect.

## Current Context

The add-item flow currently shows `ProcessingRevealImageView` while `AddItemViewModel.Stage.processing` is active. The current visual is a shutter-like processing animation inside the image preview frame.

The new direction should replace that processing state while preserving the same functional boundaries:

- It lives inside the existing image preview area.
- It appears only while the selected clothing image is processing.
- It transitions to the processed cutout/original preview when processing completes.
- It does not add network calls, accounts, remote processing, analytics, or non-local behavior.

## Selected Direction

**Studio Snap with Subtype + Code metadata** is the selected direction.

It keeps the strongest qualities from the selected explorations:

- A messy source-photo background.
- A soft studio sweep moving across the preview.
- The background fading into a clean product surface.
- The clothing item subtly lifting forward.
- Body/background artifacts fading out visually during the animation.
- A small contact shadow that snaps/settles under the garment near completion.
- A tiny restrained sparkle/finish mark at the end of the reveal.
- Bottom metadata that mirrors Pyxis closet labels: subtype on the left and candidate item code on the right, for example `PANTS / PT-009`.

## Motion Story

1. The user picks a clothing image.
2. The preview shows a stylized version of the selected image or a neutral stand-in while processing starts.
3. A soft diagonal studio-light sweep crosses the image.
4. As the light passes, the messy background fades toward the Pyxis field/surface color.
5. The clothing item subtly lifts and scales forward, as if becoming a product-card cutout.
6. The preview resolves to a clean, even Pyxis surface without a spotlight or circular glow behind the garment.
7. A small shadow compresses and settles under the garment, making the final reveal feel tangible.
8. Tiny finish marks or sparkles appear briefly at the end, but should stay restrained and not become a tech/confetti effect.
9. Bottom metadata fades in using the item's subtype and candidate item code, for example `PANTS / PT-009`.
10. When processing finishes, the real processed image replaces the motion state.

## Visual Language

The motion should stay inside the current Pyxis design language:

- White and warm off-white surfaces.
- Monospaced uppercase status text.
- Monospaced bottom metadata that resembles the existing closet item-code labels.
- Thin hairline strokes.
- Low-contrast shadows.
- No spotlight, circular glow, or stage-light halo behind the garment.
- No bright neon, gradient-orb, or colorful AI styling.
- No decorative text explaining the feature.

The bottom metadata should be derived from the pending item's actual category/subtype and candidate generated item code when available:

- Left side: subtype display label, uppercased, such as `PANTS`, `HOODIE`, or `SNEAKERS`.
- Right side: candidate generated item code, such as `PT-009` or `HD-001`.
- If the subtype is unknown, fall back to category, such as `BOTTOMS`.
- If the item code is not available yet, show a reserved pending label such as `PT-...` only if the prefix can be inferred. Otherwise omit the code.
- The candidate code should use the existing `ItemCodeGenerator` logic and the same existing-code set that save will use, so the animation label matches the final closet record whenever possible.

The status copy should be short and secondary. Preferred processing copy:

- `SAVING CLEAN ITEM`

Acceptable fallback copy:

- `PREPARING CUTOUT`
- `ISOLATING GARMENT`

## Interaction And States

### Processing

Show the Studio Snap motion. Disable save/rotate/improve controls, matching the current flow.

### Success

Transition from the motion state into the actual processed cutout preview with a quick opacity/scale settle. The final preview should feel like the garment has become the product-card image that will appear in the closet grid.

### Failure

If background removal fails, transition to the original image preview and show the existing failure state. The motion should not imply success if `cutoutPath` is unavailable.

### Reduced Motion

Respect `accessibilityReduceMotion`.

Reduced-motion behavior:

- Avoid the sweeping light animation.
- Show a static clean surface with the small settled shadow.
- Keep status text and subtype/code metadata visible.
- Avoid snap effects. Sparkle/finish marks should be omitted or rendered as a static, very low-contrast detail.

## Component Shape

Replace or refactor the current processing view into a focused component:

- `StudioCutoutProcessingView`

Inputs:

- `url: URL?`
- `isProcessing: Bool`
- `prefersReducedMotion: Bool`
- `subtypeLabel: String?`
- `candidateItemCode: String?`

The component should remain local to the Add Item UI unless reused later in item detail retry flows.

## Implementation Notes

SwiftUI can implement this without new dependencies:

- Layer `LocalImageView` or a neutral preview surface while the selected image is unavailable.
- Use translucent warm-white overlays for the clean surface.
- Use a rotated light band with `offset` or animating alignment.
- Use `scaleEffect`, `offset`, and `shadow` to create the garment lift and shadow snap.
- Use a small bottom metadata row with existing `PyxisTypography.code` or matching monospaced styling.
- Use the pending subtype and candidate generated item code from the add-item view model when possible.
- Ensure the save path reuses the displayed candidate code or regenerates only when the candidate has become unavailable.

The implementation should avoid layout shifts. The preview frame should keep the same fixed dimensions currently used by `ProcessingRevealImageView`.

## Acceptance Criteria

- Processing state uses the Studio Snap motion instead of the shutter animation.
- The motion remains visually contained inside the image preview.
- The animation feels premium and fashion/product-shot oriented.
- The final visual includes the small shadow snap/settle detail.
- The final visual includes a tiny restrained sparkle/finish mark.
- The final visual does not include a spotlight, circular glow, or stage-light halo behind the garment.
- Bottom metadata shows subtype plus candidate item code, such as `PANTS / PT-009`, when those values are available.
- Saved closet items use the same item code shown during processing unless a collision requires regeneration.
- The final preview transition does not jump or resize the layout.
- Failure still allows saving the original image as before.
- Reduced Motion users get a calmer non-sweeping version.
- Existing add-item tests continue to pass, except any pre-existing unrelated failures.

## Out Of Scope

- Changing the actual background-removal algorithm.
- Adding manual erase/cleanup tools.
- Adding cloud processing or AI APIs.
- Redesigning the whole add-item flow.
- Reworking metadata fields or closet selection.
- Changing the item-code generation format.
