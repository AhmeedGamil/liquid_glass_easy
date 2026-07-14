## 3.3.0
- **New — `OpticalBorder.lightSpread`:** controls how far the optical rim's directional highlight wraps around the perimeter, independent of the always-on ambient ring. `0.0` = tight, concentrated glint hugging the light axis, `0.5` = default (identical to the previous fixed falloff, so existing code renders unchanged), `1.0` = highlight wraps almost all the way around. Below `0.5` the angular window of each light lobe narrows — the bright core itself tightens, not just the dim tail. Applies to `LiquidGlassLens`, the border-only painter, and the `LiquidGlassBlender` metaball rim.

## 3.2.2
- **Fix — vertically mirrored refraction on OpenGL ES (emulators):** Flutter's OpenGLES coordinate-system unification (engine after 3.44.0) removed the framebuffer Y-flip, which turned the shaders' manual sampler/derivative Y-flips into a *double* flip — a symmetrical Y-axis refraction artifact visible on Android emulators that fall back to OpenGL ES (real Vulkan/Metal devices were never affected). All four `IMPELLER_TARGET_OPENGLES` flips are now guarded by `#ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED`, so they apply only on older engines and are skipped once the engine sets the macro. Skia/web and Vulkan/Metal are unchanged.

## 3.2.1
- **Fix — bottom nav bar tab selection on web:** clicking a tab on web could select the wrong tab (the neighbour), walk toward the target one click at a time, or not change selection at all — most noticeable with a trackpad. A quick click was being routed through the hold-to-drag path and committing to the glide's lagging position instead of the cell that was pressed. A click now commits to the pressed tab. The tap-and-hold drag gesture is unchanged.

