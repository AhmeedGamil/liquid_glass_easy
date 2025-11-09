// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#ifndef LIQUID_GLASS_HELPER_GLSL
#define LIQUID_GLASS_HELPER_GLSL
#define PI 3.14159265
precision highp float; // or highp float

/* ===========================
   CONSTS / SMALL HELPERS
   =========================== */
const float EPS   = 1e-6;
const float EPS_T = 1e-3;


struct RoundedRectangleData {
    float sdfNorm;   // signed distance in y-normalized units
    vec2  normal;    // normalized gradient (UV space)
};
struct SuperellipseData {
    float sdf;
    vec2 grad;
    float orthoDist;
    vec2 normal;
};

vec2  safe2(vec2 v){ return max(v, vec2(EPS)); }
float safe1(float v){ return max(v, EPS); }

float fastPow(float x, float n) {
    return exp2(n * log2(x));
}

// Rounded rectangle SDF
float roundedRectangleShape(vec2 point, vec2 center, vec2 halfSize, float radius) {
    vec2 q = abs(point - center) - halfSize + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}


// Compute all superellipse info in one go
float superellipseShape(vec2 pLocalPx, vec2 halfSizePx, float n){
    vec2 d = abs(pLocalPx) / safe2(halfSizePx);
    float k = fastPow(fastPow(d.x, n) + fastPow(d.y, n), 1.0 / n);
    float s = max(min(halfSizePx.x, halfSizePx.y), EPS);
    // <0 inside, >0 outside
    return (k - 1.0) * s;
}


SuperellipseData superellipseEvaluateAll(vec2 pLocalPx, vec2 halfSizePx, float n) {
    SuperellipseData d;
    float h = 1.0;

    // --- Central differences
    float fC = superellipseShape(pLocalPx, halfSizePx, n);
    float fX1 = superellipseShape(pLocalPx + vec2(h, 0.0), halfSizePx, n);
    float fX2 = superellipseShape(pLocalPx - vec2(h, 0.0), halfSizePx, n);
    float fY1 = superellipseShape(pLocalPx + vec2(0.0, h), halfSizePx, n);
    float fY2 = superellipseShape(pLocalPx - vec2(0.0, h), halfSizePx, n);

    vec2 grad = 0.5 * vec2(fX1 - fX2, fY1 - fY2);

    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = normalize(grad);
    d.orthoDist = fC / max(length(grad), EPS);
    return d;
}


RoundedRectangleData rrectEvaluateAllUV(vec2 uvNorm, vec2 centerUV, vec2 halfUV, float radiusNorm,float resolutionY ){
    RoundedRectangleData outv;
    float h = 1.0/resolutionY;

    float fC  = roundedRectangleShape(uvNorm, centerUV, halfUV, radiusNorm);
    float fXp = roundedRectangleShape(uvNorm + vec2(h, 0.0), centerUV, halfUV, radiusNorm);
    float fXm = roundedRectangleShape(uvNorm - vec2(h, 0.0), centerUV, halfUV, radiusNorm);
    float fYp = roundedRectangleShape(uvNorm + vec2(0.0, h), centerUV, halfUV, radiusNorm);
    float fYm = roundedRectangleShape(uvNorm - vec2(0.0, h), centerUV, halfUV, radiusNorm);

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm) / max(h, EPS);
    outv.sdfNorm = fC;
    outv.normal  = normalize(grad);
    return outv;
}

// ===================================================
// Compute distortion center for a rectangular / superellipse lens
// ===================================================
vec2 computeDistortionCenter(
    vec2 fragCoordNorm,            // normalized fragment coordinate (0–1 or UV)
    vec2 lensCenterUV,             // lens center (in UV space)
    vec2 lensHalfSize,             // half-size of the lens
    float cornerRadiusForClassification // corner radius for identifying corners
){
    // Offset of fragment from lens center
    vec2 p = fragCoordNorm - lensCenterUV;
    vec2 a = abs(p);

    // Inner rectangle region used to classify corners/edges
    vec2 inner = lensHalfSize - vec2(cornerRadiusForClassification);

    bool inCorner         = (a.x > inner.x) && (a.y > inner.y);
    bool onVerticalEdge   = (a.x > inner.x) && (a.y <= inner.y);
    bool onHorizontalEdge = (a.y > inner.y) && (a.x <= inner.x);

    vec2 distortionCenter;


    if (inCorner) {
        // --- Corner: snap to inner corner point (quadrant sign applied)
        vec2 sgn = sign(p);
        distortionCenter = lensCenterUV + sgn * inner;
    }
    else if (onVerticalEdge) {
        // --- Vertical edge: keep y, snap x to edge
        float edgeX = lensCenterUV.x + sign(p.x) * inner.x;
        distortionCenter = vec2(edgeX, fragCoordNorm.y);
    }
    else if (onHorizontalEdge) {
        // --- Horizontal edge: keep x, snap y to edge
        float edgeY = lensCenterUV.y + sign(p.y) * inner.y;
        distortionCenter = vec2(fragCoordNorm.x, edgeY);
    }
    else {
        // --- Inside center region: use lens center directly
        distortionCenter = lensCenterUV;
    }

    return distortionCenter;
}


