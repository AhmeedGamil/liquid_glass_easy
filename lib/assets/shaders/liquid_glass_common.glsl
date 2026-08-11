// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#ifndef LIQUID_GLASS_HELPER_GLSL
#define LIQUID_GLASS_HELPER_GLSL


#ifndef GLASS_FLOAT_PRECISION
#define GLASS_FLOAT_PRECISION highp
#endif
precision GLASS_FLOAT_PRECISION float;
#define PI 3.14159265

/* ===========================
   CONSTS / SMALL HELPERS
   =========================== */
const float EPS   = 1e-6;
const float EPS_T = 1e-3;

vec2  safe2(vec2 v){ return max(v, vec2(EPS)); }
float safe1(float v){ return max(v, EPS); }

float fastPow(float x, float n){ return exp2(n * log2(x)); }

/* ===========================
   SHAPE DATA
   =========================== */
struct ShapeData {
    float sdf;
    vec2  grad;
    vec2  normal;
    float orthoDist;
};

/* ===========================
   SHAPE-SDF GRADIENT METHOD (lens-anywhere-v4)
   ---------------------------------------------------
   How evaluateShape / evaluateSquircleRRect / evaluateContinuousRoundedRect
   turn an SDF sample into the surface normal (drives refraction) and orthoDist
   (edge AA). Choose ONE via GLASS_GRAD_METHOD — flip this single line to switch:

     GLASS_GRAD_DERIVATIVE  hardware dFdx/dFdy on the SDF value. 1 SDF eval,
                            cheapest, quad-quantised normal. *** IMPELLER ONLY ***
                            Skia's SkSL has no dFdx(float) → the program is
                            invalid SkSL and FAILS TO LOAD on Skia/web (the whole
                            lens then frosts).
     GLASS_GRAD_ANALYTIC    analytic gradient from rounded-rect geometry. 1 SDF
                            eval, NO derivatives → valid on BOTH backends. Exact
                            normal for circular corners; squircle/continuous
                            reuse the circular-corner normal direction (their SDF
                            VALUE stays exact) — visually very close.
     GLASS_GRAD_5TAP        5-tap central difference (center + 4 neighbours).
                            Exact for EVERY corner style on BOTH backends, at
                            ~5x the SDF cost.

   To compare: on Impeller flip DERIVATIVE <-> ANALYTIC; on Skia flip
   5TAP <-> ANALYTIC (DERIVATIVE won't load there). Default ANALYTIC keeps the
   single-lens shaders valid on every backend out of the box.

   NB: the metaball shader's MERGED smooth-union field uses the derivative 1-tap
   (shapeFrom1Tap) on Impeller; on Skia it propagates an ANALYTIC gradient
   (the h-weighted blend of the per-lens gradients) — see metaball_glass.frag.
   =========================== */
#define GLASS_GRAD_DERIVATIVE 0
#define GLASS_GRAD_ANALYTIC   1
#define GLASS_GRAD_5TAP       2

#ifndef GLASS_GRAD_METHOD
#define GLASS_GRAD_METHOD GLASS_GRAD_ANALYTIC
#endif

// Metaball merged-field gradient (separate from the single-lens method above).
// 1 = derivative 1-tap; 0 = the field's own 5-tap. Only metaball uses this.
// The metaball entry files pre-define it per backend (Impeller=1, Skia=0), so
// only set a default when nobody did.
#ifndef SHAPE_GRAD_1TAP
#define SHAPE_GRAD_1TAP 1
#endif

