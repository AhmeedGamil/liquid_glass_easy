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
// SKIA_GRAPHICS_BACKEND (impellerc's SkSL-target define): take the analytic
// branch so this entry compiles as valid SkSL on `flutter build web` (3.44+).
#if !defined(METABALL_SKIA) && !defined(SKIA_GRAPHICS_BACKEND)
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
// and caps at ~30, so what is scarce here is DECLARATIONS, not floats.
//
// The per-lens data therefore rides in mat4s: one holds TWO members, as four
// vec4 columns — (lens, meta, lens, meta). Eight members cost four
// declarations where twelve vec4s used to carry six.
//
// mat4 and nothing else. Every matrix column aligns to 16 bytes, so a mat3
// occupies twelve floats to hold nine and a mat2 eight to hold four — and the
// backends need not agree about it. A mat4 is sixteen floats packed or
// padded, which is the only layout `setFloat` can address the same way
// everywhere. Same reason there is not a single vec3 in this file.
//
// Arrays (vec4[6]) were tried and reverted: Impeller's setFloat index mapping
// for uniform ARRAYS is what desynced the Dart packer (read as a too-large
// u_smoothness -> phantom centre blob + screen frost). A matrix is a
// different construct, addressed column-major as sixteen consecutive floats.
//
// Column layout of each u_lensPairN:
//   [0] lens A = (centerX, centerY, halfWidth, halfHeight) px
//   [1] meta A = (cornerRadius px, packedScale, cornerStyle, spare)
//   [2] lens B, [3] meta B — the same, for the odd member of the pair.
//
//   packedScale is that lens's flex (deformed/rest) as two 11-bit values
//   — see unpackScale; 0 means undeformed. It took over the old `enabled`
//   slot: an absent lens is packed all-zero, so the lens column's .z
//   (half-width) already IS the enabled bit and every guard reads that.
//   The meta's fourth slot is unused. It carried per-side blend activations
//   back when a continuous corner had to be flattened to blend cleanly.
uniform mat4 u_lensPair0;
uniform mat4 u_lensPair1;
uniform mat4 u_lensPair2;
uniform mat4 u_lensPair3;

// The original per-lens names, restored so the body below reads unchanged.
#define u_lens0     u_lensPair0[0]
#define u_lensMeta0 u_lensPair0[1]
#define u_lens1     u_lensPair0[2]
#define u_lensMeta1 u_lensPair0[3]
#define u_lens2     u_lensPair1[0]
#define u_lensMeta2 u_lensPair1[1]
#define u_lens3     u_lensPair1[2]
#define u_lensMeta3 u_lensPair1[3]
#define u_lens4     u_lensPair2[0]
#define u_lensMeta4 u_lensPair2[1]
#define u_lens5     u_lensPair2[2]
#define u_lensMeta5 u_lensPair2[3]
#define u_lens6     u_lensPair3[0]
#define u_lensMeta6 u_lensPair3[1]
#define u_lens7     u_lensPair3[2]
#define u_lensMeta7 u_lensPair3[3]

// Per-member TINT — one straight-alpha RGBA column each, four members per
// mat4. Two declarations for all eight, which is why this could be added
// without going back over the Metal binding cap.
//
// Every member always carries a colour: its own when it has an adaptive
// verdict, the group's otherwise. So the shader has one rule instead of two,
// and a group where nobody adapts blends eight identical colours back into
// exactly the group colour.
uniform mat4 u_lensTintA;
uniform mat4 u_lensTintB;

