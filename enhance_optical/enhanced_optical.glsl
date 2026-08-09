// =============================================================
// enhancedOptical — EXACT port of LiquidGlassFragment.metal's
// fresnel + glare border (Alexey Demin's LiquidGlassKit), removed
// from lib/assets/shaders/liquid_glass_border.glsl on request and
// parked here for a future round.
//
// TO WIRE IT BACK into liquid_glass_border.glsl:
//  1. Paste this whole file's code above `getSweepBorder` (it only
//     needs BORDER_LUMA / LIGHT_NORMAL_EDGE / PI from that file).
//  2. Next to the mode defines add:
//         #define BORDER_MODE_ENHANCED 2
//  3. In getSweepBorder, dispatch before the optical branch:
//         if (borderMode >= 1.5) { return enhancedOptical(<the same
//         argument list as getOpticalBorder, minus wrap>); }
//     ...or, to test on existing styles without Dart changes, return
//     enhancedOptical(...) at the top of the OPTICAL branch (guard it
//     with `#ifndef LIQUID_GLASS_RIM_WRAP` so the metaball keeps its
//     wrap path).
//
// Every value is hardcoded from the kit's .lens preset. In this mode
// lightDirection / lightIntensity / borderSaturation / borderColor
// have no effect; only borderAlpha + the softness AA still apply.
// Known deltas vs Metal: the glare base is not dispersion-fringed,
// sd is fragment px (Metal uses points → ~dpr thinner on Impeller),
// ENH_NORMAL_LEN is fixed 1.7 vs their resolution-dependent factor.
// =============================================================

// EXACT port of LiquidGlassFragment.metal's fresnel + glare, every
// value hardcoded from the kit's .lens preset (its visible border).
const float ENH_FRES_RANGE  = 70.0;  // fresnelDistanceRange, pt
const float ENH_GLARE_RANGE = 30.0;  // glareDistanceRange, pt
const float ENH_FRES_SHARP  = 0.0;   // fresnelEdgeSharpness
const float ENH_GLARE_SHARP = -0.1;  // glareEdgeSharpness
const float ENH_FAR_BIAS    = 1.0;   // glareOppositeSideBias
const float ENH_CONVERGENCE = 0.1;   // glareAngleConvergence
const float ENH_FRES_INT    = 0.0;   // fresnelIntensity (kit: off)
const float ENH_GLARE_INT   = 0.1;   // glareIntensity
const float ENH_DIR_OFFSET  = -0.78539816; // glareDirectionOffset −π/4
// The kit's materialTint (thumb glass): near-clear cool white-blue.
const vec4 ENH_TINT = vec4(0.9, 0.95, 1.0, 0.15);
// Their `length(surfaceNormal)` — gradient·1.414·1000 at ~logical res.
const float ENH_NORMAL_LEN = 1.7;
// D65 white point, verbatim from the .metal.
const vec3 ENH_WHITE = vec3(0.95045592705, 1.0, 1.08905775076);

// sRGB transfer, verbatim (linearizeSRGB / gammaCorrectSRGB).
float enhLinearize(float c) {
    return c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92;
}
float enhGamma(float c) {
    return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(max(c, 0.0), 0.41666666666) - 0.055;
}

// sRGB → CIE LCH, the Metal chain: linearize → XYZ → LAB → polar.
vec3 enhSrgbToLch(vec3 srgb) {
    vec3 lin = vec3(enhLinearize(srgb.r), enhLinearize(srgb.g),
                    enhLinearize(srgb.b));
    vec3 xyz = vec3(dot(lin, vec3(0.4124, 0.3576, 0.1805)),
                    dot(lin, vec3(0.2126, 0.7152, 0.0722)),
                    dot(lin, vec3(0.0193, 0.1192, 0.9505)));
    vec3 s = xyz / ENH_WHITE;
    s.x = s.x > 0.00885645167 ? pow(s.x, 1.0 / 3.0)
                              : 7.78703703704 * s.x + 0.13793103448;
    s.y = s.y > 0.00885645167 ? pow(s.y, 1.0 / 3.0)
                              : 7.78703703704 * s.y + 0.13793103448;
    s.z = s.z > 0.00885645167 ? pow(s.z, 1.0 / 3.0)
                              : 7.78703703704 * s.z + 0.13793103448;
    vec3 lab = vec3(116.0 * s.y - 16.0, 500.0 * (s.x - s.y),
                    200.0 * (s.y - s.z));
    return vec3(lab.x, sqrt(dot(lab.yz, lab.yz)),
                atan(lab.z, lab.y) * (180.0 / PI));
}

