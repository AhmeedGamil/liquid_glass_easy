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
//  Perceptual boost (CIE Lab, D65)
//  The rim gains lightness and chroma without washing the
//  colour it was sampled from out toward grey.
// =======================================================
const vec3 LAB_WHITE = vec3(0.95045593, 1.0, 1.08905775);
// Both matrices are built COLUMN-wise from the rows they name, so the
// row-vector products below (`v * M`) evaluate the intended row dots.
const mat3 LAB_RGB_TO_XYZ = mat3(
    vec3(0.4124, 0.3576, 0.1805),
    vec3(0.2126, 0.7152, 0.0722),
    vec3(0.0193, 0.1192, 0.9505)
);
const mat3 LAB_XYZ_TO_RGB = mat3(
    vec3( 3.2406255, -1.5372080, -0.4986286),
    vec3(-0.9689307,  1.8757561,  0.0415175),
    vec3( 0.0557101, -0.2040211,  1.0569959)
);

float borderLabF(float t) {
    return t > 0.00885645 ? pow(max(t, 1e-8), 1.0 / 3.0)
                          : 7.787037 * t + 0.13793103;
}

float borderLabFInv(float t) {
    return t > 0.206897 ? t * t * t : 0.12841855 * (t - 0.13793103);
}

// Adds `dL` lightness and `dC` chroma in Lab. The sRGB triple goes into the
// matrix as-is (no transfer function); chroma scales a/b, so the hue holds.
vec3 labBoost(vec3 srgb, float dL, float dC, float maxL) {
    vec3 xyz = (srgb * LAB_RGB_TO_XYZ) / LAB_WHITE;
    vec3 f = vec3(borderLabF(xyz.x), borderLabF(xyz.y), borderLabF(xyz.z));
    vec3 lab = vec3(116.0 * f.y - 16.0,
                    500.0 * (f.x - f.y),
                    200.0 * (f.y - f.z));

    // A flat add along the existing hue; a neutral colour takes it on +b
    // (the yellow axis), so a black backdrop lifts warm-neutral, not pink.
    float chroma = length(lab.yz);
    lab.yz = chroma > 1e-4 ? lab.yz * ((chroma + dC) / chroma)
                           : vec2(0.0, dC);
    lab.x = clamp(lab.x + dL, 0.0, maxL);

    float y = (lab.x + 16.0) / 116.0;
    vec3 outXyz = LAB_WHITE * vec3(borderLabFInv(y + lab.y / 500.0),
                                   borderLabFInv(y),
                                   borderLabFInv(y - lab.z / 200.0));
    return clamp(outXyz * LAB_XYZ_TO_RGB, 0.0, 1.0);
}

