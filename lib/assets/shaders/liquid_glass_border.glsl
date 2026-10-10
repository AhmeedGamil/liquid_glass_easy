// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#ifndef LIQUID_GLASS_BORDER_GLSL
#define LIQUID_GLASS_BORDER_GLSL
#define PI 3.14159265
// mediump perf test: inherit the shared toggle from liquid_glass_common.glsl
// (always #included first). Falls back to mediump if compiled standalone.
#ifndef GLASS_FLOAT_PRECISION
#define GLASS_FLOAT_PRECISION mediump
#endif
precision GLASS_FLOAT_PRECISION float;

// =======================================================
//  Luma weights (Rec. 709)
// =======================================================
const vec3 BORDER_LUMA = vec3(0.2126, 0.7152, 0.0722);

// =======================================================
//  Rim lift
//  sRGB is already spaced for the eye, so lightness is added
//  straight to luma: equal visible steps on any backdrop.
// =======================================================
// Chroma units per sRGB unit of colour offset.
const float RIM_CHROMA_SCALE = 0.00724;
// Colour offset per chroma unit on a neutral: warm, not pink.
const vec3 RIM_NEUTRAL_WARM = vec3(0.0026, -0.0002, -0.006);

// Adds `addL` lightness (0..100 scale, capped at `ceilL`) and `addC` chroma;
// the colour offset only grows in length, so hue holds.
vec3 rimLift(vec3 rgb, float addL, float addC, float ceilL) {
    float luma = dot(rgb, BORDER_LUMA);
    vec3 offset = rgb - luma;
    float offsetLen = length(offset);
    offset = offsetLen > 1e-3
        ? offset * ((offsetLen + addC * RIM_CHROMA_SCALE) / offsetLen)
        : addC * RIM_NEUTRAL_WARM;
    return clamp(min(luma + addL * 0.01, ceilL * 0.01) + offset, 0.0, 1.0);
}

// =======================================================
//  Rim ramp — 1 on the outline, 0 at `depthPx` inside.
//  A fifth power: a hard core with a long, soft inward tail.
// =======================================================
float rimRamp(float sdPx, float depthPx) {
    float t = max(1.0 + sdPx / max(depthPx, 1e-3), 0.0);
    float t2 = t * t;
    return clamp(t2 * t2 * t, 0.0, 1.0);
}

// =======================================================
//  THE BORDER: a specular rim over a soft side glow.
//  Both layers brighten the edge, keeping hue.
// =======================================================

// How the public values read inside the rim (thickness is the band depth
// in px as given): intensity 1 and sharpness 0.5 give the rest look.
const float RIM_INTENSITY_SCALE = 0.1;   // intensity 1 -> 0.1
const float RIM_SHIFT_AT_ZERO   = -0.6;  // sharpness 0..1 -> shift -0.6..0.4
// The silhouette's AA ramp is centred this far inside the outline (in AA
// bands); the rim is measured from there so its core lands on it.
const float RIM_OUTLINE_INSET   = 0.167;

// Fixed shaping values with no uniform of their own.
const float RIM_WEIGHT_GAIN        = 6.0;       // weight scale of both layers
const float RIM_GLOW_SHIFT         = 0.0;       // shift on the glow's ramp
// Share of the tint's alpha the rim colours take; the body mixes the tint
// at full alpha, so the rim stays lighter than the body.
const float RIM_TINT_SHARE = 0.625;

// A light's arc power: spread 0 focuses the arcs on the light's axis; 1
// flattens the power so they wrap the perimeter.
float rimArcPower(float spread) {
    return 0.1 + (1.0 - clamp(spread, 0.0, 1.0)) * 2.0;
}

