import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// **Label** group for [LiquidGlassSegmented]: how each segment's text
/// renders in selected / unselected state. Mirrors
/// [LiquidGlassNavItemStyle] so the component family reads the same.
@immutable
class LiquidGlassSegmentedLabelStyle {
  /// Color of the selected segment's label.
  final Color selectedColor;

  /// Color of unselected segments' labels.
  final Color unselectedColor;

  /// Label font size.
  final double fontSize;

  /// Font weight of the selected segment's label.
  final FontWeight selectedFontWeight;

  /// Font weight of unselected segments' labels.
  final FontWeight unselectedFontWeight;

  const LiquidGlassSegmentedLabelStyle({
    this.selectedColor = Colors.white,
    this.unselectedColor = Colors.white70,
    this.fontSize = 13,
    this.selectedFontWeight = FontWeight.w600,
    this.unselectedFontWeight = FontWeight.w500,
  });

  Color colorFor({required bool selected}) =>
      selected ? selectedColor : unselectedColor;

  FontWeight weightFor({required bool selected}) =>
      selected ? selectedFontWeight : unselectedFontWeight;

  LiquidGlassSegmentedLabelStyle copyWith({
    Color? selectedColor,
    Color? unselectedColor,
    double? fontSize,
    FontWeight? selectedFontWeight,
    FontWeight? unselectedFontWeight,
  }) {
    return LiquidGlassSegmentedLabelStyle(
      selectedColor: selectedColor ?? this.selectedColor,
      unselectedColor: unselectedColor ?? this.unselectedColor,
      fontSize: fontSize ?? this.fontSize,
      selectedFontWeight: selectedFontWeight ?? this.selectedFontWeight,
      unselectedFontWeight: unselectedFontWeight ?? this.unselectedFontWeight,
    );
  }
}

/// **Selection pill** group for [LiquidGlassSegmented]: everything about
/// the highlight behind the active segment — whether it's a real
/// glass-refracting pill or a flat tinted one, whether it slides, its
/// morph "bulge", and the look of each pill state.
///
/// Mirrors [LiquidGlassNavPillStyle]:
///  • [glass] `false` → a lightweight tinted pill (the [restStyle] fill),
///    which slides when [animated];
///  • [glass] `true` → a real [LiquidGlassLens] morphing pill that
///    refracts the capsule + backdrop, styled by [glassStyle], that bulges
///    by [growHeight] mid-travel.
@immutable
class LiquidGlassSegmentedPillStyle {
  /// Whether the selection pill is a real glass-refracting lens. When
  /// `false` the cheap tinted pill ([restStyle]) is used instead — it
  /// works on every renderer with no extra lens cost.
  final bool glass;

  /// Whether the pill **slides** between segments. When `false` the
  /// selection jumps instantly.
  final bool animated;

  /// Slide duration ([animated] only).
  final Duration duration;

  /// Easing curve for the slide ([animated] only).
  final Curve curve;

  /// How much taller the **glass** pill grows than a cell at the peak of a
  /// transition — the morph "bulge". Grows out at the source and shrinks
  /// back at the destination ([glass] + [animated] only).
  final double growHeight;

  /// The **moving glass pill**'s look as one [LiquidGlassStyle] (shape +
  /// fill/blur + refraction). A `null` shape falls back to a
  /// height-tracking capsule. [glass] only.
  final LiquidGlassStyle? glassStyle;

  /// The **rest pill**'s look — the non-refracting tinted highlight. Its
  /// `appearance.color` is the fill and its `shape` the corners (falls
  /// back to a height-tracking capsule). This is what's drawn when [glass]
  /// is `false`; with [glass] `true` it is unused.
  final LiquidGlassStyle? restStyle;

  const LiquidGlassSegmentedPillStyle({
    this.glass = true,
    this.animated = true,
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutCubic,
    this.growHeight = 14,
    this.glassStyle,
    this.restStyle,
  });

  LiquidGlassSegmentedPillStyle copyWith({
    bool? glass,
    bool? animated,
    Duration? duration,
    Curve? curve,
    double? growHeight,
    LiquidGlassStyle? glassStyle,
    LiquidGlassStyle? restStyle,
  }) {
    return LiquidGlassSegmentedPillStyle(
      glass: glass ?? this.glass,
      animated: animated ?? this.animated,
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      growHeight: growHeight ?? this.growHeight,
      glassStyle: glassStyle ?? this.glassStyle,
      restStyle: restStyle ?? this.restStyle,
    );
  }

