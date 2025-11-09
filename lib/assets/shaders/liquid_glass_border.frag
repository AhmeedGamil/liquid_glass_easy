// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
#include "liquid_glass_border.glsl"
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
uniform float u_lightEffectIntensity;

out vec4 frag_color;

/* ================
   HELPERS
   ================ */
const float EPS = 1e-6;
vec2 safe2(vec2 v){ return max(v, vec2(EPS)); }

float fastPow(float x, float n) {
    return exp2(n * log2(x));
}

float superellipseShape(vec2 pLocalPx, vec2 halfSizePx, float n){
    vec2 d = abs(pLocalPx) / safe2(halfSizePx);
    float k = fastPow(fastPow(d.x, n) + fastPow(d.y, n), 1.0 / n);
    float s = max(min(halfSizePx.x, halfSizePx.y), EPS);
    return (k - 1.0) * s;
}

// Pixel-true orthogonal signed distance from the superellipse edge
float superellipseOrthoDist_px(vec2 pLocalPx, vec2 halfSizePx, float n){
    float h  = 1.0;
    float f  = superellipseShape(pLocalPx, halfSizePx, n);
    float fx = superellipseShape(pLocalPx + vec2(h, 0.0), halfSizePx, n)
    - superellipseShape(pLocalPx - vec2(h, 0.0), halfSizePx, n);
    float fy = superellipseShape(pLocalPx + vec2(0.0, h), halfSizePx, n)
    - superellipseShape(pLocalPx - vec2(0.0, h), halfSizePx, n);
    vec2  g  = vec2(fx, fy) * 0.5;
    return f / max(length(g), EPS);
}


float roundedRectangleShape(vec2 point, vec2 center, vec2 halfSize, float radius) {
    vec2 q = abs(point - center) - halfSize + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}


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
    // 🌀 Shape distance (only this part changes per shape)
    // =====================================================
    float shapeDistPx = (u_shapeType < 0.5)
    ? roundedRectangleShape(
        uvNorm, lensCenterNorm,
        lensHalfSizePx / u_resolution.y,
        min(u_cornerRadius, min(u_lensWidth, u_lensHeight) * 0.5)/ u_resolution.y
    ) * u_resolution.y
    : superellipseOrthoDist_px(localPosPx, lensHalfSizePx, max(u_superN, 1.0001));


    // =====================================================
    // Border (shared for both shapes)
    // =====================================================
    vec4 borderPremul = getSweepBorder(
        uvNorm,
        lensCenterNorm,
        shapeDistPx,                // unified signed-distance value
        u_borderWidth,
        u_borderSoftness,
        u_borderColor,
        u_lightColor,
        u_shadowColor,
        u_lightIntensity,
        u_borderAlpha,
        u_lightDirection,u_lightEffectIntensity
    );

    // output example
    frag_color = borderPremul;
}