#define u_lensTint0 u_lensTintA[0]
#define u_lensTint1 u_lensTintA[1]
#define u_lensTint2 u_lensTintA[2]
#define u_lensTint3 u_lensTintA[3]
#define u_lensTint4 u_lensTintB[0]
#define u_lensTint5 u_lensTintB[1]
#define u_lensTint6 u_lensTintB[2]
#define u_lensTint7 u_lensTintB[3]

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
// z=lightSpread (optical-rim angular spread)  w=mergeEnabled (0 = hard union)
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
// 0 = the metaball is OFF: members are unioned hard, nearest wins outright,
// and none of the smin / influence-weight machinery runs. See nearestMember.
#define u_mergeEnabled                 u_warpD.w
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
// CAVEAT: the SQUIRCLE SDF is not a true distance field (|grad| ~ 1), which
// the smooth-union assumes when it places a bridge — expect distortion when
// two squircle lenses fuse near their corners. Circular and continuous are
// both distances (the continuous corner divides by its own gradient), so
// they bridge correctly.
// Per-lens flex scale (deformed / rest), unpacked from meta.y.
// Two 11-bit values, radix 2048, over 0.5..2.0.
// 0 is the UNDEFORMED sentinel so a lens without flex is bit-identical
// to the pre-flex output rather than landing on 0.99988.
vec2 unpackScale(float p) {
    if (p <= 0.0) return vec2(1.0);
    float y = floor(p / 2048.0);
    float x = p - y * 2048.0;
    return (vec2(x, y) - 1.0) / 2046.0 * 1.5 + 0.5;
}

// The lens's REST half-size and this fragment in the lens's REST space.
// Evaluating there and letting the scale map the result back stretches the
// whole outline, so a squeezed circle is an ellipse and not a stadium —
// exactly what liquid_glass.frag does with u_shapeScale.
void lensRestSpace(vec2 p, vec4 lens, vec2 s, out vec2 halfSize, out vec2 pRest) {
    halfSize = max(lens.zw / s, vec2(EPS));
    pRest    = lens.xy + (p - lens.xy) / s;
}

// Rest-space distance back to screen px, so every member reaches smoothUnion
// in the SAME metric. Without this, u_smoothness means a different bridge
// width per member and the merged value stops being a distance.
// Direction from the centre stands in for the surface normal: exact when the
// scale is isotropic, and sub-pixel off near a corner diagonal.
float lensToScreen(float dRest, vec2 p, vec4 lens, vec2 s) {
    // Undeformed: return the distance untouched. Falling through would
    // multiply by length(normalize(rel)) — 1.0 only to within a rounding
    // error, so a lens with no flex would stop being bit-identical to
    // the pre-flex output for the sake of no effect at all.
    if (s.x == 1.0 && s.y == 1.0) return dRest;
    vec2 rel = p - lens.xy;
    float L = length(rel);
    if (L < EPS) return dRest * min(s.x, s.y);
    return dRest * length((rel / L) * s);
}

float lensDistance(vec2 p, vec4 lens, vec4 meta) {
    vec2 s = unpackScale(meta.y);
    vec2 halfSize, pRest;
    lensRestSpace(p, lens, s, halfSize, pRest);
    float maxCorner = min(halfSize.x, halfSize.y);
    float r = min(meta.x, maxCorner);

    float d;
    // Continuous (capsule-style) corners.
    if (meta.z > 1.5 && r > 0.5) {
        vec2 reach = continuousRoundedRectReach(r, halfSize);
        d = continuousRoundedRectShape(pRest, lens.xy, halfSize, r, reach);
    }
    // Squircle (Ln-norm) corners — full, fixed smoothing (1.0), matching the
    // single-lens squircle branch in liquid_glass.frag.
    else if (meta.z > 0.5 && meta.z < 1.5 && r > 0.5) {
        vec2 zn = squircleCornerParams(r, 1.0, maxCorner);
        d = squircleShape(pRest, lens.xy, halfSize, zn.x, zn.y);
    }
    else {
        d = roundedRectangleShape(pRest, lens.xy, halfSize, r);
    }
    return lensToScreen(d, p, lens, s);
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
        vec2 s = unpackScale(meta.y);
        vec2 halfSize, pRest;
        lensRestSpace(p, lens, s, halfSize, pRest);
        float r = min(meta.x, min(halfSize.x, halfSize.y));
        return lensToScreen(
            roundedRectangleShape(pRest, lens.xy, halfSize, r), p, lens, s);
    }
    return lensDistance(p, lens, meta);
}

