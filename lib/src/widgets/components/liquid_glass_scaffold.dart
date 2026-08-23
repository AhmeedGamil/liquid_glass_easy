import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../../controllers/liquid_glass_view_controller.dart';
import '../liquid_glass_view.dart';
import '../utils/liquid_glass_adaptivity.dart';
import '../utils/liquid_glass_refresh_rate.dart';
import 'bottom_nav_bar/liquid_glass_tab_bar.dart';
import 'liquid_glass_adaptive_area.dart';
import 'liquid_glass_app_bar.dart';

/// The scaffold's adaptivity: the palettes its glass chrome wears, and
/// the edge strips that drive the **system bars**.
///
/// Two jobs, deliberately kept apart:
///
///  • **System chrome.** When [LiquidGlassScaffold.systemChrome] asks
///    for a side, the scaffold pins an invisible strip along that
///    screen edge — the status bar's at the top, the navigation bar's
///    at the bottom — samples it, and drives that bar's icon brightness
///    from the result. A strip judges nothing but its own system bar.
///  • **Chrome palettes.** [adaptivity] is handed down to the app bar,
///    the bottom bar, the action button and any `lenses`, each of which
///    resolves its **own** verdict from the background directly behind
///    itself. One config, one verdict per surface.
///
/// A strip never captures the chrome: the app bar is judged by the
/// pixels behind the app bar, not by the status bar's strip. Coupling
/// goes the other way round — point a strip at an area's link with
/// [topFollowLink] / [bottomFollowLink] and the system bar mirrors
/// that area's verdict. A following strip stops sampling entirely, so
/// it has no region of its own and [topHeight] / [bottomHeight] no
/// longer apply to it.
///
/// The config's own `link` is deliberately never inherited by the
/// chrome — otherwise every surface would follow it by accident.
///
/// A surface escapes the inherited palettes with
/// `LiquidGlassAdaptivity.none`; its own `style.adaptivity` overrides
/// them. `LiquidGlassScaffold.adaptivity` left `null` (the default) →
/// nothing adapts unless a widget opts in itself.
@immutable
class LiquidGlassScaffoldAdaptivity {
  /// Palettes, thresholds and controller for the scaffold's glass
  /// chrome and for the system-bar strips. Inherited by every chrome
  /// surface — minus its `link`, which is never inherited (see
  /// [topLink]).
  final LiquidGlassAdaptivity adaptivity;

  /// Makes the TOP strip **follow** this link instead of judging the
  /// status bar's own band — hand it the link a `LiquidGlassAdaptiveArea`
  /// publishes on and the status bar mirrors that area.
  ///
  /// A following strip samples nothing, so it has no region and
  /// [topHeight] is ignored: there is no pixel height to get wrong.
  /// It inherits the area's verdict wholesale, including a
  /// `permanentBrightness` the area may be pinned to.
  final LiquidGlassAdaptivityLink? topFollowLink;

  /// Makes the BOTTOM strip follow this link instead of judging the
  /// navigation bar's own band. See [topFollowLink]; [bottomHeight] is
  /// likewise ignored while following.
  final LiquidGlassAdaptivityLink? bottomFollowLink;

  /// Tuning of the background-luminance sampler serving the strips and
  /// the chrome — see [LiquidGlassAdaptiveSampling]. The default is the
  /// standard tiny capture (pixelRatio 0.05, 8 samples/s), so it never
  /// needs to be written unless you want different numbers.
  final LiquidGlassAdaptiveSampling sampling;

  /// How tall a band the TOP system bar is judged from, measured from
  /// the top screen edge (the status bar is inside it, not added to
  /// it). `null` — the default — derives it from the safe-area inset,
  /// floored so a zero inset (`safeArea: false`) still samples
  /// something instead of freezing the chrome.
  ///
  /// Ignored while [topFollowLink] is set: a following strip judges
  /// nothing. Prefer following an area over guessing a height.
  final double? topHeight;

  /// How tall a band the BOTTOM system bar is judged from, measured
  /// from the bottom screen edge. `null` = the safe-area inset,
  /// floored — gesture navigation leaves only a few pixels. Ignored
  /// while [bottomFollowLink] is set.
  final double? bottomHeight;

