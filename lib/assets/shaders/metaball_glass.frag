// -----------------------------------------------------------------------------
// Metaball Liquid Glass — merged multi-lens glass surface.
//
// This is a SEPARATE shader from the production liquid_glass.frag (which it
// never modifies). It reuses the SAME glass math by #including the shared
// helper libraries, so the merged blob refracts, rims and tints exactly like
// a real liquid-glass lens — the only difference is the silhouette:
//
//   * liquid_glass.frag  → one rounded-rect ShapeData.
//   * metaball_glass.frag → the smooth-union (polynomial smin) of up to six
//     rounded-rect ShapeData, so neighbouring lenses fuse with a liquid
//     bridge and the glass flows across the merged outline.
//
// Everything downstream of the silhouette — coverage AA, the distortion band,
// magnification, the refraction modes (shape / radial / optical) and the
// sweep border — is the production code, called through the same helpers.
//
// Copyright © 2025 Ahmed Gamil. Free to use in any project.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
// The merged metaball field's gradient comes from hardware derivatives (1 SDF
// tap) on Impeller, or an analytic propagation (the h-weighted blend of the
// per-lens gradients — no dFdx, no extra taps) on Skia. The backend is chosen
// OUTSIDE the shader (in Dart) by loading the matching entry, because dFdx
// cannot even COMPILE in SkSL — a runtime uniform can't help, the whole
// program must be free of it on Skia:
//
//   * metaball_glass.frag      (this file) → Impeller. dFdx is valid, so opt
//     into the derivative shapeFrom1Tap (1-tap) BEFORE the shared header.
//   * metaball_glass_skia.frag → Skia/web. It #includes THIS file with
//     METABALL_SKIA pre-defined, which leaves GLASS_USE_DERIVATIVE_GRAD undefined
//     (dFdx never compiled → loads on Skia) and selects the ANALYTIC gradient:
//     the smooth-union's gradient is the h-weighted blend of the per-lens
//     rounded-rect gradients (exact, single pass, no dFdx and no 5-tap).
#ifndef METABALL_SKIA
#define GLASS_USE_DERIVATIVE_GRAD
#define SHAPE_GRAD_1TAP 1
#else
#define SHAPE_GRAD_1TAP 0
#define METABALL_GRAD_ANALYTIC 1
#endif
// Default off (Impeller path uses the derivative 1-tap); the Skia entry above
// turns it on. When 1, the merged field carries its own analytic gradient.
#ifndef METABALL_GRAD_ANALYTIC
#define METABALL_GRAD_ANALYTIC 0
#endif
#include "liquid_glass_common.glsl"
// Opt the shared border into the half-Lambert rim wrap for the MERGED shape.
// Single-lens shaders don't define this, so their border compiles unchanged.
#define LIQUID_GLASS_RIM_WRAP
#include "liquid_glass_border.glsl"
#define PI 3.14159265

// mediump perf test: inherit the shared toggle from liquid_glass_common.glsl.
precision GLASS_FLOAT_PRECISION float;

// =====================================================
// Uniforms
//
// IMPORTANT: the float-uniform DECLARATION ORDER below is the exact order
// `packMetaballGlassUniforms` writes them with `setFloat(i++, …)`. Keep the
// two in lockstep. The sampler does not consume a float index (it is bound
// via `setImageSampler(0, …)`), so it can sit anywhere.
// =====================================================
uniform vec2 u_resolution;
uniform sampler2D u_texture_input;

// --- Packed uniforms (Metal [[buffer(N)]] limit fix) -----------------------
// iOS 26 Impeller binds each runtime-effect uniform to its own Metal buffer
// and caps at ~30; this shader had 52 declarations. The six per-lens vec4s in
// each group are collapsed into a vec4[6] ARRAY (one declaration / one binding
// instead of six), and the scalar block is merged into vec4s — exactly as in
// liquid_glass.frag. The #define block below restores every original name, and
// the float-offset order is IDENTICAL to the old per-uniform layout, so
// packMetaballGlassUniforms is unchanged.