// ===================================================
// Compute refracted + diagonally flipped coordinates
// ===================================================
vec2 computeRefractedUV(
    vec2 fragCoordNorm,        // current fragment normalized coordinate
    vec2 distortionCenter,     // center point of distortion
    float distortionFactor,    // computed distortion strength
    float magnification,       // u_magnification
    float diagonalFlip,        // u_diagonalFlip (0..1)
    float edgeProgressAdjusted // normalized edge progress (0=center → 1=edge)
){
    // --- Local position relative to distortion center
    vec2 localPos = fragCoordNorm - distortionCenter;

    // --- Basic refraction (magnification)
    float denom = max(distortionFactor * magnification, 1e-6);
    vec2 refractedCoords = distortionCenter + localPos / denom;

    // --- Diagonal swap (mirrored across both axes)
    vec2 swappedCoords;
    swappedCoords.x = distortionCenter.x - sign(localPos.x) * abs(localPos.x) / denom;
    swappedCoords.y = distortionCenter.y - sign(localPos.y) * abs(localPos.y) / denom;

    // --- Smooth diagonal flip blend
    float diagonalFlipClamped = 1.0 - diagonalFlip;
    float swapFactor = smoothstep(diagonalFlipClamped, 1.0, edgeProgressAdjusted);

    // --- Final blended coordinate
    vec2 finalCoords = mix(refractedCoords, swappedCoords, swapFactor);

    return finalCoords;
}




// orthogonal (signed) distance using gradient magnitude for scale
float superellipseOrthoDist_px(vec2 pLocalPx, vec2 halfSizePx, float n){
    float h = 1.0;
    float f  = superellipseShape(pLocalPx, halfSizePx, n);
    float fx = superellipseShape(pLocalPx + vec2(h,0.0), halfSizePx, n) - superellipseShape(pLocalPx - vec2(h,0.0), halfSizePx, n);
    float fy = superellipseShape(pLocalPx + vec2(0.0,h), halfSizePx, n) - superellipseShape(pLocalPx - vec2(0.0,h), halfSizePx, n);
    vec2  g  = vec2(fx, fy) * 0.5;
    return f / max(length(g), EPS);
}



// ===================================================
// Final texture sampling after refraction
// ===================================================
// ADD this uniform near your other uniforms:

// --- helper: safe clamp UV
vec3 applyLensTint(vec3 baseRgb, float shapeMask, vec4 lensColor,float borderAlpha) {
    // Only tint inside the lens shape
    if (lensColor.a > 0.001 && shapeMask > 0.001) {
        // Physically-correct soft tint blend
        return mix(baseRgb, lensColor.rgb, lensColor.a * borderAlpha * shapeMask);
    }
    return baseRgb;
}


vec2 closestPointOnInsetRoundedRectangleUV(vec2 uvNorm,
                                vec2 normalUV,
                                float sdfNorm,
                                float insetNorm){
    // Move along the normal so that we land on f == -insetNorm (inset curve)
    return uvNorm - normalUV * (sdfNorm + insetNorm);
}

// Returns the **closest point** on an *inset* superellipse (offset inwards by `insetPx`)
// using the SDF value and normal (one-shot projection).
vec2 closestPointOnInsetSuperellipsePx(vec2 pLocalPx,vec2 superellipseNormal,float superellipseSDF, vec2 halfSizePx, float insetPx){
    // Move along the normal so that we land on f == -insetPx (i.e., the inset curve)
    return pLocalPx - superellipseNormal * (superellipseSDF + insetPx);
}