// Derivative-based gradient (dFdx/dFdy on the float SDF value). Skia's SkSL has
// no dFdx(float), and spirv-cross emits EVERY declared function whether or not
// it's called — so this is only COMPILED when actually needed: under the
// DERIVATIVE method, or when the metaball opts in via GLASS_USE_DERIVATIVE_GRAD.
//
// The hardware derivatives live in FRAMEBUFFER space, y-flipped on the GLES
// backend — mirror dFdy back so this normal matches the 5-tap one.
// Never compiled for the SkSL target (SKIA_GRAPHICS_BACKEND): dFdx(float) is
// invalid SkSL and Flutter 3.44+ rejects it at build time.
#if ((GLASS_GRAD_METHOD == GLASS_GRAD_DERIVATIVE) || defined(GLASS_USE_DERIVATIVE_GRAD)) && !defined(SKIA_GRAPHICS_BACKEND)
ShapeData shapeFrom1Tap(float fC){
    vec2 grad = vec2(dFdx(fC), dFdy(fC));
    // GLES derivative Y-flip — only on engines BEFORE the OpenGLES coordinate
    // unification (post-3.44.0 sets IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED).
    #ifdef IMPELLER_TARGET_OPENGLES
    #ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
    grad.y = -grad.y;
    #endif
    #endif
    float gL  = max(length(grad), EPS);
    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;
    return d;
}
#endif

// Analytic gradient (no derivatives → Skia-safe). One SDF evaluation, passed in
// as `sdfValue`; the normal is computed from rounded-rect geometry. Exact for
// the circular rounded rect; the squircle/continuous evaluators pass their own
// SDF value but reuse this rounded-rect normal direction at the corners.
//   corner region (q.x>0 && q.y>0): normal = sign(rel) · normalize(q)
//   edge region:                    normal = the dominant axis
ShapeData shapeFrom1TapAnalytic(vec2 p, vec2 c, vec2 hsz, float r, float sdfValue){
    vec2 rel = p - c;
    vec2 sg  = sign(rel);
    vec2 q   = abs(rel) - hsz + r;
    vec2 grad;
    if (q.x > 0.0 && q.y > 0.0) {
        grad = sg * normalize(max(q, vec2(EPS)));   // rounded corner
    } else if (q.x > q.y) {
        grad = vec2(sg.x, 0.0);                      // left / right edge
    } else {
        grad = vec2(0.0, sg.y);                      // top / bottom edge
    }
    float gL = max(length(grad), EPS);
    ShapeData o;
    o.sdf       = sdfValue;
    o.grad      = grad;
    o.normal    = grad / gL;
    o.orthoDist = sdfValue / gL;
    return o;
}

/* ===========================
   ROUNDED RECTANGLE SDF
   =========================== */
float roundedRectangleShape(vec2 p, vec2 c, vec2 h, float r){
    vec2 q = abs(p - c) - h + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

/* ===========================
   SQUIRCLE ROUNDED RECTANGLE (Ln-norm continuous corners)
   ---------------------------------------------------
   Same construction as the rounded rect, but the corner occupies a
   WIDER zone than the visual radius (Apple's continuous corners run
   ~1.528 × r along each edge) and uses an Ln-norm profile instead of
   the circular L2. `zone` is the corner-zone size in px and `n` the
   Ln exponent; both are derived ONCE per fragment from (radius,
   smoothing) by the caller — see the .frag shape branches. When
   zone == r and n == 2 this reduces exactly to the circular rounded
   rect, which is also the automatic full-radius (capsule) limit.

   NOTE: this is the "squircle" smoothing. The caller (the .frag shape
   branch) now passes a fixed smoothing of 1.0 for the squircle style.
   It is distinct from the `continuousRoundedRect*` family below, which
   is the Apple capsule-style (circular belly + tuned G2 shoulder) curve.
   =========================== */
float squircleShape(vec2 p, vec2 c, vec2 h, float zone, float n){
    vec2 q = abs(p - c) - h + zone;
    vec2 m = max(q, vec2(EPS));
    float corner = fastPow(fastPow(m.x, n) + fastPow(m.y, n), 1.0 / n) - zone;
    return min(max(q.x, q.y), 0.0) + corner;
}

/* ===========================
   SHARED: Evaluate SDF + gradient (rounded rectangle)
   =========================== */
ShapeData evaluateShape(
    vec2 fragPx,
    vec2 centerPx,
    vec2 halfSizePx,
    float radius
){
#if GLASS_GRAD_METHOD == GLASS_GRAD_DERIVATIVE
    return shapeFrom1Tap(
        roundedRectangleShape(fragPx, centerPx, halfSizePx, radius));
#elif GLASS_GRAD_METHOD == GLASS_GRAD_ANALYTIC
    return shapeFrom1TapAnalytic(fragPx, centerPx, halfSizePx, radius,
        roundedRectangleShape(fragPx, centerPx, halfSizePx, radius));
#else
    float h = 1.0;

    float fC  = roundedRectangleShape(fragPx,                  centerPx, halfSizePx, radius);
    float fXp = roundedRectangleShape(fragPx + vec2(h,0.0),    centerPx, halfSizePx, radius);
    float fXm = roundedRectangleShape(fragPx - vec2(h,0.0),    centerPx, halfSizePx, radius);
    float fYp = roundedRectangleShape(fragPx + vec2(0.0,h),    centerPx, halfSizePx, radius);
    float fYm = roundedRectangleShape(fragPx - vec2(0.0,h),    centerPx, halfSizePx, radius);

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm);
    float gL  = max(length(grad), EPS);

    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;

    return d;
#endif
}