// A/B TEST (array-revert): the per-lens groups are declared as SIX individual
// vec4 uniforms again (NOT vec4[6] arrays), to isolate whether Impeller's
// setFloat index mapping for uniform ARRAYS — the one construct the working
// single-lens shader never uses — is what desynced the Dart packer (read as a
// too-large u_smoothness → phantom centre blob + screen frost on blend). The
// scalar vec4 packs (u_warp/u_packA/B/C) are KEPT (proven good in liquid_glass.frag).
// u_lensN = (centerX, centerY, halfWidth, halfHeight) px.
uniform vec4 u_lens0;
uniform vec4 u_lens1;
uniform vec4 u_lens2;
uniform vec4 u_lens3;
uniform vec4 u_lens4;
uniform vec4 u_lens5;
// u_lensMetaN = (cornerRadius px, enabled[>0.5], cornerStyle, packedSides).
//   packedSides packs the four per-side blend activations (right,left,down,up;
//   each 0..1) at 5 bits each into one float — see unpackSides(). This folds the
//   old separate u_lensSidesN vec4 into the spare meta slot (was the debug-only
//   `blend`), saving one binding per lens. NOTE: requires highp (not fp16-safe).
uniform vec4 u_lensMeta0;
uniform vec4 u_lensMeta1;
uniform vec4 u_lensMeta2;
uniform vec4 u_lensMeta3;
uniform vec4 u_lensMeta4;
uniform vec4 u_lensMeta5;
// ── Shared glass block (same semantics as liquid_glass.frag) ──────────────
// All loose scalars are merged into vec4s to cut bindings; the #define block
// below restores their original names. The float-offset ORDER here is the exact
// order packMetaballGlassUniforms writes with setFloat(i++,…) — keep in lockstep.
// x=magnification  y=distortion  z=distortionThicknessPx  w=enableBackgroundTransparency
uniform vec4 u_warp;
// x=smoothness (the metaball "gooeyness", px)  y=diagonalFlip  z=borderWidth  w=borderSoftness
uniform vec4 u_warpB;
// x=borderAlpha  y=lightIntensity  z=lightDirection  w=honorBackdropAlpha
uniform vec4 u_warpC;
// x=blur (in-shader blur radius, fragment px)  y=shapeAaPx (edge-AA band)
// z=lightSpread (optical-rim angular spread)  w=unused
uniform vec4 u_warpD;

uniform vec4  u_borderColor;
uniform vec4  u_lightColor;
uniform vec4  u_shadowColor;
uniform vec4  u_lensColor;
// x=oneSideLightIntensity  y=chromaticAberration  z=saturation  w=lightMode
uniform vec4 u_packA;
// x=refractionMode  y=refractionType  z=refractionIndex  w=ambientIntensity
uniform vec4 u_packB;
// x=doubleSideLightIntensity  y=borderSaturation  z=borderSolidity  w=borderMode
uniform vec4 u_packC;

// Capture-region mapping (see liquid_glass.frag): xy=offset, zw=size. Full-frame
// capture = offset (0,0), size u_resolution. MUST be the last uniform — see
// packMetaballGlassUniforms.
uniform vec4 u_imageRegion;

// --- Restore original names ------------------------------------------------
// u_lensN / u_lensMetaN are real individual uniforms, so they need no aliases;
// only the scalar vec4 packs are aliased back to their original names below.
#define u_magnification                u_warp.x
#define u_distortion                   u_warp.y
#define u_distortionThicknessPx        u_warp.z
#define u_enableBackgroundTransparency u_warp.w
#define u_smoothness                   u_warpB.x
#define u_diagonalFlip                 u_warpB.y
#define u_borderWidth                  u_warpB.z
#define u_borderSoftness               u_warpB.w
#define u_borderAlpha                  u_warpC.x
#define u_lightIntensity               u_warpC.y
#define u_lightDirection               u_warpC.z
#define u_honorBackdropAlpha           u_warpC.w
#define u_blur                         u_warpD.x
#define u_shapeAaPx                    u_warpD.y
#define u_lightSpread                  u_warpD.z
#define u_imageOffset                  u_imageRegion.xy
#define u_imageSize                    u_imageRegion.zw
#define u_oneSideLightIntensity        u_packA.x
#define u_chromaticAberration          u_packA.y
#define u_saturation                   u_packA.z
#define u_lightMode                    u_packA.w
#define u_refractionMode               u_packB.x
#define u_refractionType               u_packB.y
#define u_refractionIndex              u_packB.z
#define u_ambientIntensity             u_packB.w
#define u_doubleSideLightIntensity     u_packC.x
#define u_borderSaturation             u_packC.y
#define u_borderSolidity               u_packC.z
#define u_borderMode                   u_packC.w

out vec4 frag_color;

#define REFRACTION_SHAPE    0
#define REFRACTION_RADIAL   1
#define REFRACTION_STANDARD 0
#define REFRACTION_OPTICAL  1

// Rim angular response for the MERGED shape. 0 = the production hard rim
// (front/back of the light axis, zero at 90°); 1 = half-Lambert wrap (0.5
// at 90°) so the concave neck — whose normals are perpendicular to the
// light — keeps a rim and the merged border stays connected. Tune 0..1.
#define METABALL_RIM_WRAP 1.0

// EXPERIMENT (lens-anywhere-v4): two approaches to the bad CONTINUOUS blend.
//
// METABALL_EIKONAL_CONTINUOUS: the continuous (capsule) shoulder is NOT a
// true distance field, so the smin — which places the bridge from the SDF
// VALUE, assuming it equals true distance — lands the bridge off the
// outline. Eikonal-renormalize the continuous value (f / |grad f|) before it
// enters the smin so the bridge tracks the real continuous corner. Squircle
// and circular lenses stay raw (already ~unit-gradient; squircle blends fine).
// Older approach (kept for comparison): eikonal-renormalize the continuous
// value before the smin. Fixes the bridge but the shoulder gradient spike
// paints a stray rim whisker, and gating it back to raw reintroduces the
// bridge warp at the transition — the two fight. Disabled.
#define METABALL_EIKONAL_CONTINUOUS 0

// Convert continuous → circular rounded rectangle at the blending corner.
// Disabled: keep the raw continuous corner through the blend.
#define METABALL_FLATTEN_CONTINUOUS_BLEND 0

