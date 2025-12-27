// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#ifndef LIQUID_GLASS_HELPER_GLSL
#define LIQUID_GLASS_HELPER_GLSL

precision highp float;
#define PI 3.14159265

/* ===========================
   CONSTS / SMALL HELPERS
   =========================== */
const float EPS   = 1e-6;
const float EPS_T = 1e-3;

vec2  safe2(vec2 v){ return max(v, vec2(EPS)); }
float safe1(float v){ return max(v, EPS); }

float fastPow(float x, float n){ return exp2(n * log2(x)); }

/* ===========================
   SHAPE DATA
   =========================== */
struct ShapeData {
    float sdf;
    vec2  grad;
    vec2  normal;
    float orthoDist;
};

/* ===========================
   ROUNDED RECTANGLE SDF
   =========================== */
float roundedRectangleShape(vec2 p, vec2 c, vec2 h, float r){
    vec2 q = abs(p - c) - h + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

/* ===========================
   SUPEREllipse SDF
   =========================== */
float superellipseShape(vec2 p, vec2 c, vec2 hs, float n){
    vec2 d = abs(p - c) / safe2(hs);
    float k = fastPow(fastPow(d.x,n) + fastPow(d.y,n), 1.0/n);
    float s = max(min(hs.x,hs.y), EPS);
    return (k - 1.0) * s;
}

/* ===========================
   SHARED: Evaluate SDF + gradient
   =========================== */
ShapeData evaluateShape(
    vec2 fragPx,
    vec2 centerPx,
    vec2 halfSizePx,
    float param,
    float shapeType            // 0 = rrect, 1 = superellipse
){
    float h = 1.0;

    float fC;
    float fXp;
    float fXm;
    float fYp;
    float fYm;

    if (shapeType > 0.5) {
        fC  = superellipseShape(fragPx,               centerPx, halfSizePx, param);
        fXp = superellipseShape(fragPx + vec2(h,0.0), centerPx, halfSizePx, param);
        fXm = superellipseShape(fragPx - vec2(h,0.0), centerPx, halfSizePx, param);
        fYp = superellipseShape(fragPx + vec2(0.0,h), centerPx, halfSizePx, param);
        fYm = superellipseShape(fragPx - vec2(0.0,h), centerPx, halfSizePx, param);
    }
    else {
        fC  = roundedRectangleShape(fragPx,                  centerPx, halfSizePx, param);
        fXp = roundedRectangleShape(fragPx + vec2(h,0.0),    centerPx, halfSizePx, param);
        fXm = roundedRectangleShape(fragPx - vec2(h,0.0),    centerPx, halfSizePx, param);
        fYp = roundedRectangleShape(fragPx + vec2(0.0,h),    centerPx, halfSizePx, param);
        fYm = roundedRectangleShape(fragPx - vec2(0.0,h),    centerPx, halfSizePx, param);
    }

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm);
    float gL  = max(length(grad), EPS);

    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;

    return d;
}

/* ===========================
   SHARED CORE: REFRACTION FROM ANCHOR
   =========================== */
vec2 refractFromAnchorPx(
    vec2 frag,
    vec2 anchor,
    float df,
    float mag,
    float flip,
    float t
){
    vec2 v = frag - anchor;
    float s = max(df, EPS);
    vec2 refr = anchor + v / s;

    float k = smoothstep(1.0 - flip, 1.0, t);
    vec2 flipped = anchor - (refr - anchor);

    return mix(refr, flipped, k);
}

/* ===========================
   Unified Anchor Helper
   =========================== */
vec2 computeInsetAnchor(vec2 fragPx, vec2 normal, float sdf, float insetPx){
    return fragPx - normal * (sdf + insetPx);
}

/* ===========================
   DISTORTION FACTOR
   =========================== */
float computeDistortionFactor(float u_distortion, float t){
    float d = clamp(u_distortion,0.0,1.0) * 100.0;
    return 1.0 + d * pow(t, d);
}
//float computeDistortionFactor(float u_distortion, float zoneT) {
//    // clamp distortion input
//    float distortionClamped = clamp(u_distortion, 0.0, 1.0);
//    float distortionStrength = distortionClamped * 100.0;
//
//
//    // --- stronger curve (outer edge emphasis)
//    //float edgeFactorStrongCurve = pow(zoneT, distortionStrength) * 0.5;
//    float edgeFactorStrongCurve = pow(zoneT, distortionStrength);
//
//    float distortionStrong = 1.0 + distortionStrength * edgeFactorStrongCurve;
//
//    // --- softer curve (inner falloff)
//    float edgeFactorSoftCurve = pow(zoneT, 5.0) * 0.08;
//    float distortionSoft = 1.0 + distortionStrength * edgeFactorSoftCurve;
//
//    // --- combined result
//    float distortionFactor = distortionStrong + (distortionSoft - 1.0);
//    //float distortionFactor = distortionStrong;
//
//    return distortionFactor;
//}

/* ===========================
   FINAL UNIFIED REFRACTION (PX)
   Works for rounded rect AND superellipse
   =========================== */
vec2 computeShapeRefraction(
    vec2 fragPx,
    vec2 normal,
    float sdf,
    float insetPx,
    float distortionFactor,
    float magnification,
    float diagonalFlip,
    float zoneT
){
    vec2 anchor = computeInsetAnchor(fragPx, normal, sdf, insetPx);
    return refractFromAnchorPx(
        fragPx,
        anchor,
        distortionFactor,
        magnification,
        diagonalFlip,
        zoneT
    );
}

vec2 applyLensMagnification(
    vec2 fragPx,
    vec2 lensCenterPx,
    float magnification
){
    float m = max(magnification, 0.001);
    return lensCenterPx + (fragPx - lensCenterPx) / m;
}

/* ===========================
   TINT
   =========================== */
vec3 applyLensTint(vec3 base, float mask, vec4 color, float borderAlpha){
    return (color.a > 0.001 && mask > 0.001)
        ? mix(base, color.rgb, color.a * borderAlpha * mask)
        : base;
}

#endif