// One specular layer: `base` lifted up to +150 L and +30 C by angle x depth.
// Returns (colour, weight).
vec4 rimSpecular(float sd, vec2 normal, vec3 base, float depthPx,
                 float shift, vec3 light, vec4 lightColor, float opposite
#ifdef LIQUID_GLASS_RIM_WRAP
                 , float wrap
#endif
){
    float ramp = rimRamp(sd + shift * depthPx, depthPx);
    if (ramp <= 0.0) return vec4(0.0);
    float rad = radians(light.x);
    float ndl = dot(normal, vec2(cos(rad), sin(rad)));
    // Two opposing arcs on the light's axis, dark at 90 degrees to it.
    float facing = ndl * ndl;
#ifdef LIQUID_GLASS_RIM_WRAP
    // A merged blob's concave neck faces sideways; wrap keeps it lit.
    facing = mix(facing, ndl * 0.5 + 0.5, clamp(wrap, 0.0, 1.0));
#endif
    // The far arc's strength, relative to the near one.
    float backGain = ndl < 0.0 ? opposite : 1.0;
    // The pow() base is floored: an exact zero base is undefined.
    float arc = clamp(
        pow(max(facing * 1.2 * backGain * light.z * RIM_INTENSITY_SCALE, 1e-6),
            rimArcPower(light.y)),
        0.0, 1.0);
    float strength = arc * ramp;
    float own = clamp(lightColor.a, 0.0, 1.0);
    vec3 color = vec3(0.0);
    // The light's own colour replaces the lifted backdrop by its alpha.
    if (own < 1.0) {
        color = rimLift(base, 150.0 * strength,
                        30.0 * strength, 120.0);
    }
    color = mix(color, lightColor.rgb, own);
    return vec4(color, clamp(strength * RIM_WEIGHT_GAIN, 0.0, 1.0));
}

