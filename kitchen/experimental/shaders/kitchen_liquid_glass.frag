// -----------------------------------------------------------------------------
// Kitchen liquid glass — experimental, Impeller-only.
//
// Up to FOUR rounded-rect lobes fuse into one silhouette with a polynomial
// smooth-union, and the merged surface refracts the live backdrop with a
// thickness/IOR model, per-channel dispersion, a Fresnel rim and a directional
// glare. Every knob is a uniform so a tuning panel can drive it live.
//
// Coordinate space: FlutterFragCoord() is FULL-SCREEN PHYSICAL px under
// BackdropFilter(ImageFilter.shader(...)), so every geometry uniform is packed
// in that same space. Distances stay in physical px and convert to logical
// points only where the optical model is defined in points, which keeps the
// look independent of device pixel ratio.
// -----------------------------------------------------------------------------
#include <flutter/runtime_effect.glsl>

precision highp float;

// Every uniform is a vec4 so the float packing stays 16-byte aligned on every
// backend; the defines below restore readable scalar names.
uniform vec4 uFrame;    // xy = backdrop size px, zw = blob centre px
uniform sampler2D uTexture;

// Lobes: xy = top-left px, zw = size px. Inactive lobes carry zero size.
uniform vec4 uRect0;
uniform vec4 uRect1;
uniform vec4 uRect2;
uniform vec4 uRect3;

uniform vec4 uShapeA;   // x=lobeCount y=cornerRadiusPx z=cornerExponent w=mergePx
uniform vec4 uTint;     // rgba material tint
uniform vec4 uGlassA;   // x=thicknessPt y=refractiveIndex z=dispersion w=magnification
uniform vec4 uFresnel;  // x=rangePt y=intensity z=sharpness w=edgeGain
uniform vec4 uGlareA;   // x=rangePt y=convergence z=oppositeBias w=intensity
uniform vec4 uGlareB;   // x=sharpness y=angleOffset z=blurPx w=devicePixelRatio
uniform vec4 uImage;    // xy = texture rect origin px, zw = texture rect size px
uniform vec4 uMisc;     // x=aaPx y=debugMode z/w unused

out vec4 fragColor;

#define PI 3.141592653589793

#define uResolution      uFrame.xy
#define uBlobCentre      uFrame.zw
#define uLobeCount       uShapeA.x
#define uCornerRadius    uShapeA.y
#define uCornerExponent  uShapeA.z
#define uMergePx         uShapeA.w
#define uThickness       uGlassA.x
#define uRefractiveIndex uGlassA.y
#define uDispersion      uGlassA.z
#define uMagnification   uGlassA.w
#define uFresnelRange    uFresnel.x
#define uFresnelStrength uFresnel.y
#define uFresnelSharp    uFresnel.z
#define uEdgeGain        uFresnel.w
#define uGlareRange      uGlareA.x
#define uGlareConverge   uGlareA.y
#define uGlareBias       uGlareA.z
#define uGlareStrength   uGlareA.w
#define uGlareSharp      uGlareB.x
#define uGlareOffset     uGlareB.y
#define uBlurPx          uGlareB.z
#define uScale           uGlareB.w
#define uAaPx            uMisc.x
#define uDebugMode       uMisc.y

// Per-channel refractive offsets: red bends least, blue most.
const float kIndexRed = -0.02;
const float kIndexBlue = 0.02;

// The optics express the edge shift in a normalised space; this constant
// converts that shift back into logical points.
const float kShiftToPoints = 70.7106781;

// =============================================================================
// Signed distance field
// =============================================================================

// Superellipse corner: exponent 2 is a circle, higher values square it off.
float superellipseCorner(vec2 p, float radius, float exponent) {
    p = max(abs(p), vec2(1e-5));
    float v = pow(pow(p.x, exponent) + pow(p.y, exponent), 1.0 / exponent);
    return v - radius;
}

// Rounded rect with superellipse corners. rect = (x, y, w, h) in px.
float roundedRectSDF(vec2 p, vec4 rect) {
    vec2 halfSize = rect.zw * 0.5;
    vec2 q = p - (rect.xy + halfSize);
    float r = min(uCornerRadius, min(halfSize.x, halfSize.y));
    vec2 edge = abs(q) - halfSize;
    if (edge.x > -r && edge.y > -r) {
        vec2 centre = sign(q) * (halfSize - vec2(r));
        return superellipseCorner(q - centre, r, uCornerExponent);
    }
    return min(max(edge.x, edge.y), 0.0) + length(max(edge, 0.0));
}

// Polynomial smooth union — the bridge that lets neighbouring lobes flow.
float smoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Merged field of every active lobe, signed, in physical px.
float sceneSDF(vec2 p) {
    float k = max(uMergePx, 0.001);
    float d = roundedRectSDF(p, uRect0);
    if (uLobeCount > 1.5) d = smoothUnion(d, roundedRectSDF(p, uRect1), k);
    if (uLobeCount > 2.5) d = smoothUnion(d, roundedRectSDF(p, uRect2), k);
    if (uLobeCount > 3.5) d = smoothUnion(d, roundedRectSDF(p, uRect3), k);
    return d;
}

