// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
// Same backend-split gradient method as liquid_glass.frag: derivative on
// Impeller (this entry), analytic on Skia (liquid_glass_border_skia.frag).
#include "liquid_glass_grad_select.glsl"
#include "liquid_glass_border.glsl"
#include "liquid_glass_common.glsl"
#define PI 3.14159265
precision highp float; // or highp float

/* ================
   SHARED UNIFORMS
   ================ */
uniform vec2 u_resolution;
uniform vec2 u_touch;
uniform sampler2D u_texture_input;

// --- Packed scalar uniforms (Metal [[buffer(N)]] limit fix) ----------------
// Mirrors liquid_glass.frag: scalars merged into vec4s to stay under iOS 26
// Impeller's ~30 Metal-buffer cap. The #define block restores scalar names;
// float offsets are unchanged, so the Dart packing code stays in sync. The
// border shader has no u_lensColor, so u_packA..C sit four floats earlier than
// in the main shader — but their component meaning is identical.

// x=lensWidth  y=lensHeight  z=cornerRadius  w=cornerStyle
//   cornerStyle: 0 = circular, 1 = squircle (full smoothing),
//   2 = continuous (Apple capsule-style). Mirrors liquid_glass.frag.
uniform vec4 u_lensGeom;
// x=magnification  y=distortion  z=distortionThicknessPx
// w=enableBackgroundTransparency
uniform vec4 u_warp;

uniform float u_diagonalFlip;

// Border controls
uniform float u_borderWidth;
uniform float u_borderSoftness;
uniform vec4  u_borderColor;
uniform float u_borderAlpha;
uniform float u_lightIntensity;
uniform vec4  u_lightColor;
uniform vec4  u_shadowColor;
uniform float u_lightDirection;
// x=oneSideLightIntensity  y=chromaticAberration  z=saturation  w=lightMode
uniform vec4 u_packA;
// x=refractionMode  y=refractionType  z=refractionIndex  w=ambientIntensity
uniform vec4 u_packB;
// x=doubleSideLightIntensity  y=borderSaturation  z=borderSolidity  w=borderMode
uniform vec4 u_packC;
// Optical-rim angular spread (higher = highlight wraps further around).
uniform float u_lightSpread;

// Restore the original scalar names (plain float aliases, no swizzle chain).
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

// Capture-region mapping — see liquid_glass.frag. The bound texture
// covers parent rect [u_imageOffset, u_imageOffset + u_imageSize].
// Full-frame = (0,0)/u_resolution (old behavior); region = sub-rect.
uniform vec2 u_imageOffset;
uniform vec2 u_imageSize;

// Deformed size / rest size, from the flex. Must match the main shader's
// value exactly or the rim stops hugging the fill.
uniform vec2 u_shapeScale;

out vec4 frag_color;

#define REFRACTION_SHAPE    0
#define REFRACTION_RADIAL   1
#define REFRACTION_STANDARD 0
#define REFRACTION_OPTICAL  1