// The rim body: the glow, the specular over it and the second specular on
// top. `specular`, `specular2` and `glow` are (angleDeg, spread, intensity).
// A light colour's alpha is how much of it replaces the picked-up colour.
vec4 getBorder(
    float signedEdgeOrthoDistPx,
    vec2 gradDistPx,
    vec4 tint,
    float borderAlpha,
    vec3 backdropColor,
    float specularThicknessPx, float sharpness,
    vec3 specular, vec4 specularLight,
    float glowThicknessPx,
    vec3 glow, vec4 glowLight,
    vec4 specular2Shape, // (thicknessPx, sharpness, angleDeg, spread)
    float specular2Intensity, vec4 specular2Light,
    vec3 opposite,    // far-arc strength: (specular, glow, second specular)
    float aaPx        // the silhouette's AA band width, in fragment px
#ifdef LIQUID_GLASS_RIM_WRAP
    , float wrap   // half-Lambert blend amount; only compiled for the metaball
#endif
){
    // Outside the outline the silhouette's own coverage ends the rim.
    // Each layer is live only with a thickness (the glow also needs an
    // intensity); a layer that is off costs nothing below.
    bool specularOn = specularThicknessPx > 0.0;
    bool specular2On = specular2Shape.x > 0.0;
    bool glowOn = glowThicknessPx > 0.0 && glow.z > 0.0;
    if ((!specularOn && !specular2On && !glowOn) || borderAlpha <= 0.0) {
        return vec4(0.0);
    }

    // Distance from where the silhouette actually sits, not the outline.
    float sd = signedEdgeOrthoDistPx + RIM_OUTLINE_INSET * max(aaPx, 1.0);

    // Each ramp's depth IS its light's thickness; sharpness shifts a
    // specular's, read from its 0..1 range.
    float specularDepthPx = specularThicknessPx;
    float specularShift = RIM_SHIFT_AT_ZERO + clamp(sharpness, 0.0, 1.0);
    float specular2DepthPx = specular2Shape.x;
    float specular2Shift =
        RIM_SHIFT_AT_ZERO + clamp(specular2Shape.y, 0.0, 1.0);
    float glowDepthPx = glowThicknessPx;

    // Past every live ramp's end the rim is exactly zero: skip the pow work.
    float reachPx = specularOn ? (1.0 + specularShift) * specularDepthPx : 0.0;
    if (specular2On) {
        reachPx = max(reachPx, (1.0 + specular2Shift) * specular2DepthPx);
    }
    if (glowOn) {
        reachPx = max(reachPx, (1.0 + RIM_GLOW_SHIFT) * glowDepthPx);
    }
    if (sd <= -reachPx) return vec4(0.0);

    // Surface normal: the shape's gradient.
    vec2 normal = normalize(gradDistPx);

    float tintShare = clamp(tint.a, 0.0, 1.0) * RIM_TINT_SHARE;
    // Every layer's picked-up colour: the backdrop at the tint's rim share.
    vec3 base = mix(backdropColor, tint.rgb, tintShare);

    // Glow: the same two-arc response on its own axis and spread, driven by
    // its intensity on the specular's intensity scale, in the specular's
    // colour.
    vec3 glowColor = vec3(0.0);
    float glowWeight = 0.0;
    float glowRamp = glowOn
        ? rimRamp(sd + RIM_GLOW_SHIFT * glowDepthPx, glowDepthPx) : 0.0;
    if (glowRamp > 0.0) {
        float glowRad = radians(glow.x);
        float ndlGlow = dot(normal, vec2(cos(glowRad), sin(glowRad)));
        float glowFacing = ndlGlow * ndlGlow;
#ifdef LIQUID_GLASS_RIM_WRAP
        glowFacing = mix(glowFacing, ndlGlow * 0.5 + 0.5, clamp(wrap, 0.0, 1.0));
#endif
        float glowBack = ndlGlow < 0.0 ? opposite.y : 1.0;
        float glowArc = clamp(
            pow(max(glowFacing * 1.2 * glowBack * glow.z * RIM_INTENSITY_SCALE,
                    1e-6),
                rimArcPower(glow.y)),
            0.0, 1.0);
        float glowStrength = glowArc * glowRamp;
        float glowOwn = clamp(glowLight.a, 0.0, 1.0);
        if (glowOwn < 1.0) {
            glowColor = rimLift(base, 150.0 * glowStrength,
                                30.0 * glowStrength, 120.0);
        }
        glowColor = mix(glowColor, glowLight.rgb, glowOwn);
        glowWeight = clamp(glowStrength * 0.7 * RIM_WEIGHT_GAIN, 0.0, 1.0);
    }

    vec4 specularLayer = specularOn
        ? rimSpecular(sd, normal, base, specularDepthPx,
                      specularShift, specular, specularLight, opposite.x
#ifdef LIQUID_GLASS_RIM_WRAP
                      , wrap
#endif
                      )
        : vec4(0.0);
    vec4 specular2Layer = specular2On
        ? rimSpecular(sd, normal, base, specular2DepthPx,
                      specular2Shift,
                      vec3(specular2Shape.z, specular2Shape.w,
                           specular2Intensity),
                      specular2Light, opposite.z
#ifdef LIQUID_GLASS_RIM_WRAP
                      , wrap
#endif
                      )
        : vec4(0.0);

    // Glow first, the specular over it, the second specular on top.
    float s1 = specularLayer.a;
    float s2 = specular2Layer.a;
    float rimWeight = 1.0 - (1.0 - glowWeight) * (1.0 - s1) * (1.0 - s2);
    if (rimWeight <= 0.001) return vec4(0.0);
    vec3 rimPremul = (glowColor * glowWeight * (1.0 - s1)
                      + specularLayer.rgb * s1) * (1.0 - s2)
                   + specular2Layer.rgb * s2;

    return vec4(rimPremul * borderAlpha, rimWeight * borderAlpha);
}

// =======================================================
//  Compositing: the rim mixes into the glass under it by its
//  own weight and leaves the glass's coverage alone.
// =======================================================
vec4 overlayPremul(vec4 base, vec4 over){
    float baseA = base.a;
    float strength = clamp(over.a, 0.0, 1.0);
    if (baseA <= 1e-4 || strength <= 1e-4) {
        return base;
    }

    vec3 baseColor = base.rgb / max(baseA, 1e-4);
    vec3 rimColor = over.rgb / max(over.a, 1e-4);
    vec3 mixedColor = mix(baseColor, rimColor, strength);
    return vec4(mixedColor * baseA, baseA);
}
#endif