// Central-difference gradient, one-pixel step: unit length on the field, and it
// follows the smooth-union bridge where a per-lobe analytic normal would not.
vec2 sceneGradient(vec2 p) {
    const float e = 1.0;
    return vec2(
        sceneSDF(p + vec2(e, 0.0)) - sceneSDF(p - vec2(e, 0.0)),
        sceneSDF(p + vec2(0.0, e)) - sceneSDF(p - vec2(0.0, e))
    ) / (2.0 * e);
}

// =============================================================================
// Backdrop sampling
// =============================================================================

vec3 sampleBackdrop(vec2 px) {
    vec2 uv = clamp((px - uImage.xy) / uImage.zw, vec2(0.001), vec2(0.999));
    // GLES samplers were Y-flipped before the engine unified the convention.
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    uv.y = 1.0 - uv.y;
    #endif
    #endif
    return texture(uTexture, uv).rgb;
}

// Nine-tap golden-angle spiral: a cheap frost on the sampled backdrop only, so
// the rim and glare drawn on top of it stay sharp.
vec3 sampleSoft(vec2 px) {
    if (uBlurPx <= 0.0) return sampleBackdrop(px);
    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 9; ++i) {
        float fi = float(i) + 0.5;
        float t = fi / 9.0;
        float radius = uBlurPx * sqrt(t);
        float angle = fi * 2.39996323;
        float w = exp(-1.8 * t);
        acc += sampleBackdrop(px + vec2(cos(angle), sin(angle)) * radius) * w;
        wsum += w;
    }
    return acc / wsum;
}

// Prismatic fringe: each channel walks a slightly different refracted distance.
vec3 sampleDispersed(vec2 basePx, vec2 offsetPx, float dispersion) {
    if (dispersion <= 0.0) return sampleSoft(basePx + offsetPx);
    float fr = 1.0 - kIndexRed * dispersion;
    float fb = 1.0 - kIndexBlue * dispersion;
    return vec3(
        sampleSoft(basePx + offsetPx * fr).r,
        sampleSoft(basePx + offsetPx).g,
        sampleSoft(basePx + offsetPx * fb).b
    );
}

// =============================================================================
// Perceptual colour (LCH) — highlights gain lightness without washing to grey
// =============================================================================

const vec3 kWhite = vec3(0.95045592705, 1.0, 1.08905775076);
const mat3 kRgbToXyz = mat3(
    vec3(0.4124, 0.3576, 0.1805),
    vec3(0.2126, 0.7152, 0.0722),
    vec3(0.0193, 0.1192, 0.9505)
);
const mat3 kXyzToRgb = mat3(
    vec3( 3.2406255, -1.537208 , -0.4986286),
    vec3(-0.9689307,  1.8757561,  0.0415175),
    vec3( 0.0557101, -0.2040211,  1.0569959)
);

float toLinear(float c) {
    return c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92;
}

float toGamma(float c) {
    return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(max(c, 0.0), 0.4166666667) - 0.055;
}

float labF(float t) {
    return t > 0.00885645167 ? pow(t, 1.0 / 3.0) : 7.78703703704 * t + 0.13793103448;
}

float labFInv(float t) {
    return t > 0.206897 ? t * t * t : 0.12841854934 * (t - 0.137931034);
}

vec3 srgbToLch(vec3 c) {
    vec3 lin = vec3(toLinear(c.r), toLinear(c.g), toLinear(c.b));
    vec3 xyz = (lin * kRgbToXyz) / kWhite;
    vec3 f = vec3(labF(xyz.x), labF(xyz.y), labF(xyz.z));
    vec3 lab = vec3(116.0 * f.y - 16.0, 500.0 * (f.x - f.y), 200.0 * (f.y - f.z));
    return vec3(lab.x, length(lab.yz), atan(lab.z, lab.y) * (180.0 / PI));
}

vec3 lchToSrgb(vec3 lch) {
    float hue = lch.z * (PI / 180.0);
    vec3 lab = vec3(lch.x, lch.y * cos(hue), lch.y * sin(hue));
    float y = (lab.x + 16.0) / 116.0;
    vec3 xyz = kWhite * vec3(
        labFInv(y + lab.y / 500.0),
        labFInv(y),
        labFInv(y - lab.z / 200.0)
    );
    vec3 lin = xyz * kXyzToRgb;
    return clamp(vec3(toGamma(lin.r), toGamma(lin.g), toGamma(lin.b)), 0.0, 1.0);
}

// Angle of a vector in [0, 2PI), y-down screen space.
float vectorAngle(vec2 v) {
    float a = atan(v.y, v.x);
    return a < 0.0 ? a + 2.0 * PI : a;
}

vec3 hsvToRgb(vec3 hsv) {
    vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(hsv.xxx + k.xyz) * 6.0 - k.www);
    return hsv.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), hsv.y);
}

// =============================================================================
// Fragment
// =============================================================================