// =====================================================
// Metaball field: smooth-union of the enabled lens SDFs
// =====================================================

// Unpack the four per-side blend activations from a single float (see
// u_lensMetaN.w). Each side (right, left, down, up) was quantised to 5 bits
// (0..31) and packed as r + l*32 + d*1024 + u*32768 on the Dart side; here we
// peel them back off and renormalise to 0..1. highp-only (the packed integer
// reaches ~2^20, which fp16 cannot represent exactly).
vec4 unpackSides(float p) {
    float u = floor(p / 32768.0); p -= u * 32768.0;
    float d = floor(p / 1024.0);  p -= d * 1024.0;
    float l = floor(p / 32.0);    p -= l * 32.0;
    float r = p;
    return vec4(r, l, d, u) / 31.0;   // (right, left, down, up)
}

// Polynomial smooth minimum — the metaball blend. As two SDFs come within ~k
// of each other their union grows a smooth bridge instead of a hard crease.
float smoothUnion(float a, float b, float k) {
    float kk = max(k, EPS);
    float h = clamp(0.5 + 0.5 * (b - a) / kk, 0.0, 1.0);
    return mix(b, a, h) - kk * h * (1.0 - h);
}

// One lens's signed distance.
//
// meta.z selects the corner SDF (0 = circular rounded rect, 1 = squircle,
// 2 = continuous), mirroring the single-lens shader's u_cornerStyle.
//
// CAVEAT: only the circular rounded-rect SDF is a TRUE distance field
// (|grad| ~ 1). The metaball smooth-union assumes that to grow a correct
// bridge — the squircle/continuous corner SDFs carry a non-unit-gradient
// "shoulder" near their corners, which warps the blend so the neck stops
// hugging the outline. The squircle branch below is intentionally exposed
// so the look can be evaluated on device; expect bridge distortion when
// two squircle lenses fuse near their corners.
float lensDistance(vec2 p, vec4 lens, vec4 meta) {
    vec2 halfSize  = max(lens.zw, vec2(EPS));
    float maxCorner = min(halfSize.x, halfSize.y);
    float r = min(meta.x, maxCorner);

    // Continuous (Apple capsule-style) corners. RAW here; the per-corner morph
    // lives in lensDistanceMorph (used by field only).
    if (meta.z > 1.5 && r > 0.5) {
        vec2 reach = continuousRoundedRectReach(r, halfSize);
        return continuousRoundedRectShape(p, lens.xy, halfSize, r, reach);
    }

    // Squircle (Ln-norm) corners — full, fixed smoothing (1.0), matching the
    // single-lens squircle branch in liquid_glass.frag.
    if (meta.z > 0.5 && meta.z < 1.5 && r > 0.5) {
        vec2 zn = squircleCornerParams(r, 1.0, maxCorner);
        return squircleShape(p, lens.xy, halfSize, zn.x, zn.y);
    }

    return roundedRectangleShape(p, lens.xy, halfSize, r);
}

// Analytic gradient DIRECTION (unit) of one lens, from rounded-rect geometry —
// the same construction as shapeFrom1TapAnalytic. Squircle/continuous reuse this
// rounded-rect direction (their SDF VALUE stays exact), matching the single-lens
// analytic path. Feeds the merged-field analytic gradient (no dFdx, Skia-safe).
vec2 lensGradDir(vec2 p, vec4 lens, vec4 meta) {
    vec2 halfSize = max(lens.zw, vec2(EPS));
    float r = min(meta.x, min(halfSize.x, halfSize.y));
    vec2 rel = p - lens.xy;
    vec2 sg  = sign(rel);
    vec2 q   = abs(rel) - halfSize + r;
    if (q.x > 0.0 && q.y > 0.0) return sg * normalize(max(q, vec2(EPS)));
    if (q.x > q.y) return vec2(sg.x, 0.0);
    return vec2(0.0, sg.y);
}

// Per-lens SDF with the PER-CORNER continuous→rounded-rect morph. `sides` =
// (right, left, down, up) activation from Dart. A corner rounds when either of
// the two sides it joins is active, so the WHOLE corner attached to a blending
// side flattens. Cheap: just a quadrant lookup, no neighbour search. Used for
// the silhouette (field) only — fieldHard/anchor keep the raw lensDistance.
float lensDistanceMorph(vec2 p, vec4 lens, vec4 meta, vec4 sides) {
    float base = lensDistance(p, lens, meta);
    if (meta.z < 1.5) return base;                       // only continuous morphs
    vec2 halfSize = max(lens.zw, vec2(EPS));
    float r = min(meta.x, min(halfSize.x, halfSize.y));
    vec2 rel = p - lens.xy;
    // Which corner is this fragment in → the two sides it joins.
    float xAct = (rel.x > 0.0) ? sides.x : sides.y;      // right : left
    float yAct = (rel.y > 0.0) ? sides.z : sides.w;      // down  : up
    float w = max(xAct, yAct);                           // either side rounds it
    if (w < 0.001) return base;
    float rrect = roundedRectangleShape(p, lens.xy, halfSize, r);
    return mix(base, rrect, w);
}

