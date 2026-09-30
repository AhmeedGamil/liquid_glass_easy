// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#ifndef LIQUID_GLASS_BORDER_GLSL
#define LIQUID_GLASS_BORDER_GLSL
#define LIGHT_NORMAL_EDGE   0  // Follow the shape gradient (curvature)
#define LIGHT_NORMAL_RADIAL 1  // Radial from center
#define BORDER_MODE_CLASSIC  0
#define BORDER_MODE_OPTICAL  1
#define PI 3.14159265
// mediump perf test: inherit the shared toggle from liquid_glass_common.glsl
// (always #included first). Falls back to mediump if compiled standalone.
#ifndef GLASS_FLOAT_PRECISION
#define GLASS_FLOAT_PRECISION mediump
#endif
precision GLASS_FLOAT_PRECISION float;

// =======================================================
//  Luma weights (Rec. 709) — used by optical mode
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
//  CLASSIC MODE: Original sweep gradient border
//  Centered on the edge (half inside, half outside).
//  Light/shadow colors sweep around the shape based on
//  the angle between the surface normal and light direction.
// =======================================================
vec4 getClassicBorder(
    vec2 uvNorm, vec2 centerNorm, float signedEdgeOrthoDistPx,
    vec2 gradDistPx,
    float borderWidthPx, float softnessPx, vec4 tint,
    vec4 lightColor, vec4 shadowColor, float lightIntensity,
    float borderAlpha, float lightDirDeg,
    float oneSideLightIntensity, float lightMode,
    float doubleSideLightIntensity
){
    if (borderWidthPx <= 0.0 || borderAlpha <= 0.0) return vec4(0.0);

    // The band is centred on the outline and spans the authored width to each
    // side; the outer half is clipped away, leaving that width inside.
    float halfW = borderWidthPx;
    if (signedEdgeOrthoDistPx > halfW) return vec4(0.0);

    float mask = 1.0 - smoothstep(
        halfW, halfW + max(softnessPx, 1e-3),
        abs(signedEdgeOrthoDistPx)
    );
    if (mask <= 0.001) return vec4(0.0);

    vec2 normal;
    float ang;

    if (lightMode == LIGHT_NORMAL_EDGE) {
        normal = normalize(gradDistPx);
    } else {
        normal = normalize(uvNorm - centerNorm);
    }
    ang = atan(normal.y, normal.x);
    float lightRad = radians(lightDirDeg);
    ang -= radians(lightDirDeg);
    ang = mod(ang, 2.0 * PI);
    float tAngle = ang / (2.0 * PI);

    vec4 c0, c1;
    if (tint.a > 0.0) {
        c0 = tint;
        c1 = tint;
    } else {
        c0 = lightColor;
        c1 = shadowColor;
    }

    vec4 col =
        (tAngle <= 0.25) ? mix(c0, c1, tAngle / 0.25) :
        (tAngle <= 0.50) ? mix(c1, c0, (tAngle - 0.25) / 0.25) :
        (tAngle <= 0.75) ? mix(c0, c1, (tAngle - 0.50) / 0.25) :
                           mix(c1, c0, (tAngle - 0.75) / 0.25);

    // One-side specular highlight
    if (oneSideLightIntensity > 0.0) {
        vec2 lightDirV = vec2(cos(lightRad), sin(lightRad));
        float spec = max(dot(normal, lightDirV), 0.0);
        spec = pow(spec, 8.0);
        col.rgb += lightColor.rgb * spec * lightIntensity * (0.8 * oneSideLightIntensity);
    }

    // Double-side specular highlight
    if (doubleSideLightIntensity > 0.0) {
        vec2 lightDirV = vec2(cos(lightRad), sin(lightRad));
        float specFront = max(dot(normal, lightDirV), 0.0);
        specFront = pow(specFront, 8.0);
        float specBack = max(dot(normal, -lightDirV), 0.0);
        specBack = pow(specBack, 8.0);
        col.rgb += lightColor.rgb * (specFront + specBack) * lightIntensity * (0.8 * doubleSideLightIntensity);
    }

    // Apply global intensity
    col.rgb *= lightIntensity;
    float a = col.a * borderAlpha * mask;
    return vec4(col.rgb * a, a);
}

// =======================================================
//  OPTICAL MODE: a specular rim over a soft side glow.
//  Both layers brighten the edge, keeping hue.
// =======================================================

// How the public values read inside the rim: width 1, intensity 1 and
// solidity 0.5 give the rest look.
const float RIM_DEPTH_PER_WIDTH = 5.4;   // specular ramp depth per unit of width
const float RIM_INTENSITY_SCALE = 0.1;   // lightIntensity 1 -> 0.1
const float RIM_SHIFT_AT_ZERO   = -0.6;  // solidity 0..1 -> shift -0.6..0.4
// The silhouette's AA ramp is centred this far inside the outline (in AA
// bands); the rim is measured from there so its core lands on it.
const float RIM_OUTLINE_INSET   = 0.167;

