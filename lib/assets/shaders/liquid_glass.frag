// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
// Shape-gradient method, chosen BEFORE common.glsl applies it: derivative on
// Impeller (this entry), analytic on Skia (liquid_glass_skia.frag) — or 5-tap on
// both when LIQUID_GLASS_FORCE_5TAP is set. See liquid_glass_grad_select.glsl.
#include "liquid_glass_grad_select.glsl"
#include "liquid_glass_common.glsl"
#include "liquid_glass_border.glsl"
#define PI 3.14159265

// mediump perf test: inherit the shared toggle from liquid_glass_common.glsl.
precision GLASS_FLOAT_PRECISION float;

// =====================================================
// Uniforms
// =====================================================
uniform vec2  u_resolution;
uniform vec2  u_touch;
uniform sampler2D u_texture_input;

// --- Packed scalar uniforms (Metal [[buffer(N)]] limit fix) ----------------
// iOS 26 Impeller binds each runtime-effect uniform to its own Metal buffer
// and caps at ~30. To stay under the limit, several scalars are merged into
// vec4s below; the #define block right after restores the original scalar
// names. The float-offset order is IDENTICAL to the old per-scalar layout, so
// the Dart-side packing code (packLiquidGlassUniforms, the painters) is
// unchanged.

// x=lensWidth  y=lensHeight  z=cornerRadius  w=cornerStyle
//   cornerStyle selects the corner SDF (see the shape branch in main):
//   0 = circular rounded rect, 1 = squircle (Ln-norm, full smoothing),
//   2 = continuous (Apple capsule-style) corners.
uniform vec4 u_lensGeom;
// x=magnification  y=refractionIndex  z=refractionWidthPx
// w=dispersion
uniform vec4 u_warp;

// Border
// The specular's thickness, in fragment px.
uniform float u_borderWidth;
uniform float u_borderAlpha;
// Each light's own colour, straight alpha: alpha 0 keeps the picked-up
// colour, 1 draws the light in this colour as given.
uniform vec4  u_specularColor;
uniform vec4  u_glowColor;
uniform vec4 u_lensColor;
// x=specularIntensity  y=saturation  z=glowIntensity  w=glowThickness
uniform vec4 u_packA;
// x=specularAngle  y=specularSpread  z=borderSharpness  w=glowAngle
uniform vec4 u_packB;
// x=glowSpread  y=specular2Intensity  zw unused
uniform vec4 u_packC;
// The second specular: x=thicknessPx  y=sharpness  z=angle  w=spread.
// A zero thickness turns it off.
uniform vec4 u_specular2;
// The second specular's own colour, as u_specularColor.
uniform vec4 u_specular2Color;
// Far-arc strength per light: x=specular  y=glow  z=second specular.
uniform vec4 u_lightOpposite;

// Restore the original scalar names. These are plain float aliases (a single
// component access, no swizzle chaining), so the shader body and every helper
// function below compile unchanged.
#define u_lensWidth                    u_lensGeom.x
#define u_lensHeight                   u_lensGeom.y
#define u_cornerRadius                 u_lensGeom.z
#define u_cornerStyle                  u_lensGeom.w
#define u_magnification                u_warp.x
#define u_refractionIndex              u_warp.y
#define u_refractionWidthPx            u_warp.z
#define u_dispersion                   u_warp.w
#define u_specularIntensity            u_packA.x
#define u_saturation                   u_packA.y
#define u_glowIntensity                u_packA.z
#define u_glowThickness                u_packA.w
#define u_specularAngle                u_packB.x
#define u_specularSpread               u_packB.y
#define u_borderSharpness              u_packB.z
#define u_glowAngle                    u_packB.w
#define u_glowSpread                   u_packC.x
#define u_specular2Intensity           u_packC.y
// Each light as the border reads it: (angle in degrees, spread, intensity).
#define u_specular vec3(u_specularAngle, u_specularSpread, u_specularIntensity)
#define u_glow     vec3(u_glowAngle, u_glowSpread, u_glowIntensity)