// The distance actually fed into the metaball smin. For CONTINUOUS lenses,
// renormalize the raw value to a first-order true distance (f / |grad f|) so
// the smin's bridge, which assumes value == distance, sits on the real
// outline. |grad f| is taken from hardware derivatives (the lens value across
// the 2x2 quad). Circular/squircle pass through unchanged. meta.z is uniform,
// so the dFdx/dFdy sit in uniform control flow.
float lensDistanceBlend(vec2 p, vec4 lens, vec4 meta) {
    float f = lensDistance(p, lens, meta);
#if METABALL_EIKONAL_CONTINUOUS
    if (meta.z > 1.5) {
        vec2 g = vec2(dFdx(f), dFdy(f));
        // Clamp the divisor. The shoulder makes |grad| SPIKE along a fixed
        // band; an unbounded f/|grad| collapses there and paints a stray rim
        // whisker flicking off the convex side (opposite the bridge). The
        // bridge correction only needs |grad| in a moderate range, so bound
        // it — gentle where it should be, no blow-up at the spike.
        f = f / clamp(length(g), 0.7, 1.4);
    }
#endif
    return f;
}

// Like lensDistance, but a CONTINUOUS lens (meta.z > 1.5) is replaced by the
// plain circular rounded-rect SDF — a true distance field that blends cleanly.
// Crossfading field() against this (by the bridge indicator) converts the
// continuous corner smoothly into a rounded rectangle exactly at the blending
// corner, and nowhere else. Squircle/circular lenses are unchanged.
float lensDistanceContFlat(vec2 p, vec4 lens, vec4 meta) {
    if (meta.z > 1.5) {
        vec2 halfSize = max(lens.zw, vec2(EPS));
        float r = min(meta.x, min(halfSize.x, halfSize.y));
        return roundedRectangleShape(p, lens.xy, halfSize, r);
    }
    return lensDistance(p, lens, meta);
}

float field(vec2 p) {
    float d = 1e9;
    if (u_lensMeta0.y > 0.5) d = smoothUnion(d, lensDistanceMorph(p, u_lens0, u_lensMeta0, unpackSides(u_lensMeta0.w)), u_smoothness);
    if (u_lensMeta1.y > 0.5) d = smoothUnion(d, lensDistanceMorph(p, u_lens1, u_lensMeta1, unpackSides(u_lensMeta1.w)), u_smoothness);
    if (u_lensMeta2.y > 0.5) d = smoothUnion(d, lensDistanceMorph(p, u_lens2, u_lensMeta2, unpackSides(u_lensMeta2.w)), u_smoothness);
    if (u_lensMeta3.y > 0.5) d = smoothUnion(d, lensDistanceMorph(p, u_lens3, u_lensMeta3, unpackSides(u_lensMeta3.w)), u_smoothness);
    if (u_lensMeta4.y > 0.5) d = smoothUnion(d, lensDistanceMorph(p, u_lens4, u_lensMeta4, unpackSides(u_lensMeta4.w)), u_smoothness);
    if (u_lensMeta5.y > 0.5) d = smoothUnion(d, lensDistanceMorph(p, u_lens5, u_lensMeta5, unpackSides(u_lensMeta5.w)), u_smoothness);
    return d;
}

// EIKONAL smooth union — continuous lenses renormalized (lensDistanceBlend).
// Used ONLY inside the neck via fieldShape, so its shoulder artifacts never
// reach the exposed convex corners. Identical to field() for squircle/circular.
float fieldEik(vec2 p) {
    float d = 1e9;
    if (u_lensMeta0.y > 0.5) d = smoothUnion(d, lensDistanceBlend(p, u_lens0, u_lensMeta0), u_smoothness);
    if (u_lensMeta1.y > 0.5) d = smoothUnion(d, lensDistanceBlend(p, u_lens1, u_lensMeta1), u_smoothness);
    if (u_lensMeta2.y > 0.5) d = smoothUnion(d, lensDistanceBlend(p, u_lens2, u_lensMeta2), u_smoothness);
    if (u_lensMeta3.y > 0.5) d = smoothUnion(d, lensDistanceBlend(p, u_lens3, u_lensMeta3), u_smoothness);
    if (u_lensMeta4.y > 0.5) d = smoothUnion(d, lensDistanceBlend(p, u_lens4, u_lensMeta4), u_smoothness);
    if (u_lensMeta5.y > 0.5) d = smoothUnion(d, lensDistanceBlend(p, u_lens5, u_lensMeta5), u_smoothness);
    return d;
}

// Same smooth union as field(), but continuous corners flattened to circular
// (see lensDistanceContFlat). Identical to field() for squircle/circular
// lenses — only the continuous ones differ.
float fieldContFlat(vec2 p) {
    float d = 1e9;
    if (u_lensMeta0.y > 0.5) d = smoothUnion(d, lensDistanceContFlat(p, u_lens0, u_lensMeta0), u_smoothness);
    if (u_lensMeta1.y > 0.5) d = smoothUnion(d, lensDistanceContFlat(p, u_lens1, u_lensMeta1), u_smoothness);
    if (u_lensMeta2.y > 0.5) d = smoothUnion(d, lensDistanceContFlat(p, u_lens2, u_lensMeta2), u_smoothness);
    if (u_lensMeta3.y > 0.5) d = smoothUnion(d, lensDistanceContFlat(p, u_lens3, u_lensMeta3), u_smoothness);
    if (u_lensMeta4.y > 0.5) d = smoothUnion(d, lensDistanceContFlat(p, u_lens4, u_lensMeta4), u_smoothness);
    if (u_lensMeta5.y > 0.5) d = smoothUnion(d, lensDistanceContFlat(p, u_lens5, u_lensMeta5), u_smoothness);
    return d;
}