// Fixed shaping values with no uniform of their own.
const float RIM_WEIGHT_GAIN        = 6.0;       // weight scale of both layers
const float RIM_SPECULAR_BACK_GAIN = 1.0;       // specular on the arc facing away
const float RIM_GLOW_SHIFT         = 0.0;       // shift on the glow's ramp
const float RIM_GLOW_DEPTH_RATIO   = 5.4444444; // glow depth, in specular depths
// The glow's arcs sit 90 degrees from the specular's, at this fixed spread.
const float RIM_GLOW_SPREAD        = 0.5;
// Share of the tint's alpha the rim colours take; the body mixes the tint
// at full alpha, so the rim stays lighter than the body.
const float RIM_TINT_SHARE = 0.625;

// The rim body: the specular layer over the glow, both lifted.
vec4 getOpticalBorder(
    vec2 uvNorm, vec2 centerNorm, float signedEdgeOrthoDistPx,
    vec2 gradDistPx,
    float borderWidthPx, float softnessPx, vec4 tint,
    vec4 lightColor, float lightIntensity,
    float borderAlpha, float lightDirDeg,
    float lightMode,
    vec3 backdropColor, float ambientIntensity,
    float borderSaturation,
    float borderSolidity,
    float lightSpread,
    float aaPx        // the silhouette's AA band width, in fragment px
#ifdef LIQUID_GLASS_RIM_WRAP
    , float wrap   // half-Lambert blend amount; only compiled for the metaball
#endif
){
    // lightColor, softnessPx and borderSaturation take no part here. Outside
    // the outline the silhouette's own coverage ends the rim.
    if (borderWidthPx <= 0.0 || borderAlpha <= 0.0) return vec4(0.0);

    // Distance from where the silhouette actually sits, not the outline.
    float sd = signedEdgeOrthoDistPx + RIM_OUTLINE_INSET * max(aaPx, 1.0);

    // The specular ramp's depth follows the authored width; borderSolidity
    // shifts it, read from its 0..1 range.
    float specularDepthPx = borderWidthPx * RIM_DEPTH_PER_WIDTH;
    float specularShift = RIM_SHIFT_AT_ZERO + clamp(borderSolidity, 0.0, 1.0);
    float specularRamp =
        rimRamp(sd + specularShift * specularDepthPx, specularDepthPx);

    float glowDepthPx = specularDepthPx * RIM_GLOW_DEPTH_RATIO;

    // Past every live ramp's end the rim is exactly zero: skip the pow work.
    // The glow only reaches in when ambientIntensity lights it.
    bool glowOn = ambientIntensity > 0.0;
    float reachPx = (1.0 + specularShift) * specularDepthPx;
    if (glowOn) {
        reachPx = max(reachPx, (1.0 + RIM_GLOW_SHIFT) * glowDepthPx);
    }
    if (sd <= -reachPx) return vec4(0.0);

    // Surface normal — shape gradient, or radial from the centre.
    vec2 normal;
    if (lightMode == LIGHT_NORMAL_EDGE) {
        normal = normalize(gradDistPx);
    } else {
        normal = normalize(uvNorm - centerNorm);
    }

    float lightRad = radians(lightDirDeg);
    vec2 lightDirV = vec2(cos(lightRad), sin(lightRad));
    float ndl = dot(normal, lightDirV);

    // Angular response: two opposing arcs on the light axis, brightest where
    // the surface faces the light and dark at 90°.
    float specularFacing = ndl * ndl;
    // The glow's axis: the light turned 90°, so its arcs fill the gaps.
    float ndlGlow = dot(normal, vec2(-lightDirV.y, lightDirV.x));
    float glowFacing = ndlGlow * ndlGlow;
#ifdef LIQUID_GLASS_RIM_WRAP
    // A merged blob's concave neck faces sideways and would fall in the dark
    // band; wrap blends toward a half-Lambert response that keeps it lit.
    specularFacing = mix(specularFacing, ndl * 0.5 + 0.5, clamp(wrap, 0.0, 1.0));
    glowFacing = mix(glowFacing, ndlGlow * 0.5 + 0.5, clamp(wrap, 0.0, 1.0));
#endif
    float backGain = ndl < 0.0 ? RIM_SPECULAR_BACK_GAIN : 1.0;

    // lightSpread 0 focuses the arcs on the light axis; 1 flattens the
    // power so they wrap the perimeter.
    float specularArcPower = 0.1 + (1.0 - clamp(lightSpread, 0.0, 1.0)) * 2.0;
    // Both pow() bases below are floored: an exact zero base is undefined.
    float tintShare = clamp(tint.a, 0.0, 1.0) * RIM_TINT_SHARE;

    // Glow: the same two-arc response on the side axis, at a fixed spread,
    // driven by ambientIntensity on the specular's intensity scale.
    vec3 glowColor = vec3(0.0);
    float glowWeight = 0.0;
    float glowRamp = glowOn
        ? rimRamp(sd + RIM_GLOW_SHIFT * glowDepthPx, glowDepthPx) : 0.0;
    if (glowRamp > 0.0) {
        float glowArcPower = 0.1 + (1.0 - RIM_GLOW_SPREAD) * 2.0;
        float glowArc = clamp(
            pow(max(glowFacing * 1.2 * ambientIntensity * RIM_INTENSITY_SCALE,
                    1e-6), glowArcPower),
            0.0, 1.0);

        // Its colour: white pulled toward the tint by its rim share, lifted
        // up to +20 L, weighted by its own ramp.
        vec3 glowBase = mix(vec3(1.0), tint.rgb, tintShare);
        float glowStrength = glowArc * glowRamp;
        glowColor = rimLift(glowBase, 20.0 * glowStrength, 0.0, 100.0);
        glowWeight = clamp(glowStrength * 0.7 * RIM_WEIGHT_GAIN, 0.0, 1.0);
    }

    // Specular: the refracted backdrop with the tint at its rim share, lifted
    // up to +150 L and +30 C by angle x depth. Past its ramp it is zero.
    vec3 specularColor = vec3(0.0);
    float specularWeight = 0.0;
    if (specularRamp > 0.0) {
        float specularArc = clamp(
            pow(max(specularFacing * 1.2 * backGain * lightIntensity
                        * RIM_INTENSITY_SCALE, 1e-6), specularArcPower),
            0.0, 1.0);
        vec3 specularBase = mix(backdropColor, tint.rgb, tintShare);
        float specularStrength = specularArc * specularRamp;
        specularColor = rimLift(specularBase, 150.0 * specularStrength,
                                30.0 * specularStrength, 120.0);
        specularWeight = clamp(specularStrength * RIM_WEIGHT_GAIN, 0.0, 1.0);
    }

    // The glow mixed in first and the specular over it, folded into one layer.
    float rimWeight = 1.0 - (1.0 - glowWeight) * (1.0 - specularWeight);
    if (rimWeight <= 0.001) return vec4(0.0);
    vec3 rimPremul = glowColor * glowWeight * (1.0 - specularWeight)
                   + specularColor * specularWeight;

    return vec4(rimPremul * borderAlpha, rimWeight * borderAlpha);
}