// Capture-region mapping. The bound texture (u_texture_input) covers the
// parent-space rectangle [u_imageOffset, u_imageOffset + u_imageSize] in
// the SAME pixel space as FlutterFragCoord / u_resolution. For a normal
// full-frame capture this is offset (0,0) and size u_resolution, which
// reproduces the old `refrPx / u_resolution` mapping exactly. For a
// region capture it is the captured sub-rect, so a smaller texture can be
// bound without recompositing it back to full size.
uniform vec2 u_imageOffset;
uniform vec2 u_imageSize;

// 1.0 = fold the sampled backdrop's alpha into coverage (Skia capture:
// the bound snapshot carries meaningful authored transparency — e.g. the
// slider/toggle capture a mostly-transparent track). 0.0 = ignore it and
// treat the backdrop as opaque (Impeller live backdrop: its alpha is not
// a transparency signal and reads 0 over dark regions, which would
// otherwise zero the body coverage and drop the optical rim).
uniform float u_honorBackdropAlpha;

// Edge-AA band width in FRAGMENT pixels (one logical pixel): 1.0 on the Skia
// (logical-px) shader space, devicePixelRatio on the Impeller (physical-px)
// space. Lets the centered shape-coverage ramp be the same ~1 logical px wide
// on both backends — without it, Impeller's 1-physical-px band undersamples
// and the corners alias. Must be the LAST uniform (see packLiquidGlassUniforms).
uniform float u_shapeAaPx;

// Deformed size / rest size, from the flex. (1,1) = undeformed, and the
// whole rest-space path below then collapses to the original math.
uniform vec2 u_shapeScale;

// Lens→shader affine map for ancestor transforms (scale/rotation):
// shader = [[x,y],[z,w]]·lens + off. Identity when untransformed.
uniform vec4 u_xformRow;
uniform vec2 u_xformOff;


out vec4 frag_color;

// ===================================================


#define PIXEL_TO_NORM(px) ((px) / u_resolution.y)

vec3 applyDispersion(vec2 uv, float shift, vec2 texSizePx) {
    // Compute offsets based on luma
    vec3 color = texture(u_texture_input, uv).rgb;
    if(shift < DISPERSION_MIN_LOGICAL_PX) return color;
    // Luma calculation (Rec. 709)
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // Offset depends on brightness
    vec2 offset = dispersionOffsetUv(shift, luma, texSizePx, max(u_shapeAaPx, 1.0));

    float r = texture(u_texture_input, uv + offset).r;
    float g = texture(u_texture_input, uv).g;
    float b = texture(u_texture_input, uv - offset).b;

    return vec3(r, g, b);
}

vec3 applySaturation(vec3 color, float saturation) {

    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luminance), color, saturation);
}
// Engine-blur pass: u_imageOffset/u_imageSize hold the pass clip, size negated.
// The input texture is then u_resolution (the engine writes its size there).
bool composePass() { return u_imageSize.x < 0.0; }

// Where FlutterFragCoord counts from. Engines that crop the input to the clip
// hand a texture smaller than the clip's far corner; newer ones keep the pass.
vec2 fragOrigin() {
    if (!composePass()) return vec2(0.0);
    vec2 clipFar = u_imageOffset - u_imageSize;
    bool clipLocal = u_resolution.x < clipFar.x - 1.0 ||
                     u_resolution.y < clipFar.y - 1.0;
    return clipLocal ? u_imageOffset : vec2(0.0);
}

// ===================================================
// Final texture sampling after refraction
// ===================================================