// HARD union (plain min) of the enabled lenses — the silhouette WITHOUT the
// smooth bridge. The smooth union is always <= this, and the gap between them
// (`hard - smooth`) is exactly the bridge the smin grew: ~0 on an isolated
// lens, peaking at the neck. We use it to localize the rim `wrap` to the
// blend only, so separated lenses keep the original two-sided hard rim.
float fieldHard(vec2 p) {
    float d = 1e9;
    if (u_lensMeta0.y > 0.5) d = min(d, lensDistance(p, u_lens0, u_lensMeta0));
    if (u_lensMeta1.y > 0.5) d = min(d, lensDistance(p, u_lens1, u_lensMeta1));
    if (u_lensMeta2.y > 0.5) d = min(d, lensDistance(p, u_lens2, u_lensMeta2));
    if (u_lensMeta3.y > 0.5) d = min(d, lensDistance(p, u_lens3, u_lensMeta3));
    if (u_lensMeta4.y > 0.5) d = min(d, lensDistance(p, u_lens4, u_lensMeta4));
    if (u_lensMeta5.y > 0.5) d = min(d, lensDistance(p, u_lens5, u_lensMeta5));
    return d;
}

// Rim wrap localized to the blend: 0 where lenses are isolated (keep the
// production two-sided hard rim), ramping to METABALL_RIM_WRAP at the neck
// (half-Lambert so the concave bridge stays lit/connected). The bridge
// amount is `hard - smooth`, normalized by the smin's peak subtraction
// (~smoothness * 0.25).
float bridgeWrap(vec2 fragPx, float smoothSdf) {
    float bridge = fieldHard(fragPx) - smoothSdf;            // >= 0
    float t = clamp(bridge / max(u_smoothness * 0.25, EPS), 0.0, 1.0);
    return t * METABALL_RIM_WRAP;
}

// Shape SDF used for the silhouette/refraction. Continuous corners survive
// where the lens is isolated, and crossfade to the flattened (circular) blend
// inside the neck so the capsule shoulder can't warp the bridge. Squircle and
// circular lenses are unaffected (field == fieldContFlat for them). The blend
// amount reuses the bridge indicator (`fieldHard - field`, ~0 isolated, ~1 at
// the neck).
float fieldShape(vec2 p) {
#if METABALL_FLATTEN_CONTINUOUS_BLEND
    float styled = field(p);
    float bridge = fieldHard(p) - styled;                       // >= 0, peaks at neck
    // Smooth S-curve ramp (not a linear clamp) so the continuous corner
    // converts into the rounded rectangle GRADUALLY across the blending
    // corner — C1 at both ends, no visible kink where the morph starts/ends.
    // Saturates a touch before the deepest neck so the bridge itself is fully
    // rounded-rect.
    float t = smoothstep(0.0, u_smoothness * 0.05, bridge);
    return mix(styled, fieldContFlat(p), t);                    // blend corner -> rounded rect
#elif METABALL_EIKONAL_CONTINUOUS
    // Gate the eikonal to the concave NECK. Raw continuous everywhere (correct
    // capsule corner, no whisker), crossfading to the eikonal-corrected field
    // only where the smin actually bridges — so the shoulder artifact can't
    // reach the exposed convex corners. Bridge indicator = fieldHard - field.
    float raw    = field(p);
    float bridge = fieldHard(p) - raw;                          // >= 0
    float t = clamp(bridge / max(u_smoothness * 0.25, EPS), 0.0, 1.0);
    return mix(raw, fieldEik(p), t);                            // neck -> eikonal
#else
    return field(p);
#endif
}

// Merged ShapeData. The gradient method is fixed at COMPILE time by the entry
// file (SHAPE_GRAD_1TAP): Impeller → hardware-derivative 1-tap (dFdx, cheap);
// Skia → 5-tap central difference (no dFdx).
ShapeData evaluateField(vec2 fragPx) {
#if SHAPE_GRAD_1TAP
    return shapeFrom1Tap(fieldShape(fragPx));
#else
    float h = 1.0;
    float fC  = fieldShape(fragPx);
    float fXp = fieldShape(fragPx + vec2(h, 0.0));
    float fXm = fieldShape(fragPx - vec2(h, 0.0));
    float fYp = fieldShape(fragPx + vec2(0.0, h));
    float fYm = fieldShape(fragPx - vec2(0.0, h));

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm);
    float gL = max(length(grad), EPS);

    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;
    return d;
#endif
}