  /// Debug: outline each strip the scaffold pins (cyan), so the
  /// invisible strips' size and position can be verified on screen.
  /// Same idea as the blender's `debugClipBounds`. Off by default.
  final bool debugBounds;

  const LiquidGlassScaffoldAdaptivity(
    this.adaptivity, {
    this.topFollowLink,
    this.bottomFollowLink,
    this.sampling = const LiquidGlassAdaptiveSampling(),
    this.topHeight,
    this.bottomHeight,
    this.debugBounds = false,
  });
}

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
/// `bottomNavigationBarAction` → `floatingActionButton` → `dialog`.
class LiquidGlassScaffold extends StatefulWidget {
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

  /// A glass panel laid over the page, inside this scaffold's own view.
  ///
  /// Unlike `showLiquidGlassDialog`, which pushes a route, this one is an
  /// ordinary widget in the lens layer: it refracts the live [body] on
  /// every backend, and can be merged with the other slots' glass by a
  /// `LiquidGlassBlender`. What it gives up is the navigator — there is no
  /// `Future` to await and no route on the stack, so you hold the open/
  /// closed state yourself and set this back to `null` to close it.
  ///
  /// Typically a [LiquidGlassDialog] or [LiquidGlassAlertDialog].
  final Widget? dialog;

  /// Called when the [dialog] asks to close — a tap on the barrier or a
  /// system back gesture. Clear [dialog] from here; the panel plays its
  /// exit animation on the way out.
  final VoidCallback? onDialogDismissed;

  /// Scrim painted under [dialog] and over everything else. It fades with
  /// the panel and swallows taps meant for the page beneath.
  final Color dialogBarrierColor;

  /// Whether tapping the barrier fires [onDialogDismissed].
  final bool dialogBarrierDismissible;

  /// How long [dialog] takes to appear and to leave.
  final Duration dialogTransitionDuration;

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

  /// Drives the OS status / navigation bar icon brightness from the
  /// scaffold's adaptivity verdict, so the system chrome flips with the
  /// glass instead of staying pinned.
  ///
  /// Each requested side pins an invisible strip along that screen edge
  /// which samples it and annotates the bar — on [adaptivity]'s
  /// palettes when one is configured, else on the defaults, so this
  /// works on its own. The strips judge only the system bars; the glass
  /// chrome judges its own backdrop. [LiquidGlassSystemChrome.none]
  /// (the default) puts nothing in the tree at all.
  final LiquidGlassSystemChrome systemChrome;

  /// The palettes this scaffold's glass chrome wears, plus the strips
  /// that drive the system bars — see [LiquidGlassScaffoldAdaptivity].
  /// `null` (the default) means nothing adapts unless a widget opts in
  /// itself.
  final LiquidGlassScaffoldAdaptivity? adaptivity;

  const LiquidGlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.bottomNavigationBarAction,
    this.floatingActionButton,
    this.floatingActionButtonAlignment = AlignmentDirectional.bottomEnd,
    this.floatingActionButtonClearance,
    this.dialog,
    this.onDialogDismissed,
    this.dialogBarrierColor = const Color(0x80000000),
    this.dialogBarrierDismissible = true,
    this.dialogTransitionDuration = const Duration(milliseconds: 350),
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
    this.systemChrome = LiquidGlassSystemChrome.none,
    this.adaptivity,
  });

  @override
  State<LiquidGlassScaffold> createState() => _LiquidGlassScaffoldState();
}

class _LiquidGlassScaffoldState extends State<LiquidGlassScaffold> {
  /// Smallest strip a system bar may be judged from. A safe-area inset
  /// can be a handful of pixels (gesture navigation) or zero
  /// (`safeArea: false`); a zero-height strip samples nothing and would
  /// silently freeze the chrome on its entry guess.
  static const double _kMinStripExtent = 24;