float field(vec2 p) {
    float d = 1e9;
    if (u_lens0.z > 0.0) d = smoothUnion(d, lensDistance(p, u_lens0, u_lensMeta0), u_smoothness);
    if (u_lens1.z > 0.0) d = smoothUnion(d, lensDistance(p, u_lens1, u_lensMeta1), u_smoothness);
    if (u_lens2.z > 0.0) d = smoothUnion(d, lensDistance(p, u_lens2, u_lensMeta2), u_smoothness);
    if (u_lens3.z > 0.0) d = smoothUnion(d, lensDistance(p, u_lens3, u_lensMeta3), u_smoothness);
    if (u_lens4.z > 0.0) d = smoothUnion(d, lensDistance(p, u_lens4, u_lensMeta4), u_smoothness);
    if (u_lens5.z > 0.0) d = smoothUnion(d, lensDistance(p, u_lens5, u_lensMeta5), u_smoothness);
    if (u_lens6.z > 0.0) d = smoothUnion(d, lensDistance(p, u_lens6, u_lensMeta6), u_smoothness);
    if (u_lens7.z > 0.0) d = smoothUnion(d, lensDistance(p, u_lens7, u_lensMeta7), u_smoothness);
    return d;
}

// EIKONAL smooth union — continuous lenses renormalized (lensDistanceBlend).
// Used ONLY inside the neck via fieldShape, so its shoulder artifacts never
// reach the exposed convex corners. Identical to field() for squircle/circular.
float fieldEik(vec2 p) {
    float d = 1e9;
    if (u_lens0.z > 0.0) d = smoothUnion(d, lensDistanceBlend(p, u_lens0, u_lensMeta0), u_smoothness);
    if (u_lens1.z > 0.0) d = smoothUnion(d, lensDistanceBlend(p, u_lens1, u_lensMeta1), u_smoothness);
    if (u_lens2.z > 0.0) d = smoothUnion(d, lensDistanceBlend(p, u_lens2, u_lensMeta2), u_smoothness);
    if (u_lens3.z > 0.0) d = smoothUnion(d, lensDistanceBlend(p, u_lens3, u_lensMeta3), u_smoothness);
    if (u_lens4.z > 0.0) d = smoothUnion(d, lensDistanceBlend(p, u_lens4, u_lensMeta4), u_smoothness);
    if (u_lens5.z > 0.0) d = smoothUnion(d, lensDistanceBlend(p, u_lens5, u_lensMeta5), u_smoothness);
    if (u_lens6.z > 0.0) d = smoothUnion(d, lensDistanceBlend(p, u_lens6, u_lensMeta6), u_smoothness);
    if (u_lens7.z > 0.0) d = smoothUnion(d, lensDistanceBlend(p, u_lens7, u_lensMeta7), u_smoothness);
    return d;
}

// Same smooth union as field(), but continuous corners flattened to circular
// (see lensDistanceContFlat). Identical to field() for squircle/circular
// lenses — only the continuous ones differ.
float fieldContFlat(vec2 p) {
    float d = 1e9;
    if (u_lens0.z > 0.0) d = smoothUnion(d, lensDistanceContFlat(p, u_lens0, u_lensMeta0), u_smoothness);
    if (u_lens1.z > 0.0) d = smoothUnion(d, lensDistanceContFlat(p, u_lens1, u_lensMeta1), u_smoothness);
    if (u_lens2.z > 0.0) d = smoothUnion(d, lensDistanceContFlat(p, u_lens2, u_lensMeta2), u_smoothness);
    if (u_lens3.z > 0.0) d = smoothUnion(d, lensDistanceContFlat(p, u_lens3, u_lensMeta3), u_smoothness);
    if (u_lens4.z > 0.0) d = smoothUnion(d, lensDistanceContFlat(p, u_lens4, u_lensMeta4), u_smoothness);
    if (u_lens5.z > 0.0) d = smoothUnion(d, lensDistanceContFlat(p, u_lens5, u_lensMeta5), u_smoothness);
    if (u_lens6.z > 0.0) d = smoothUnion(d, lensDistanceContFlat(p, u_lens6, u_lensMeta6), u_smoothness);
    if (u_lens7.z > 0.0) d = smoothUnion(d, lensDistanceContFlat(p, u_lens7, u_lensMeta7), u_smoothness);
    return d;
}

