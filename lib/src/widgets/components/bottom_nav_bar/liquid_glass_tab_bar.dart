import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../lens/liquid_glass_lens.dart';
import '../../lens/liquid_glass_lens_scope.dart';
import '../../liquid_glass_style.dart';
import '../../utils/liquid_glass_light.dart';
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_adaptivity.dart';
import '../../utils/liquid_glass_shape.dart';
import '../liquid_glass_adaptive_area.dart';
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
/// Most commonly it goes in the `bottomNavigationBar:` slot of a
/// `LiquidGlassScaffold`, which places it and feeds its glass.
///
/// It also works **on its own**. Where it finds no host above it (no
/// `LiquidGlassScaffold` or `LiquidGlassView`), a bar whose
/// [pillStyle] `mode` is a glass mode fills its parent and places itself
/// from [alignment] and [margin] — so drop it as the LAST child of a
/// `Stack` over your page:
///
/// ```dart
/// Stack(children: [
///   myPage,
///   LiquidGlassTabBar(
///     items: items, selectedIndex: i, onChanged: (v) => setState(...),
///   ),
/// ])
/// ```
///
/// On Impeller the bar and its morph pill sample the **live backdrop**,
/// so the page is never handed in. On Skia / Web there is no live-backdrop
/// shader and no captured page, so it falls back to the plain frosted
/// single-lens bar, placed the same way. For the refracting morph pill on
/// Skia, use a `LiquidGlassScaffold` with a real `body`.
///
/// With `mode: LiquidGlassPillMode.none` the bar is a plain [width] x
/// [height] capsule instead — a single [LiquidGlassLens] with the icons,
/// labels and selection highlight baked into its child — that you
/// position yourself (a `Column`, an `Align`, a Material `Scaffold`).
///
/// The bar capsule's look is one [LiquidGlassStyle] ([style] — shape +
/// appearance + refraction), plus grouped [itemStyle] / [pillStyle]
/// descriptors for the icons and selection pill.
///
/// By default the selection moves **instantly** between tabs. Set the
/// pill style's `animated: true` to make the selection pill **slide**.
/// When [pillStyle]'s `mode` enables the glass-refracting morph pill, a
/// `LiquidGlassScaffold` — or the bar itself, standing alone — swaps in
/// the self-contained dual-pipeline variant via [buildGlassPillBar].
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
  })  : assert(items.length > 0, 'Provide at least one item'),
        assert(selectedIndex >= 0 && selectedIndex < items.length,
            'selectedIndex out of range');

  /// The same bar as the default constructor, which now places itself
  /// when it has no host.
  @Deprecated('Use LiquidGlassTabBar(...): outside a LiquidGlassScaffold it '
      'places itself as this constructor did. Deprecated in 5.0.0.')
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
  })  : assert(items.length > 0, 'Provide at least one item'),
        assert(selectedIndex >= 0 && selectedIndex < items.length,
            'selectedIndex out of range');

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
    specular: LiquidGlassLight.specular(),
    color: Color(0x16FFFFFF),
    blur: 2,
    refractionIndex: 1.1,
    refractionWidth: 12,
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
  /// [body] is the page content captured behind the glass. [chromeChild]
  /// is the host's chrome (app bar, side action, extra lenses) — a
  /// full-screen `Stack` of lens-anywhere widgets — which the bar places
  /// by renderer: in the outer view over the bar and the pill on Impeller,
  /// in the inner view under the bar's cells on Skia, where the outer
  /// capture then sleeps whenever the pill is at rest. [outerChild] is the
  /// explicit outer slot on both renderers; pass [outerNeedsRealtime]
  /// while it is showing. [bottomInset] is the safe-area bottom inset.
  /// [batch] is off by default: every lens in both views takes a read of
  /// its own.
  Widget buildGlassPillBar({
    required Widget body,
    Widget? chromeChild,
    Widget? outerChild,
    Color? backgroundColor,
    double bottomInset = 0,
    double pixelRatio = 1.0,
    bool useSync = true,
    bool? useImpellerBackdrop,
    bool batch = false,
    int? foregroundBatchId,
    bool realTimeCapture = true,
    bool outerNeedsRealtime = false,
    LiquidGlassAdaptiveSampling? adaptiveSampling,
    LiquidGlassAdaptiveSampling? outerAdaptiveSampling,
    LiquidGlassAdaptivity? areaAdaptivity,
    LiquidGlassAdaptivityLink? areaLink,
    LiquidGlassSystemChrome systemChrome = LiquidGlassSystemChrome.none,
  }) {
    return _glassPillBar(
      body: body,
      chromeChild: chromeChild,
      outerChild: outerChild,
      backgroundColor: backgroundColor,
      bottomInset: bottomInset,
      pixelRatio: pixelRatio,
      useSync: useSync,
      useImpellerBackdrop: useImpellerBackdrop,
      batch: batch,
      foregroundBatchId: foregroundBatchId,
      realTimeCapture: realTimeCapture,
      outerNeedsRealtime: outerNeedsRealtime,
      adaptiveSampling: adaptiveSampling,
      outerAdaptiveSampling: outerAdaptiveSampling,
      areaAdaptivity: areaAdaptivity,
      areaLink: areaLink,
      systemChrome: systemChrome,
      sampleBackground: true,
    );
  }

  /// [buildGlassPillBar], plus whether the inner view samples its body
  /// for adaptivity — off for the bodyless standalone bar.
  Widget _glassPillBar({
    required Widget body,
    Widget? chromeChild,
    Widget? outerChild,
    Color? backgroundColor,
    double bottomInset = 0,
    double pixelRatio = 1.0,
    bool useSync = true,
    bool? useImpellerBackdrop,
    bool batch = false,
    int? foregroundBatchId,
    bool realTimeCapture = true,
    bool outerNeedsRealtime = false,
    LiquidGlassAdaptiveSampling? adaptiveSampling,
    LiquidGlassAdaptiveSampling? outerAdaptiveSampling,
    LiquidGlassAdaptivity? areaAdaptivity,
    LiquidGlassAdaptivityLink? areaLink,
    LiquidGlassSystemChrome systemChrome = LiquidGlassSystemChrome.none,
    required bool sampleBackground,
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
      chromeChild: chromeChild,
      outerChild: outerChild,
      backgroundColor: backgroundColor,
      barShape: barStyle.shape,
      barSpecular: barStyle.specular,
      barGlow: barStyle.glow,
      barSecondSpecular: barStyle.secondSpecular,
      barRefraction: barStyle.refraction,
      barAppearance: barStyle.appearance,
      // The bar capsule's contact shadow rides its style's appearance —
      // the same place every lens carries one.
      barShadow: barStyle.appearance.shadow,
      pillBlur: glassStyle.appearance.blur,
      pillColor: glassStyle.appearance.color,
      pillGrowHeight: pillStyle.growHeight,
      pillRefraction: glassStyle.refraction,
      pillShape: glassStyle.shape,
      pillSpecular: glassStyle.specular,
      pillGlow: glassStyle.glow,
      pillSecondSpecular: glassStyle.secondSpecular,
      pillShadow: glassStyle.appearance.shadow,
      restStyle: restStyle,
      travelStiffness: pillStyle.travelStiffness,
      travelDamping: pillStyle.travelDamping,
      motion: pillStyle.motion,
      magnifierPill: pillStyle.magnifierPill,
      pixelRatio: pixelRatio,
      useSync: useSync,
      useImpellerBackdrop: useImpellerBackdrop,
      batch: batch,
      foregroundBatchId: foregroundBatchId,
      realTimeCapture: realTimeCapture,
      adaptivity: barStyle.adaptivity,
      adaptiveSampling: adaptiveSampling,
      outerAdaptiveSampling: outerAdaptiveSampling,
      areaAdaptivity: areaAdaptivity,
      areaLink: areaLink,
      systemChrome: systemChrome,
      // The bodyless standalone bar has nothing behind its inner view to
      // sample (the real page is painted below the overlay, out of
      // reach), so adaptivity falls back to a manual `permanentBrightness`,
      // a followed link, or the platform brightness — like a standalone lens.
      sampleBackground: sampleBackground,
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
    // A host (a `LiquidGlassScaffold`, or any `LiquidGlassView`) places
    // the bar and feeds its glass; `mode: none` is placed by the caller.
    // Either way: the plain capsule.
    if (glassPill == LiquidGlassPillMode.none ||
        LiquidGlassLensScope.maybeOf(context) != null) {
      return _buildPlainBar(context);
    }

    // On its own, a glass-mode bar is a full-screen overlay that places
    // itself.
    if (resolveGlassPill() && ui.ImageFilter.isShaderFilterSupported) {
      // Impeller: the self-contained morph-pill bar over an empty,
      // transparent body. The pill samples the LIVE backdrop (the page
      // painted behind this overlay), so no `body` is handed in.
      return _glassPillBar(
        body: const SizedBox.expand(),
        bottomInset: MediaQuery.of(context).padding.bottom,
        sampleBackground: false,
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
              padding: EdgeInsets.only(left: margin.left, right: margin.right),
              child: _buildPlainBar(context),
            ),
          ),
        ),
      ],
    );
  }

  /// The plain frosted single-lens bar (icons + selection highlight inside
  /// one [LiquidGlassLens]). Used under a host, with `mode: none`, and as
  /// the Skia/Web fallback of the standalone bar.
  Widget _buildPlainBar(BuildContext context) {
    final barStyle = effectiveBarStyle;
    final LiquidGlassShape effectiveShape = barStyle.shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: height / 2,
        );

    // The non-glass tiers share the rest pill's look (fill + corners +
    // opt-in border) so they match the glass-pill bar.
    final restStyle = pillStyle.effectiveRest;

    // Adaptivity (style.adaptivity, or an enclosing adaptive area): the
    // lens samples/follows, animates its glass tint, and installs the
    // animated content color as the ambient IconTheme/DefaultTextStyle —
    // the adaptive cells below pick it up from there.
    final bool adaptive = barStyle.adaptivity != null ||
        LiquidGlassAdaptiveArea.maybeOf(context) != null;
    // A bar that adapts brings its pill along on the shipped palette,
    // whether that adaptivity is the bar's OWN or inherited from an
    // enclosing area/scaffold — the pill contrasts the CAPSULE, and the
    // capsule flips either way. `rest.adaptivity` overrides the palette;
    // `LiquidGlassAdaptivity.none` keeps a caller-chosen fill fixed.
    final LiquidGlassAdaptivity? pillAdaptivity = adaptive
        ? (restStyle.adaptivity ??
            LiquidGlassTabPillStyle.defaultRestAdaptivity)
        : null;

    final Widget content = pillStyle.animated
        ? AnimatedBottomNavBarContent(
            items: items,
            selectedIndex: selectedIndex,
            onChanged: onChanged,
            itemPadding: itemPadding,
            showSelectionPill: pillStyle.show,
            selectionColor: restStyle.appearance.color,
            selectionAdaptivity: pillAdaptivity,
            itemStyle: itemStyle,
            duration: pillStyle.animationDuration,
            curve: pillStyle.animationCurve,
            pillShape: restStyle.shape,
            adaptive: adaptive,
          )
        : BottomNavBarContent(
            items: items,
            selectedIndex: selectedIndex,
            onChanged: onChanged,
            itemPadding: itemPadding,
            showSelectionPill: pillStyle.show,
            selectionColor: restStyle.appearance.color,
            selectionAdaptivity: pillAdaptivity,
            itemStyle: itemStyle,
            pillShape: restStyle.shape,
            adaptive: adaptive,
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
          specular: barStyle.specular,
          glow: barStyle.glow,
          saturation: barStyle.saturation,
          blur: barStyle.blur,
          color: barStyle.color,
          shadow: barStyle.shadow,
          refractionIndex: barStyle.refractionIndex,
          refractionWidth: barStyle.refractionWidth,
          magnification: barStyle.magnification,
          dispersion: barStyle.dispersion,
          adaptivity: barStyle.adaptivity,
          liteGlass: barStyle.liteGlass,
        ),
        visibility: visibility,
        child: content,
      ),
    );
  }
}