vec4 finalSample(
    vec2 refractedPx,
    float shapeMask,
    float dispersionShift,
    bool xformed,
    out vec3 preTintColor
){
    vec3 refrColor;

    // Geometry ran in LENS space; the backdrop lives in shader space —
    // map the refracted position back through the forward transform.
    if (xformed) {
        refractedPx = mat2(u_xformRow.x, u_xformRow.z,
                           u_xformRow.y, u_xformRow.w)
                      * refractedPx + u_xformOff;
    }

    // Map the refracted PARENT-pixel position into the bound texture's
    // [u_imageOffset, u_imageOffset + u_imageSize] rect. Full-frame =
    // (refractedPx - 0) / u_resolution, identical to the old behavior.
    vec2 imageOffset = composePass() ? fragOrigin() : u_imageOffset;
    vec2 imageSize = composePass() ? u_resolution : u_imageSize;
    vec2 sampleUV = clamp((refractedPx - imageOffset) / imageSize,
                          vec2(0.001), vec2(0.999));
    // GLES sampler Y-flip — only on engines BEFORE the OpenGLES coordinate
    // unification (post-3.44.0 sets IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED).
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    sampleUV.y = 1.0 - sampleUV.y;
    #endif
    #endif
    // Dispersion is confined to the distortion band (dispersionShift),
    // not applied across the whole lens body. The caller passes 0 outside
    // the band and a zoneT-ramped shift inside it, so the colour fringing
    // appears only where the glass actually bends light — at the edge.
    refrColor = applyDispersion(sampleUV, dispersionShift, imageSize);
    // Apply saturation BEFORE tinting
    refrColor = applySaturation(refrColor,u_saturation);
    preTintColor = refrColor; // capture before tint for optical border

    // Coverage = shape mask, optionally modulated by the sampled
    // backdrop's alpha (see u_honorBackdropAlpha). Skia capture honors it
    // so an authored-transparent snapshot (slider/toggle track) shows the
    // real screen through; Impeller ignores it (its live-backdrop alpha
    // reads 0 over dark regions and would otherwise drop the lens/rim —
    // the "border missing on a black background" bug).
    float texA = (u_honorBackdropAlpha > 0.5)
        ? texture(u_texture_input, sampleUV).a
        : 1.0;
    float coverage = shapeMask * texA;

    vec4 base = vec4(refrColor * shapeMask, coverage);
    // Then apply lens tint
    base.rgb = applyLensTint(base.rgb, shapeMask, u_lensColor, u_borderAlpha);
    return base;
}


float computeShapeMask(float shapeDistPx) {
    // Centered signed-distance coverage. `shapeDistPx` (orthoDist =
    // fC / length(grad)) is a first-order Euclidean distance measured in
    // FRAGMENT pixels, so a fixed 1px band CENTERED on the outline is the
    // correct antialiasing in the shader's own raster space — for circular,
    // squircle AND continuous corners alike. This makes the edge self-AA so
    // the silhouette no longer depends on a wrapping drawRRect for coverage.
    //
    // (The previous version was `1 - smoothstep(0, aa, sd)` times
    // `step(sd, 0)`, which pushed the whole ramp OUTSIDE the shape and then
    // deleted it with step() — i.e. a hard edge with no shader AA. The AA
    // came entirely from the canvas drawRRect; drawing a plain rect aliased.)
    //
    // Don't use fwidth()/dFdx(): SkSL's transpiler chokes on the float form.
    // The band width comes from u_shapeAaPx (= one logical pixel) so the ramp
    // is the same physical width on Skia and Impeller; the max() floor keeps a
    // safe 1px fallback if the uniform is ever unset.
    float aa = max(u_shapeAaPx, 1.0);
    // Two thirds of the band sit inside the outline: the outline itself is
    // 74% faded, so over a dark backdrop the lighter glass shows a thin dark
    // hairline at its very edge. The optical rim measures from that centre.
    return 1.0 - smoothstep(-0.667 * aa, 0.333 * aa, shapeDistPx);
}