/* ===========================
   REST-SPACE SHAPE -> SCREEN SPACE
   ---------------------------------------------------
   The flex resizes a lens instead of transforming it, so a stretched
   circle would keep its pixel radius and grow flat runs — a stadium, not
   an ellipse. The fix is to evaluate the shape at its REST size in a
   domain divided by `scale` (deformed / rest); the anisotropy then falls
   out of the mapping and every corner style stretches correctly.

   That leaves the SDF in rest units, while the AA ramp, the refraction
   band and the rim are all measured in screen px. This maps it back:
   d_screen = f / |grad_screen| with grad_screen = grad_rest / scale,
   which is first-order exact — all those consumers need is the local
   gradient.

   The derivative method is already screen-space: dFdx/dFdy differentiate
   w.r.t. the real fragment position however the SDF was parameterised, so
   its gradient (and therefore orthoDist) needs no correction.
   =========================== */
ShapeData shapeToScreen(ShapeData d, vec2 scale){
#if GLASS_GRAD_METHOD == GLASS_GRAD_DERIVATIVE
    return d;
#else
    vec2  g  = d.grad / scale;
    float gL = max(length(g), EPS);
    d.orthoDist *= max(length(d.grad), EPS) / gL;
    d.grad   = g;
    d.normal = g / gL;
    return d;
#endif
}

/* ===========================
   Continuous-corner zone + exponent from (radius, smoothing).
   ---------------------------------------------------
   smoothing 0 → zone = r, n = 2 (plain circular corner).
   smoothing 1 → zone = 1.528 r (Apple's continuous-corner extension),
   n ≈ 3.26 chosen so the curve passes through the SAME apex point as
   the circular corner of radius r — the perceived radius stays r.
   The zone is clamped to the shorter half-side, so as the radius
   approaches full (capsule) the zone collapses back to r and n → 2:
   a smooth degradation to a circular cap, exactly like iOS/Figma.
   Returns vec2(zone, n).
   =========================== */
vec2 squircleCornerParams(float r, float smoothing, float maxCorner){
    // Corner zone, clamped by the shorter half-side. As the radius
    // approaches the maximum the zone collapses back to r and the
    // exponent below lands exactly on n = 2 — the smoothing fades out
    // and the shape returns to the PLAIN rounded rectangle (a clean
    // capsule at full radius), matching iOS/Figma behavior.
    float zone  = min(r * (1.0 + 0.528 * smoothing), maxCorner);
    // Solve  1 - 2^(-1/n) = (1 - 1/sqrt(2)) * r / zone  for n, so the
    // Ln corner's 45° apex coincides with the circular corner's apex.
    float base  = 1.0 - 0.29289322 * (r / max(zone, EPS));
    float n     = -1.0 / log2(clamp(base, 0.5, 1.0 - EPS));
    return vec2(zone, n);
}