void main() {
    vec2 fragPx = FlutterFragCoord().xy;
    float dist = sceneSDF(fragPx);
    float aa = max(uAaPx, 0.5);

    // Outside the silhouette the pass must be a no-op: zero premultiplied
    // colour lets the untouched backdrop composite straight through.
    if (dist >= 0.5 * aa) {
        fragColor = vec4(0.0);
        return;
    }

    float scale = max(uScale, 1.0);
    float distPt = dist / scale;     // signed distance in logical points
    float depthPt = -distPt;         // > 0 inside the glass

    // The lens zooms about the merged blob centre; magnification 1 = flat.
    vec2 basePx = uBlobCentre + (fragPx - uBlobCentre) / max(uMagnification, 0.0001);

    // Snell walk across a slab `thickness` points deep: the incidence angle
    // sweeps from grazing at the outline to zero once past the slab.
    float thickness = max(uThickness, 0.0001);
    float depthRatio = clamp(1.0 - depthPt / thickness, 0.0, 1.0);
    float incident = asin(clamp(depthRatio * depthRatio, 0.0, 1.0));
    float transmitted = asin(clamp(sin(incident) / max(uRefractiveIndex, 1.0001), -1.0, 1.0));
    float edgeShift = -tan(transmitted - incident);
    if (depthPt >= thickness) edgeShift = 0.0;

    vec4 color;

    if (uDebugMode > 0.5 && uDebugMode < 1.5) {
        // Debug 1: the merged field, banded every 10 points.
        float band = fract(abs(distPt) * 0.1);
        color = vec4(mix(vec3(0.1, 0.5, 1.0), vec3(1.0, 0.85, 0.2), band), 1.0);
    } else if (uDebugMode > 1.5) {
        // Debug 2: the surface normal as a hue wheel.
        vec2 g = sceneGradient(fragPx);
        color = vec4(hsvToRgb(vec3(vectorAngle(normalize(g)) / (2.0 * PI), 1.0, 1.0)), 1.0);
    } else if (edgeShift <= 0.0) {
        // Interior: straight through the slab, tinted by the material.
        color = vec4(sampleSoft(basePx), 1.0);
        color = mix(color, vec4(uTint.rgb, 1.0), uTint.a * 0.8);
    } else {
        vec2 grad = sceneGradient(fragPx);
        float gl = length(grad);
        vec2 normal = gl > 1e-5 ? grad / gl : vec2(0.0, 1.0);

        // Pull the sample back along the inward normal by the refracted walk.
        vec2 offsetPx = -normal * edgeShift * kShiftToPoints * scale;
        vec3 refracted = sampleDispersed(basePx, offsetPx, uDispersion);
        color = mix(vec4(refracted, 1.0), vec4(uTint.rgb, 1.0), uTint.a * 0.8);

        // Fresnel: a rim that builds over `range` points in from the outline.
        float fresnelBase = 1.0 + distPt / 1500.0 *
            pow(500.0 / max(uFresnelRange, 1.0), 2.0) + uFresnelSharp;
        float fresnelValue = clamp(pow(max(fresnelBase, 0.0), 5.0), 0.0, 1.0);

        vec3 fresnelTint = mix(vec3(1.0), uTint.rgb, uTint.a * 0.5);
        vec3 fresnelLch = srgbToLch(fresnelTint);
        fresnelLch.x = clamp(fresnelLch.x + 20.0 * fresnelValue * uFresnelStrength, 0.0, 100.0);
        color = mix(color, vec4(lchToSrgb(fresnelLch), 1.0),
                    clamp(fresnelValue * uFresnelStrength * 0.7 * uEdgeGain, 0.0, 1.0));

        // Glare: the same edge ramp, gated by the normal direction so the
        // highlight sits on opposing arcs instead of the whole rim.
        float glareBase = 1.0 + distPt / 1500.0 *
            pow(500.0 / max(uGlareRange, 1.0), 2.0) + uGlareSharp;
        float glareGeometry = clamp(pow(max(glareBase, 0.0), 5.0), 0.0, 1.0);

        float glareAngle = (vectorAngle(normal) - PI / 4.0 + uGlareOffset) * 2.0;
        bool farSide = (glareAngle > PI * 1.5 && glareAngle < PI * 3.5) || glareAngle < -PI * 0.5;
        float angular = (0.5 + sin(glareAngle) * 0.5) *
                        (farSide ? 1.2 * uGlareBias : 1.2) * uGlareStrength;
        angular = clamp(pow(max(angular, 0.0), 0.1 + uGlareConverge * 2.0), 0.0, 1.0);

        vec3 glareBaseColor = mix(refracted, uTint.rgb, uTint.a * 0.5);
        vec3 glareLch = srgbToLch(glareBaseColor);
        glareLch.x = clamp(glareLch.x + 150.0 * angular * glareGeometry, 0.0, 120.0);
        glareLch.y += 30.0 * angular * glareGeometry;
        color = mix(color, vec4(lchToSrgb(glareLch), 1.0),
                    clamp(angular * glareGeometry * uEdgeGain, 0.0, 1.0));
    }

    // Outline anti-aliasing: fade to fully transparent across one logical pixel.
    fragColor = mix(color, vec4(0.0), smoothstep(-0.5 * aa, 0.5 * aa, dist));
}
