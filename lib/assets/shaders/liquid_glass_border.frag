// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
#include "liquid_glass_border.glsl"
#include "liquid_glass_common.glsl"
#define PI 3.14159265
precision highp float; // or highp float

/* ================
   SHARED UNIFORMS
   ================ */
uniform vec2 u_resolution;
uniform vec2 u_touch;

uniform float u_lensWidth;
uniform float u_lensHeight;
uniform float u_shapeType; // 0 = rounded-rect, 1 = superellipse
uniform float u_cornerRadius;
uniform float u_superN;

// Border controls
uniform float u_borderWidth;
uniform float u_borderSoftness;
uniform vec4  u_borderColor;
uniform float u_borderAlpha;
uniform float u_lightIntensity;
uniform vec4  u_lightColor;
uniform vec4  u_shadowColor;
uniform float u_lightDirection;
uniform float u_oneSideLightIntensity;
uniform float u_lightMode;

out vec4 frag_color;

/* ================
   MAIN
   ================ */
void main() {
    vec2 fragPosPx = FlutterFragCoord().xy;
    float invResY  = 1.0 / u_resolution.y;
    vec2  uvNorm   = fragPosPx * invResY;
    vec2  texScale = u_resolution.y / u_resolution;

    vec2 lensHalfSizePx = 0.5 * vec2(u_lensWidth, u_lensHeight);
    vec2 lensCenterPx   = u_touch + lensHalfSizePx;
    vec2 lensCenterNorm = lensCenterPx * invResY;
    vec2 localPosPx     = fragPosPx - lensCenterPx;

    // =====================================================
    // Shape distance (only this part changes per shape)
    // =====================================================
    ShapeData shapeData;
    if (u_shapeType > 0.5) {
        // Superellipse
        float n = max(u_superN, 1.0001);
        shapeData = evaluateShape(fragPosPx,lensCenterPx, lensHalfSizePx, n,u_shapeType);
    } else {
        // Rounded rectangle
        float maxCorner      = min(u_lensWidth, u_lensHeight) * 0.5;
        float cornerRadiusPx = min(u_cornerRadius, maxCorner);
        shapeData = evaluateShape(
            fragPosPx,
            lensCenterPx,
            lensHalfSizePx,
            cornerRadiusPx,
            u_shapeType
        );
    }

    // =====================================================
    // Border (shared for both shapes)
    // =====================================================
    vec4 borderPremul = getSweepBorder(
        uvNorm,
        lensCenterNorm,
        shapeData.orthoDist,
    shapeData.grad,// unified signed-distance value
        u_borderWidth,
        u_borderSoftness,
        u_borderColor,
        u_lightColor,
        u_shadowColor,
        u_lightIntensity,
        u_borderAlpha,
        u_lightDirection, u_oneSideLightIntensity,u_lightMode
    );
    // output example
    frag_color = borderPremul;
}