  /// The config, or `null` when absent or opted out with
  /// `LiquidGlassAdaptivity.none`.
  LiquidGlassScaffoldAdaptivity? get _cfg {
    final LiquidGlassScaffoldAdaptivity? c = widget.adaptivity;
    return (c == null || c.adaptivity.isNone) ? null : c;
  }

  /// What the glass chrome inherits: the config's palettes, thresholds
  /// and controller — but NOT its link. Dropping the link is what makes
  /// each surface resolve its own verdict from its own backdrop instead
  /// of following a strip (see [LiquidGlassScaffoldAdaptivity]).
  LiquidGlassAdaptivity? get _inheritedChromeAdaptivity =>
      _cfg?.adaptivity.withoutLink();

  bool get _chromeStatusSide =>
      widget.systemChrome == LiquidGlassSystemChrome.statusBar ||
      widget.systemChrome == LiquidGlassSystemChrome.both;

  bool get _chromeNavSide =>
      widget.systemChrome == LiquidGlassSystemChrome.navigationBar ||
      widget.systemChrome == LiquidGlassSystemChrome.both;

  /// Whether anything at all needs the sampler running.
  bool _needsSampling(Widget? nav) {
    if (_cfg != null) return true;
    if (widget.systemChrome != LiquidGlassSystemChrome.none) return true;
    // An adaptive bar (its own style.adaptivity) samples through this
    // view — opt in automatically so it just works.
    return nav is LiquidGlassTabBar && nav.effectiveBarStyle.adaptivity != null;
  }

  @override
  Widget build(BuildContext context) {
    // Safe-area insets. The bars are shifted off the system UI, while the
    // body keeps filling the whole window behind the glass.
    final EdgeInsets pad =
        widget.safeArea ? MediaQuery.of(context).padding : EdgeInsets.zero;

    final LiquidGlassAdaptiveSampling? sampling =
        _needsSampling(widget.bottomNavigationBar)
            ? (_cfg?.sampling ?? const LiquidGlassAdaptiveSampling())
            : null;

    // Glass-pill morph path: the bar owns the whole-screen dual pipeline,
    // so the scaffold hands it the body plus the composed outer slots.
    final nav = widget.bottomNavigationBar;
    if (nav is LiquidGlassTabBar &&
        nav.resolveGlassPill(useImpellerBackdrop: widget.useImpellerBackdrop)) {
      return nav.buildGlassPillBar(
        body: widget.body,
        backgroundColor: widget.backgroundColor,
        bottomInset: pad.bottom,
        outerChild: _outerSlots(context, pad, includeNavBar: false),
        pixelRatio: widget.pixelRatio,
        useSync: widget.useSync,
        useImpellerBackdrop: widget.useImpellerBackdrop,
        realTimeCapture: widget.realTimeCapture,
        // The bar's outer pipeline also carries OUR overlay slots. If any of
        // them is a lens it needs a live capture even while the pill is
        // hidden; with none, the capture can sleep at rest.
        outerNeedsRealtime: widget.appBar != null ||
            widget.bottomNavigationBarAction != null ||
            widget.floatingActionButton != null ||
            widget.dialog != null ||
            widget.lenses.isNotEmpty,
        adaptiveSampling: sampling,
        // The chrome strips (and any adaptive slot) live in `outerChild`
        // — this redirects them to the bar's single INNER sampler (the
        // pre-glass body image), so the whole pipeline runs exactly one
        // sampler and nothing ever reads its own glass back.
        outerAdaptiveSampling: sampling,
        // The bar judges its OWN capsule rect like every other surface;
        // the system navigation bar is driven by the bottom strip in
        // `outerChild`, not by the bar's verdict.
        areaAdaptivity: _inheritedChromeAdaptivity,
        systemChrome: LiquidGlassSystemChrome.none,
      );
    }

    final Widget rawBackground = widget.backgroundColor == null
        ? widget.body
        : ColoredBox(color: widget.backgroundColor!, child: widget.body);
    final Widget background = Material(
      type: MaterialType.transparency,
      child: rawBackground,
    );

    return LiquidGlassView(
      controller: widget.controller,
      pixelRatio: widget.pixelRatio,
      realTimeCapture: widget.realTimeCapture,
      useSync: widget.useSync,
      refreshRate: widget.refreshRate,
      useImpellerBackdrop: widget.useImpellerBackdrop,
      adaptiveSampling: sampling,
      backgroundWidget: background,
      child: _outerSlots(context, pad, includeNavBar: true),
    );
  }