  /// The moving glass pill's resolved look for a pill of [radius] corner
  /// radius: [glassStyle] when set (its `null` shape filled with a
  /// capsule of [radius]), otherwise the shipped default — a faint white
  /// tint over a tight refraction band and a bright optical rim.
  LiquidGlassStyle resolveGlass(double radius) {
    final g = glassStyle;
    return LiquidGlassStyle(
      shape: g?.shape ?? _capsule(radius, solidity: 0.5, light: 1.3, sat: 1.4),
      appearance: g?.appearance ??
          const LiquidGlassAppearance(
            color: Color(0x1CFFFFFF), // white, alpha 28
            blur: LiquidGlassBlur(sigmaX: 1.5, sigmaY: 1.5),
          ),
      refraction: g?.refraction ??
          const LiquidGlassRefraction(
            distortion: 0.06,
            distortionWidth: 10,
            chromaticAberration: 0.002,
          ),
    );
  }

  /// The rest pill's resolved fill + corners for a pill of [radius].
  LiquidGlassStyle resolveRest(double radius) {
    final r = restStyle;
    return LiquidGlassStyle(
      shape: r?.shape ?? _capsule(radius, solidity: 0, light: 1, sat: 1),
      appearance: r?.appearance ??
          const LiquidGlassAppearance(color: Color(0x3CFFFFFF)), // white, a60
    );
  }
}

/// A drop-in liquid-glass **segmented control** with a morphing glass
/// pill — the inline sibling of [LiquidGlassBottomNavBar].
///
/// The capsule is one [LiquidGlassLens] styled by [style]; the active
/// segment is marked by a selection pill configured through [pillStyle]
/// — either a real glass-refracting [LiquidGlassLens] that morphs and
/// bulges as it slides ([LiquidGlassSegmentedPillStyle.glass] `true`,
/// the default) or a cheap tinted highlight (`glass: false`). Labels are
/// styled by [labelStyle].
///
/// Like every lens-anywhere widget it works standalone on Impeller (no
/// `LiquidGlassView` needed) and refracts a captured background when
/// placed inside a `LiquidGlassView` on Skia / Web.
///
/// ```dart
/// LiquidGlassSegmented(
///   segments: const ['Day', 'Week', 'Month'],
///   selectedIndex: _i,
///   onChanged: (i) => setState(() => _i = i),
///   // turn the glass pill off for the lightweight tinted highlight:
///   // pillStyle: const LiquidGlassSegmentedPillStyle(glass: false),
/// )
/// ```
class LiquidGlassSegmented extends StatefulWidget {
  const LiquidGlassSegmented({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.style,
    this.pillStyle = const LiquidGlassSegmentedPillStyle(),
    this.labelStyle = const LiquidGlassSegmentedLabelStyle(),
    this.width = 280,
    this.height = 44,
    this.padding = 4,
    this.segmentBuilder,
  })  : assert(segments.length > 0, 'Provide at least one segment'),
        assert(selectedIndex >= 0 && selectedIndex < segments.length,
            'selectedIndex out of range');

  /// The segment labels. Still required with [segmentBuilder] — it sets
  /// the segment **count**; pass empty strings if the builder draws
  /// everything.
  final List<String> segments;

  /// The selected segment index.
  final int selectedIndex;

  /// Selection callback.
  final ValueChanged<int> onChanged;

  /// The **capsule**'s look as one [LiquidGlassStyle] (shape + appearance
  /// + refraction). Any facet left unset falls back to a tuned default: a
  /// height-tracking full-pill optical-border shape, a faint white tint,
  /// and a soft refraction.
  final LiquidGlassStyle? style;

  /// Everything about the selection pill — glass vs tinted, slide, morph,
  /// and the look of each pill state.
  final LiquidGlassSegmentedPillStyle pillStyle;

  /// Label colors / weights / size.
  final LiquidGlassSegmentedLabelStyle labelStyle;

  /// Capsule width. Pass `double.infinity` to fill the available width.
  final double width;

  /// Capsule height; also drives the default pill radius (`height / 2`).
  final double height;

  /// Inner padding between the capsule rim and the segment row (and the
  /// gap the pill keeps from the rim).
  final double padding;

  /// Builds a segment's content instead of the plain label — an icon, an
  /// SVG, an icon + text row. Called with the segment index, whether it
  /// is selected, and the [labelStyle] color already resolved for that
  /// state, so custom content follows the same palette the labels do.
  /// Content is centered and scaled down to fit its cell; it never sizes
  /// the capsule.
  final Widget Function(
    BuildContext context,
    int index,
    bool selected,
    Color color,
  )? segmentBuilder;

  @override
  State<LiquidGlassSegmented> createState() => _LiquidGlassSegmentedState();
}

