import 'package:flutter/material.dart';

import '../../controllers/liquid_glass_view_controller.dart';
import '../liquid_glass_view.dart';
import '../utils/liquid_glass_refresh_rate.dart';
import 'bottom_nav_bar/liquid_glass_tab_bar.dart';

/// A `Scaffold`-style layout for liquid-glass UIs.
///
/// [LiquidGlassScaffold] owns a single [LiquidGlassView] internally so
/// you don't have to wire one up by hand. Your page content goes in
/// [body] and becomes the **background** that every glass slot refracts;
/// the [appBar], [bottomNavigationBar], and [bottomNavigationBarAction]
/// are placed on top of it as ordinary widgets (typically the package's
/// `LiquidGlassLens`-based components).
///
/// ```dart
/// LiquidGlassScaffold(
///   appBar: LiquidGlassAppBar(
///     title: const Text('Gallery'),
///     actions: const [Icon(Icons.search)],
///   ),
///   body: MyPageContent(),
///   bottomNavigationBar: LiquidGlassTabBar(
///     items: const [
///       LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
///       LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Search'),
///       LiquidGlassTabBarItem(icon: Icons.person_rounded, label: 'You'),
///     ],
///     selectedIndex: _index,
///     onChanged: (i) => setState(() => _index = i),
///   ),
///   bottomNavigationBarAction: LiquidGlassTabBarAction(
///     icon: Icons.add_rounded,
///     onTap: _compose,
///   ),
/// )
/// ```
///
/// The renderer is chosen automatically — Impeller devices sample the
/// live backdrop, Skia / Web fall back to a captured snapshot — so the
/// same scaffold runs on both.
///
/// ### Z-order
///
/// Slots are composited bottom-to-top:
/// `lenses` → `appBar` → `bottomNavigationBar` →
/// `bottomNavigationBarAction` → `floatingActionButton`.
class LiquidGlassScaffold extends StatelessWidget {
  /// Clearance assumed under the FAB for a bottom bar the scaffold cannot
  /// measure. Override it with [floatingActionButtonClearance].
  static const double kFallbackNavClearance = 64;

  /// The primary content of the screen. Rendered behind every glass slot
  /// and used as the background the lenses refract.
  final Widget body;

  /// A glass app bar pinned to the top. Typically a [LiquidGlassAppBar].
  final Widget? appBar;

  /// A glass bottom navigation bar pinned to the bottom. Typically a
  /// [LiquidGlassTabBar].
  final Widget? bottomNavigationBar;

  /// A standalone glass action that floats at the bottom-right, the
  /// common "tab bar + side action" pairing. Typically a
  /// [LiquidGlassTabBarAction].
  final Widget? bottomNavigationBarAction;

  /// A floating action button, typically a [LiquidGlassFab].
  ///
  /// With the default alignment this shares the bottom-end corner with
  /// [bottomNavigationBarAction]; the button is lifted clear of the bar,
  /// so use both only when there is a [bottomNavigationBar] between them.
  final Widget? floatingActionButton;

  /// Position of [floatingActionButton]. Defaults to the bottom-end
  /// corner — bottom-right in LTR, bottom-left in RTL. Pass a plain
  /// [Alignment] to pin a physical side, or any offset to nudge it.
  final AlignmentGeometry floatingActionButtonAlignment;

  /// Room kept clear below a bottom-aligned [floatingActionButton] so it
  /// floats above the [bottomNavigationBar].
  ///
  /// Left `null` the scaffold measures a [LiquidGlassTabBar] itself. Any
  /// other bar can't be measured from here, so it falls back to
  /// [kFallbackNavClearance] — set this when yours is a different height.
  /// Ignored unless the button is aligned toward the bottom.
  final double? floatingActionButtonClearance;

  /// Extra free-floating glass widgets composited between the [body] and
  /// the bars. An escape hatch — position each with your own
  /// `Align`/`Positioned`.
  final List<Widget> lenses;

  /// Optional solid color painted behind [body]. Leave `null` to let
  /// [body] supply its own background.
  final Color? backgroundColor;

  /// Whether the bars automatically clear the device safe areas. When
  /// `true` (the default), the [appBar] is pushed below the top inset and
  /// the bottom slots above the bottom inset. The [body] still fills the
  /// whole window behind the glass.
  final bool safeArea;

  /// Extra space above the [appBar], in addition to the safe-area inset.
  final double appBarTopMargin;

  /// Bottom-right padding applied to [bottomNavigationBarAction].
  final double actionMargin;

  // ── Render pipeline (forwarded to the internal LiquidGlassView) ──

  /// Controls the internal view's capture pipeline. Optional.
  final LiquidGlassViewController? controller;

  /// See [LiquidGlassView.pixelRatio].
  final double pixelRatio;

  /// See [LiquidGlassView.realTimeCapture].
  final bool realTimeCapture;

  /// See [LiquidGlassView.useSync].
  final bool useSync;

  /// See [LiquidGlassView.refreshRate].
  final LiquidGlassRefreshRate refreshRate;

  /// See [LiquidGlassView.useImpellerBackdrop]. Leave `null` for
  /// automatic Skia / Impeller detection.
  final bool? useImpellerBackdrop;