// =======================================================
//  Unified entry point — dispatches to classic or optical
// =======================================================
vec4 getSweepBorder(
    vec2 uvNorm, vec2 centerNorm, float signedEdgeOrthoDistPx,
    vec2 gradDistPx,
    float borderWidthPx, float softnessPx, vec4 tint,
    vec4 lightColor, vec4 shadowColor, float lightIntensity,
    float borderAlpha, float lightDirDeg,
    float oneSideLightIntensity, float lightMode,
    vec3 backdropColor, float ambientIntensity,
    float doubleSideLightIntensity,
    float borderSaturation,
    float borderSolidity,
    float lightSpread,
    float aaPx,
    float borderMode
#ifdef LIQUID_GLASS_RIM_WRAP
    , float wrap
#endif
){
    if (borderMode >= 0.5) {
        // OPTICAL mode. The one-/double-side specular terms and the shadow
        // colour are classic-only, and the Dart side already zeroes them here.
        return getOpticalBorder(
            uvNorm, centerNorm, signedEdgeOrthoDistPx, gradDistPx,
            borderWidthPx, softnessPx, tint,
            lightColor, lightIntensity,
            borderAlpha, lightDirDeg,
            lightMode,
            backdropColor, ambientIntensity,
            borderSaturation,
            borderSolidity, lightSpread, aaPx
#ifdef LIQUID_GLASS_RIM_WRAP
            , wrap
#endif
        );
    } else {
        // CLASSIC mode
        return getClassicBorder(
            uvNorm, centerNorm, signedEdgeOrthoDistPx, gradDistPx,
            borderWidthPx, softnessPx, tint,
            lightColor, shadowColor, lightIntensity,
            borderAlpha, lightDirDeg,
            oneSideLightIntensity, lightMode,
            doubleSideLightIntensity
        );
    }
}

// =======================================================
//  Compositing — mode-aware
//  Classic: standard alpha compositing (over operator)
//  Optical: additive blend for glow effect
// =======================================================
vec4 overlayPremulClassic(vec4 base, vec4 over){
    float outA   = over.a + base.a * (1.0 - over.a);
    vec3  outRGB = over.rgb + base.rgb * (1.0 - over.a);
    return vec4(outRGB, outA);
}

vec4 overlayPremulOptical(vec4 base, vec4 over){
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

vec4 overlayPremul(vec4 base, vec4 over, float borderMode){
    if (borderMode >= 0.5) {
        return overlayPremulOptical(base, over);
    } else {
        return overlayPremulClassic(base, over);
    }
}
#endif
