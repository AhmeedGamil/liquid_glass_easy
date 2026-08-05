import 'package:flutter/material.dart';

import '../../liquid_glass.dart';
import '../../liquid_glass_style.dart';
import '../liquid_glass_morph_pill.dart';
import 'liquid_glass_toggle_layout.dart';
import 'liquid_glass_toggle_motion.dart';

/// Rounds [v] to a whole device pixel.
///
/// Every rect handed to an `ImageFilter` wants to land on the device
/// pixel grid. `ImageFilter.blur` downsamples the backdrop before
/// blurring it and aligns that downsample to the filter's **bounds**, so
/// a rect that moves or resizes by fractions of a pixel re-phases the
/// grid every frame and the blurred result visibly shifts under it. The
/// handle's springs move and resize it continuously, which is exactly
/// that case — the shader pass then refracts the shifting blur and the
/// jitter shows up inside the glass.
double liquidGlassSnapToPixel(double v, double devicePixelRatio) =>
    devicePixelRatio > 0
        ? (v * devicePixelRatio).roundToDouble() / devicePixelRatio
        : v;

/// Size of the glass handle at these scales, in logical px. The track
/// cuts its hole to exactly this, so both sides read the footprint from
/// one place instead of each deriving it.
///
/// Pass [devicePixelRatio] to snap the result to whole device pixels —
/// see [liquidGlassSnapToPixel] for why that matters.
Size liquidGlassToggleThumbSize({
  required LiquidGlassToggleLayout layout,
  required double scaleX,
  required double scaleY,
  double devicePixelRatio = 0,
}) =>
    Size(
      liquidGlassSnapToPixel(layout.thumbWidth * scaleX, devicePixelRatio),
      liquidGlassSnapToPixel(layout.thumbHeight * scaleY, devicePixelRatio),
    );

/// Build the moving glass handle. [travelFraction] is `0` when off and
/// `1` when on; the parent should drive it from
/// [LiquidGlassToggleMotion.value] so the handle trails the finger
/// through a spring instead of tracking it rigidly.
///
/// [scaleX] / [scaleY] size the handle against its rest footprint —
/// `1` is the resting pill, [LiquidGlassToggleLayout.pressedScale] the
/// held one, and the two differ from each other while the handle is
/// squashing or stretching with its own momentum.
///
/// [trackLeft] / [trackBottom] are the track's bottom-left corner
/// in the outer view's local coordinate space.
LiquidGlass buildLiquidGlassToggleThumb({
  required LiquidGlassToggleLayout layout,
  required double trackLeft,
  required double trackBottom,
  required double travelFraction,
  required double scaleX,
  required double scaleY,

  /// Snaps the lens rect to whole device pixels. `0` disables it. Pass
  /// the real ratio unless you want the handle to jitter — see
  /// [liquidGlassSnapToPixel].
  double devicePixelRatio = 0,

  /// Glass look of the handle pill. When null the tuned default capsule
  /// glass is used; see [buildLiquidGlassMorphPill].
  LiquidGlassStyle? style,

  /// Optional content rendered inside the lens, above the glass (e.g.
  /// the white rest handle + its gesture surface).
  Widget? child,
}) {
  final size = liquidGlassToggleThumbSize(
    layout: layout,
    scaleX: scaleX,
    scaleY: scaleY,
    devicePixelRatio: devicePixelRatio,
  );
  final pillW = size.width;
  final pillH = size.height;

  // Center of the rest handle at this travel fraction, in track-local
  // coordinates. The swollen pill is anchored on the same center point,
  // so it grows evenly outward and settles back.
  final restCenterXInTrack =
      layout.padding + travelFraction * layout.travel + layout.thumbWidth / 2;
  final restCenterYInTrack = layout.height / 2;

  // Snapped along with the size, so the whole rect lands on the device
  // pixel grid and the blur underneath keeps a stable phase.
  final left = liquidGlassSnapToPixel(
    trackLeft + restCenterXInTrack - pillW / 2,
    devicePixelRatio,
  );
  final bottomFromTrackBottom = layout.height - restCenterYInTrack - pillH / 2;
  final bottom = liquidGlassSnapToPixel(
    trackBottom + bottomFromTrackBottom,
    devicePixelRatio,
  );

  final spec = LiquidGlassMorphPillSpec(
    width: pillW,
    restHeight: pillH,
    extraHeight: 0,
    restRadius: pillH / 2,
  );

  // The refraction band is a distance inward from the rim, so it has to
  // grow with the handle. At rest the handle is only `1 / pressedScale`
  // of its full height, and a band authored for the full size would
  // reach past its half-height and swallow the whole pill. Normalising
  // against the FULL-press height means the authored value is what you
  // get once the handle is fully swollen, and anything smaller gets a
  // proportionally narrower band.
  //
  // Driven by scaleY, not scaleX: the band competes with the pill's
  // thickness, so the momentum squash should thin it too. Capped at 1 so
  // the spring's overshoot never pushes past the authored width.
  final fullHeight = layout.thumbHeight * layout.pressedScale;
  final widthScale = fullHeight > 0
      ? ((layout.thumbHeight * scaleY) / fullHeight).clamp(0.0, 1.0)
      : 1.0;

  return buildLiquidGlassMorphPill(
    spec: spec,
    left: left,
    bottom: bottom,
    extraHeight: 0,
    style: style,
    refractionWidthScale: widthScale,
    child: child,
  );
}