## 3.2.0
- **Per-backend single-lens shaders:** the shape-gradient method now differs by engine. Impeller keeps the hardware-derivative (`dFdx`) gradient, while Skia/web loads a separate `liquid_glass_skia.frag` / `liquid_glass_border_skia.frag` that selects an **analytic gradient** instead — `dFdx` is invalid SkSL, so the previous shared program was only correct on Impeller. Programs are cached **per backend** and resolved automatically; the frosted fallback now also covers the brief async load when a lens mounts on a backend that wasn't preloaded.
- **`LiquidGlassShaders` API (backward-compatible):** `ensureLoaded`, `isLoaded`/`isLoadedFor`, `createMainShader`, and `createBorderShader` now accept an optional `impeller` flag, defaulting to the engine's native backend (`ui.ImageFilter.isShaderFilterSupported`). Existing no-argument calls keep working.
- **Metaball blend on Skia — quality + blur:** the merged smooth-union field now propagates an **analytic gradient** (the h-weighted blend of the per-lens gradients) on Skia instead of the heavier 5-tap, and **in-shader blur is re-enabled** on the Skia blend path. Chromatic aberration is applied per blur tap, so CA lands **before** the blur (matching Impeller's order).
- **Blender Impeller perf — tight engine-blur clip:** on the Impeller engine-blur path the costly backdrop + blur pass is now clipped to the **tight glass region** (the blob union plus rim/blur/refraction/bridge margin) instead of the whole surface. The shader is packed in that clip-local frame — lens centres, resolution, and the sampling window all share one coordinate space — so the blob stays locked to the lenses while the expensive pass only covers the glass.
- **New — `LiquidGlassBlender.debugClipBounds`** (off by default): draws a magenta outline around the backdrop clip region on both backends, to verify the costly pass hugs the merged glass. Diagnostic only — it costs a stroked draw every frame; keep it `false` in production.
- **Example:** added a liquid-glass showcase/menu page and an image-backed lens demo to the gallery.

## 3.1.0
- **New — `LiquidGlassBlender`:** blend two to six `LiquidGlassLens` descendants into one liquid surface. Neighbouring lenses fuse with a smooth metaball bridge as they meet and pull apart as they separate, while each member keeps its own corner style. Place it inside a `LiquidGlassView` and it works on **both backends** — Impeller samples the live backdrop, Skia refracts the captured background.
- **Metaball gradient split:** the merged-field normal uses the hardware-derivative 1-tap on Impeller and a 5-tap central difference on Skia (whose SkSL has no `dFdx`), selected per backend so the blend loads and renders on both.
- **Single-lens shaders** now use the exact 5-tap gradient for every corner style.
- Chromatic aberration on the Skia blend path is now applied **after** the blur (matching Impeller's order); in-shader blur is disabled on the Skia blend path for now.
- **Note:** the blend is **not optimized for Skia yet** — it works on the Skia capture path but can be heavy there; best performance is on Impeller for now.

## 3.0.0
- **New — lens anywhere:** `LiquidGlassLens` is a layout-driven lens you can drop anywhere in the widget tree (no position/size params; size comes from layout). It **supports both Impeller and Skia automatically**, resolving the best render path for the running engine: on Impeller it refracts the **live backdrop** with no `LiquidGlassView` and no background widget at all; on Skia it refracts an ancestor `LiquidGlassView`'s captured background, and gracefully degrades to a frosted look when neither is available.
- **New:** `LiquidGlassStyle` — one shared descriptor (**shape + appearance + refraction**) for every glass surface (lens, components, nav pill), with `copyWith(...)` and `merge(...)`.
- **New — jelly motion:** the `LiquidGlassSlider`, `LiquidGlassToggle`, and `LiquidGlassBottomNavBar` now share an iOS-style jelly spring — squash/stretch with a direction-memory spring and momentum-sided squash. The slider/toggle thumb stretches toward its travel and snaps back, and the nav bar's selection pill springs between items. Exposed standalone as the reusable `LiquidGlassJelly` widget.
- **New components:** `LiquidGlassSlider`, `LiquidGlassToggle`, `LiquidGlassAppBar`, `LiquidGlassScaffold` (owns the glass pipeline), `LiquidGlassDraggable`, and `LiquidGlassJelly` join the existing `LiquidGlassButton`, `LiquidGlassBottomNavBar`, and `LiquidGlassTabBar`.
- **Migration:** the old position-driven lens API (`LiquidGlass`) is superseded by `LiquidGlassLens` and the drop-in components; write new code against `LiquidGlassLens`.
- **Breaking:** removed the `LiquidGlassSearchBar` component.
- **Breaking:** `LiquidGlassAppIcon` and `LiquidGlassDock` are no longer part of the public API (kept internally for maintenance).
- Rewrote the README around the lens-anywhere API and consolidated the example into a single `main.dart` gallery whose home menu opens each demo as its own route.
- **New shape:** `LiquidGlassShape.continuousRoundedRectangle(...)` — an **Apple capsule-style** continuous rounded rectangle, now the **default** shape; it collapses to a clean capsule at full corner radius.
- **Breaking:** removed `SuperellipseShape`; its L^n squircle now lives on `LiquidGlassShape.squircle(...)` (same iOS-style continuous-curvature look) and ships with **its own exact, shader-matched `ClipPath` clipper** (via `clipQuality: LiquidGlassClipQuality.exact`). The old superellipse had no exact Flutter clip path, which forced a rectangle clip and capped its blur; the squircle's dedicated clipper now matches the SDF the shader draws and blurs correctly at any sigma.
- Shapes are now selected via the `LiquidGlassShape.roundedRectangle(...)` / `.squircle(...)` / `.continuousRoundedRectangle(...)` convenience constructors (a single `cornerStyle` vocabulary) instead of separate `RoundedRectangleShape` / `SuperellipseShape` classes.
- Simplified the shaders: removed the superellipse SDF branch and the `u_shapeType` uniform, so every lens now uses the analytic rounded-rect path.
- Added `LiquidGlassView.regionCapture` (off by default): per-lens region capture on the Skia sync path — each capture grabs only every lens's own rect (+ margin) instead of the whole background. A performance win when lenses cover a small part of a large background; no effect on Impeller.

## 2.0.1
- Fixed lens position being clamped to the parent bounds even when `outOfBoundaries: true`. A lens moved past the parent's edge (in any direction) now keeps its true position instead of being pinned, so spacing between lenses stays correct.

## 2.0.0
- Added **optical border mode** (`OpticalBorder`) — Apple-style, SDF-based rim lighting with background-tinted highlights, dual-sided specular reflections, and a lens height profile — alongside the existing `ClassicBorder`.
- Added new ready-made components: `LiquidGlassButton`, `LiquidGlassSearchBar`, `LiquidGlassAppIcon`, `LiquidGlassDock`, `LiquidGlassTabBar`, and `LiquidGlassBottomNavBar`.
- Improved rendering stability on release/profile builds with Impeller.
- Fixed lens and border content rendering upside down on Impeller's OpenGL ES backend (older Android devices) by inverting the texture sample Y-axis under `IMPELLER_TARGET_OPENGLES`.
- **Breaking:** `oneSideLightIntensity` and `doubleSideLightIntensity` moved from the shape to `ClassicBorder`. Pass them via `borderType: ClassicBorder(...)` instead of directly on the shape.

## 1.1.1
- Formatted the dart files and changed the size of the thumbnail of screenshot.

## 1.1.0
- Added new refraction modes: **shape refraction** and **radial refraction**.
- Added new light modes: **edge** and **radial**.
- Added **chromatic aberration** support.
- Added **one side light intensity** support.
- Added **saturation** control.
- Updated magnification behavior to apply to the entire lens area rather than only the distortion region.
- Improved and optimized shader code.
- Removed `highDistortionOnCurves`; the same effect can now be achieved by increasing `distortion` and setting `distortionWidth` to half of the smallest lens dimension.

## 1.0.0
**Initial Stable Release – Liquid Glass Easy**

- First official release of the **`liquid_glass_easy`** Flutter package.
- Provides real-time **liquid glass lens effects** with smooth distortion, magnification, and refraction.
- Built with **shader-based rendering** for high performance and flexibility.
- Includes `LiquidGlassView` and `LiquidGlass` widgets for quick and easy integration into any UI.
- Example app included to demonstrate usage, configuration, and visual styles.
- Ready for production and pub.dev distribution.

