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
// x=magnification  y=distortion  z=distortionThicknessPx
// w=enableBackgroundTransparency
uniform vec4 u_warp;

uniform float u_diagonalFlip;

// Border
uniform float u_borderWidth;
uniform float u_borderSoftness;
uniform vec4  u_borderColor;
uniform float u_borderAlpha;
uniform float u_lightIntensity;
uniform vec4  u_lightColor;
uniform vec4  u_shadowColor;
uniform float u_lightDirection;
uniform vec4 u_lensColor;
// x=oneSideLightIntensity  y=chromaticAberration  z=saturation  w=lightMode
uniform vec4 u_packA;
// x=refractionMode  y=refractionType  z=refractionIndex  w=ambientIntensity
uniform vec4 u_packB;
// x=doubleSideLightIntensity  y=borderSaturation  z=borderSolidity  w=borderMode
uniform vec4 u_packC;
// Optical-rim angular spread (higher = highlight wraps further around).
uniform float u_lightSpread;

// Restore the original scalar names. These are plain float aliases (a single
// component access, no swizzle chaining), so the shader body and every helper
// function below compile unchanged.
#define u_lensWidth                    u_lensGeom.x
#define u_lensHeight                   u_lensGeom.y
#define u_cornerRadius                 u_lensGeom.z
#define u_cornerStyle                  u_lensGeom.w
#define u_magnification                u_warp.x
#define u_distortion                   u_warp.y
#define u_distortionThicknessPx        u_warp.z
#define u_enableBackgroundTransparency u_warp.w
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


out vec4 frag_color;

// ===================================================

#define REFRACTION_SHAPE    0
#define REFRACTION_RADIAL   1
#define REFRACTION_STANDARD 0
#define REFRACTION_OPTICAL  1

#define PIXEL_TO_NORM(px) ((px) / u_resolution.y)

vec3 applyChromaticAberration(vec2 uv, float shift) {
    // Compute offsets based on luma
    vec3 color = texture(u_texture_input, uv).rgb;
    if(shift < 0.001) return color;
    // Luma calculation (Rec. 709)
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // Offset depends on brightness
    vec2 offset = vec2(shift * luma);

    float r = texture(u_texture_input, uv + offset).r;
    float g = texture(u_texture_input, uv).g;
    float b = texture(u_texture_input, uv - offset).b;

    return vec3(r, g, b);
}

vec3 applySaturation(vec3 color, float saturation) {

    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luminance), color, saturation);
}
// ===================================================
// Final texture sampling after refraction
// ===================================================


vec4 finalSample(
    vec2 refractedPx,
    float shapeMask,
    float caShift,
    out vec3 preTintColor
){
    vec3 refrColor;

    // Map the refracted PARENT-pixel position into the bound texture's
    // [u_imageOffset, u_imageOffset + u_imageSize] rect. Full-frame =
    // (refractedPx - 0) / u_resolution, identical to the old behavior.
    vec2 sampleUV = clamp((refractedPx - u_imageOffset) / u_imageSize,
                          vec2(0.001), vec2(0.999));
    // GLES sampler Y-flip — only on engines BEFORE the OpenGLES coordinate
    // unification (post-3.44.0 sets IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED).
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    sampleUV.y = 1.0 - sampleUV.y;
    #endif
    #endif
    // Chromatic aberration is confined to the distortion band (caShift),
    // not applied across the whole lens body. The caller passes 0 outside
    // the band and a zoneT-ramped shift inside it, so the colour fringing
    // appears only where the glass actually bends light — at the edge.
    refrColor = applyChromaticAberration(sampleUV, caShift);
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
    return 1.0 - smoothstep(-0.5 * aa, 0.5 * aa, shapeDistPx);
}