// Influence-weighted centroid: the magnification / radial-light anchor that
// flows with the merged shape instead of snapping between fixed centers.
void accumulateAnchor(vec4 lens, vec4 meta, vec2 p, inout vec2 acc, inout float wsum) {
    if (meta.y < 0.5) return;
    float w = exp(-max(lensDistance(p, lens, meta), 0.0) / max(u_smoothness, EPS));
    acc  += lens.xy * w;
    wsum += w;
}

vec2 anchorFor(vec2 p) {
    vec2 acc = vec2(0.0);
    float wsum = 0.0;
    accumulateAnchor(u_lens0, u_lensMeta0, p, acc, wsum);
    accumulateAnchor(u_lens1, u_lensMeta1, p, acc, wsum);
    accumulateAnchor(u_lens2, u_lensMeta2, p, acc, wsum);
    accumulateAnchor(u_lens3, u_lensMeta3, p, acc, wsum);
    accumulateAnchor(u_lens4, u_lensMeta4, p, acc, wsum);
    accumulateAnchor(u_lens5, u_lensMeta5, p, acc, wsum);
    return (wsum > EPS) ? acc / wsum : p;
}

// =====================================================
// FUSED single-pass evaluation (perf): compute the smooth union (field),
// the hard min (fieldHard) and the influence-weighted anchor (anchorFor) in
// ONE loop over the lenses, from a SINGLE raw lensDistance() per lens.
//
// The original main() evaluated each lens's SDF up to three times at the
// same fragment — once for field() (via lensDistanceMorph), once for
// fieldHard() and once for anchorFor(). lensDistance() is pure, so reusing
// its result here is bit-identical: smoothSdf == field(p), hardSdf ==
// fieldHard(p), anchor == anchorFor(p). No visual change; ~3x fewer SDFs.
//
// Used only on the DEFAULT path (1-tap gradient, no experiment macro). The
// 5-tap and EIKONAL/FLATTEN paths still go through the separate field*()
// functions above, which they need.
// =====================================================
struct MergedField {
    float smoothSdf;   // == field(p)
    float hardSdf;     // == fieldHard(p)
    vec2  anchor;      // == anchorFor(p)
    vec2  grad;        // analytic merged gradient (METABALL_GRAD_ANALYTIC only)
};

void accumulateMerged(vec2 p, vec4 lens, vec4 meta, vec4 sides,
                      inout float smoothSdf, inout float hardSdf,
                      inout vec2 anchorAcc, inout float anchorW,
                      inout vec2 gradAcc) {
    if (meta.y < 0.5) return;

    // The one raw SDF for this lens — shared by all three accumulators.
    float base = lensDistance(p, lens, meta);

    // Hard union (== fieldHard's min).
    hardSdf = min(hardSdf, base);

    // Anchor weight (== accumulateAnchor).
    float w = exp(-max(base, 0.0) / max(u_smoothness, EPS));
    anchorAcc += lens.xy * w;
    anchorW   += w;

    // Per-corner continuous→rounded-rect morph (== lensDistanceMorph),
    // reusing `base` instead of recomputing lensDistance().
    float dMorph = base;
    if (meta.z > 1.5) {                                  // only continuous morphs
        vec2 halfSize = max(lens.zw, vec2(EPS));
        float r = min(meta.x, min(halfSize.x, halfSize.y));
        vec2 rel = p - lens.xy;
        float xAct = (rel.x > 0.0) ? sides.x : sides.y;  // right : left
        float yAct = (rel.y > 0.0) ? sides.z : sides.w;  // down  : up
        float wMorph = max(xAct, yAct);                  // either side rounds it
        if (wMorph >= 0.001) {
            float rrect = roundedRectangleShape(p, lens.xy, halfSize, r);
            dMorph = mix(base, rrect, wMorph);
        }
    }

    // Smooth union, inlined so the blend weight h is shared with the gradient.
    // h and the value are bit-identical to smoothUnion(smoothSdf, dMorph, k).
    float kk = max(u_smoothness, EPS);
    float h  = clamp(0.5 + 0.5 * (dMorph - smoothSdf) / kk, 0.0, 1.0);
    smoothSdf = mix(dMorph, smoothSdf, h) - kk * h * (1.0 - h);

#if METABALL_GRAD_ANALYTIC
    // Analytic merged gradient: the polynomial smin's gradient is exactly the
    // h-weighted blend of the two input gradients (the -k·h·(1-h) correction
    // term's derivative cancels). gradAcc carries the running accumulator's
    // gradient; lensGradDir is this lens's. The first lens lands h≈0 → gradAcc
    // takes its direction outright.
    gradAcc = mix(lensGradDir(p, lens, meta), gradAcc, h);
#endif
}