// heuristic: corners on boxier superellipses want a little larger inset so the anchor
// sits on a visually nice "inner curve"
float superellipseCornerBandPx(vec2 halfSizePx, float n, float thicknessPx){
    float boxiness = clamp((n - 2.0) / 6.0, 0.0, 1.0); // n≈2 => round; n→∞ => boxy
    float geomBand = min(halfSizePx.x, halfSizePx.y) * (0.25 * boxiness);
    return max(thicknessPx, geomBand * 0.6);
}
// =============================
// Distortion helper
// =============================
float computeDistortionFactor(float u_distortion, float zoneT) {
    // clamp distortion input
    float distortionClamped = clamp(u_distortion, 0.0, 1.0);
    float distortionStrength = distortionClamped * 20.0;


        // --- stronger curve (outer edge emphasis)
    float edgeFactorStrongCurve = pow(zoneT, distortionStrength) * 0.5;
    float distortionStrong = 1.0 + distortionStrength * edgeFactorStrongCurve;

    // --- softer curve (inner falloff)
    float edgeFactorSoftCurve = pow(zoneT, 5.0) * 0.08;
    float distortionSoft = 1.0 + distortionStrength * edgeFactorSoftCurve;

    // --- combined result
    float distortionFactor = distortionStrong + (distortionSoft - 1.0);
    return distortionFactor;
}

// Compute refracted position (in PIXELS) for rounded-rect using the SAME model as superellipse
vec2 computeRefractedPositionRoundedRectPx(
    vec2 fragPx,              // current fragment position (px)
    vec2 uvNorm,              // current fragment (y-normalized UV)
    vec2 lensCenterPx,        // lens center (px)
    vec2 lensCenterUV,        // lens center (UV)
    vec2 lensHalfUV,          // half-size (UV)
    float cornerRadiusNorm,   // corner radius (UV)
    float insetNorm,            // inset thickness in px (use band thickness)
    float distortionFactor,   // precomputed distortion
    float u_magnification,    // magnification
    float u_diagonalFlip,     // 0..1
    float zoneT,
float resolutionY// 0 center → 1 edge
){
    // 1) SDF + normal in UV
    RoundedRectangleData roundedRectangleData = rrectEvaluateAllUV(uvNorm, lensCenterUV, lensHalfUV, cornerRadiusNorm,resolutionY);

    // 2) Anchor on inset curve in UV → then to PX
    vec2 anchorUV = closestPointOnInsetRoundedRectangleUV(uvNorm, roundedRectangleData.normal, roundedRectangleData.sdfNorm, insetNorm);
    vec2 anchorPx = anchorUV * resolutionY; // since uvNorm = fragPx * (1/ResY)

    // 3) Refract from anchor with SAME scale as superellipse
    vec2 vFromAnchor = fragPx - anchorPx;
    float scale = max(distortionFactor * u_magnification, EPS);
    vec2 refrPx = anchorPx + vFromAnchor / scale;

    // 4) Optional diagonal flip (mirror around anchor) blended by zoneT
    float flipT = smoothstep(1.0 - u_diagonalFlip, 1.0, zoneT);
    vec2 flipped = anchorPx - (refrPx - anchorPx);
    refrPx = mix(refrPx, flipped, flipT);

    return refrPx;
}

// =============================
// Compute refracted position on superellipse
// =============================
vec2 computeRefractedPositionPx(
    vec2 fragPx,              // current fragment position
    vec2 pL,
    vec2 superellipseNormal,// fragment local position (fragPx - lensCenterPx)
    float superellipseSDF,
    vec2 lensCenterPx,        // lens center in pixels
    vec2 lensHalfPx,          // half size of lens
    float cornerBand,         // inset band thickness
    float distortionFactor,   // precomputed distortion factor
    float u_magnification,    // magnification strength
    float u_diagonalFlip,     // flip factor 0..1
    float zoneT               // normalized distance to edge (0 center → 1 edge)
){
    // 1 Find anchor point on the inset curve
    vec2 anchorLocalPx = closestPointOnInsetSuperellipsePx(pL, superellipseNormal,superellipseSDF, lensHalfPx, cornerBand);
    vec2 anchorPx      = lensCenterPx + anchorLocalPx;

    // 2 Refract vector from anchor (acts like a hinge)
    vec2 vFromAnchor = fragPx - anchorPx;
    float scale = max(distortionFactor * u_magnification, EPS);
    vec2 refrPx = anchorPx + vFromAnchor / scale;

    // 3 Optional diagonal flip (mirror around anchor)
    float flipT = smoothstep(1.0 - u_diagonalFlip, 1.0, zoneT);
    vec2 flipped = anchorPx - (refrPx - anchorPx);
    refrPx = mix(refrPx, flipped, flipT);

    return refrPx;
}
#endif