// HARD union (plain min) of the enabled lenses — the silhouette WITHOUT the
// smooth bridge. The smooth union is always <= this, and the gap between them
// (`hard - smooth`) is exactly the bridge the smin grew: ~0 on an isolated
// lens, peaking at the neck. We use it to localize the rim `wrap` to the
// blend only, so separated lenses keep the original two-sided hard rim.
float fieldHard(vec2 p) {
    float d = 1e9;
    if (u_lens0.z > 0.0) d = min(d, lensDistance(p, u_lens0, u_lensMeta0));
    if (u_lens1.z > 0.0) d = min(d, lensDistance(p, u_lens1, u_lensMeta1));
    if (u_lens2.z > 0.0) d = min(d, lensDistance(p, u_lens2, u_lensMeta2));
    if (u_lens3.z > 0.0) d = min(d, lensDistance(p, u_lens3, u_lensMeta3));
    if (u_lens4.z > 0.0) d = min(d, lensDistance(p, u_lens4, u_lensMeta4));
    if (u_lens5.z > 0.0) d = min(d, lensDistance(p, u_lens5, u_lensMeta5));
    if (u_lens6.z > 0.0) d = min(d, lensDistance(p, u_lens6, u_lensMeta6));
    if (u_lens7.z > 0.0) d = min(d, lensDistance(p, u_lens7, u_lensMeta7));
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
    // Metaball off: the silhouette IS the hard union, so none of the bridge
    // machinery below runs. bridgeWrap follows for free — with smooth == hard
    // its indicator is 0, which is exactly "no neck".
    if (u_mergeEnabled < 0.5) return fieldHard(p);
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
// The influence weight `w` is the same quantity the anchor is built from, so
// the tint rides along on it for free: no second SDF, no second falloff to
// tune. A member owns its own interior (its w is 1 where its SDF is <= 0) and
// hands over across the bridge at exactly the rate u_smoothness set for the
// geometry — so the colour seam sits where the shape seam already is.
void accumulateAnchor(vec4 lens, vec4 meta, vec4 tint, vec2 p,
                      inout vec2 acc, inout float wsum, inout vec4 tintAcc) {
    if (lens.z <= 0.0) return;
    float w = exp(-max(lensDistance(p, lens, meta), 0.0) / max(u_smoothness, EPS));
    acc  += lens.xy * w;
    wsum += w;
    // PREMULTIPLIED, because two members can differ in alpha as well as hue —
    // averaging straight alpha would drag the more transparent one's colour in
    // at full strength.
    tintAcc += vec4(tint.rgb * tint.a, tint.a) * w;
}

// Weighted premultiplied accumulation back to the straight-alpha colour
// applyLensTint expects. No members in reach (a fragment out past every
// blob's falloff) falls back to the group tint; it is masked out there anyway.
vec4 resolveTint(vec4 tintAcc, float wsum) {
    if (wsum <= EPS) return u_lensColor;
    vec4 pm = tintAcc / wsum;
    return (pm.a > EPS) ? vec4(pm.rgb / pm.a, pm.a) : vec4(0.0);
}

// ── Hard union (u_mergeEnabled == 0) ─────────────────────────────────────
//
// With the metaball off there is nothing to blend, so nothing needs blending
// maths: whichever member is nearest owns the fragment outright and hands over
// its distance, its centre and its colour. No smin, no per-member exp(), no
// accumulators — one compare per member instead.
//
// This is NOT the same as running the smooth path with smoothness 0. That
// degenerates correctly for the DISTANCE, but its weights collapse to a 0/1
// indicator, so two OVERLAPPING members both weigh 1 and their colours average
// 50/50 with a hard step at each outline. Nearest-wins has no such tie.
struct NearestMember {
    float dist;
    vec4  lens;
    vec4  meta;
    vec4  tint;
};

void keepNearest(vec2 p, vec4 lens, vec4 meta, vec4 tint, inout NearestMember n) {
    if (lens.z <= 0.0) return;
    float d = lensDistance(p, lens, meta);
    if (d >= n.dist) return;
    n.dist = d;
    n.lens = lens;
    n.meta = meta;
    n.tint = tint;
}

NearestMember nearestMember(vec2 p) {
    NearestMember n;
    n.dist = 1e9;
    n.lens = vec4(0.0);
    n.meta = vec4(0.0);
    n.tint = u_lensColor;
    keepNearest(p, u_lens0, u_lensMeta0, u_lensTint0, n);
    keepNearest(p, u_lens1, u_lensMeta1, u_lensTint1, n);
    keepNearest(p, u_lens2, u_lensMeta2, u_lensTint2, n);
    keepNearest(p, u_lens3, u_lensMeta3, u_lensTint3, n);
    keepNearest(p, u_lens4, u_lensMeta4, u_lensTint4, n);
    keepNearest(p, u_lens5, u_lensMeta5, u_lensTint5, n);
    keepNearest(p, u_lens6, u_lensMeta6, u_lensTint6, n);
    keepNearest(p, u_lens7, u_lensMeta7, u_lensTint7, n);
    return n;
}

vec2 anchorFor(vec2 p, out vec4 tint) {
    // The branch is on a UNIFORM, so it costs nothing: every fragment in the
    // draw takes the same side of it.
    if (u_mergeEnabled < 0.5) {
        NearestMember n = nearestMember(p);
        tint = n.tint;
        return (n.dist < 1e8) ? n.lens.xy : p;
    }
    vec2 acc = vec2(0.0);
    float wsum = 0.0;
    vec4 tintAcc = vec4(0.0);
    accumulateAnchor(u_lens0, u_lensMeta0, u_lensTint0, p, acc, wsum, tintAcc);
    accumulateAnchor(u_lens1, u_lensMeta1, u_lensTint1, p, acc, wsum, tintAcc);
    accumulateAnchor(u_lens2, u_lensMeta2, u_lensTint2, p, acc, wsum, tintAcc);
    accumulateAnchor(u_lens3, u_lensMeta3, u_lensTint3, p, acc, wsum, tintAcc);
    accumulateAnchor(u_lens4, u_lensMeta4, u_lensTint4, p, acc, wsum, tintAcc);
    accumulateAnchor(u_lens5, u_lensMeta5, u_lensTint5, p, acc, wsum, tintAcc);
    accumulateAnchor(u_lens6, u_lensMeta6, u_lensTint6, p, acc, wsum, tintAcc);
    accumulateAnchor(u_lens7, u_lensMeta7, u_lensTint7, p, acc, wsum, tintAcc);
    tint = resolveTint(tintAcc, wsum);
    return (wsum > EPS) ? acc / wsum : p;
}

// =====================================================
// FUSED single-pass evaluation (perf): compute the smooth union (field),
// the hard min (fieldHard) and the influence-weighted anchor (anchorFor) in
// ONE loop over the lenses, from a SINGLE raw lensDistance() per lens.
//
// The original main() evaluated each lens's SDF up to three times at the
// same fragment — once for field(), once for fieldHard() and once for
// anchorFor(). lensDistance() is pure, so reusing
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
    vec4  tint;        // == anchorFor's tint out — the blended member colour
    vec2  grad;        // analytic merged gradient (METABALL_GRAD_ANALYTIC only)
};

