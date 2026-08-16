import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_position.dart';
import '../utils/liquid_glass_shape.dart';

/// Geometry shared between the segmented capsule lens, the
/// labels shell, and the morphing selection pill.
///
/// This is the segmented-control variant of
/// `LiquidGlassTabBarLayout` — it follows the same
/// dual-pipeline pattern (inner view captures the capsule, outer
/// view draws the moving pill on top) but is sized for an inline
/// labelled selector instead of a floating bottom bar.
class LiquidGlassMorphSegmentedLayout {
  /// Number of segments.
  final int itemCount;

  /// Width of the whole capsule.
  final double width;

  /// Height of the capsule.
  final double height;

  /// Inner padding between the capsule rim and the segments row.
  final double padding;

  /// How much taller the moving glass pill is than the cell at
  /// the peak of the morph. Drives the "bulges out and shrinks
  /// back" envelope.
  final double pillExtraHeight;

  const LiquidGlassMorphSegmentedLayout({
    required this.itemCount,
    this.width = 280,
    this.height = 44,
    this.padding = 4,
    this.pillExtraHeight = 18,
  });

  double get cellWidth => (width - padding * 2) / itemCount;
  double get cellHeight => height - padding * 2;
  double get pillWidth => cellWidth;
  double get pillHeight => cellHeight + pillExtraHeight;
}

/// Static labels row sitting on top of the capsule. Owns the tap
/// handling and reports the selection through [onChanged]. Place
/// this in the **inner** `LiquidGlassView`'s `backgroundWidget` so
/// the capsule lens refracts the wallpaper underneath while the
/// labels stay crisp.
class LiquidGlassMorphSegmentedShell extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final LiquidGlassMorphSegmentedLayout layout;

  /// Top-of-screen anchor of the capsule. The shell uses an
  /// `Align(Alignment.topCenter)` + `Padding(top: topMargin)` so
  /// the labels match the position of the capsule lens (which is
  /// placed via [buildLiquidGlassMorphSegmentedCapsule] using the
  /// same margin).
  final double topMargin;

  const LiquidGlassMorphSegmentedShell({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    required this.layout,
    this.topMargin = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: topMargin),
        child: SizedBox(
          width: layout.width,
          height: layout.height,
          child: Padding(
            padding: EdgeInsets.all(layout.padding),
            child: Row(
              children: [
                for (int i = 0; i < segments.length; i++)
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        // Suppress the Material ripple/splash so
                        // tapping a segment doesn't draw a circle
                        // expanding from the tap point — the
                        // morphing glass pill is the only
                        // selection feedback we want here, exactly
                        // like the bottom nav's hand-off pattern.
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(layout.cellHeight / 2),
                        onTap: () => onChanged(i),
                        child: Center(
                          child: Text(
                            segments[i],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: i == selectedIndex
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The capsule-shaped liquid-glass background. Place this in the
/// **inner** `LiquidGlassView`'s `children:` list so its glass
/// output is captured into the snapshot the OUTER view refracts.
LiquidGlass buildLiquidGlassMorphSegmentedCapsule({
  required LiquidGlassMorphSegmentedLayout layout,
  required double topMargin,
}) {
  return LiquidGlass(
    geometry: LiquidGlassGeometry(
      position: LiquidGlassAlignPosition(
        alignment: Alignment.topCenter,
        margin: EdgeInsets.only(top: topMargin),
      ),
      width: layout.width,
      height: layout.height,
    ),
    shape: LiquidGlassShape.roundedRectangle(
      cornerRadius: layout.height / 2,
      borderWidth: 1.0,
      lightIntensity: 1.0,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.1,
        ambientIntensity: 1.0,
        borderSolidity: 0.25,
      ),
    ),
    refraction: const LiquidGlassRefraction(
      distortion: 0.06,
      distortionWidth: 22,
      chromaticAberration: 0.002,
    ),
    appearance: LiquidGlassAppearance(
      color: Colors.white.withAlpha(20),
      blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
    ),
  );
}

/// The moving glass pill that slides between segments. Place this
/// in the **outer** `LiquidGlassView`'s `children:` list while
/// the morph animation is running. Pass [animatedIndex] as a
/// fractional value in `[0..itemCount-1]` driven by an
/// `AnimationController` running an `easeOutCubic` tween between
/// the previous and next index.
///
/// [extraHeight] grows from `0` → `layout.pillExtraHeight` → `0`
/// across the animation so the pill bulges out of the static
/// highlight at the source and shrinks back into the highlight at
/// the destination — the same morph envelope the bottom nav bar's
/// pill uses.
///
/// [extraWidth] grows in lockstep with [extraHeight], scaled so
/// the moving pill keeps the same w:h ratio as the static rest
/// pill (`pillWidth / cellHeight`) and just appears as a larger
/// version of the same shape. Always grows symmetrically (left
/// and right) so the pill stays centered on its base index.
LiquidGlass buildLiquidGlassMorphSegmentedPill({
  required LiquidGlassMorphSegmentedLayout layout,
  required double animatedIndex,
  required double parentWidth,
  required double topMargin,
  double? extraHeight,
  double? extraWidth,
}) {
  final extraH = extraHeight ?? layout.pillExtraHeight;
  // Default extraWidth keeps the rest pill's w:h ratio. The rest
  // pill is `pillWidth × cellHeight`, so the morphed pill grows
  // by the same proportion along both axes.
  final restRatio = layout.pillWidth / layout.cellHeight;
  final extraW = extraWidth ?? extraH * restRatio;

  final cellW = layout.cellWidth;
  final barLeft = (parentWidth - layout.width) / 2;
  final pillLeft = barLeft + layout.padding + animatedIndex * cellW;
  final pillH = layout.cellHeight + extraH;
  final pillW = layout.pillWidth + extraW;
  // Center the pill (taller AND wider than the cell) over the
  // cell row.
  final pillTop = topMargin + layout.padding - extraH / 2;
  final adjustedLeft = pillLeft - extraW / 2;

  return LiquidGlass(
    geometry: LiquidGlassGeometry(
      position: LiquidGlassOffsetPosition(
        left: adjustedLeft,
        top: pillTop,
      ),
      width: pillW,
      height: pillH,
    ),
    shape: LiquidGlassShape.roundedRectangle(
      cornerRadius: pillH / 2,
      borderWidth: 1.0,
      lightIntensity: 1.3,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.4,
        ambientIntensity: 1.0,
        borderSolidity: 0.5,
      ),
    ),
    refraction: const LiquidGlassRefraction(
      distortion: 0.06,
      distortionWidth: 10,
      chromaticAberration: 0.002,
    ),
    appearance: LiquidGlassAppearance(
      color: Colors.white.withAlpha(28),
      blur: const LiquidGlassBlur(sigmaX: 1.5, sigmaY: 1.5),
    ),
  );
}

/// Static rest pill — the soft selection highlight visible while
/// the glass pill is NOT on screen. Mirrors
/// `LiquidGlassBottomNavPillStatic` so the segmented control reads
/// as part of the same component family.
class LiquidGlassMorphSegmentedPillStatic extends StatelessWidget {
  final double width;
  final double height;

  const LiquidGlassMorphSegmentedPillStatic({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(60),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: Colors.white.withAlpha(80),
            width: 0.6,
          ),
        ),
      ),
    );
  }
}