// =====================================================
// Main entry
// =====================================================
void main() {
    // ===============================
    // Fragment coordinate setup
    // ===============================
    vec2 fragPx   = FlutterFragCoord().xy;
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

    // Rounded rectangle. u_cornerStyle selects the corner SDF:
    //   2 = continuous (Apple capsule-style), 1 = squircle, 0 = circular.
    float maxCorner      = min(u_lensWidth, u_lensHeight) * 0.5;
    float cornerRadiusPx = min(u_cornerRadius, maxCorner);

    if (u_cornerStyle > 1.5 && cornerRadiusPx > 0.5) {
        // Continuous (Apple capsule-style) corners.
        vec2 reach = continuousRoundedRectReach(cornerRadiusPx, lensHalfSizePx);
        shapeData = evaluateContinuousRoundedRect(
            fragPx, lensCenterPx, lensHalfSizePx, cornerRadiusPx, reach);
    } else if (u_cornerStyle > 0.5 && cornerRadiusPx > 0.5) {
        // Squircle (Ln-norm) corners — smoothing fixed at full (1.0).
        vec2 zn = squircleCornerParams(cornerRadiusPx, 1.0, maxCorner);
        shapeData = evaluateSquircleRRect(
            fragPx, lensCenterPx, lensHalfSizePx, zn.x, zn.y);
    } else {
        shapeData = evaluateShape(
            fragPx,
            lensCenterPx,
            lensHalfSizePx,
            cornerRadiusPx
        );
    }

    shapeDistPx = shapeData.orthoDist;

    // --- Shared antialiasing + mask ---
    shapeMask = computeShapeMask(shapeDistPx);

    // ===============================
    // Distortion band setup
    // ===============================
    float distAbsPx = abs(shapeDistPx);
    float zoneLimit = u_distortionThicknessPx;
    float zoneMask  = step(distAbsPx, zoneLimit);

    // ===============================
    // Apply uniform magnification to entire lens
    // ===============================

    vec2 magPx = applyLensMagnification(
        fragPx,
        lensCenterPx,
        u_magnification
    );

    if (zoneMask < 0.5) {
        // Outside distortion zone
        vec3 preTintCol = vec3(0.0);
        // No chromatic aberration outside the distortion band.
        vec4 base = (u_enableBackgroundTransparency > 0.5)
        ? vec4(0.0)
        : finalSample(magPx, shapeMask, 0.0, preTintCol);

        vec3 ambientCol = preTintCol;
        vec4 borderPremul = getSweepBorder(
            uvNorm, lensCenterNorm, shapeData.orthoDist,shapeData.grad,
            u_borderWidth, u_borderSoftness, u_borderColor,
            u_lightColor, u_shadowColor,
            u_lightIntensity, u_borderAlpha, u_lightDirection, u_oneSideLightIntensity,u_lightMode,
            ambientCol, u_ambientIntensity,
            u_doubleSideLightIntensity,
            u_borderSaturation,
            u_borderSolidity,
            u_lightSpread,
            u_borderMode
        );

        frag_color = overlayPremul(base, borderPremul, u_borderMode);
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

    if (u_refractionType == REFRACTION_OPTICAL) {
        // Shape mode follows the SDF normal; radial mode bends outward
        // from the lens center while using the same physical calculation.
        vec2 opticalNormal = shapeData.normal;
        if (u_refractionMode == REFRACTION_RADIAL) {
            vec2 radial = magPx - lensCenterPx;
            float radialLength = length(radial);
            if (radialLength > EPS) {
                opticalNormal = radial / radialLength;
            }
        }
        refrPx = computeRefractedPosition(
            magPx,
            opticalNormal,
            shapeData.sdf,
            u_distortionThicknessPx,
            u_refractionIndex,
            u_distortion,
            zoneT
        );
    }
    else if(u_refractionMode== REFRACTION_SHAPE) {
        // Stable shape refraction (inset-anchor based).
        float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
        refrPx = computeShapeRefraction(
            magPx,
            shapeData.normal,
            shapeData.sdf,
            u_distortionThicknessPx,
            distortionFactor,
            u_magnification,
            u_diagonalFlip,
            zoneT
        );

    }
    else if(u_refractionMode== REFRACTION_RADIAL){
        vec2 distortionCenter = lensCenterPx;
        float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
        refrPx = refractFromAnchorPx(
            magPx,
            distortionCenter,
            distortionFactor,
            u_magnification,
            u_diagonalFlip,
            zoneT
        );
    }
    // ===============================
    // Final sample & border
    // ===============================
    vec3 preTintCol2 = vec3(0.0);
    // Confine chromatic aberration to the distortion band and ramp it with
    // zoneT so the colour fringing is strongest at the shape edge (zoneT→1)
    // and fades to none at the band's inner boundary (zoneT→0).
    float caShift = u_chromaticAberration * zoneT;
    vec4 base = finalSample(refrPx, shapeMask, caShift, preTintCol2);

    vec3 ambientCol2 = preTintCol2;
    vec4 borderPremul = getSweepBorder(
        uvNorm, lensCenterNorm, shapeData.orthoDist,shapeData.grad,
        u_borderWidth, u_borderSoftness, u_borderColor,
        u_lightColor, u_shadowColor,
        u_lightIntensity, u_borderAlpha, u_lightDirection, u_oneSideLightIntensity,u_lightMode,
        ambientCol2, u_ambientIntensity,
        u_doubleSideLightIntensity,
        u_borderSaturation,
        u_borderSolidity,
        u_lightSpread,
        u_borderMode
    );

    // ===============================
    // Output composite
    // ===============================
    frag_color = overlayPremul(base, borderPremul, u_borderMode);
}