  const LiquidGlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.bottomNavigationBarAction,
    this.floatingActionButton,
    this.floatingActionButtonAlignment = AlignmentDirectional.bottomEnd,
    this.floatingActionButtonClearance,
    this.lenses = const [],
    this.backgroundColor,
    this.safeArea = true,
    this.appBarTopMargin = 0,
    this.actionMargin = 16,
    this.controller,
    this.pixelRatio = 1.0,
    this.realTimeCapture = true,
    this.useSync = true,
    this.refreshRate = LiquidGlassRefreshRate.deviceRefreshRate,
    this.useImpellerBackdrop,
  });

  @override
  Widget build(BuildContext context) {
    // Safe-area insets. The bars are shifted off the system UI, while the
    // body keeps filling the whole window behind the glass.
    final EdgeInsets pad =
        safeArea ? MediaQuery.of(context).padding : EdgeInsets.zero;

    // Glass-pill morph path: the bar owns the whole-screen dual pipeline,
    // so the scaffold hands it the body plus the composed outer slots.
    final nav = bottomNavigationBar;
    if (nav is LiquidGlassTabBar &&
        nav.resolveGlassPill(useImpellerBackdrop: useImpellerBackdrop)) {
      return nav.buildGlassPillBar(
        body: body,
        backgroundColor: backgroundColor,
        bottomInset: pad.bottom,
        outerChild: _outerSlots(context, pad, includeNavBar: false),
        pixelRatio: pixelRatio,
        useSync: useSync,
        useImpellerBackdrop: useImpellerBackdrop,
        realTimeCapture: realTimeCapture,
        // The bar's outer pipeline also carries OUR overlay slots. If any of
        // them is a lens it needs a live capture even while the pill is
        // hidden; with none, the capture can sleep at rest.
        outerNeedsRealtime: appBar != null ||
            bottomNavigationBarAction != null ||
            lenses.isNotEmpty,
      );
    }

    final Widget rawBackground = backgroundColor == null
        ? body
        : ColoredBox(color: backgroundColor!, child: body);
    final Widget background = Material(
      type: MaterialType.transparency,
      child: rawBackground,
    );

    return LiquidGlassView(
      controller: controller,
      pixelRatio: pixelRatio,
      realTimeCapture: realTimeCapture,
      useSync: useSync,
      refreshRate: refreshRate,
      useImpellerBackdrop: useImpellerBackdrop,
      backgroundWidget: background,
      child: _outerSlots(context, pad, includeNavBar: true),
    );
  }

  /// Builds the full-screen `Stack` of glass slots placed over the body.
  /// When [includeNavBar] is false the bottom nav bar is omitted (the
  /// glass-pill path renders the bar itself).
  Widget _outerSlots(
    BuildContext context,
    EdgeInsets pad, {
    required bool includeNavBar,
  }) {
    final EdgeInsets navMargin = bottomNavigationBar is LiquidGlassTabBar
        ? (bottomNavigationBar as LiquidGlassTabBar).margin
        : EdgeInsets.zero;
    final Alignment navAlignment =
        bottomNavigationBar is LiquidGlassTabBar
            ? (bottomNavigationBar as LiquidGlassTabBar).alignment
            : Alignment.bottomCenter;

    // Where the FAB actually lands, once RTL has had its say.
    // resolve() asserts on a null direction for the directional defaults,
    // and nothing guarantees a Directionality above a bare scaffold.
    final Alignment fabAlignment = floatingActionButtonAlignment
        .resolve(Directionality.maybeOf(context) ?? TextDirection.ltr);

    // Vertical room the FAB keeps clear above the bar: whatever the caller
    // set, else the tab bar's real height plus its bottom margin, else a
    // guess — no other bar reports its height to us.
    // Only bottom-leaning alignments are lifted; for the rest the bar is
    // nowhere near, and trimming the box would drag `center` off-centre.
    final double navClearance =
        bottomNavigationBar == null || fabAlignment.y <= 0
            ? 0
            : floatingActionButtonClearance ??
                (bottomNavigationBar is LiquidGlassTabBar
                    ? (bottomNavigationBar as LiquidGlassTabBar).height +
                        navMargin.bottom
                    : kFallbackNavClearance);

    // The glass overlays float outside any Scaffold/Material, so bare
    // Text/Icon in the app bar, nav, side action, or `lenses` would inherit
    // Flutter's yellow error text style. A transparent Material paints
    // nothing but installs the theme's DefaultTextStyle/IconTheme, so every
    // overlay slot is themed normally. Cheap and side-effect-free.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ...lenses,
          if (appBar != null)
            Positioned(
              top: pad.top + appBarTopMargin,
              left: 0,
              right: 0,
              child: Align(alignment: Alignment.topCenter, child: appBar!),
            ),
          if (includeNavBar && bottomNavigationBar != null)
            Positioned(
              bottom: pad.bottom + navMargin.bottom,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment(navAlignment.x, 0),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: navMargin.left,
                    right: navMargin.right,
                  ),
                  child: bottomNavigationBar!,
                ),
              ),
            ),
          if (bottomNavigationBarAction != null)
            Positioned(
              bottom: pad.bottom + navMargin.bottom,
              right: actionMargin,
              child: bottomNavigationBarAction!,
            ),
          if (floatingActionButton != null)
            Positioned(
              top: pad.top + actionMargin,
              bottom: pad.bottom + actionMargin + navClearance,
              left: actionMargin,
              right: actionMargin,
              child: Align(
                alignment: fabAlignment,
                child: floatingActionButton!,
              ),
            ),
        ],
      ),
    );
  }
}
