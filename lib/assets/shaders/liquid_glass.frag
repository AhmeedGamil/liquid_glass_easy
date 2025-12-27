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
uniform float u_oneSideLightIntensity;
uniform float u_chromaticAberration;
uniform float u_saturation;
uniform float u_lightMode;
uniform float u_refractionMode;


out vec4 frag_color;

// ===================================================

#define REFRACTION_SHAPE    0
#define REFRACTION_RADIAL   1

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
    vec2 texScale,
    float shapeMask
){
    vec3 refrColor;

    vec2 sampleUV = clamp(refractedPx * texScale, vec2(0.001), vec2(0.999));
    refrColor = applyChromaticAberration(sampleUV, u_chromaticAberration);
    // Apply saturation BEFORE tinting
    refrColor = applySaturation(refrColor,u_saturation);
    vec4 base = vec4(refrColor * shapeMask, shapeMask);
    // Then apply lens tint
    base.rgb = applyLensTint(base.rgb, shapeMask, u_lensColor, u_borderAlpha);
    return base;
}


float computeShapeMask(float shapeDistPx) {
    float aa = 1.0;

    #ifdef GL_OES_standard_derivatives
        aa = max(fwidth(shapeDistPx), 1.0);
    #endif

    float mask = 1.0 - smoothstep(0.0, aa, shapeDistPx);
    mask *= step(shapeDistPx, 0.0);
    return mask;
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

    // ===============================
    // Shape distance (SDF)
    // ===============================
    float shapeDistPx;
    float shapeMask;
    ShapeData shapeData;

    // --- Compute shape distance depending on type ---
    if (u_shapeType > 0.5) {
        // Superellipse
        float n = max(u_superN, 1.0001);
        shapeData = evaluateShape(fragPx,lensCenterPx, lensHalfSizePx, n,u_shapeType);
        shapeDistPx = shapeData.orthoDist;
    } else {
        // Rounded rectangle
        float maxCorner      = min(u_lensWidth, u_lensHeight) * 0.5;
        float cornerRadiusPx = min(u_cornerRadius, maxCorner);

        shapeData = evaluateShape(
            fragPx,
            lensCenterPx,
            lensHalfSizePx,
            cornerRadiusPx,
            u_shapeType
        );

        shapeDistPx = shapeData.orthoDist;
    }

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

    vec2 magUV=magPx*invResY;
    if (zoneMask < 0.5) {
        // Outside distortion zone
        vec4 base = (u_enableBackgroundTransparency > 0.5)
        ? vec4(0.0)
        : finalSample(magUV, texScale, shapeMask);

        vec4 borderPremul = getSweepBorder(
            uvNorm, lensCenterNorm, shapeData.orthoDist,shapeData.grad,
            u_borderWidth, u_borderSoftness, u_borderColor,
            u_lightColor, u_shadowColor,
            u_lightIntensity, u_borderAlpha, u_lightDirection, u_oneSideLightIntensity,u_lightMode
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

    vec2 refrPx;

    if(u_refractionMode== REFRACTION_SHAPE) {
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
        refrPx = refractFromAnchorPx(
            magPx,
            distortionCenter,
            distortionFactor,
            u_magnification,
            u_diagonalFlip,
            zoneT
        );
    }
    vec2 refrUV = refrPx * invResY;
    // ===============================
    // Final sample & border
    // ===============================
    vec4 base = finalSample(refrUV, texScale, shapeMask);

    vec4 borderPremul = getSweepBorder(
        uvNorm, lensCenterNorm, shapeData.orthoDist,shapeData.grad,
        u_borderWidth, u_borderSoftness, u_borderColor,
        u_lightColor, u_shadowColor,
        u_lightIntensity, u_borderAlpha, u_lightDirection, u_oneSideLightIntensity,u_lightMode
    );

    // ===============================
    // Output composite
    // ===============================
    frag_color = overlayPremul(base, borderPremul);
}