class _LiquidGlassSegmentedState extends State<LiquidGlassSegmented>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.pillStyle.duration,
    value: 1, // start settled on the initial selection
  )..addListener(_onTick);

  /// Endpoints of the current slide, in fractional segment-index units.
  late double _from = widget.selectedIndex.toDouble();
  late double _to = widget.selectedIndex.toDouble();

  void _onTick() => setState(() {});

  @override
  void didUpdateWidget(LiquidGlassSegmented old) {
    super.didUpdateWidget(old);
    _controller.duration = widget.pillStyle.duration;
    if (old.selectedIndex != widget.selectedIndex) {
      // Slide from wherever the pill currently is to the new target.
      _from = _animatedIndex;
      _to = widget.selectedIndex.toDouble();
      if (widget.pillStyle.animated) {
        _controller.forward(from: 0);
      } else {
        _from = _to;
        _controller.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Current fractional segment index the pill sits at.
  double get _animatedIndex {
    final t = widget.pillStyle.curve.transform(_controller.value);
    return lerpDouble(_from, _to, t)!;
  }

  /// Morph "bulge" progress: 0 at the endpoints, 1 mid-travel.
  double get _morph =>
      widget.pillStyle.animated ? math.sin(math.pi * _controller.value) : 0.0;

  /// Fraction of a transition spent settling the glass pill into the
  /// destination rest pill (the fade-out tail).
  static const double _settleFraction = 0.22;

  /// Opacity of the moving glass pill. It **lifts off instantly** at the
  /// source cell (full opacity at `t = 0`, swapping cleanly with the rest
  /// pill that sat there) and only **fades out** over the last
  /// [_settleFraction] as it arrives — so it is the sole indicator for the
  /// whole travel and never leaves a gap.
  double get _glassOpacity {
    final pill = widget.pillStyle;
    if (!pill.glass) return 0;
    if (!pill.animated) return 1; // static glass pill, always shown
    return ((1 - _controller.value) / _settleFraction).clamp(0.0, 1.0);
  }

  /// Opacity of the tinted rest pill. It is the inverse hand-off of the
  /// glass pill: hidden for the whole travel (so it never flashes at the
  /// destination) and fading in only as the glass pill settles.
  double get _restOpacity {
    final pill = widget.pillStyle;
    if (!pill.glass) return 1; // the only indicator — always visible
    if (!pill.animated) return 0; // static glass pill leaves no rest pill
    return 1 - _glassOpacity;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width.isFinite ? widget.width : null,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double w =
              widget.width.isFinite ? widget.width : constraints.maxWidth;
          return _build(w);
        },
      ),
    );
  }

  Widget _build(double w) {
    final n = widget.segments.length;
    final pad = widget.padding;
    final cellW = (w - pad * 2) / n;
    final cellH = widget.height - pad * 2;

    final pill = widget.pillStyle;
    final idx = _animatedIndex;

    // Morph growth (glass pill only). Keeps the rest pill's w:h ratio so
    // it reads as a bigger version of the same capsule.
    final growH = pill.glass ? pill.growHeight * _morph : 0.0;
    final growW = growH * (cellW / cellH);
    final pillH = cellH + growH;
    final pillW = cellW + growW;
    final pillLeft = pad + idx * cellW - growW / 2;
    final pillTop = pad - growH / 2;

    // Hand-off cross-fade (glass + animated only): a tinted rest pill sits
    // at the committed selection; the glass pill fades IN as it lifts off
    // and travels, then fades OUT into the rest pill at the destination —
    // so the costly glass lens only lives while the pill is moving.
    final glassOpacity = _glassOpacity;
    final restOpacity = _restOpacity;

    // When the tinted pill is the *only* indicator (glass off) it slides
    // itself; with the glass pill on it's the static rest pill, parked at
    // the committed selection while the glass pill carries the motion.
    final double restIndex = pill.glass ? widget.selectedIndex.toDouble() : idx;
    final double restLeft = pad + restIndex * cellW;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── the capsule: the whole-component glass ──
        Positioned.fill(
          child: LiquidGlassLens(style: _capsuleStyle()),
        ),

        // ── the tinted rest pill (static hand-off target, or the sole
        //    sliding indicator when the glass pill is off) ──
        if (restOpacity > 0.001)
          Positioned(
            left: restLeft,
            top: pad,
            width: cellW,
            height: cellH,
            child: Opacity(
              opacity: restOpacity,
              child: _tintedPill(pill.resolveRest(cellH / 2)),
            ),
          ),

        // ── the moving glass pill (only built while it's visible) ──
        // The fade is folded into the lens STYLE (distortion / tint / blur
        // / rim scaled toward 0), NOT an `Opacity` wrapper: an Opacity
        // layer isolates the live Impeller backdrop the lens samples, so
        // the glass would render broken. Dissolving via shader uniforms is
        // backdrop-safe on every renderer.
        if (pill.glass && glassOpacity > 0.001)
          Positioned(
            left: pillLeft,
            top: pillTop,
            width: pillW,
            height: pillH,
            child: LiquidGlassLens(
              style: _fadeStyle(pill.resolveGlass(pillH / 2), glassOpacity),
            ),
          ),

        // ── labels (on top, tappable) ──
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  for (int i = 0; i < n; i++)
                    Expanded(
                      child: InkWell(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        borderRadius: BorderRadius.circular(cellH / 2),
                        onTap: () {
                          if (i != widget.selectedIndex) widget.onChanged(i);
                        },
                        child: Center(
                          child: widget.segmentBuilder != null
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: widget.segmentBuilder!(
                                    context,
                                    i,
                                    i == widget.selectedIndex,
                                    widget.labelStyle.colorFor(
                                        selected: i == widget.selectedIndex),
                                  ),
                                )
                              : Text(
                                  widget.segments[i],
                                  style: TextStyle(
                                    color: widget.labelStyle.colorFor(
                                        selected: i == widget.selectedIndex),
                                    fontSize: widget.labelStyle.fontSize,
                                    fontWeight: widget.labelStyle.weightFor(
                                        selected: i == widget.selectedIndex),
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
      ],
    );
  }

  /// The capsule look — the tuned default overlaid by [widget.style].
  LiquidGlassStyle _capsuleStyle() {
    final base = LiquidGlassStyle(
      shape: _capsule(widget.height / 2, solidity: 0.25, light: 1, sat: 1.1),
      appearance: const LiquidGlassAppearance(
        color: Color(0x14FFFFFF), // white, alpha 20
        blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.06,
        distortionWidth: 22,
        chromaticAberration: 0.002,
      ),
    );
    return base.merge(widget.style);
  }

  /// Dissolves a glass [style] toward invisible by scaling its visible
  /// quantities by [f] (`1` = full glass, `0` = gone): refraction
  /// distortion + chroma, tint alpha, blur, and the rim (border width +
  /// light) all fade together. Unlike an `Opacity` wrapper this keeps the
  /// lens's backdrop sampling intact on Impeller.
  LiquidGlassStyle _fadeStyle(LiquidGlassStyle style, double f) {
    if (f >= 0.999) return style;
    final shape = style.shape;
    final color = style.appearance.color;
    final blur = style.appearance.blur;
    final refractionType = style.refraction.refractionType;
    return LiquidGlassStyle(
      shape: shape == null
          ? null
          : LiquidGlassShape(
              cornerStyle: shape.cornerStyle,
              cornerRadius: shape.cornerRadius,
              clipQuality: shape.clipQuality,
              borderWidth: shape.borderWidth * f,
              borderColor: shape.borderColor,
              lightIntensity: shape.lightIntensity * f,
              lightColor: shape.lightColor,
              lightDirection: shape.lightDirection,
              lightMode: shape.lightMode,
              borderType: shape.borderType,
            ),
      appearance: style.appearance.copyWith(
        color: color.withValues(alpha: color.a * f),
        blur: LiquidGlassBlur(sigmaX: blur.sigmaX * f, sigmaY: blur.sigmaY * f),
      ),
      refraction: style.refraction.copyWith(
        distortion:
            refractionType == null ? style.refraction.distortion * f : null,
        refractionType: refractionType?.withEffectFactor(f),
        chromaticAberration: style.refraction.chromaticAberration * f,
      ),
    );
  }

  /// The cheap tinted pill used when the glass pill is disabled.
  Widget _tintedPill(LiquidGlassStyle rest) {
    final radius =
        rest.shape?.cornerRadius ?? (widget.height - widget.padding * 2) / 2;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rest.appearance.color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A height-tracking full-pill optical-border capsule shape, shared by
/// the segmented control's capsule and its pills.
LiquidGlassShape _capsule(
  double radius, {
  required double solidity,
  required double light,
  required double sat,
}) {
  return LiquidGlassShape.roundedRectangle(
    cornerRadius: radius,
    borderWidth: 1,
    lightIntensity: light,
    lightDirection: 80,
    borderType: OpticalBorder(
      borderSaturation: sat,
      ambientIntensity: 1.0,
      borderSolidity: solidity,
    ),
  );
}