// =====================================================
// Main entry
// =====================================================
void main() {
    // ===============================
    // Fragment coordinate setup
    // ===============================
    vec2 fragPx   = FlutterFragCoord().xy + fragOrigin();

    // Under an ancestor transform the geometry runs in LENS space and
    // the refracted sample maps back out (finalSample).
    bool xformed = any(notEqual(u_xformRow, vec4(1.0, 0.0, 0.0, 1.0))) ||
                   any(notEqual(u_xformOff, vec2(0.0)));
    if (xformed) {
        float det = u_xformRow.x * u_xformRow.w - u_xformRow.y * u_xformRow.z;
        if (abs(det) < 1e-6) xformed = false;
    #ifndef LIQUID_GLASS_SKIA
        // Impeller's fragments arrive in screen space, so map them in.
        // Skia draws the lens locally: they are lens space already.
        if (xformed) {
            fragPx = mat2(u_xformRow.w, -u_xformRow.z,
                          -u_xformRow.y, u_xformRow.x)
                     * (fragPx - u_xformOff) / det;
        }
    #endif
    }

    float invResY = 1.0 / u_resolution.y;
    vec2 uvNorm   = fragPx * invResY;

    // ===============================
    // Lens geometry
    // ===============================
    vec2 lensHalfSizePx = 0.5 * vec2(u_lensWidth, u_lensHeight);
    vec2 lensCenterPx   = u_touch + lensHalfSizePx;
    vec2 lensCenterNorm = lensCenterPx * invResY;

    // ===============================
    // Shape distance (SDF)
    // ===============================
    float shapeDistPx;
    float shapeMask;
    ShapeData shapeData;

    // Evaluate at REST size in a domain divided by the deformation, so a
    // stretched circle becomes an ellipse instead of growing flat runs.
    // Pass the geometry through UNTOUCHED when there is no deformation.
    // (p - c)/1 + c is not guaranteed to round-trip to p, so mapping anyway
    // would shift every undeformed lens by an ulp for no effect. A zero
    // uniform (never set) reads as undeformed rather than as a huge scale.
    bool deformed = u_shapeScale.x > 0.0 && u_shapeScale.y > 0.0 &&
                    (u_shapeScale.x != 1.0 || u_shapeScale.y != 1.0);
    vec2 shapeScale = deformed ? max(u_shapeScale, vec2(1e-4)) : vec2(1.0);
    vec2 restHalfPx = deformed ? lensHalfSizePx / shapeScale : lensHalfSizePx;
    vec2 fragRestPx =
        deformed ? lensCenterPx + (fragPx - lensCenterPx) / shapeScale : fragPx;

    // Rounded rectangle. u_cornerStyle selects the corner SDF:
    //   2 = continuous (Apple capsule-style), 1 = squircle, 0 = circular.
    float maxCorner      = min(restHalfPx.x, restHalfPx.y);
    float cornerRadiusPx = min(u_cornerRadius, maxCorner);

    if (u_cornerStyle > 1.5 && cornerRadiusPx > 0.5) {
        // Continuous (capsule-style) corners.
        vec2 reach = continuousRoundedRectReach(cornerRadiusPx, restHalfPx);
        shapeData = evaluateContinuousRoundedRect(
            fragRestPx, lensCenterPx, restHalfPx, cornerRadiusPx, reach);
    } else if (u_cornerStyle > 0.5 && cornerRadiusPx > 0.5) {
        // Squircle (Ln-norm) corners — smoothing fixed at full (1.0).
        vec2 zn = squircleCornerParams(cornerRadiusPx, 1.0, maxCorner);
        shapeData = evaluateSquircleRRect(
            fragRestPx, lensCenterPx, restHalfPx, zn.x, zn.y);
    } else {
        shapeData = evaluateShape(
            fragRestPx,
            lensCenterPx,
            restHalfPx,
            cornerRadiusPx
        );
    }

    // Back to screen px — the AA ramp, the band and the rim all measure there.
    shapeData   = shapeToScreen(shapeData, shapeScale);
    shapeDistPx = shapeData.orthoDist;

    // Refraction's depth, in the same px as the thickness it divides by. Raw
    // `sdf` is REST px when deformed, so the backdrop zooms with the pull.
    // Undeformed keeps `sdf` verbatim: orthoDist divides by a length that is
    // only approximately 1, and unused must stay bit-identical.
    float refrDistPx = deformed ? shapeData.orthoDist : shapeData.sdf;

    // --- Shared antialiasing + mask ---
    shapeMask = computeShapeMask(shapeDistPx);

    // ===============================
    // Distortion band setup
    // ===============================
    float distAbsPx = abs(shapeDistPx);
    float zoneLimit = u_refractionWidthPx;
    float zoneMask  = step(distAbsPx, zoneLimit);

    // ===============================
    // Apply uniform magnification to entire lens
    // ===============================

    vec2 magPx = applyLensMagnification(
        fragPx,
        lensCenterPx,
        u_magnification
    );

    // The rim's tint: the lens colour, so the rim lifts from the
    // tinted glass rather than the bare backdrop (a black backdrop under a
    // light tint would otherwise lift to a grey darker than the body).
    vec4 rimTint = u_lensColor;

#ifdef LIQUID_GLASS_DESKTOP
    // Outside the band: the straight magnified sample, no dispersion. One sample and
    // one border call serve both sides, so each is compiled once.
    vec2 samplePx = magPx;
    float dispersionShift = 0.0;
    bool drawBase = true;
    if (zoneMask >= 0.5) {
        // ===============================
        // Distortion zone logic
        // ===============================
        float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);

        // ===============================
        // Refracted position
        // ===============================

        vec2 refrPx = magPx;

        refrPx = computeRefractedPosition(
            magPx, shapeData.normal, refrDistPx,
            u_refractionWidthPx, u_refractionIndex,
            REFRACTION_DEPTH_LOGICAL_PX * max(u_shapeAaPx, 1.0), zoneT
        );
        samplePx = refrPx;
        // Confine dispersion to the distortion band and ramp it with
        // zoneT so the colour fringing is strongest at the shape edge.
        dispersionShift = u_dispersion * zoneT;
    }

    // ===============================
    // Final sample & border
    // ===============================
    vec3 preTintCol = vec3(0.0);
    vec4 base = vec4(0.0);
    if (drawBase) {
        base = finalSample(samplePx, shapeMask, dispersionShift, xformed, preTintCol);
    }

    vec4 borderPremul = getBorder(
        shapeData.orthoDist, shapeData.grad,
        rimTint, u_borderAlpha,
        preTintCol,
        u_borderWidth, u_borderSharpness, u_specular, u_specularColor,
        u_glowThickness, u_glow, u_glowColor,
        u_specular2, u_specular2Intensity, u_specular2Color,
        u_lightOpposite.xyz,
        u_shapeAaPx
    );

    // ===============================
    // Output composite
    // ===============================
    frag_color = overlayPremul(base, borderPremul);