MergedField evaluateMerged(vec2 p) {
    MergedField m;
    m.smoothSdf = 1e9;
    m.hardSdf   = 1e9;
    m.grad      = vec2(0.0);
    vec2 anchorAcc = vec2(0.0);
    float anchorW = 0.0;
    accumulateMerged(p, u_lens0, u_lensMeta0, unpackSides(u_lensMeta0.w), m.smoothSdf, m.hardSdf, anchorAcc, anchorW, m.grad);
    accumulateMerged(p, u_lens1, u_lensMeta1, unpackSides(u_lensMeta1.w), m.smoothSdf, m.hardSdf, anchorAcc, anchorW, m.grad);
    accumulateMerged(p, u_lens2, u_lensMeta2, unpackSides(u_lensMeta2.w), m.smoothSdf, m.hardSdf, anchorAcc, anchorW, m.grad);
    accumulateMerged(p, u_lens3, u_lensMeta3, unpackSides(u_lensMeta3.w), m.smoothSdf, m.hardSdf, anchorAcc, anchorW, m.grad);
    accumulateMerged(p, u_lens4, u_lensMeta4, unpackSides(u_lensMeta4.w), m.smoothSdf, m.hardSdf, anchorAcc, anchorW, m.grad);
    accumulateMerged(p, u_lens5, u_lensMeta5, unpackSides(u_lensMeta5.w), m.smoothSdf, m.hardSdf, anchorAcc, anchorW, m.grad);
    m.anchor = (anchorW > EPS) ? anchorAcc / anchorW : p;
    return m;
}

// The fused path is exact only when fieldShape == field (no experiment macro)
// AND the gradient comes from a SINGLE per-fragment pass: the 1-tap derivative
// (Impeller) or the analytic merged gradient (Skia). The 5-tap needs field
// sampled at 4 neighbours, which the fused single-point pass doesn't give.
#define METABALL_FUSED_PATH \
    ((SHAPE_GRAD_1TAP || METABALL_GRAD_ANALYTIC) && !METABALL_EIKONAL_CONTINUOUS && !METABALL_FLATTEN_CONTINUOUS_BLEND)

// =====================================================
// Background sampling (CA + optional in-shader blur), saturation, tint —
// mirrors liquid_glass.frag's finalSample.
// =====================================================
vec2 refractedToUv(vec2 refractedPx) {
    vec2 uv = clamp((refractedPx - u_imageOffset) / u_imageSize,
                    vec2(0.001), vec2(0.999));
    // GLES sampler Y-flip — only on engines BEFORE the OpenGLES coordinate
    // unification (post-3.44.0 sets IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED).
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    uv.y = 1.0 - uv.y;
    #endif
    #endif
    return uv;
}

vec3 sampleChroma(vec2 uv, float shift) {
    vec3 color = texture(u_texture_input, uv).rgb;
    if (shift < 0.001) return color;
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    vec2 offset = vec2(shift * luma);
    float r = texture(u_texture_input, uv + offset).r;
    float g = texture(u_texture_input, uv).g;
    float b = texture(u_texture_input, uv - offset).b;
    return vec3(r, g, b);
}

// Two-ring blur where EACH tap is a chroma-split sample, so CA happens BEFORE
// the blur — the colour fringe is diffused by the frost, not laid over it.
vec3 blurFieldChroma(vec2 uv, float shift) {
    vec2 pxToUv = 1.0 / max(u_imageSize, vec2(EPS));
    vec3 color = sampleChroma(uv, shift);
    float count = 1.0;
    for (int ring = 1; ring <= 2; ring++) {
        float radius = u_blur * float(ring) * 0.5;
        for (int tap = 0; tap < 6; tap++) {
            float angle = 6.2831853 * float(tap) / 6.0 + float(ring) * 0.5;
            vec2 duv = vec2(cos(angle), sin(angle)) * radius * pxToUv;
            color += sampleChroma(clamp(uv + duv, vec2(0.001), vec2(0.999)), shift);
            count += 1.0;
        }
    }
    return color / count;
}

vec3 sampleBackground(vec2 refractedPx, float caShift) {
    vec2 uv = refractedToUv(refractedPx);
    // No in-shader blur (e.g. Impeller engine-blur path): CA on the sample.
    if (u_blur < 0.5) return sampleChroma(uv, caShift);
    // Skia in-shader blur: CA FIRST (each tap is a chroma sample), then the
    // kernel averages — so the colour fringe is blurred along with the field.
    return blurFieldChroma(uv, caShift);
}

vec3 applySaturation(vec3 color, float saturation) {
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luminance), color, saturation);
}

vec4 finalSample(vec2 refractedPx, float shapeMask, float caShift, out vec3 preTintColor) {
    vec3 refrColor = sampleBackground(refractedPx, caShift);
    refrColor = applySaturation(refrColor, u_saturation);
    preTintColor = refrColor;

    vec2 uv = refractedToUv(refractedPx);
    float texA = (u_honorBackdropAlpha > 0.5) ? texture(u_texture_input, uv).a : 1.0;
    float coverage = shapeMask * texA;

    vec4 base = vec4(refrColor * shapeMask, coverage);
    base.rgb = applyLensTint(base.rgb, shapeMask, u_lensColor, u_borderAlpha);
    return base;
}

float computeShapeMask(float shapeDistPx) {
    float aa = max(u_shapeAaPx, 1.0);
    return 1.0 - smoothstep(-0.5 * aa, 0.5 * aa, shapeDistPx);
}