  /// One system-bar strip: an invisible band pinned to a screen edge,
  /// there purely to drive that bar's icon brightness. It never
  /// contains the chrome — the chrome sits above it in the stack and
  /// judges its own backdrop.
  ///
  /// Two modes. With [followLink] it **follows**: it samples nothing
  /// and mirrors whatever that link carries, so its height is only
  /// enough to cover the probe point Flutter reads the annotation at.
  /// Without one it **judges** its own band at [height].
  Widget? _systemStrip({
    required LiquidGlassAdaptivity adaptivity,
    required bool debugBounds,
    required bool top,
    required double height,
    required bool driveChrome,
    required LiquidGlassAdaptivityLink? followLink,
    required Brightness platformBrightness,
  }) {
    // A strip exists only to annotate: with the side switched off there
    // is nothing for it to do, following or not.
    if (!driveChrome) return null;
    final LiquidGlassSystemChrome chrome = top
        ? LiquidGlassSystemChrome.statusBar
        : LiquidGlassSystemChrome.navigationBar;
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: height,
      child: IgnorePointer(
        child: followLink == null
            ? LiquidGlassAdaptiveArea(
                adaptivity: adaptivity,
                debugBounds: debugBounds,
                systemChrome: chrome,
                child: const SizedBox.expand(),
              )
            : _ChromeFollower(
                link: followLink,
                chrome: chrome,
                debugBounds: debugBounds,
                // Until the followed area delivers its first verdict,
                // sit on the same guess the palettes use.
                fallback: adaptivity.permanentBrightness ??
                    adaptivity.initialBrightness ??
                    platformBrightness,
              ),
      ),
    );
  }

  /// Builds the full-screen `Stack` of glass slots placed over the body.
  /// When [includeNavBar] is false the bottom nav bar is omitted (the
  /// glass-pill path renders the bar itself).
  ///
  /// Adaptivity here is two independent things. The **system strips**
  /// are invisible bands at the screen edges that judge only the OS
  /// bars. The **chrome** — app bar, bottom bar, action, `lenses` —
  /// sits above them as ordinary slots and inherits the config's
  /// palettes through a link-less [LiquidGlassAdaptiveAreaScope], so
  /// each surface samples the background directly behind itself.
  /// Coupling a surface to a strip is opt-in: publish the strip on
  /// `topLink`/`bottomLink` and put the same link on that surface's own
  /// adaptivity.
  Widget _outerSlots(
    BuildContext context,
    EdgeInsets pad, {
    required bool includeNavBar,
  }) {
    final LiquidGlassTabBar? navBar =
        widget.bottomNavigationBar is LiquidGlassTabBar
            ? widget.bottomNavigationBar as LiquidGlassTabBar
            : null;
    final EdgeInsets navMargin = navBar?.margin ?? EdgeInsets.zero;
    final Alignment navAlignment = navBar?.alignment ?? Alignment.bottomCenter;
    final LiquidGlassScaffoldAdaptivity? cfg = _cfg;

    // Where the FAB actually lands, once RTL has had its say.
    // resolve() asserts on a null direction for the directional defaults,
    // and nothing guarantees a Directionality above a bare scaffold.
    final Alignment fabAlignment = widget.floatingActionButtonAlignment
        .resolve(Directionality.maybeOf(context) ?? TextDirection.ltr);

    // Vertical room the FAB keeps clear above the bar: whatever the caller
    // set, else the tab bar's real height plus its bottom margin, else a
    // guess — no other bar reports its height to us.
    // Only bottom-leaning alignments are lifted; for the rest the bar is
    // nowhere near, and trimming the box would drag `center` off-centre.
    final double navClearance =
        widget.bottomNavigationBar == null || fabAlignment.y <= 0
            ? 0
            : widget.floatingActionButtonClearance ??
                (navBar != null
                    ? navBar.height + navMargin.bottom
                    : LiquidGlassScaffold.kFallbackNavClearance);

    // Strip geometry: the system bar's own inset, floored so it stays
    // samplable. These describe what the OS bars are JUDGED from — they
    // never move any chrome, whose layout stays owned by the scaffold's
    // own params.
    final double topStripH = cfg?.topHeight ??
        (pad.top > _kMinStripExtent ? pad.top : _kMinStripExtent);
    final double bottomStripH = cfg?.bottomHeight ??
        (pad.bottom > _kMinStripExtent ? pad.bottom : _kMinStripExtent);
    final Brightness platformBrightness =
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;

    // A strip is pinned for a requested system-bar side even with no
    // config at all — `systemChrome` alone is a complete feature, and
    // then the strip judges on the default palettes.
    final LiquidGlassAdaptivity stripAdaptivity =
        cfg?.adaptivity ?? const LiquidGlassAdaptivity();
    final bool stripDebug = cfg?.debugBounds ?? false;
    final Widget? topStrip = _systemStrip(
      adaptivity: stripAdaptivity,
      debugBounds: stripDebug,
      top: true,
      height: topStripH,
      driveChrome: _chromeStatusSide,
      followLink: cfg?.topFollowLink,
      platformBrightness: platformBrightness,
    );
    final Widget? bottomStrip = _systemStrip(
      adaptivity: stripAdaptivity,
      debugBounds: stripDebug,
      top: false,
      height: bottomStripH,
      driveChrome: _chromeNavSide,
      followLink: cfg?.bottomFollowLink,
      platformBrightness: platformBrightness,
    );

    // The glass overlays float outside any Scaffold/Material, so bare
    // Text/Icon in the app bar, nav, side action, or `lenses` would inherit
    // Flutter's yellow error text style. A transparent Material paints
    // nothing but installs the theme's DefaultTextStyle/IconTheme, so every
    // overlay slot is themed normally. Cheap and side-effect-free.
    Widget slots = Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Strips sit behind everything — invisible, hit-transparent,
          // sampling their own edge and nothing else.
          if (topStrip != null) topStrip,
          if (bottomStrip != null) bottomStrip,
          ...widget.lenses,
          if (widget.appBar != null)
            Positioned(
              top: pad.top + widget.appBarTopMargin,
              left: 0,
              right: 0,
              child:
                  Align(alignment: Alignment.topCenter, child: widget.appBar!),
            ),
          if (includeNavBar && widget.bottomNavigationBar != null)
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
                  child: widget.bottomNavigationBar!,
                ),
              ),
            ),
          if (widget.bottomNavigationBarAction != null)
            Positioned(
              bottom: pad.bottom + navMargin.bottom,
              right: widget.actionMargin,
              child: widget.bottomNavigationBarAction!,
            ),
          if (widget.floatingActionButton != null)
            Positioned(
              top: pad.top + widget.actionMargin,
              bottom: pad.bottom + widget.actionMargin + navClearance,
              left: widget.actionMargin,
              right: widget.actionMargin,
              child: Align(
                alignment: fabAlignment,
                child: widget.floatingActionButton!,
              ),
            ),
          // Last, so the barrier covers the bars as a route's would.
          _LiquidGlassScaffoldDialog(
            dialog: widget.dialog,
            barrierColor: widget.dialogBarrierColor,
            barrierDismissible: widget.dialogBarrierDismissible,
            onDismissed: widget.onDialogDismissed,
            duration: widget.dialogTransitionDuration,
            useSafeArea: widget.safeArea,
          ),
        ],
      ),
    );

    // Config WITHOUT the link: every chrome surface inherits the
    // palettes and samples its own backdrop. A surface follows a strip
    // only by carrying that strip's link itself.
    final LiquidGlassAdaptivity? inherited = _inheritedChromeAdaptivity;
    if (inherited != null) {
      slots = LiquidGlassAdaptiveAreaScope(adaptivity: inherited, child: slots);
    }
    return slots;
  }
}


