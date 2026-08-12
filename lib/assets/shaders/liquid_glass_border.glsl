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
//  Compute a renderer-style highlight color informed by
//  the sampled background, but compressed toward a stable,
//  coherent rim tone instead of raw per-pixel colors.
// =======================================================
vec3 getHighlightColor(vec3 bgColor, float targetBrightness) {
    float luminance = dot(bgColor, BORDER_LUMA);
    vec3 saturatedBg = bgColor / max(luminance, 0.001);
    saturatedBg = mix(bgColor, saturatedBg, 0.8);

    float colorfulness = length(bgColor - vec3(luminance));
    float colorMix = clamp(colorfulness + 0.5, 0.5, 1.0);

    vec3 highlight = mix(vec3(targetBrightness), saturatedBg, colorMix);
    return clamp(highlight, 0.0, 1.0);
}

// =======================================================
//  Lens height profile — circular cross-section
//  (used by optical mode only)
// =======================================================
float getLensHeight(float sd, float thickness) {
    if (sd >= 0.0 || thickness <= 0.0) return 0.0;
    if (sd < -thickness) return thickness;
    float x = thickness + sd;
    return sqrt(max(0.0, thickness * thickness - x * x));
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

    float halfW = borderWidthPx * 0.5;
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
//  OPTICAL MODE: Apple-style rim light + specular + caustic
//  Border emerges as an optical consequence of the glass shape.
// =======================================================
vec4 getOpticalBorder(
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
#ifdef LIQUID_GLASS_RIM_WRAP
    , float wrap   // half-Lambert blend amount; only compiled for the metaball
#endif
){
    if (borderWidthPx <= 0.0 || borderAlpha <= 0.0) return vec4(0.0);

    // NOTE: the optical-mode width adjustment (historically `+ 2` here)
    // is now applied on the Dart side, in *logical* px, before the
    // per-path `scale` is applied. Doing it there keeps the rim the same
    // logical width on both the Skia (logical-px) and Impeller
    // (physical-px) shader spaces; adding a fixed constant here would be
    // ~dpr too thin on Impeller. `borderWidthPx` already includes it.

    float sd = signedEdgeOrthoDistPx;

    // 1. Rim factor — SDF-based rational falloff
    float rimWidth = max(borderWidthPx, 1.0);
    float k = 0.89;
    float x = sd / rimWidth;
    float rimFactor = 1.0 / (1.0 + k * x * x);

    // Fade out deep inside
    float innerFade = 1.0 - smoothstep(
        borderWidthPx * 1.5, borderWidthPx * 3.0,
        max(-sd, 0.0)
    );
    rimFactor *= innerFade;

    // Fade out outside the shape
    float outerFade = 1.0 - smoothstep(0.0, max(softnessPx, 1.0), max(sd, 0.0));
    rimFactor *= outerFade;

    if (rimFactor <= 0.001) return vec4(0.0);

    // 2. Surface normal
    vec2 normal;
    if (lightMode == LIGHT_NORMAL_EDGE) {
        normal = normalize(gradDistPx);
    } else {
        normal = normalize(uvNorm - centerNorm);
    }

    // 3. Light direction
    float lightRad = radians(lightDirDeg);
    vec2 lightDirV = vec2(cos(lightRad), sin(lightRad));

    // 4. Lens height for shape mask
    float thickness = borderWidthPx;
    float height = getLensHeight(sd, thickness);
    float normalizedHeight = thickness > 0.0 ? height / thickness : 0.0;
    float shapeMask = clamp((1.0 - normalizedHeight) * 1.111, 0.0, 1.0);
    float thicknessFactor = clamp((thickness - 2.0) * 0.5, 0.0, 1.0);

    // 5. Background-tinted highlight color
    vec3 highlightCol = vec3(1.0);
    if (dot(ambientColor, ambientColor) > 1e-5) {
        highlightCol = getHighlightColor(ambientColor, 1.0);
    }
    highlightCol *= lightColor.rgb;

    if (tint.a > 0.0) {
        highlightCol = mix(highlightCol, tint.rgb, clamp(tint.a, 0.0, 1.0));
    }

    if (borderSaturation != 1.0) {
        float rimLuma = dot(highlightCol, BORDER_LUMA);
        highlightCol = mix(vec3(rimLuma), highlightCol, borderSaturation);
    }

    // 6. Light-driven strength — computed WITHOUT the spatial mask.
    //    These terms control how strongly the rim shows, but must not
    //    extend its physical extent. We sum them up first, then cap the
    //    total to 1.0 before multiplying by the geometric mask.
    // Angular response. Default: lights the front and back of the light
    // axis but is ZERO at 90° — fine for a single convex shape. Under
    // LIQUID_GLASS_RIM_WRAP (metaball only) it blends toward a half-Lambert
    // response (0.5 at 90°), so a merged shape's concave neck — whose
    // normals are perpendicular to the light — keeps a rim and the border
    // stays connected. The production single-lens shaders don't define the
    // macro, so this compiles to just the original hard response.

    // lightSpread widens the rim's angular reach (higher = broader);
    // 0.5 reproduces the original pow(.,1.5) falloff exactly.
    float spread = clamp(lightSpread, 0.0, 1.0);
    float spreadExp = mix(2.5, 0.5, spread);
    // Below 0.5 the exponent alone can't shrink the bright core (the ×3 gain
    // saturates it), so also narrow the angular window of each light lobe.
    float lobeCut = (0.5 - min(spread, 0.5)) * 1.7;
#ifdef LIQUID_GLASS_RIM_WRAP
    float ndl = dot(normal, lightDirV);
    float hardFront = clamp((max(ndl, 0.0) - lobeCut) / (1.0 - lobeCut), 0.0, 1.0);
    float hardBack = clamp((max(-ndl, 0.0) - lobeCut) / (1.0 - lobeCut), 0.0, 1.0);
    float hard = hardFront + hardBack * 1;
    float wrapped = clamp((ndl * 0.5 + 0.5 - lobeCut) / (1.0 - lobeCut), 0.0, 1.0);
    float totalInfluence = mix(hard, wrapped, clamp(wrap, 0.0, 1.0));
#else
    float mainLight = max(dot(normal, lightDirV), 0.0);
    float oppositeLight = max(dot(normal, -lightDirV), 0.0);
    mainLight = clamp((mainLight - lobeCut) / (1.0 - lobeCut), 0.0, 1.0);
    oppositeLight = clamp((oppositeLight - lobeCut) / (1.0 - lobeCut), 0.0, 1.0);
    float totalInfluence = mainLight + oppositeLight * 1;
#endif
    float directional = pow(totalInfluence, spreadExp) * lightIntensity * 3.0;
    float ambient = ambientIntensity * 0.1;
    float lightStrength = directional + ambient;

    // 7. One-side specular boost (visibility only — no spatial mask here)
    if (oneSideLightIntensity > 0.0) {
        float spec1 = max(dot(normal, lightDirV), 0.0);
        spec1 = pow(spec1, 8.0);
        lightStrength += spec1 * lightIntensity * (0.8 * oneSideLightIntensity);
    }

    // 8. Double-side specular boost (visibility only — no spatial mask here)
    if (doubleSideLightIntensity > 0.0) {
        float sf = max(dot(normal, lightDirV), 0.0);
        sf = pow(sf, 8.0);
        float sb = max(dot(normal, -lightDirV), 0.0);
        sb = pow(sb, 8.0);
        lightStrength += (sf + sb) * lightIntensity * (0.8 * doubleSideLightIntensity);
    }

    // 9. Decouple thickness from intensity: cap light contribution to 1.0
    //    BEFORE applying the spatial mask. Without this cap, large light
    //    values would push pixels in the soft tail of rimFactor past 1.0,
    //    and the final clamp would make them fully visible — visually
    //    fattening the rim. With the cap, the rim's physical extent is
    //    fixed by rimFactor * thicknessFactor * shapeMask alone, while
    //    lights only modulate visibility within that extent.
    //
    //    `borderSolidity` blends between the two regimes:
    //      0.0 → cap on (current behavior, fixed extent, never goes solid)
    //      1.0 → cap off (old behavior — high lightIntensity pushes the
    //            rim to fully solid via the final alpha clamp)
    float cappedLight = clamp(lightStrength, 0.0, 1.0);
    float effectiveLight = mix(cappedLight, lightStrength, clamp(borderSolidity, 0.0, 1.0));
    float spatialMask = rimFactor * thicknessFactor * shapeMask;

    // 10. Final strength and premultiply
    float a = clamp(borderAlpha * effectiveLight * spatialMask, 0.0, 1.0);
    return vec4(highlightCol * a, a);
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
    float borderMode
#ifdef LIQUID_GLASS_RIM_WRAP
    , float wrap
#endif
){
    if (borderMode >= 0.5) {
        // OPTICAL mode
        return getOpticalBorder(
            uvNorm, centerNorm, signedEdgeOrthoDistPx, gradDistPx,
            borderWidthPx, softnessPx, tint,
            lightColor, shadowColor, lightIntensity,
            borderAlpha, lightDirDeg,
            oneSideLightIntensity, lightMode,
            ambientColor, ambientIntensity,
            doubleSideLightIntensity, borderSaturation,
            borderSolidity, lightSpread
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
