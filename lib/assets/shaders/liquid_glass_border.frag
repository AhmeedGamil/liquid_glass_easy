// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
// Same backend-split gradient method as liquid_glass.frag: derivative on
// Impeller (this entry), analytic on Skia (liquid_glass_border_skia.frag).
// common.glsl must come FIRST: it sets GLASS_FLOAT_PRECISION, and the optical
// rim's Lab conversion needs the highp it selects.
#include "liquid_glass_grad_select.glsl"
#include "liquid_glass_common.glsl"
#include "liquid_glass_border.glsl"
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
// float offsets are unchanged, so the Dart packing code stays in sync,
// including u_lensColor at the main shader's slot: the rim lifts from the
// tinted glass, so this pass needs the tint too.

// x=lensWidth  y=lensHeight  z=cornerRadius  w=cornerStyle
//   cornerStyle: 0 = circular, 1 = squircle (full smoothing),
//   2 = continuous (Apple capsule-style). Mirrors liquid_glass.frag.
uniform vec4 u_lensGeom;
// x=magnification  y=refractionIndex  z=refractionWidthPx
// w=dispersion
uniform vec4 u_warp;

// Border controls
// The specular's thickness, in fragment px.
uniform float u_borderWidth;
uniform float u_borderAlpha;
// Each light's own colour, straight alpha: alpha 0 keeps the picked-up
// colour, 1 draws the light in this colour as given.
uniform vec4  u_specularColor;
uniform vec4  u_glowColor;
uniform vec4  u_lensColor;
// The rim's tint: the lens colour.
#define rimTint u_lensColor
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

// Restore the original scalar names (plain float aliases, no swizzle chain).
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

// Capture-region mapping — see liquid_glass.frag. The bound texture
// covers parent rect [u_imageOffset, u_imageOffset + u_imageSize].
// Full-frame = (0,0)/u_resolution (old behavior); region = sub-rect.
uniform vec2 u_imageOffset;
uniform vec2 u_imageSize;

// Deformed size / rest size, from the flex. Must match the main shader's
// value exactly or the rim stops hugging the fill.
uniform vec2 u_shapeScale;

// Lens->shader affine map for ancestor transforms, as in liquid_glass.frag.
// This pass only ever DRAWS in lens space, so it maps on sampling alone.
uniform vec4 u_xformRow;
uniform vec2 u_xformOff;

out vec4 frag_color;


vec3 applyDispersion(vec2 uv, float shift, vec2 texSizePx) {
    vec3 color = texture(u_texture_input, uv).rgb;
    if (shift < DISPERSION_MIN_LOGICAL_PX) return color;

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    // The border pass runs in logical px.
    vec2 offset = dispersionOffsetUv(shift, luma, texSizePx, 1.0);

    float r = texture(u_texture_input, uv + offset).r;
    float g = texture(u_texture_input, uv).g;
    float b = texture(u_texture_input, uv - offset).b;

    return vec3(r, g, b);
}

vec3 applySaturation(vec3 color, float saturation) {
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luminance), color, saturation);
}

vec3 sampleBackdropColor(vec2 refractedPx) {
    // Geometry ran in LENS space under an ancestor transform; the capture
    // lives in shader space, so map the sample position forward.
    bool xformed = any(notEqual(u_xformRow, vec4(1.0, 0.0, 0.0, 1.0))) ||
                   any(notEqual(u_xformOff, vec2(0.0)));
    float det = u_xformRow.x * u_xformRow.w - u_xformRow.y * u_xformRow.z;
    if (xformed && abs(det) > 1e-6) {
        refractedPx = mat2(u_xformRow.x, u_xformRow.z,
                           u_xformRow.y, u_xformRow.w)
                      * refractedPx + u_xformOff;
    }

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

    vec3 color = applyDispersion(sampleUV, u_dispersion, u_imageSize);
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

    shapeData = shapeToScreen(shapeData, shapeScale);

    // Refraction's depth, in the same px as the thickness it divides by — keep
    // in sync with liquid_glass.frag, whose sample this one has to match.
    float refrDistPx = deformed ? shapeData.orthoDist : shapeData.sdf;

    // =====================================================
    // Border (shared for both shapes)
    // =====================================================
    vec3 backdropCol = vec3(0.0);

    // Soft outer-edge mask. The Skia path got outer AA "for free"
    // from the drawRRect call wrapping the border painter; on
    // Impeller (ImageFilter.shader inside a BackdropFilter) there is
    // no such wrapping draw, so we have to fade the border alpha
    // ourselves over the last screen-space pixel of the shape.
    //
    // 1-pixel constant — fwidth(float) trips up SkSL on some
    // devices, so don't use it.
    float outerAa = 1.0;
    // Same inward bias as the main pass's shape mask.
    float outerMask = 1.0 - smoothstep(-outerAa * 0.667, outerAa * 0.333,
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
    float zoneLimit = u_refractionWidthPx;
    float zoneMask = step(distAbsPx, zoneLimit);

    backdropCol = vec3(0.0);
    if (zoneMask < 0.5) {
        backdropCol = sampleBackdropColor(magPx);
    } else {
        float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);
        vec2 refrPx;

        refrPx = computeRefractedPosition(
            magPx, shapeData.normal, refrDistPx,
            u_refractionWidthPx, u_refractionIndex,
            REFRACTION_DEPTH_LOGICAL_PX, zoneT
        );

        backdropCol = sampleBackdropColor(refrPx);
    }

    // The authored width, verbatim — the border expands it into its own
    // band. Kept as a named local for readability.
    float effectiveBorderWidth = u_borderWidth;

    vec4 borderPremul = getBorder(
        shapeData.orthoDist, shapeData.grad,
        rimTint, u_borderAlpha,
        backdropCol,
        effectiveBorderWidth, u_borderSharpness, u_specular, u_specularColor,
        u_glowThickness, u_glow, u_glowColor,
        u_specular2, u_specular2Intensity, u_specular2Color,
        u_lightOpposite.xyz,
        outerAa
    );
    // Apply the soft outer-edge mask so the rounded corners fade
    // out smoothly on Impeller (where there's no surrounding draw
    // call to provide AA).
    frag_color = borderPremul * outerMask;
}