// =====================================================
// Main
// =====================================================
void main() {
    vec2 fragPx   = FlutterFragCoord().xy;
    float invResY = 1.0 / u_resolution.y;
    vec2 uvNorm   = fragPx * invResY;

    // Merged silhouette + flowing anchor.
#if METABALL_FUSED_PATH
    // Fast path: one per-lens pass yields the smooth union, the hard min and
    // the anchor together (see evaluateMerged). Bit-identical to the
    // separate-pass branch below for this config.
    MergedField mf      = evaluateMerged(fragPx);
#if METABALL_GRAD_ANALYTIC
    // Skia: build ShapeData from the merged ANALYTIC gradient (no dFdx). The
    // gradient is a blend of unit per-lens gradients, so |grad| <= 1 — dividing
    // by it inflates orthoDist at the neck exactly like a true distance field.
    ShapeData shapeData;
    shapeData.sdf       = mf.smoothSdf;
    shapeData.grad      = mf.grad;
    float gLen          = max(length(mf.grad), EPS);
    shapeData.normal    = mf.grad / gLen;
    shapeData.orthoDist = mf.smoothSdf / gLen;
#else
    ShapeData shapeData = shapeFrom1Tap(mf.smoothSdf);
#endif
    float shapeDistPx   = shapeData.orthoDist;
    float shapeMask     = computeShapeMask(shapeDistPx);

    // Rim wrap only at the blend neck; 0 on isolated lenses (== bridgeWrap,
    // reusing the hard min we already have).
    float bridge  = mf.hardSdf - mf.smoothSdf;                       // >= 0
    float rimWrap = clamp(bridge / max(u_smoothness * 0.25, EPS), 0.0, 1.0)
                    * METABALL_RIM_WRAP;

    vec2 anchorPx   = mf.anchor;
    vec2 anchorNorm = anchorPx * invResY;
#else
    ShapeData shapeData = evaluateField(fragPx);
    float shapeDistPx   = shapeData.orthoDist;
    float shapeMask     = computeShapeMask(shapeDistPx);

    // Rim wrap only at the blend neck; 0 on isolated lenses.
    float rimWrap = bridgeWrap(fragPx, shapeData.sdf);

    vec2 anchorPx   = anchorFor(fragPx);
    vec2 anchorNorm = anchorPx * invResY;
#endif

    float distAbsPx = abs(shapeDistPx);
    float zoneLimit = u_distortionThicknessPx;
    float zoneMask  = step(distAbsPx, zoneLimit);

    vec2 magPx = applyLensMagnification(fragPx, anchorPx, u_magnification);

    if (zoneMask < 0.5) {
        // Outside the distortion band — straight magnified sample + border.
        vec3 preTintCol = vec3(0.0);
        vec4 base = (u_enableBackgroundTransparency > 0.5)
            ? vec4(0.0)
            : finalSample(magPx, shapeMask, 0.0, preTintCol);

        vec4 borderPremul = getSweepBorder(
            uvNorm, anchorNorm, shapeData.orthoDist, shapeData.grad,
            u_borderWidth, u_borderSoftness, u_borderColor,
            u_lightColor, u_shadowColor,
            u_lightIntensity, u_borderAlpha, u_lightDirection,
            u_oneSideLightIntensity, u_lightMode,
            preTintCol, u_ambientIntensity,
            u_doubleSideLightIntensity,
            u_borderSaturation, u_borderSolidity, u_lightSpread, u_borderMode,
            rimWrap
        );

        frag_color = overlayPremul(base, borderPremul, u_borderMode);
        return;
    }

    float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);

    vec2 refrPx;
    if (u_refractionType == REFRACTION_OPTICAL) {
        vec2 opticalNormal = shapeData.normal;
        if (u_refractionMode == REFRACTION_RADIAL) {
            vec2 radial = magPx - anchorPx;
            float radialLength = length(radial);
            if (radialLength > EPS) opticalNormal = radial / radialLength;
        }
        refrPx = computeRefractedPosition(
            magPx, opticalNormal, shapeData.sdf,
            u_distortionThicknessPx, u_refractionIndex, u_distortion, zoneT
        );
    } else if (u_refractionMode == REFRACTION_SHAPE) {
        float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
        refrPx = computeShapeRefraction(
            magPx, shapeData.normal, shapeData.sdf,
            u_distortionThicknessPx, distortionFactor,
            u_magnification, u_diagonalFlip, zoneT
        );
    } else {
        float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
        refrPx = refractFromAnchorPx(
            magPx, anchorPx, distortionFactor,
            u_magnification, u_diagonalFlip, zoneT
        );
    }

    vec3 preTintCol2 = vec3(0.0);
    float caShift = u_chromaticAberration * zoneT;
    vec4 base = finalSample(refrPx, shapeMask, caShift, preTintCol2);

    vec4 borderPremul = getSweepBorder(
        uvNorm, anchorNorm, shapeData.orthoDist, shapeData.grad,
        u_borderWidth, u_borderSoftness, u_borderColor,
        u_lightColor, u_shadowColor,
        u_lightIntensity, u_borderAlpha, u_lightDirection,
        u_oneSideLightIntensity, u_lightMode,
        preTintCol2, u_ambientIntensity,
        u_doubleSideLightIntensity,
        u_borderSaturation, u_borderSolidity, u_lightSpread, u_borderMode,
        rimWrap
    );

    frag_color = overlayPremul(base, borderPremul, u_borderMode);
}