/* ===========================
   Evaluate SDF + gradient for the SQUIRCLE ROUNDED RECT.
   Same 5-tap central-difference scheme as evaluateShape; kept
   separate because it needs both the zone size AND the exponent.
   =========================== */
ShapeData evaluateSquircleRRect(
    vec2 fragPx,
    vec2 centerPx,
    vec2 halfSizePx,
    float zone,
    float n
){
#if GLASS_GRAD_METHOD == GLASS_GRAD_DERIVATIVE
    return shapeFrom1Tap(
        squircleShape(fragPx, centerPx, halfSizePx, zone, n));
#elif GLASS_GRAD_METHOD == GLASS_GRAD_ANALYTIC
    return shapeFrom1TapAnalytic(fragPx, centerPx, halfSizePx, zone,
        squircleShape(fragPx, centerPx, halfSizePx, zone, n));
#else
    float h = 1.0;
    float fC  = squircleShape(fragPx,               centerPx, halfSizePx, zone, n);
    float fXp = squircleShape(fragPx + vec2(h,0.0), centerPx, halfSizePx, zone, n);
    float fXm = squircleShape(fragPx - vec2(h,0.0), centerPx, halfSizePx, zone, n);
    float fYp = squircleShape(fragPx + vec2(0.0,h), centerPx, halfSizePx, zone, n);
    float fYm = squircleShape(fragPx - vec2(0.0,h), centerPx, halfSizePx, zone, n);

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm);
    float gL  = max(length(grad), EPS);

    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;
    return d;
#endif
}

/* ===========================
   CONTINUOUS ROUNDED RECTANGLE (capsule-style corners)
   ---------------------------------------------------
   A distinct continuous-corner model from the squircle above. Each
   corner is a p-norm ball whose box is STRETCHED along whichever edge
   has room, and whose exponent on each axis rises with that same room.
   The stretch is the whole trick: the curve leaves the edge at
   r·(1 + CRR_REACH) with zero tangent AND curvature, instead of turning
   in at r. It matches `liquidGlassContinuousRoundedRectPath` in Dart, so
   the refraction follows the same outline the clip cuts.

   t is an edge's slack, clamp((half − r) / r, 0, 1). At t = 0 the model
   collapses to reach r and exponent 2 — a circle — so a square at full
   radius is a clean capsule end. Per-AXIS is what carries capsules: an
   end cap has no room, so it stays circular while the long flank keeps
   the smoothing.

   The value is a p-norm magnitude MINUS a radius, which is what keeps
   the corner and the straight edges on speaking terms: set either
   offset to zero and the p-norm collapses to the other one, landing on
   exactly what the box formula says there. A normalized value does not
   do that, and the disagreement shows up as a seam across the corner
   box.
   =========================== */
const float CRR_REACH    = 0.2893;  // corner reach past r, at full room
const float CRR_EXP_RISE = 0.7198;  // exponent above 2, at full room
const float CRR_EPS      = 1e-6;
const float CRR_DEGEN    = 1e-20;   // both offsets vanish: no radius to pick

// Per-edge corner reach (px) PAST the radius, ramped by the room on that
// edge. reach.x runs onto the horizontal (top/bottom) edges, reach.y onto
// the vertical ones. halfSize = the lens half-extents.
vec2 continuousRoundedRectReach(float rr, vec2 halfSize){
    vec2 t = clamp((halfSize - vec2(rr)) / max(rr, CRR_EPS), 0.0, 1.0);
    return CRR_REACH * rr * t;
}

