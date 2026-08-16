import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../lens/liquid_glass_lens.dart';
import '../../liquid_glass_config.dart';
import '../../liquid_glass_style.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_border_mode.dart';
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_shape.dart';
import '../liquid_glass_tab_item.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_animated_nav_bar.dart';
import 'liquid_glass_nav_bar_animated_content.dart';
import 'liquid_glass_nav_bar_content.dart';
import 'liquid_glass_nav_bar_layout.dart';
import 'liquid_glass_nav_bar_style.dart';

export 'liquid_glass_nav_bar_animated_content.dart';
export 'liquid_glass_nav_bar_animated_shell.dart';
export 'liquid_glass_nav_bar_content.dart';
export 'liquid_glass_nav_bar_icon_row.dart';
export 'liquid_glass_nav_bar_layout.dart';
export 'liquid_glass_nav_bar_pill.dart';
export 'liquid_glass_nav_bar_pill_clippers.dart';
export 'liquid_glass_nav_bar_shell.dart';
export 'liquid_glass_nav_bar_style.dart';

/// A floating, drop-in liquid-glass bottom navigation bar.
///
/// It is a single [LiquidGlassLens] capsule with the icons, labels, and
/// the selection highlight baked into the lens child — so drop it
/// wherever you want the bar to sit (most commonly the
/// `bottomNavigationBar:` slot of a `LiquidGlassScaffold`).
///
/// The bar capsule's look is one [LiquidGlassStyle] ([style] — shape +
/// appearance + refraction), plus grouped [itemStyle] / [pillStyle]
/// descriptors for the icons and selection pill.
///
/// By default the selection moves **instantly** between tabs. Set the
/// pill style's `animated: true` to make the selection pill **slide**.
/// When [pillStyle]'s `mode` enables the glass-refracting morph pill, a
/// `LiquidGlassScaffold` swaps in the self-contained dual-pipeline
/// variant via [buildGlassPillBar].
class LiquidGlassTabBar extends StatelessWidget {
  const LiquidGlassTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.itemStyle = const LiquidGlassTabItemStyle(),
    this.pillStyle = const LiquidGlassTabPillStyle(),
    this.style,
    this.visibility = true,
    this.width = 300,
    this.height = 64,
    this.margin = const EdgeInsets.only(bottom: 24),
    this.itemPadding = 6,
    this.alignment = Alignment.bottomCenter,
  })  : _impellerStandalone = false,
        assert(items.length > 0, 'Provide at least one item'),
        assert(selectedIndex >= 0 && selectedIndex < items.length,
            'selectedIndex out of range');

  /// Impeller-only, **bodyless** morph-pill bar: the animated
  /// glass-refracting morph selection pill WITHOUT a captured `body`.
  ///
  /// Drop the widget as the LAST child of a `Stack` over your page — it
  /// expands to fill (a transparent full-screen overlay with the bar at
  /// the bottom), and on Impeller the bar + pill sample the **live
  /// backdrop** (the content painted behind them), so you never hand in
  /// the page. No `LiquidGlassScaffold`, no `body`:
  ///
  /// ```dart
  /// Stack(children: [
  ///   myPage,
  ///   LiquidGlassTabBar.withImpeller(
  ///     items: items, selectedIndex: i, onChanged: (v) => setState(...),
  ///   ),
  /// ])
  /// ```
  ///
  /// On Impeller this is [buildGlassPillBar] with an empty, transparent
  /// body. On **Skia / Web** there is no live-backdrop shader and no
  /// captured page, so the morph pill can't refract — it falls back to the
  /// plain frosted single-lens bar (a real blur of the content behind it,
  /// positioned at the bottom), not a black capture. For the refracting
  /// morph pill on Skia, use `LiquidGlassScaffold` / [buildGlassPillBar]
  /// with a real `body`.
  const LiquidGlassTabBar.withImpeller({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.itemStyle = const LiquidGlassTabItemStyle(),
    this.pillStyle = const LiquidGlassTabPillStyle(),
    this.style,
    this.visibility = true,
    this.width = 300,
    this.height = 64,
    this.margin = const EdgeInsets.only(bottom: 24),
    this.itemPadding = 6,
    this.alignment = Alignment.bottomCenter,
  })  : _impellerStandalone = true,
        assert(items.length > 0, 'Provide at least one item'),
        assert(selectedIndex >= 0 && selectedIndex < items.length,
            'selectedIndex out of range');

  /// True when built via [LiquidGlassTabBar.withImpeller]: render
  /// the bodyless Impeller morph-pill overlay from [build] instead of the
  /// single-lens capsule. Internal.
  final bool _impellerStandalone;

  /// The tab items.
  final List<LiquidGlassTabBarItem> items;

  /// The selected tab index.
  final int selectedIndex;

  /// Selection callback.
  final ValueChanged<int> onChanged;

  /// Icon + label styling of the tabs (colors, icon size, label font).
  final LiquidGlassTabItemStyle itemStyle;

  /// Everything about the selection pill — highlight look, slide
  /// animation, and the glass-refracting morph mode.
  final LiquidGlassTabPillStyle pillStyle;

  /// The **bar capsule**'s look as one [LiquidGlassStyle] (shape +
  /// appearance + refraction), taken as the complete look. When `null` the
  /// tuned [defaultStyle] (full-pill optical-border shape, faint white
  /// tint, default refraction) is used. To keep the tuned default but
  /// change a single facet, compose with `copyWith`, e.g.
  /// `LiquidGlassTabBar.defaultStyle.copyWith(shape: …)`. Honored by
  /// both the plain and glass-pill bars.
  final LiquidGlassStyle? style;

  /// Whether the bar is shown; toggling animates the glass in/out.
  final bool visibility;

  /// Capsule width.
  final double width;

  /// Capsule height; also drives the default pill radius (`height / 2`).
  final double height;

  /// Outer margin honored by a host (e.g. `LiquidGlassScaffold`) when
  /// placing the bar. `margin.bottom` is the gap above the bottom edge
  /// (the safe-area inset is added on top of it); `margin.left`/
  /// `margin.right` inset the bar from the matching edge. The bar has a
  /// fixed [width], so on a centered bar symmetric left/right values are a
  /// no-op while an asymmetric pair shifts it off-center; the side insets
  /// matter most when [alignment] is biased to an edge.
  final EdgeInsets margin;

  /// Inner padding between the capsule rim and the icon row.
  final double itemPadding;

  /// Where the bar floats within its host. Defaults to
  /// [Alignment.bottomCenter]. The edge spacing comes from [margin]: the
  /// bottom gap from `margin.bottom` (plus any safe-area inset) and, when
  /// the alignment is biased to a side (e.g. [Alignment.bottomLeft]), the
  /// horizontal inset from `margin.left`/`margin.right`. Honored by
  /// `LiquidGlassScaffold` on both the plain and glass-pill paths.
  final Alignment alignment;

  /// The tuned default capsule look — a faint white frost over the
  /// default refraction. Its `shape` is `null`: the bar derives a
  /// height-tracking full-pill optical-border shape when [style] supplies
  /// no shape. Compose with `copyWith` to tweak one facet while keeping
  /// the rest of the tuned look, e.g.
  /// `style: LiquidGlassTabBar.defaultStyle.copyWith(shape: …)`.
  static const LiquidGlassStyle defaultStyle = LiquidGlassStyle(
    appearance: LiquidGlassAppearance(
      color: Color(0x16FFFFFF), // white, alpha 22
      blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
    ),
    refraction: LiquidGlassRefraction(
      distortion: 0.07,
      distortionWidth: 28,
      chromaticAberration: 0.002,
    ),
  );

  /// Which renderer(s) use the glass-refracting morphing pill.
  LiquidGlassPillMode get glassPill => pillStyle.mode;

  /// Geometry derived from this bar's size/margins, used by the animated
  /// glass variant.
  LiquidGlassTabBarLayout get navLayout => LiquidGlassTabBarLayout(
        itemCount: items.length,
        width: width,
        height: height,
        bottomMargin: margin.bottom,
        padding: itemPadding,
      );

  /// Whether [glassPill] resolves to the glass-refracting morphing pill
  /// on the active renderer.
  bool resolveGlassPill({bool? useImpellerBackdrop}) {
    switch (glassPill) {
      case LiquidGlassPillMode.none:
        return false;
      case LiquidGlassPillMode.both:
        return true;
      case LiquidGlassPillMode.impellerOnly:
        // `true`/`null` → prefer Impeller, but only when the shader path
        // is actually supported; explicit `false` forces it off.
        return (useImpellerBackdrop ?? true) &&
            ui.ImageFilter.isShaderFilterSupported;
    }
  }

  /// Builds the self-contained dual-pipeline variant of this bar — the
  /// glass-refracting morphing pill. Hosts like `LiquidGlassScaffold`
  /// check [resolveGlassPill] and call this, passing their slots through.
  ///
  /// [body] is the page content captured behind the glass. [outerChild]
  /// is the widget subtree composited above the bar (app bar, side
  /// action, extra lenses) — a full-screen `Stack` of lens-anywhere
  /// widgets. [bottomInset] is the safe-area bottom inset.
  Widget buildGlassPillBar({
    required Widget body,
    Widget? outerChild,
    Color? backgroundColor,
    double bottomInset = 0,
    double pixelRatio = 1.0,
    bool useSync = true,
    bool? useImpellerBackdrop,
    bool realTimeCapture = true,
    bool outerNeedsRealtime = false,
  }) {
    final base = navLayout;
    final layout = LiquidGlassTabBarLayout(
      itemCount: base.itemCount,
      width: base.width,
      height: base.height,
      bottomMargin: base.bottomMargin + bottomInset,
      padding: base.padding,
      pillExtraHeight: base.pillExtraHeight,
    );

    final glassStyle = pillStyle.effectiveGlass;
    final restStyle = pillStyle.effectiveRest;
    final barStyle = effectiveBarStyle;

    return LiquidGlassAnimatedNavBar(
      body: body,
      items: items,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      layout: layout,
      barPosition: resolveBarPosition(bottomInset: bottomInset),
      itemStyle: itemStyle,
      showSelectionPill: pillStyle.show,
      outerNeedsRealtime: outerNeedsRealtime,
      outerChild: outerChild,
      backgroundColor: backgroundColor,
      barShape: barStyle.shape,
      barRefraction: barStyle.refraction,
      barAppearance: barStyle.appearance,
      // The bar capsule's contact shadow rides its style's appearance —
      // the same place every lens carries one.
      barShadow: barStyle.appearance.shadow,
      pillBlur: glassStyle.appearance.blur,
      pillColor: glassStyle.appearance.color,
      pillGrowHeight: pillStyle.growHeight,
      pillRefraction: glassStyle.refraction,
      pillEnableInnerRadiusTransparent:
          glassStyle.appearance.enableInnerRadiusTransparent,
      pillShape: glassStyle.shape,
      pillShadow: glassStyle.appearance.shadow,
      restStyle: restStyle,
      travelStiffness: pillStyle.travelStiffness,
      travelDamping: pillStyle.travelDamping,
      motion: pillStyle.motion,
      magnifierPill: pillStyle.magnifierPill,
      pixelRatio: pixelRatio,
      useSync: useSync,
      useImpellerBackdrop: useImpellerBackdrop,
      realTimeCapture: realTimeCapture,
    );
  }

  /// The bar's placement derived from [alignment] and [margin], or `null`
  /// for the default bottom-center anchor with no horizontal margin (so
  /// the centered fast-path is kept untouched). [bottomInset] is the
  /// host's safe-area bottom inset, folded into `margin.bottom`.
  LiquidGlassPosition? resolveBarPosition({double bottomInset = 0}) {
    if (alignment == Alignment.bottomCenter &&
        margin.left == 0 &&
        margin.right == 0) {
      return null;
    }
    return LiquidGlassAlignPosition(
      alignment: alignment,
      margin: margin.copyWith(bottom: margin.bottom + bottomInset),
    );
  }

  /// The bar capsule's resolved look: the tuned [defaultStyle] when no
  /// [style] is given, otherwise [style] taken as the *whole* look — its
  /// appearance + refraction replace the defaults wholesale (matching how
  /// every other component merges a `style`). Its `shape` falls back to
  /// [defaultStyle]'s when null; `shape` may still be `null` here, in which
  /// case [build] / [buildGlassPillBar] supply the height-derived capsule.
  ///
  /// To tweak a single facet while keeping the rest of the tuned look,
  /// compose from the default rather than passing a bare style, e.g.
  /// `style: LiquidGlassTabBar.defaultStyle.copyWith(shape: …)`.
  LiquidGlassStyle get effectiveBarStyle => defaultStyle.merge(style);

  @override
  Widget build(BuildContext context) {
    // Bodyless Impeller path (LiquidGlassTabBar.withImpeller).
    if (_impellerStandalone) {
      // Impeller: the self-contained morph-pill bar over an empty,
      // transparent body. The pill samples the LIVE backdrop (the page
      // painted behind this overlay), so no `body` is handed in.
      if (ui.ImageFilter.isShaderFilterSupported) {
        return buildGlassPillBar(
          body: const SizedBox.expand(),
          bottomInset: MediaQuery.of(context).padding.bottom,
        );
      }
      // Skia / Web: there is no live-backdrop shader and no captured page,
      // so the morph pill's capture would come back empty (black). Fall
      // back to the plain frosted single-lens bar — its `LiquidGlassLens`
      // degrades to a real blur-of-content (the page behind it), not
      // black — positioned at the bottom like a host would place it.
      final EdgeInsets pad = MediaQuery.of(context).padding;
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: pad.bottom + margin.bottom,
            child: Align(
              alignment: Alignment(alignment.x, 0),
              child: Padding(
                padding:
                    EdgeInsets.only(left: margin.left, right: margin.right),
                child: _buildPlainBar(context),
              ),
            ),
          ),
        ],
      );
    }

    return _buildPlainBar(context);
  }

  /// The plain frosted single-lens bar (icons + selection highlight inside
  /// one [LiquidGlassLens]). The default render path, and the Skia/Web
  /// fallback for [LiquidGlassTabBar.withImpeller].
  Widget _buildPlainBar(BuildContext context) {
    final barStyle = effectiveBarStyle;
    final LiquidGlassShape effectiveShape = barStyle.shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: height / 2,
          borderWidth: 1.2,
          lightIntensity: 1.1,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.2,
            ambientIntensity: 1.0,
            borderSolidity: 0.35,
          ),
        );

    // The non-glass tiers share the rest pill's look (fill + corners +
    // opt-in border) so they match the glass-pill bar.
    final restStyle = pillStyle.effectiveRest;

    final Widget content = pillStyle.animated
        ? AnimatedBottomNavBarContent(
            items: items,
            selectedIndex: selectedIndex,
            onChanged: onChanged,
            itemPadding: itemPadding,
            showSelectionPill: pillStyle.show,
            selectionColor: restStyle.appearance.color,
            itemStyle: itemStyle,
            duration: pillStyle.animationDuration,
            curve: pillStyle.animationCurve,
            pillShape: restStyle.shape,
          )
        : BottomNavBarContent(
            items: items,
            selectedIndex: selectedIndex,
            onChanged: onChanged,
            itemPadding: itemPadding,
            showSelectionPill: pillStyle.show,
            selectionColor: restStyle.appearance.color,
            itemStyle: itemStyle,
            pillShape: restStyle.shape,
          );

    // The bar's contact shadow rides the lens's appearance
    // (`appearance.shadow`): the lens wraps itself in the ring, painting
    // it behind the glass and composing its visibility with the bar's.
    return SizedBox(
      width: width,
      height: height,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: effectiveShape,
          appearance: barStyle.appearance,
          refraction: barStyle.refraction,
        ),
        visibility: visibility,
        child: content,
      ),
    );
  }
}
