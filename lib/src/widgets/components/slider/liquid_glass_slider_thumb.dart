import 'package:flutter/material.dart';

import '../../liquid_glass.dart';
import '../../liquid_glass_style.dart';
import '../../utils/liquid_glass_jelly_config.dart';
import '../../utils/liquid_glass_jelly_resolver.dart';
import '../../utils/liquid_glass_shape.dart';
import '../liquid_glass_morph_pill.dart';
import 'liquid_glass_slider_layout.dart';

/// Builds the moving glass thumb at the requested track position.
/// Place the result in the OUTER `LiquidGlassView`'s `children:`
/// list. While the user holds the thumb, drive [growFraction]
/// toward `1` (peak overlay size). Reverse it back to `0` on
/// release.
///
/// **Signed jelly spring:**
///
/// - [stretchFraction] (-1..1) — signed spring output. Sign tells
///   the direction the thumb is being dragged (negative = left,
///   positive = right); magnitude tells how hard. The glass pill
///   **squeezes narrower** along its long axis while
///   **stretching taller** in the cross axis (a vertical
///   "pinch & extrude" rather than a horizontal stretch — the
///   pill leans into the drag like a soft jelly bead). Its center
///   is biased slightly in the direction of motion via the sign so
///   the leading edge leads the trailing edge.
///
/// On release, drive the spring's target to 0; the spring's own
/// momentum produces a single overshoot, then settle. There is no
/// separate rebound state; the spring's underdamping handles it.
///
/// [trackLeft] / [trackBottom] are the track's bottom-left corner
/// in the OUTER view's local coordinate space.
LiquidGlass buildLiquidGlassSliderThumb({
  required LiquidGlassSliderLayout layout,
  required double trackLeft,
  required double trackBottom,
  required double value,
  required double growFraction,
  double stretchFraction = 0,

  /// `stretch` style only: the smoothed motion direction in `-1..1`
  /// (negative = left). Drives the anchor-bias lean; the deformation
  /// itself is direction-symmetric.
  double motionSign = 1,
  LiquidGlassJellyConfig jelly = const LiquidGlassJellyConfig(),

  /// Glass look of the thumb pill. When null the tuned default capsule
  /// glass is used; see [buildLiquidGlassMorphPill].
  LiquidGlassStyle? style,

  /// Optional content rendered inside the lens, above the glass (e.g.
  /// the white rest handle + its gesture surface).
  Widget? child,
}) {
  final f = growFraction.clamp(0.0, 1.0);
  final extraW = layout.thumbExtraWidth * f;
  final extraH = layout.thumbExtraHeight * f;

  // Squash/stretch via the shared resolver (the single source of the
  // jelly geometry math — also used by LiquidGlassJelly and the nav pill).
  // pinch squeezes/extrudes by the layout's thumb deltas; stretch uses
  // the jelly's stretch/squash amounts. [stretchFraction] is already the
  // style-appropriate spring output (lean spring for pinch, deform spring
  // for stretch), selected by the slider widget.
  final bool isPinch = jelly.style == LiquidGlassJellyStyle.pinchExtrude;
  final deform = resolveJellyDeformation(
    style: isPinch
        ? LiquidGlassJellyStyle.pinchExtrude
        : LiquidGlassJellyStyle.squashStretch,
    springValue: stretchFraction,
    directionSign: motionSign,
    alongAmount: isPinch ? layout.thumbSqueezeWidth : jelly.stretchWidth,
    crossAmount: isPinch ? layout.thumbStretchHeight : jelly.squashHeight,
    anchorBias: jelly.anchorBias,
    recoilScale: jelly.recoilScale,
    recoilAnchor: jelly.recoilAnchor,
    alongFloor: -layout.thumbWidth * 0.45,
    crossFloor: -layout.thumbHeight * 0.4,
  );
  final double deltaW = deform.along;
  final double deltaH = deform.cross;
  final double centerBiasX = deform.bias;

  final pillW = layout.thumbWidth + extraW + deltaW;
  final pillH = layout.thumbHeight + extraH + deltaH;

  // The refraction band is a distance inward from the rim, so it competes
  // with the pill's THICKNESS, not its length. The jelly drives both axes,
  // but only the height one matters here: squash the thumb and a band
  // authored for the full thickness keeps its absolute width, so it eats a
  // steadily larger share of what is left and the glass reads solid.
  // Thinning it by the same ratio the height lost keeps it proportional.
  //
  // Measured against the height BEFORE the jelly (rest + grow), so the
  // band is exactly as authored at rest and while merely growing — this
  // only ever engages on the deformation. Capped at 1 so a stretch
  // overshoot cannot push it past the authored width.
  final double baseH = layout.thumbHeight + extraH;
  final double refractionScale =
      baseH > 0 ? (pillH / baseH).clamp(0.0, 1.0) : 1.0;

  // Center of the rest thumb at this value, in track-local
  // coordinates. The grown pill expands evenly outward from there.
  final thumbCenterXInTrack = value * layout.travel;
  final thumbCenterYInTrack = layout.thumbHeight / 2;

  final left = trackLeft + thumbCenterXInTrack - pillW / 2 + centerBiasX;
  final bottomFromTrackBottom =
      layout.thumbHeight - thumbCenterYInTrack - pillH / 2;
  final bottom = trackBottom + bottomFromTrackBottom;

  final spec = LiquidGlassMorphPillSpec(
    width: pillW,
    restHeight: pillH,
    extraHeight: 0,
    restRadius: pillH / 2,
  );

  return buildLiquidGlassMorphPill(
    spec: spec,
    left: left,
    bottom: bottom,
    extraHeight: 0,
    style: style,
    refractionWidthScale: refractionScale,
    // The slider thumb defaults to the Apple continuous rounded rectangle
    // (honored only when the caller doesn't supply an explicit shape).
    defaultCornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
    // Thinner rim than the shared morph-pill default for a subtler thumb.
    defaultBorderWidth: 0.6,
    child: child,
  );
}