// SDF of the capsule-style continuous rounded rectangle. `reach` comes
// from continuousRoundedRectReach(); the exponent is derived from it, so
// a caller that shortens the reach softens the corner along with it.
float continuousRoundedRectShape(vec2 p, vec2 c, vec2 hsz, float rr, vec2 reach){
    vec2 a = abs(p - c);
    vec2 e = a - hsz;
    float box = min(max(e.x, e.y), 0.0) + length(max(e, vec2(0.0)));

    vec2 R = min(vec2(rr) + reach, hsz);   // the corner box
    vec2 q = a - (hsz - R);                // where we are inside it
    if (min(q.x, q.y) <= 0.0) return box;  // straight edge, or interior

    vec2  n = vec2(2.0) + CRR_EXP_RISE * reach / max(CRR_REACH * rr, CRR_EPS);
    vec2  t = pow(q / R, n);               // each axis' share of the p-norm
    float S = t.x + t.y;                   // 1 exactly on the surface
    // The box's inner corner: both shares vanish, there is no radius to
    // subtract, and the straight edges are the nearest surface anyway.
    if (S <= CRR_DEGEN) return box;

    // Radius and exponent both follow whichever axis carries the value, so on
    // either edge of the box this collapses to that axis alone and lands on
    // q - R — exactly what the box formula says there. A square box (a
    // circular corner) keeps length(q) - R, exact at any depth.
    vec2  w = t / S;
    float corner = dot(R, w) * (pow(S, 1.0 / dot(n, w)) - 1.0);

    // Inside a corner the nearest surface can be a straight edge rather than
    // the arc. Whichever is nearer wins — and on the box's edges the two
    // agree, so the branch above is seamless.
    return max(corner, box);
}

/* ===========================
   Evaluate SDF + gradient for the CONTINUOUS (capsule) ROUNDED RECT.
   Same 5-tap central-difference scheme; needs the radius and the
   per-edge shoulder reach.
   =========================== */
ShapeData evaluateContinuousRoundedRect(
    vec2 fragPx,
    vec2 centerPx,
    vec2 halfSizePx,
    float rr,
    vec2 reach
){
#if GLASS_GRAD_METHOD == GLASS_GRAD_DERIVATIVE
    return shapeFrom1Tap(
        continuousRoundedRectShape(fragPx, centerPx, halfSizePx, rr, reach));
#elif GLASS_GRAD_METHOD == GLASS_GRAD_ANALYTIC
    return shapeFrom1TapAnalytic(fragPx, centerPx, halfSizePx, rr,
        continuousRoundedRectShape(fragPx, centerPx, halfSizePx, rr, reach));
#else
    float h = 1.0;
    float fC  = continuousRoundedRectShape(fragPx,               centerPx, halfSizePx, rr, reach);
    float fXp = continuousRoundedRectShape(fragPx + vec2(h,0.0), centerPx, halfSizePx, rr, reach);
    float fXm = continuousRoundedRectShape(fragPx - vec2(h,0.0), centerPx, halfSizePx, rr, reach);
    float fYp = continuousRoundedRectShape(fragPx + vec2(0.0,h), centerPx, halfSizePx, rr, reach);
    float fYm = continuousRoundedRectShape(fragPx - vec2(0.0,h), centerPx, halfSizePx, rr, reach);

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm);
    float gL  = max(length(grad), EPS);

    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;
    return d;
#endif
}

/* ===========================
   SHARED CORE: REFRACTION FROM ANCHOR
   =========================== */
vec2 refractFromAnchorPx(
    vec2 frag,
    vec2 anchor,
    float df,
    float mag,
    float flip,
    float t
){
    vec2 v = frag - anchor;
    float s = max(df, EPS);
    vec2 refr = anchor + v / s;

    float k = smoothstep(1.0 - flip, 1.0, t);
    vec2 flipped = anchor - (refr - anchor);

    return mix(refr, flipped, k);
}

/* ===========================
   Unified Anchor Helper
   =========================== */
vec2 computeInsetAnchor(vec2 fragPx, vec2 normal, float sdf, float insetPx){
    return fragPx - normal * (sdf + insetPx);
}

/* ===========================
   DISTORTION FACTOR
   =========================== */
