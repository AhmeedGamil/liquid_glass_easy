// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

// Progressive scroll-edge blur, in ONE backdrop read.
//
// The tap RADIUS alone carries the falloff: it rides the curve from full
// blur at the hugged edge down to zero at the inner boundary. At zero the
// pass samples each fragment's own pixel, so it already lands on the
// sharp page exactly — no alpha ramp is needed to hide a seam, and adding
// one only squares the falloff and kills the blur mid-band. Bound through
// `ImageFilter.shader`, whose `FlutterFragCoord()` is in SCREEN physical
// pixels — every geometry uniform below is in that same space.

#include <flutter/runtime_effect.glsl>

precision highp float;

// The bound texture's size in physical px. Must stay the first uniform:
// `ImageFilter.shader` overwrites it with the real backdrop size.
uniform vec2 u_resolution;

// The band in screen physical px: origin in .xy, size in .zw.
uniform vec4 u_band;

// x = blur sigma at the hugged edge, physical px.
// y = 1 when the band hugs the top edge, 0 when it hugs the bottom.
uniform vec2 u_config;

// The falloff curve sampled into 16 stops, edge (x of the first) to
// inner boundary. Four vec4s stand in for a float[16] array uniform.
uniform vec4 u_ramp0;
uniform vec4 u_ramp1;
uniform vec4 u_ramp2;
uniform vec4 u_ramp3;

uniform sampler2D u_texture_input;

out vec4 fragColor;

// Enough taps that the disc reads as a blur rather than as copies, with
// the jitter below covering the rest.
const int   kTaps = 20;
// The turn between consecutive taps: a golden-angle spiral leaves no
// direction under-sampled at any radius.
const float kGoldenAngle = 2.39996323;
// How much of the Gaussian's mass the taps span. Cutting the tail early
// costs real radius: at 0.92 the blur lands ~12% under the sigma asked for.
const float kTailCut = 0.96;
// Below this the disc is under a pixel wide: one tap is the same picture,
// and it is also where the pass may fade out with nothing left to show.
const float kMinSigma = 0.75;

float rampStop(int i) {
    if (i < 4)  return u_ramp0[i];
    if (i < 8)  return u_ramp1[i - 4];
    if (i < 12) return u_ramp2[i - 8];
    return u_ramp3[i - 12];
}

// The curve at `t`, interpolated between the 16 packed stops.
float rampAt(float t) {
    float x = clamp(t, 0.0, 1.0) * 15.0;
    int i = int(floor(x));
    return mix(rampStop(i), rampStop(min(i + 1, 15)), x - float(i));
}

// Per-fragment spiral rotation. Without it every fragment samples the
// same 20 directions and a hard edge shows up as 20 ghosts of itself.
float dither(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 tap(vec2 fragPx) {
    vec2 uv = fragPx / u_resolution;
    // GLES sampler Y-flip — only on engines BEFORE the OpenGLES
    // coordinate unification (which defines the guard below).
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    uv.y = 1.0 - uv.y;
    #endif
    #endif
    return texture(u_texture_input, clamp(uv, vec2(0.0005), vec2(0.9995)));
}

void main() {
    vec2 fragPx = FlutterFragCoord().xy;

    // Depth into the band from the edge it hugs: 0 at that edge, 1 where
    // the band meets sharp content.
    float depth = max(u_band.w, 1.0);
    float into = u_config.y > 0.5
        ? fragPx.y - u_band.y
        : (u_band.y + u_band.w) - fragPx.y;
    float t = clamp(into / depth, 0.0, 1.0);

    // Inverted curve: full strength at the edge, none at the boundary.
    float sigma = u_config.x * (1.0 - rampAt(t));

    // Opaque wherever there is a blur to show. The fade exists ONLY for
    // the sub-pixel tail, as a guard against the backdrop snapshot not
    // being exactly pixel-aligned — never as a second falloff.
    float alpha = clamp(sigma / kMinSigma, 0.0, 1.0);

    if (sigma < kMinSigma) {
        // Premultiplied, so one factor fades colour and coverage together.
        fragColor = tap(fragPx) * alpha;
        return;
    }

    float spin = dither(fragPx) * 6.2831853;
    vec4 acc = vec4(0.0);
    for (int i = 0; i < kTaps; i++) {
        // Rayleigh inverse CDF: the taps land with the 2D Gaussian's own
        // radial density, so each one carries the same weight.
        float u = (float(i) + 0.5) / float(kTaps) * kTailCut;
        float r = sigma * sqrt(-2.0 * log(1.0 - u));
        float a = float(i) * kGoldenAngle + spin;
        acc += tap(fragPx + vec2(cos(a), sin(a)) * r);
    }
    fragColor = acc / float(kTaps);
}
