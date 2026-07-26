import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// A segmented control rendered on top of liquid glass.
///
/// The capsule itself is a single [LiquidGlassLens]; the selected
/// segment is highlighted with a brighter inner pill that animates
/// across. Tapping a segment reports its index via [onChanged]. The
/// widget is stateless on purpose — the parent owns [selectedIndex].
///
/// Drop it anywhere in your layout. Styling uses the [LiquidGlassLens]
/// vocabulary — [shape], [appearance], [refraction].
class LiquidGlassSegmentedControl extends StatelessWidget {
  const LiquidGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.width = 320,
    this.height = 36,
    this.shape,
    this.appearance = _defaultAppearance,
    this.refraction = _defaultRefraction,
    this.style,
    this.visibility = true,
    this.selectionColor = const Color(0x3CFFFFFF), // white, alpha 60
    this.selectionBorderColor = const Color(0x50FFFFFF), // alpha 80
    this.selectionDuration = const Duration(milliseconds: 220),
    this.foregroundColor = Colors.white,
    this.fontSize = 13,
    this.segmentBuilder,
  })  : assert(segments.length >= 2, 'Need at least two segments'),
        assert(selectedIndex >= 0 && selectedIndex < segments.length);

  /// The segment labels, left to right. Still required with
  /// [segmentBuilder] — it sets the segment **count**.
  final List<String> segments;

  /// Builds a segment's content instead of the plain label — an icon, an
  /// SVG, an icon + text row. Called with the segment index, whether it
  /// is selected, and [foregroundColor]. Content is centered and scaled
  /// down to fit its cell; it never sizes the control.
  final Widget Function(
    BuildContext context,
    int index,
    bool selected,
    Color color,
  )? segmentBuilder;

  /// Currently selected segment index.
  final int selectedIndex;

  /// Called with the tapped segment index.
  final ValueChanged<int> onChanged;

  /// Explicit width. When null the control hugs its content.
  final double? width;

  /// Capsule height; also drives the default pill radius (`height / 2`).
  final double height;

  /// Glass shape + border. When null, a full pill with a tuned optical
  /// border is used.
  final LiquidGlassShape? shape;

  /// The glass material: tint, blur, saturation.
  final LiquidGlassAppearance appearance;

  /// How the glass bends light.
  final LiquidGlassRefraction refraction;

  /// Full glass look as one [LiquidGlassStyle] (shape + appearance +
  /// refraction). When non-null it supersedes the individual [shape] /
  /// [appearance] / [refraction] params — the preferred, library-wide
  /// way to style this component.
  final LiquidGlassStyle? style;

  /// Whether the control is shown; toggling animates the glass in/out.
  final bool visibility;

  /// Fill color of the moving selection pill.
  final Color selectionColor;

  /// Border color of the moving selection pill.
  final Color selectionBorderColor;

  /// Slide duration of the selection pill between segments.
  final Duration selectionDuration;

  /// Color of segment labels.
  final Color foregroundColor;

  /// Font size of segment labels.
  final double fontSize;

  static const LiquidGlassAppearance _defaultAppearance =
      LiquidGlassAppearance(
    color: Color(0x14FFFFFF), // white, alpha 20
    blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
  );

  static const LiquidGlassRefraction _defaultRefraction =
      LiquidGlassRefraction(
    distortion: 0.06,
    distortionWidth: 22,
    chromaticAberration: 0.002,
  );

  @override
  Widget build(BuildContext context) {
    final LiquidGlassShape effectiveShape = shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: height / 2,
          borderWidth: 1.0,
          lightIntensity: 1.0,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.1,
            ambientIntensity: 1.0,
            borderSolidity: 0.25,
          ),
        );

    return SizedBox(
      width: width,
      height: height,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: effectiveShape,
          appearance: appearance,
          refraction: refraction,
        ).merge(style),
        visibility: visibility,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: LayoutBuilder(builder: (context, constraints) {
            final segWidth = constraints.maxWidth / segments.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: selectionDuration,
                  curve: Curves.easeOut,
                  left: selectedIndex * segWidth,
                  top: 0,
                  bottom: 0,
                  width: segWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: selectionColor,
                      borderRadius: BorderRadius.circular(height / 2),
                      border: Border.all(
                        color: selectionBorderColor,
                        width: 0.6,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < segments.length; i++)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(height / 2),
                            onTap: () => onChanged(i),
                            child: Center(
                              child: segmentBuilder != null
                                  ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: segmentBuilder!(context, i,
                                          i == selectedIndex, foregroundColor),
                                    )
                                  : Text(
                                      segments[i],
                                      style: TextStyle(
                                        color: foregroundColor,
                                        fontSize: fontSize,
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
              ],
            );
          }),
        ),
      ),
    );
  }
}
