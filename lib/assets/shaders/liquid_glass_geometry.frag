// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

// The lens's shape, baked once into a texture that liquid_glass.frag reads in
// place of its SDF. Rest space, one texel per fragment px, the box `pad` in
// from the texture's top-left.
//   r,g = the edge distance over [-range, range], 16 bits (high, low)
//   b,a = the unit normal, 0.5 + 0.5 n
// Drawn with BlendMode.src, so the alpha channel carries data, not coverage.

#include <flutter/runtime_effect.glsl>
#include "liquid_glass_grad_select.glsl"
#include "liquid_glass_common.glsl"

// x,y = rest half size px  z = corner radius px  w = corner style
uniform vec4 u_box;
// x = range px  y = pad px
uniform vec4 u_bake;

out vec4 frag_color;

void main() {
    vec2 halfPx = u_box.xy;
    vec2 p = FlutterFragCoord().xy - u_bake.y;
    float maxCorner = min(halfPx.x, halfPx.y);
    float r = min(u_box.z, maxCorner);

    // The same three branches as the lens's own shape evaluation.
    ShapeData d;
    if (u_box.w > 1.5 && r > 0.5) {
        vec2 reach = continuousRoundedRectReach(r, halfPx);
        d = evaluateContinuousRoundedRect(p, halfPx, halfPx, r, reach);
    } else if (u_box.w > 0.5 && r > 0.5) {
        vec2 zn = squircleCornerParams(r, 1.0, maxCorner);
        d = evaluateSquircleRRect(p, halfPx, halfPx, zn.x, zn.y);
    } else {
        d = evaluateShape(p, halfPx, halfPx, r);
    }

    float t = clamp(0.5 + 0.5 * d.orthoDist / max(u_bake.x, EPS), 0.0, 1.0);
    float v = floor(t * 65535.0 + 0.5);
    float hi = floor(v / 256.0);
    frag_color = vec4(hi / 255.0, (v - hi * 256.0) / 255.0,
                      0.5 + 0.5 * d.normal);
}
