# Batched glass under route transitions — work notes (2026-09-13)

Status of the "batched lens does not follow the page transition" bug: **fixed in
the working tree, uncommitted, device-verified once.** This note records what
the bug was, what changed, how it was checked, and what is still open.

---

## The bug

A `LiquidGlassLens` with blur, inside a scrollable list, on a
`LiquidGlassScaffold` with `batch: true`, did not move with its page during a
route push or pop. The glass was drawn to the left of its own box, up to the
pass padding (about 39 logical px with the default button style), converging as
the page settled. With the batch off the same lens followed the page exactly.
Lite glass and unblurred batched lenses were never affected.

It was **not** the transform. Both paths sample the same matrix at compositing
time, the slide is a pure translation so the affine-map uniforms stay identity,
and the transform-tracking probe layer is Skia-only. The defect was in how the
batched pass predicted its coordinate frame.

## Root cause

A batched, blurred lens uses one composed backdrop pass (`shader ∘ blur`).
Composing bounds the shader's input to the pass's clip, so `FlutterFragCoord()`
counts from that rect's top-left rather than the window's, and the lens must
predict where the engine puts that origin. The engine puts it at the top-left of
the pass rect intersected with every clip already on its stack.

The prediction (`liquidGlassAncestorPaintClip`) asked each render ancestor for
`describeApproximatePaintClip`. That is a semantics estimate. A viewport reports
its bounds unconditionally, but pushes the clip only while its content overflows
(`RenderViewport.paint`). A short list mid-slide therefore "clipped" at the
page's moving edge for the lens and at nothing for the engine, and the origin
prediction was off by the page's translation, capped at the pass padding. The
previous attempt to explain this through the route's opacity subpass was wrong:
Impeller rounds a save layer within 30 % of its limit up to the full window, and
a fade-forwards slide is only 25 % of the width, so that subpass never re-based
the frame.

## What changed

- `lib/src/widgets/lens/liquid_glass_transform_tracking.dart` — the render walk
  is replaced by `liquidGlassAncestorLayerClip(Layer from, {Layer? until})` plus
  `liquidGlassLayerClipBounds(Layer)`. It walks `Layer.parent` from the lens's
  own shader-clip layer, takes only `ClipRectLayer` / `ClipRRectLayer` /
  `ClipPathLayer` bounds (the only layers that reach the engine as clips),
  composes the ancestors' `applyTransform` root-down, and returns the
  intersection together with the map into that space. The root layer's
  physical-pixel scale is left out, so the space is the window in logical px.
- `lib/src/widgets/lens/render_liquid_glass_lens.dart` — `_composedPassRect`
  takes the lens→surface transform and calls `_ancestorClipInSurface`, which
  lines the layer frame up with the render frame by translation through the
  lens's own clip (the one rect known in both). `_pushedShaderClip` records the
  lens-local rect the pass was pushed inside.
- `test/ancestor_paint_clip_test.dart` — rewritten: layer-tree unit tests, and
  framework tests proving a short list contributes no clip while an overflowing
  one contributes the window rect.
- `CHANGELOG.md` — Unreleased entry.

Cost: one layer walk per Impeller lens per frame, on the UI thread, in place of
a render walk plus one `getTransformTo` per clipping ancestor. Nothing changes
on the GPU. Not profiled.

## Verification

- `flutter test`: 33 / 33. `flutter analyze`: nothing above the pre-existing
  infos.
- Device (OnePlus IN2017, Impeller/Vulkan): the lab page
  `../lab/lib/route_transition_batch/route_transition_page.dart` (first entry
  in the lab launcher) pushes a page of three blurred `LiquidGlassButton`s in a
  short list at 16× time dilation. A screenshot burst across the push shows the
  entering pills with rounded left ends in every frame and a measured width of
  960 px (the full 320 lp box) while the page is still 17 lp from rest. The old
  code would have cut the left end flat and left a bare strip on the right.
- Only the "after" state was captured. The "before" figure (≈19 px ahead at
  8× dilation) is from the earlier session's measurement.

## Remaining issues

1. **Equal-filter collapse (separate bug, still live).** Batched, blurred
   lenses of identical style and size pack identical uniform bytes because the
   composed path packs clip-local. Impeller then renders byte-equal shared-key
   filters once and lets each member copy its slice, which reads as one
   oversized lens or missing pills. The per-lens nonce fix (folded into the
   resolution uniform) was verified and then reverted on request; it is not in
   the tree. The repro page avoids it by giving the buttons different heights.
2. **Opacity subpasses smaller than the window.** An animated opacity around a
   single card puts its content in a save layer whose origin is the card's, and
   both batched and unbatched shader passes still measure from the window.
   Pre-existing, unrelated to this fix.
3. **Image-filter subpass origin is assumed, not read.** Inside an
   `ImageFiltered` ancestor (Android stretch overscroll) the frame is taken to
   start at that render object's box. Clips above the subpass are ignored on
   purpose (they are baked into the subpass coverage), but the coverage itself
   is not modelled. Pre-existing.
4. **No profiling, no "before" capture** for this fix. Both are quick to add:
   UI-thread frame time on the batch example page, and one release build of the
   lab against the previous lens code.
5. **Uncommitted.** The working tree also carries unrelated one-line edits in
   several component files and the example app that predate this work; sort
   them out before committing so the fix lands on its own.
6. **Device storage.** The phone has ≈630 MB free, under the low-storage install
   threshold for a debug APK; the lab was verified from a 45 MB release build.
   Hot reload therefore was not available for this check.

## Reproducing

1. Lab app → "Route transition batch" → "Push route 1" (or any deeper push).
2. Watch the entering page's pills against their labels during the slide. A
   displaced glass shows as a flat-cut left end and a bare strip at the right
   end of each box.
3. Tap the middle button to toggle the batch off and compare. Odd-depth pages
   sit their list lower so the entering and exiting glass never overlap.
