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
#define PI 3.14159265
precision highp float; // or highp float


// =======================================================
//  Sweep border coloring with optional tint or sweep light
// =======================================================
vec4 getSweepBorder(
    vec2 uvNorm, vec2 centerNorm, float signedEdgeOrthoDistPx,
    vec2 gradDistPx,
    float borderWidthPx, float softnessPx, vec4 tint,
    vec4 lightColor, vec4 shadowColor, float lightIntensity,
    float borderAlpha, float lightDirDeg,
    float oneSideLightIntensity, float lightMode  // 0 = no extra lighting
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

    if(lightMode == LIGHT_NORMAL_EDGE){
        normal = normalize(gradDistPx);
    } else {
        normal = normalize(uvNorm - centerNorm);
    }
    ang = atan(normal.y, normal.x);
    float lightRad= radians(lightDirDeg);
    ang -= radians(lightDirDeg);
    ang = mod(ang, 2.0 * PI);
    float tAngle = ang / (2.0 * PI);

    vec4 c0, c1;
    if(tint.a > 0.0){
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

    // ===========================================================
    // Balanced Glass Lighting — mirrored highlights on both sides
    // ===========================================================
    if (oneSideLightIntensity > 0.0)
    {
        vec2 lightDirV = vec2(cos(lightRad), sin(lightRad));
        float spec = max(dot(normal, lightDirV), 0.0);
        spec = pow(spec, 8.0); // higher exponent = smaller highlight
        col.rgb += lightColor.rgb * spec * lightIntensity * (0.8 * oneSideLightIntensity);
    }
    // Apply global intensity
    col.rgb *= lightIntensity;
    float a = col.a * borderAlpha * mask;
    return vec4(col.rgb * a, a);
}



vec4 overlayPremul(vec4 base, vec4 over){
    float outA   = over.a + base.a * (1.0 - over.a);
    vec3  outRGB = over.rgb + base.rgb * (1.0 - over.a);
    return vec4(outRGB, outA);
}
#endif