/// A system-bar strip that FOLLOWS a link instead of judging pixels.
///
/// It owns no driver and registers with no sampler: it just relays the
/// verdict some `LiquidGlassAdaptiveArea` published. That is what frees
/// a following strip from having a height to configure — it has no
/// region, only the footprint needed to cover the point Flutter probes
/// for the annotation.
class _ChromeFollower extends StatelessWidget {
  final LiquidGlassAdaptivityLink link;
  final LiquidGlassSystemChrome chrome;
  final Brightness fallback;
  final bool debugBounds;

  const _ChromeFollower({
    required this.link,
    required this.chrome,
    required this.fallback,
    required this.debugBounds,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Brightness?>(
      valueListenable: link,
      builder: (context, verdict, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: liquidGlassSystemChromeStyle(verdict ?? fallback, chrome),
        child: debugBounds
            ? const DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFF00FFFF), width: 2),
                  ),
                ),
                child: SizedBox.expand(),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

/// Drives [LiquidGlassScaffold.dialog]: barrier, entrance, and the exit it
/// has to finish painting after the caller has already let the widget go.
class _LiquidGlassScaffoldDialog extends StatefulWidget {
  final Widget? dialog;
  final Color barrierColor;
  final bool barrierDismissible;
  final VoidCallback? onDismissed;
  final Duration duration;
  final bool useSafeArea;