// =======================================================
//  Rim falloff — 1 on the outline, 0 at `rangePx` inside.
//  The fifth power keeps the bright core hard against the
//  outline and gives it a long, soft inward tail; it
//  integrates to rangePx / 6.
// =======================================================
float getRimFalloff(float sdPx, float rangePx) {
    float t = max(1.0 + sdPx / max(rangePx, 1e-3), 0.0);
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
//  OPTICAL MODE: an all-round rim under a directional glare
//  The border is not drawn as a stroke — it is what the
//  glass edge does to the backdrop behind it. Both bands
//  ramp in from the outline and brighten in CIE Lab, so a
//  coloured backdrop keeps its hue as the rim goes hot.
// =======================================================

// How the public values read inside the rim, so their usual ranges land on
// the rim's own: width 1, intensity 1, solidity 0.5 = the rest look.
const float RIM_RANGE_PER_WIDTH   = 5.4;   // ramp depth per unit of width
const float RIM_INTENSITY_SCALE   = 0.1;   // lightIntensity 1 -> 0.1
const float RIM_SHARPNESS_AT_ZERO = -0.6;  // solidity 0..1 -> shift -0.6..0.4
// The silhouette's coverage ramp is centred this far INSIDE the outline (in
// units of the AA band); the rim is measured from there so its core lands on it.
const float RIM_OUTLINE_INSET     = 0.167;

// Rim constants: the values with no uniform of their own.
const float RIM_EDGE_GAIN       = 6.0;   // weight scale of both bands
const float RIM_OPPOSITE_BIAS   = 1.0;   // glare on the arc facing away
const float RIM_FRESNEL_SHARPNESS = 0.0; // shift on the side rim's ramp
// The side rim's depth, as a multiple of the glare's: (70 / 30)^2.
const float RIM_FRESNEL_RANGE_RATIO = 5.4444444;
// The side rim's arcs sit 90 degrees from the glare's, at this fixed spread.
const float RIM_FRESNEL_SPREAD = 0.5;
// Share of the tint's alpha the rim colours take. The body mixes at the
// full alpha, which reads as 0.8 of the material amount; the rim wants 0.5.
const float RIM_TINT_SHARE = 0.625;

// The rim body: the glare over the side rim, both boosted in Lab.
vec4 getOpticalBorder(
    vec2 uvNorm, vec2 centerNorm, float signedEdgeOrthoDistPx,
    vec2 gradDistPx,
    float borderWidthPx, float softnessPx, vec4 tint,
    vec4 lightColor, float lightIntensity,
    float borderAlpha, float lightDirDeg,
    float lightMode,
    vec3 ambientColor, float ambientIntensity,
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

    // The glare ramp's depth follows the authored width; borderSolidity is
    // the additive shift on it, read from its 0..1 range.
    float rangePx = borderWidthPx * RIM_RANGE_PER_WIDTH;
    float sharpness = RIM_SHARPNESS_AT_ZERO + clamp(borderSolidity, 0.0, 1.0);
    float glareGeometry = getRimFalloff(sd + sharpness * rangePx, rangePx);

    float fresnelRangePx = rangePx * RIM_FRESNEL_RANGE_RATIO;

    // Past every live ramp's end the rim is exactly zero: skip the pow work.
    // The side rim only reaches in when ambientIntensity lights it.
    bool sideOn = ambientIntensity > 0.0;
    float reachPx = (1.0 + sharpness) * rangePx;
    if (sideOn) {
        reachPx = max(reachPx, (1.0 + RIM_FRESNEL_SHARPNESS) * fresnelRangePx);
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
    float facing = ndl * ndl;
    // The side rim's axis: the light turned 90°, so its arcs fill the gaps.
    float ndlSide = dot(normal, vec2(-lightDirV.y, lightDirV.x));
    float facingSide = ndlSide * ndlSide;
#ifdef LIQUID_GLASS_RIM_WRAP
    // A merged blob's concave neck faces sideways and would fall in the dark
    // band; wrap blends toward a half-Lambert response that keeps it lit.
    facing = mix(facing, ndl * 0.5 + 0.5, clamp(wrap, 0.0, 1.0));
    facingSide = mix(facingSide, ndlSide * 0.5 + 0.5, clamp(wrap, 0.0, 1.0));
#endif
    float sideBias = ndl < 0.0 ? RIM_OPPOSITE_BIAS : 1.0;

    // lightSpread is the inverse of convergence: 0 focuses the arcs on the
    // light axis, 1 flattens the exponent so they wrap the perimeter.
    float arcExponent = 0.1 + (1.0 - clamp(lightSpread, 0.0, 1.0)) * 2.0;
    // Both pow() bases below are floored: an exact zero base is undefined.
    float tintShare = clamp(tint.a, 0.0, 1.0) * RIM_TINT_SHARE;

    // Side rim: the same two-arc response on the side axis, at a fixed
    // spread, driven by ambientIntensity on the glare's intensity scale.
    vec3 fresnelColor = vec3(0.0);
    float fresnelWeight = 0.0;
    float fresnelValue = sideOn ? getRimFalloff(
        sd + RIM_FRESNEL_SHARPNESS * fresnelRangePx, fresnelRangePx) : 0.0;
    if (fresnelValue > 0.0) {
        float sideExponent = 0.1 + (1.0 - RIM_FRESNEL_SPREAD) * 2.0;
        float angularSide = clamp(
            pow(max(facingSide * 1.2 * ambientIntensity * RIM_INTENSITY_SCALE,
                    1e-6), sideExponent),
            0.0, 1.0);

        // Its colour: white pulled toward the tint by its rim share, lifted
        // up to +20 L, weighted by its own ramp.
        vec3 fresnelTint = mix(vec3(1.0), tint.rgb, tintShare);
        float fresnelDrive = angularSide * fresnelValue;
        fresnelColor = labBoost(fresnelTint, 20.0 * fresnelDrive, 0.0, 100.0);
        fresnelWeight = clamp(fresnelDrive * 0.7 * RIM_EDGE_GAIN, 0.0, 1.0);
    }

    // Glare: the refracted backdrop with the tint at its rim share, lifted
    // up to +150 L and +30 C by angle x depth. Past its ramp it is zero.
    vec3 glareColor = vec3(0.0);
    float glareWeight = 0.0;
    if (glareGeometry > 0.0) {
        float angular = clamp(
            pow(max(facing * 1.2 * sideBias * lightIntensity * RIM_INTENSITY_SCALE,
                    1e-6), arcExponent),
            0.0, 1.0);
        vec3 glareSource = mix(ambientColor, tint.rgb, tintShare);
        float glareDrive = angular * glareGeometry;
        glareColor = labBoost(glareSource, 150.0 * glareDrive,
                              30.0 * glareDrive, 120.0);
        glareWeight = clamp(glareDrive * RIM_EDGE_GAIN, 0.0, 1.0);
    }

    // The side rim mixed in first and the glare over it, folded into one layer.
    float rimWeight = 1.0 - (1.0 - fresnelWeight) * (1.0 - glareWeight);
    if (rimWeight <= 0.001) return vec4(0.0);
    vec3 rimPremul = fresnelColor * fresnelWeight * (1.0 - glareWeight)
                   + glareColor * glareWeight;

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
    vec3 ambientColor, float ambientIntensity,
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
            ambientColor, ambientIntensity,
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