#else
    if (zoneMask < 0.5) {
        // Outside distortion zone
        vec3 preTintCol = vec3(0.0);
        // No dispersion outside the distortion band.
        vec4 base = finalSample(magPx, shapeMask, 0.0, xformed, preTintCol);

        vec3 backdropCol = preTintCol;
        vec4 borderPremul = getBorder(
            shapeData.orthoDist, shapeData.grad,
            rimTint, u_borderAlpha,
            backdropCol,
            u_borderWidth, u_borderSharpness, u_specular, u_specularColor,
            u_glowThickness, u_glow, u_glowColor,
            u_specular2, u_specular2Intensity, u_specular2Color,
            u_lightOpposite.xyz,
            u_shapeAaPx
        );

        frag_color = overlayPremul(base, borderPremul);
        return;
    }

    // ===============================
    // Distortion zone logic
    // ===============================
    float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);

    // ===============================
    // Refracted position
    // ===============================

    vec2 refrPx;

    refrPx = computeRefractedPosition(
        magPx, shapeData.normal, refrDistPx,
        u_refractionWidthPx, u_refractionIndex,
            REFRACTION_DEPTH_LOGICAL_PX * max(u_shapeAaPx, 1.0), zoneT
    );
    // ===============================
    // Final sample & border
    // ===============================
    vec3 preTintCol2 = vec3(0.0);
    // Confine dispersion to the distortion band and ramp it with
    // zoneT so the colour fringing is strongest at the shape edge (zoneT→1)
    // and fades to none at the band's inner boundary (zoneT→0).
    float dispersionShift = u_dispersion * zoneT;
    vec4 base = finalSample(refrPx, shapeMask, dispersionShift, xformed, preTintCol2);

    vec3 backdropCol2 = preTintCol2;
    vec4 borderPremul = getBorder(
        shapeData.orthoDist, shapeData.grad,
        rimTint, u_borderAlpha,
        backdropCol2,
        u_borderWidth, u_borderSharpness, u_specular, u_specularColor,
        u_glowThickness, u_glow, u_glowColor,
        u_specular2, u_specular2Intensity, u_specular2Color,
        u_lightOpposite.xyz,
        u_shapeAaPx
    );

    // ===============================
    // Output composite
    // ===============================
    frag_color = overlayPremul(base, borderPremul);
#endif
}