void accumulateMerged(vec2 p, vec4 lens, vec4 meta, vec4 tint,
                      inout float smoothSdf, inout float hardSdf,
                      inout vec2 anchorAcc, inout float anchorW,
                      inout vec4 tintAcc, inout vec2 gradAcc) {
    if (lens.z <= 0.0) return;

    // The one raw SDF for this lens — shared by all three accumulators.
    float base = lensDistance(p, lens, meta);

    // Hard union (== fieldHard's min).
    hardSdf = min(hardSdf, base);

    // Anchor weight (== accumulateAnchor).
    float w = exp(-max(base, 0.0) / max(u_smoothness, EPS));
    anchorAcc += lens.xy * w;
    anchorW   += w;
    // Tint on the same weight — see accumulateAnchor.
    tintAcc   += vec4(tint.rgb * tint.a, tint.a) * w;

    // Smooth union, inlined so the blend weight h is shared with the gradient.
    // h and the value are bit-identical to smoothUnion(smoothSdf, base, k).
    float kk = max(u_smoothness, EPS);
    float h  = clamp(0.5 + 0.5 * (base - smoothSdf) / kk, 0.0, 1.0);
    smoothSdf = mix(base, smoothSdf, h) - kk * h * (1.0 - h);

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
    // Metaball off: one pass of compares, then straight out — see nearestMember.
    if (u_mergeEnabled < 0.5) {
        NearestMember n = nearestMember(p);
        m.smoothSdf = n.dist;
        m.hardSdf   = n.dist;
        m.anchor    = (n.dist < 1e8) ? n.lens.xy : p;
        m.tint      = n.tint;
#if METABALL_GRAD_ANALYTIC
        // One gradient — the winner's own — instead of eight blended together.
        m.grad = (n.dist < 1e8) ? lensGradDir(p, n.lens, n.meta) : vec2(0.0);
#else
        m.grad = vec2(0.0);
#endif
        return m;
    }
    m.smoothSdf = 1e9;
    m.hardSdf   = 1e9;
    m.grad      = vec2(0.0);
    vec2 anchorAcc = vec2(0.0);
    float anchorW = 0.0;
    vec4 tintAcc = vec4(0.0);
    accumulateMerged(p, u_lens0, u_lensMeta0, u_lensTint0, m.smoothSdf,
                     m.hardSdf, anchorAcc, anchorW, tintAcc, m.grad);
    accumulateMerged(p, u_lens1, u_lensMeta1, u_lensTint1, m.smoothSdf,
                     m.hardSdf, anchorAcc, anchorW, tintAcc, m.grad);
    accumulateMerged(p, u_lens2, u_lensMeta2, u_lensTint2, m.smoothSdf,
                     m.hardSdf, anchorAcc, anchorW, tintAcc, m.grad);
    accumulateMerged(p, u_lens3, u_lensMeta3, u_lensTint3, m.smoothSdf,
                     m.hardSdf, anchorAcc, anchorW, tintAcc, m.grad);
    accumulateMerged(p, u_lens4, u_lensMeta4, u_lensTint4, m.smoothSdf,
                     m.hardSdf, anchorAcc, anchorW, tintAcc, m.grad);
    accumulateMerged(p, u_lens5, u_lensMeta5, u_lensTint5, m.smoothSdf,
                     m.hardSdf, anchorAcc, anchorW, tintAcc, m.grad);
    accumulateMerged(p, u_lens6, u_lensMeta6, u_lensTint6, m.smoothSdf,
                     m.hardSdf, anchorAcc, anchorW, tintAcc, m.grad);
    accumulateMerged(p, u_lens7, u_lensMeta7, u_lensTint7, m.smoothSdf,
                     m.hardSdf, anchorAcc, anchorW, tintAcc, m.grad);
    m.anchor = (anchorW > EPS) ? anchorAcc / anchorW : p;
    m.tint   = resolveTint(tintAcc, anchorW);
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

vec4 finalSample(vec2 refractedPx, float shapeMask, float caShift,
                 vec4 lensTint, out vec3 preTintColor) {
    vec3 refrColor = sampleBackground(refractedPx, caShift);
    refrColor = applySaturation(refrColor, u_saturation);
    preTintColor = refrColor;

    vec2 uv = refractedToUv(refractedPx);
    float texA = (u_honorBackdropAlpha > 0.5) ? texture(u_texture_input, uv).a : 1.0;
    float coverage = shapeMask * texA;

    vec4 base = vec4(refrColor * shapeMask, coverage);
    base.rgb = applyLensTint(base.rgb, shapeMask, lensTint, u_borderAlpha);
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
    vec4 lensTint   = mf.tint;
#else
    ShapeData shapeData = evaluateField(fragPx);
    float shapeDistPx   = shapeData.orthoDist;
    float shapeMask     = computeShapeMask(shapeDistPx);

    // Rim wrap only at the blend neck; 0 on isolated lenses.
    float rimWrap = bridgeWrap(fragPx, shapeData.sdf);

    vec4 lensTint;
    vec2 anchorPx   = anchorFor(fragPx, lensTint);
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
            : finalSample(magPx, shapeMask, 0.0, lensTint, preTintCol);

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
    vec4 base = finalSample(refrPx, shapeMask, caShift, lensTint, preTintCol2);

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