  const _LiquidGlassScaffoldDialog({
    required this.dialog,
    required this.barrierColor,
    required this.barrierDismissible,
    required this.onDismissed,
    required this.duration,
    required this.useSafeArea,
  });

  @override
  State<_LiquidGlassScaffoldDialog> createState() =>
      _LiquidGlassScaffoldDialogState();
}

class _LiquidGlassScaffoldDialogState extends State<_LiquidGlassScaffoldDialog>
    with SingleTickerProviderStateMixin {
  // Same shape as the route presenter's: a soft overshoot in, a sharp
  // pull out.
  static const Curve _in = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Curve _out = Cubic(0.7, 0.0, 0.84, 0.0);

  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  /// The last dialog handed to us. Outlives `widget.dialog` going null so
  /// the panel can animate out instead of vanishing.
  Widget? _outgoing;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.duration,
      value: widget.dialog == null ? 0.0 : 1.0,
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: _in,
      reverseCurve: _out,
    );
    _outgoing = widget.dialog;
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    // Fully closed: drop the widget we were only holding on to for the
    // exit, so its lens stops costing a capture.
    if (status == AnimationStatus.dismissed && widget.dialog == null) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(_LiquidGlassScaffoldDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    _controller.reverseDuration = widget.duration;
    if (widget.dialog != null) {
      _outgoing = widget.dialog;
      _controller.forward();
    } else if (oldWidget.dialog != null) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() => widget.onDismissed?.call();

  @override
  Widget build(BuildContext context) {
    final Widget? panel = widget.dialog ?? _outgoing;
    if (panel == null) return const SizedBox.shrink();

    // Open means "the caller still wants it". While closing we keep
    // painting but stop taking input, and let a back gesture through
    // rather than swallowing it to close something already on its way out.
    final bool open = widget.dialog != null;

    // No Center here: the dialog widgets align themselves, and the scale
    // rides the full-screen box exactly as the route presenter's does.
    Widget content = panel;
    if (widget.useSafeArea) content = SafeArea(child: content);

    return PopScope(
      canPop: !open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: IgnorePointer(
        ignoring: !open,
        child: AnimatedBuilder(
          animation: _controller,
          // Handed through so the panel's own subtree is not rebuilt on
          // every frame of the transition.
          child: content,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // The scrim may fade freely — it is not glass. The panel
                // itself never gets an opacity layer: that would isolate
                // its lens from the page and drop the refraction
                // mid-flight, which is the whole point of the glass.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.barrierDismissible ? _dismiss : null,
                  child: ColoredBox(
                    color: widget.barrierColor.withValues(
                      alpha: widget.barrierColor.a * _controller.value,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.84 + 0.16 * _curve.value,
                  child: child,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
