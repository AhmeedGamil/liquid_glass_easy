// -----------------------------------------------------------------------------
// Gradient-method selector for the SINGLE-LENS shaders (liquid_glass + border).
// #include this BEFORE liquid_glass_common.glsl, which applies GLASS_GRAD_METHOD.
// -----------------------------------------------------------------------------
#ifndef LIQUID_GLASS_GRAD_SELECT_GLSL
#define LIQUID_GLASS_GRAD_SELECT_GLSL

// Internal flag. 1 = BOTH backends use the 5-tap central difference (exact for
// every corner style, ~5x SDF cost). 0 = the analytic gradient everywhere.
#ifndef LIQUID_GLASS_FORCE_5TAP
#define LIQUID_GLASS_FORCE_5TAP 0
#endif

// Raw values (the named GLASS_GRAD_* constants live in common.glsl, not yet
// included): 0 = derivative, 1 = analytic, 2 = 5-tap.
// Analytic on every backend: each pixel finds its slope alone, with no 2x2
// neighbours, so pixels are free to skip the shape (the interior fast path).
#ifndef GLASS_GRAD_METHOD
#if LIQUID_GLASS_FORCE_5TAP
#define GLASS_GRAD_METHOD 2
#else
#define GLASS_GRAD_METHOD 1
#endif
#endif

#endif