vec3 applyChromaticAberration(vec2 uv, float shift) {
    vec3 color = texture(u_texture_input, uv).rgb;
    if (shift < 0.001) return color;

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
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

vec3 sampleAmbientColor(vec2 refractedPx) {
    // Map parent-pixel position into the bound texture's region rect.
    // Full-frame = refractedPx / u_resolution (old behavior).
    vec2 sampleUV = clamp((refractedPx - u_imageOffset) / u_imageSize,
                          vec2(0.001), vec2(0.999));
    // GLES sampler Y-flip — only on engines BEFORE the OpenGLES coordinate
    // unification (post-3.44.0 sets IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED).
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    sampleUV.y = 1.0 - sampleUV.y;
    #endif
    #endif

    vec3 color = applyChromaticAberration(sampleUV, u_chromaticAberration);
    return applySaturation(color, u_saturation);
}

/* ================
   MAIN
   ================ */
void main() {
    vec2 fragPosPx = FlutterFragCoord().xy;
    float invResY  = 1.0 / u_resolution.y;
    vec2  uvNorm   = fragPosPx * invResY;

    vec2 lensHalfSizePx = 0.5 * vec2(u_lensWidth, u_lensHeight);
    vec2 lensCenterPx   = u_touch + lensHalfSizePx;
    vec2 lensCenterNorm = lensCenterPx * invResY;

    // =====================================================
    // Shape distance (only this part changes per shape)
    // =====================================================
    ShapeData shapeData;
    // Rounded rectangle. u_cornerStyle selects the corner SDF
    //   (2 = continuous, 1 = squircle, 0 = circular). Must mirror the main
    //   shader's branch exactly so the rim hugs the same outline as the fill.
    // Same rest-space evaluation as the main shader — see its comment.
    // Pass the geometry through UNTOUCHED when there is no deformation.
    // (p - c)/1 + c is not guaranteed to round-trip to p, so mapping anyway
    // would shift every undeformed lens by an ulp for no effect. A zero
    // uniform (never set) reads as undeformed rather than as a huge scale.
    bool deformed = u_shapeScale.x > 0.0 && u_shapeScale.y > 0.0 &&
                    (u_shapeScale.x != 1.0 || u_shapeScale.y != 1.0);
    vec2 shapeScale = deformed ? max(u_shapeScale, vec2(1e-4)) : vec2(1.0);
    vec2 restHalfPx = deformed ? lensHalfSizePx / shapeScale : lensHalfSizePx;
    vec2 fragRestPx =
        deformed ? lensCenterPx + (fragPosPx - lensCenterPx) / shapeScale : fragPosPx;

    float maxCorner      = min(restHalfPx.x, restHalfPx.y);
    float cornerRadiusPx = min(u_cornerRadius, maxCorner);

    if (u_cornerStyle > 1.5 && cornerRadiusPx > 0.5) {
        // Continuous (Apple capsule-style) corners.
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

    shapeData = shapeToScreen(shapeData, shapeScale);

    // Refraction's depth, in the same px as the thickness it divides by — keep
    // in sync with liquid_glass.frag, whose sample this one has to match.
    float refrDistPx = deformed ? shapeData.orthoDist : shapeData.sdf;

    // =====================================================
    // Border (shared for both shapes)
    // =====================================================
    vec3 ambientCol = vec3(0.0);

    // Soft outer-edge mask. The Skia path got outer AA "for free"
    // from the drawRRect call wrapping the border painter; on
    // Impeller (ImageFilter.shader inside a BackdropFilter) there is
    // no such wrapping draw, so we have to fade the border alpha
    // ourselves over the last screen-space pixel of the shape.
    //
    // 1-pixel constant — fwidth(float) trips up SkSL on some
    // devices, so don't use it.
    float outerAa = 1.0;
    float outerMask = 1.0 - smoothstep(-outerAa * 0.5, outerAa * 0.5,
                                       shapeData.orthoDist);

    // Cheap early-out for fragments well past the AA band.
    if (shapeData.orthoDist > outerAa) {
        frag_color = vec4(0.0);
        return;
    }

    vec2 magPx = applyLensMagnification(
        fragPosPx,
        lensCenterPx,
        u_magnification
    );
    float distAbsPx = abs(shapeData.orthoDist);
    float zoneLimit = u_distortionThicknessPx;
    float zoneMask = step(distAbsPx, zoneLimit);

    ambientCol = vec3(0.0);
    if (zoneMask < 0.5) {
        if (u_enableBackgroundTransparency <= 0.5) {
            ambientCol = sampleAmbientColor(magPx);
        }
    } else {
        float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);
        vec2 refrPx;

        if (u_refractionType == REFRACTION_OPTICAL) {
            // Match the main shader's optical sample for both geometries.
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
                refrDistPx,
                u_distortionThicknessPx,
                u_refractionIndex,
                u_distortion,
                zoneT
            );
        } else if (u_refractionMode == REFRACTION_SHAPE) {
            // Stable shape refraction (inset-anchor based) — keep in
            // sync with liquid_glass.frag.
            float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
            refrPx = computeShapeRefraction(
                magPx,
                shapeData.normal,
                refrDistPx,
                u_distortionThicknessPx,
                distortionFactor,
                u_magnification,
                u_diagonalFlip,
                zoneT
            );

        } else {
            float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
            refrPx = refractFromAnchorPx(
                magPx,
                lensCenterPx,
                distortionFactor,
                u_magnification,
                u_diagonalFlip,
                zoneT
            );
        }

        ambientCol = sampleAmbientColor(refrPx);
    }

    // The caller already passes the full band width (pre-doubled, and
    // including the optical-mode extra when applicable). After clipping
    // the outer half, the visible inner portion matches the intended
    // width. Kept as a named local for readability.
    float effectiveBorderWidth = u_borderWidth;

    vec4 borderPremul = getSweepBorder(
        uvNorm,
        lensCenterNorm,
        shapeData.orthoDist,
    shapeData.grad,// unified signed-distance value
        effectiveBorderWidth,
        u_borderSoftness,
        u_borderColor,
        u_lightColor,
        u_shadowColor,
        u_lightIntensity,
        u_borderAlpha,
        u_lightDirection, u_oneSideLightIntensity,u_lightMode,
        ambientCol, u_ambientIntensity,
        u_doubleSideLightIntensity,
        u_borderSaturation,
        u_borderSolidity,
        u_lightSpread,
        u_borderMode
    );
    // Apply the soft outer-edge mask so the rounded corners fade
    // out smoothly on Impeller (where there's no surrounding draw
    // call to provide AA).
    frag_color = borderPremul * outerMask;
}
