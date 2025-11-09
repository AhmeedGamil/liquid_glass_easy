// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
#include "liquid_glass_common.glsl"
#include "liquid_glass_border.glsl"
#define PI 3.14159265

precision highp float;

// =====================================================
// Uniforms
// =====================================================
uniform vec2  u_resolution;
uniform vec2  u_touch;
uniform sampler2D u_texture_input;
uniform float u_lensWidth;
uniform float u_lensHeight;
uniform float u_shapeType;
uniform float u_cornerRadius;
uniform float u_superN;

uniform float u_magnification;
uniform float u_distortion;
uniform float u_distortionThicknessPx;
uniform float u_enableBackgroundTransparency;
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
uniform float u_highDistoritonOnCurves;
uniform float u_lightEffectIntensity;


out vec4 frag_color;

#define PIXEL_TO_NORM(px) ((px) / u_resolution.y)

// ===================================================
// Final texture sampling after refraction
// ===================================================
vec4 finalSample(
    vec2 refractedPx,    // refracted position in pixels
    vec2 texScale,       // texture coordinate scale
    float shapeMask      // mask (usually 0..1)
){
    // Convert refracted pixel position to normalized texture UV
    vec2 sampleUV = clamp((refractedPx) * texScale, vec2(0.001), vec2(0.999));

    // Sample the color from the texture
    vec3 refrColor = texture(u_texture_input, sampleUV).rgb;

    // Apply the shape mask for transparency/alpha control
    vec4 base = vec4(refrColor * shapeMask, shapeMask);

    base.rgb = applyLensTint(base.rgb,shapeMask,u_lensColor,u_borderAlpha);

    return base;
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
    vec2 texScale = u_resolution.y / u_resolution;

    // ===============================
    // Lens geometry
    // ===============================
    vec2 lensHalfSizePx = 0.5 * vec2(u_lensWidth, u_lensHeight);
    vec2 lensCenterPx   = u_touch + lensHalfSizePx;
    vec2 lensCenterNorm = lensCenterPx * invResY;
    vec2 localPosPx     = fragPx - lensCenterPx;

    // ===============================
    // Shape distance (SDF)
    // ===============================
    float shapeDistPx;
    float shapeMask;
    SuperellipseData superellipseData;

    if (u_shapeType > 0.5) {
        // Superellipse mode
        float n = max(u_superN, 1.0001);
        superellipseData= superellipseEvaluateAll(localPosPx, lensHalfSizePx, n);

        shapeDistPx = superellipseData.orthoDist;

        float aa = 1.0;
        #ifdef GL_OES_standard_derivatives
        aa = max(fwidth(shapeDistPx), 1.0);
        #endif

        shapeMask = 1.0 - smoothstep(0.0, aa, shapeDistPx);
        shapeMask *= step(shapeDistPx, 0.0);
    } else {
        // RoundedRect mode
        vec2 lensHalfUV  = lensHalfSizePx / u_resolution.y;
        float cornerNorm = PIXEL_TO_NORM(min(u_cornerRadius, min(u_lensWidth, u_lensHeight) * 0.5));
        float roundedRectDist = roundedRectangleShape(uvNorm, lensCenterNorm, lensHalfUV, cornerNorm);
        shapeDistPx = roundedRectDist * u_resolution.y;
        shapeMask   = smoothstep(PIXEL_TO_NORM(1.5), 0.0, roundedRectDist);
    }

    // ===============================
    // Distortion band setup
    // ===============================
    float distAbsPx = abs(shapeDistPx);
    float zoneLimit = u_distortionThicknessPx;
    float zoneMask  = step(distAbsPx, zoneLimit);

    if (zoneMask < 0.5) {
        // Outside distortion zone
        vec4 base = (u_enableBackgroundTransparency > 0.5)
        ? vec4(0.0)
        : finalSample(uvNorm, texScale, shapeMask);

        vec4 borderPremul = getSweepBorder(
            uvNorm, lensCenterNorm, shapeDistPx,
            u_borderWidth, u_borderSoftness, u_borderColor,
            u_lightColor, u_shadowColor,
            u_lightIntensity, u_borderAlpha, u_lightDirection,u_lightEffectIntensity
        );

        frag_color = overlayPremul(base, borderPremul);
        return;
    }

    // ===============================
    // Distortion zone logic
    // ===============================
    float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);
    float distortionFactor = computeDistortionFactor(u_distortion, zoneT);

    // ===============================
    // Refracted position
    // ===============================
    vec2 refrUV;

    if (u_shapeType > 0.5) {
        // --- Superellipse refraction
        float n = max(u_superN, 1.0001);
        float cornerBand = superellipseCornerBandPx(lensHalfSizePx, n, u_distortionThicknessPx);

        vec2 refrPx = computeRefractedPositionPx(
            fragPx,
            localPosPx,
             superellipseData.normal,
            superellipseData.sdf,
            lensCenterPx,
            lensHalfSizePx,
            cornerBand,
            distortionFactor,
            u_magnification,
            u_diagonalFlip,
            zoneT
        );

        refrUV = refrPx * invResY;
    } else {
        // --- Shared setup ---
        float maxCorner = min(u_lensWidth, u_lensHeight) * 0.5;
        float cornerRadiusClamped = min(u_cornerRadius, maxCorner);
        float cornerRadiusNorm = PIXEL_TO_NORM(cornerRadiusClamped);
        float thicknessNorm = PIXEL_TO_NORM(u_distortionThicknessPx);
        vec2 lensHalfUV = lensHalfSizePx / u_resolution.y;

        // --- Conditional logic ---
        if (u_highDistoritonOnCurves > 0.5) {
            float cornerRadiusForClassification = max(cornerRadiusNorm, thicknessNorm);

            vec2 distortionCenter = computeDistortionCenter(
                uvNorm,
                lensCenterNorm,
                lensHalfUV,
                cornerRadiusForClassification
            );

            refrUV = computeRefractedUV(
                uvNorm,
                distortionCenter,
                distortionFactor,
                u_magnification,
                u_diagonalFlip,
                zoneT
            );

        } else {
            vec2 refrPx = computeRefractedPositionRoundedRectPx(
                fragPx,
                uvNorm,
                lensCenterPx,
                lensCenterNorm,
                lensHalfUV,
                cornerRadiusNorm,
                thicknessNorm,
                distortionFactor,
                u_magnification,
                u_diagonalFlip,
                zoneT,
                u_resolution.y
            );
            refrUV = refrPx * invResY;
        }
    }

    // ===============================
    // Final sample & border
    // ===============================
    vec4 base = finalSample(refrUV, texScale, shapeMask);

    vec4 borderPremul = getSweepBorder(
        uvNorm, lensCenterNorm, shapeDistPx,
        u_borderWidth, u_borderSoftness, u_borderColor,
        u_lightColor, u_shadowColor,
        u_lightIntensity, u_borderAlpha, u_lightDirection,u_lightEffectIntensity
    );

    // ===============================
    // Output composite
    // ===============================
    frag_color = overlayPremul(base, borderPremul);
}