// LCH → sRGB, the inverse chain, verbatim constants.
vec3 enhLchToSrgb(vec3 lch) {
    float hRad = lch.z * (PI / 180.0);
    vec3 lab = vec3(lch.x, lch.y * cos(hRad), lch.y * sin(hRad));
    float w = (lab.x + 16.0) / 116.0;
    vec3 f = vec3(w + lab.y / 500.0, w, w - lab.z / 200.0);
    vec3 xyz;
    xyz.x = f.x > 0.206897 ? f.x * f.x * f.x
                           : 0.12841854934 * (f.x - 0.137931034);
    xyz.y = f.y > 0.206897 ? f.y * f.y * f.y
                           : 0.12841854934 * (f.y - 0.137931034);
    xyz.z = f.z > 0.206897 ? f.z * f.z * f.z
                           : 0.12841854934 * (f.z - 0.137931034);
    xyz *= ENH_WHITE;
    vec3 lin = vec3(dot(xyz, vec3(3.2406255, -1.537208, -0.4986286)),
                    dot(xyz, vec3(-0.9689307, 1.8757561, 0.0415175)),
                    dot(xyz, vec3(0.0557101, -0.2040211, 1.0569959)));
    return clamp(vec3(enhGamma(lin.r), enhGamma(lin.g), enhGamma(lin.b)),
                 0.0, 1.0);
}

vec4 enhancedOptical(
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
    float lightSpread
){
    if (borderWidthPx <= 0.0 || borderAlpha <= 0.0) return vec4(0.0);
    float sd = signedEdgeOrthoDistPx;

    // Outside the silhouette the rim ends on a soft AA edge.
    float outerFade = 1.0 - smoothstep(0.0, max(softnessPx, 1.0), max(sd, 0.0));
    if (outerFade <= 0.001) return vec4(0.0);

    // The Metal normal is the SDF gradient — our gradDistPx, exactly.
    vec2 normal = normalize(gradDistPx);

    // The Metal falloff, verbatim: pow(1 + sd/1500·(500/range)² + sharp, 5).
    float fresFall = 1.0 + sd * pow(500.0 / ENH_FRES_RANGE, 2.0) / 1500.0
        + ENH_FRES_SHARP;
    float fres = clamp(pow(max(fresFall, 0.0), 5.0), 0.0, 1.0);
    float glareFall = 1.0 + sd * pow(500.0 / ENH_GLARE_RANGE, 2.0) / 1500.0
        + ENH_GLARE_SHARP;
    float glareGeom = clamp(pow(max(glareFall, 0.0), 5.0), 0.0, 1.0);

    // vectorToAngle + the Metal glare angle, verbatim (−π/4 + offset)·2.
    float theta = atan(normal.y, normal.x);
    theta = theta < 0.0 ? theta + 2.0 * PI : theta;
    float glareAngle = (theta - PI / 4.0 + ENH_DIR_OFFSET) * 2.0;

    // Far-side window test, verbatim (inert at bias 1.0, kept exact).
    float sideGain = 1.2;
    if ((glareAngle > PI * 1.5 && glareAngle < PI * 3.5) ||
        glareAngle < -PI * 0.5) {
        sideGain = 1.2 * ENH_FAR_BIAS;
    }
    float angularGlare =
        (0.5 + sin(glareAngle) * 0.5) * sideGain * ENH_GLARE_INT;
    angularGlare = clamp(
        pow(max(angularGlare, 0.0), 0.1 + ENH_CONVERGENCE * 2.0), 0.0, 1.0);

    // FRESNEL, verbatim: white→tint base, LCH L += 20·fres·intensity.
    float fA = 0.0;
    vec3 fresCol = vec3(1.0);
    if (ENH_FRES_INT > 0.0) {
        vec3 fresBase =
            mix(vec3(1.0), ENH_TINT.rgb, clamp(ENH_TINT.a * 0.5, 0.0, 1.0));
        vec3 fLch = enhSrgbToLch(fresBase);
        fLch.x = clamp(fLch.x + 20.0 * fres * ENH_FRES_INT, 0.0, 100.0);
        fresCol = enhLchToSrgb(fLch);
        fA = clamp(fres * ENH_FRES_INT * 0.7 * ENH_NORMAL_LEN, 0.0, 1.0);
    }

    // GLARE, verbatim: refracted-backdrop→tint base, LCH L += 150·g,
    // C += 30·g, L clamped to 120 — the saturated-white streak.
    float gAmt = angularGlare * glareGeom;
    vec3 gBase =
        mix(ambientColor, ENH_TINT.rgb, clamp(ENH_TINT.a * 0.5, 0.0, 1.0));
    vec3 gLch = enhSrgbToLch(gBase);
    gLch.x = clamp(gLch.x + 150.0 * gAmt, 0.0, 120.0);
    gLch.y += 30.0 * gAmt;
    vec3 glareCol = enhLchToSrgb(gLch);
    float gA = clamp(gAmt * ENH_NORMAL_LEN, 0.0, 1.0);

    // Sequential composite, as the Metal applies them: fresnel mix
    // first, glare mix over it — folded into one premultiplied layer.
    float strength = fA + gA - fA * gA;
    if (strength <= 1e-4) return vec4(0.0);
    vec3 rimCol = (fresCol * fA * (1.0 - gA) + glareCol * gA) / strength;

    float a = clamp(borderAlpha * strength * outerFade, 0.0, 1.0);
    return vec4(rimCol * a, a);
}