float computeDistortionFactor(float u_distortion, float t){
    float d = clamp(u_distortion,0.0,1.0) * 100.0;
    return 1.0 + d * pow(t, d);
}
//float computeDistortionFactor(float u_distortion, float zoneT) {
//    // clamp distortion input
//    float distortionClamped = clamp(u_distortion, 0.0, 1.0);
//    float distortionStrength = distortionClamped * 100.0;
//
//
//    // --- stronger curve (outer edge emphasis)
//    //float edgeFactorStrongCurve = pow(zoneT, distortionStrength) * 0.5;
//    float edgeFactorStrongCurve = pow(zoneT, distortionStrength);
//
//    float distortionStrong = 1.0 + distortionStrength * edgeFactorStrongCurve;
//
//    // --- softer curve (inner falloff)
//    float edgeFactorSoftCurve = pow(zoneT, 5.0) * 0.08;
//    float distortionSoft = 1.0 + distortionStrength * edgeFactorSoftCurve;
//
//    // --- combined result
//    float distortionFactor = distortionStrong + (distortionSoft - 1.0);
//    //float distortionFactor = distortionStrong;
//
//    return distortionFactor;
//}

/* ===========================
   FINAL UNIFIED REFRACTION (PX)
   =========================== */
vec2 computeShapeRefraction(
    vec2 fragPx,
    vec2 normal,
    float sdf,
    float insetPx,
    float distortionFactor,
    float magnification,
    float diagonalFlip,
    float zoneT
){
    vec2 anchor = computeInsetAnchor(fragPx, normal, sdf, insetPx);
    return refractFromAnchorPx(
        fragPx,
        anchor,
        distortionFactor,
        magnification,
        diagonalFlip,
        zoneT
    );
}

/* ===========================
   PHYSICAL REFRACTION (Snell's law via a 3D surface normal)
   ---------------------------------------------------------
   Lifts the 2D SDF gradient into a 3D normal that faces the viewer
   deep inside the glass and tilts outward at the edge, then bends the
   incident ray with refract() and displaces the sample by its
   screen-space part.

   Three independent controls:
     • refractiveIndex (IOR) — the bending ANGLE. Snell's law saturates,
       so its useful range is ~1.0–2.0; beyond that the ray is already
       fully bent and higher values barely change the look.
     • thickness        — the WIDTH of the beveled edge band (the `h` ramp).
     • strength         — HOW MUCH the sample is displaced (the public lens
       `distortion` dial, 0..1). This is the magnitude knob; without it the
       displacement is welded to `thickness` and the index becomes the only
       (saturating) control.
   REFRACTION_DEPTH_SCALE is an extra global multiplier (1.0).
   =========================== */
#ifndef REFRACTION_DEPTH_SCALE
#define REFRACTION_DEPTH_SCALE 1.0
#endif

vec2 computeRefractedPosition(
    vec2 fragPx,
    vec2 normal2D,
    float sdf,
    float thickness,
    float refractiveIndex,
    float strength,
    float zoneT
){
    // 2D gradient -> 3D surface normal.
    float h     = clamp(-sdf / max(thickness, EPS), 0.0, 1.0);
    float bulge = sqrt(max(1.0 - h * h, 0.0));
    vec3  normal3D = normalize(vec3(normal2D * bulge, h));

    // Incident ray straight into the screen.
    vec3  I   = vec3(0.0, 0.0, -1.0);
    float eta = 1.0 / max(refractiveIndex, 1.0);

    vec3 refr = refract(I, normal3D, eta);

    // Displace by the refracted ray's screen-space (xy) component. The
    // `strength` dial scales the travel distance independently of the band
    // width; the 5.0 matches the original optical tuning.
    float depth = thickness * strength * 5.0 * REFRACTION_DEPTH_SCALE * zoneT;
    return fragPx + refr.xy * depth;
}

vec2 applyLensMagnification(
    vec2 fragPx,
    vec2 lensCenterPx,
    float magnification
){
    float m = max(magnification, 0.001);
    return lensCenterPx + (fragPx - lensCenterPx) / m;
}

/* ===========================
   TINT
   =========================== */
vec3 applyLensTint(vec3 base, float mask, vec4 color, float borderAlpha){
    return (color.a > 0.001 && mask > 0.001)
        ? mix(base, color.rgb, color.a * borderAlpha * mask)
        : base;
}

#endif
