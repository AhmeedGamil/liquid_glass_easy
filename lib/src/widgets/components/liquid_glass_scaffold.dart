import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../../controllers/liquid_glass_view_controller.dart';
import '../lens/liquid_glass_batch.dart';
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
///  • **System chrome.** For every side [systemChrome] asks for — the
///    status bar by default — the scaffold pins an invisible strip
///    along that screen edge, the status bar's at the top and the
///    navigation bar's at the bottom, samples it, and drives that bar's
///    icon brightness from the result. A strip judges nothing but its
///    own system bar.
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
/// nothing adapts unless a widget opts in itself, and no strip is
/// pinned: with nothing to sample there is nothing to tell the OS bars.
@immutable
class LiquidGlassScaffoldAdaptivity {
  /// Palettes, thresholds and controller for the scaffold's glass
  /// chrome and for the system-bar strips. Inherited by every chrome
  /// surface — minus its `link`, which is never inherited (see
  /// [topLink]).
  final LiquidGlassAdaptivity adaptivity;

  /// Which OS bars this scaffold's verdict also drives — icon
  /// brightness only, never bar colours.
  ///
  /// Each requested side pins an invisible strip along that screen
  /// edge, samples it, and annotates that bar from the result. The
  /// strips judge only the system bars; the glass chrome judges its own
  /// backdrop. Defaults to [LiquidGlassSystemChrome.statusBar] — the
  /// bar the glass chrome sits under on every screen. Pass
  /// [LiquidGlassSystemChrome.none] to leave the OS bars alone: nothing
  /// goes in the tree at all.
  ///
  /// It lives here, and not on the scaffold, because a strip is only
  /// worth pinning where there is something to judge from: a scaffold
  /// with no adaptivity never touches the bars.
  final LiquidGlassSystemChrome systemChrome;

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
    this.systemChrome = LiquidGlassSystemChrome.statusBar,
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
/// `bottomNavigationBarAction` → `floatingActionButton`.
///
/// Dialogs and sheets are not slots: present them with
/// `showLiquidGlassDialog` and `showLiquidGlassSheet`.
///
/// With a glass-pill [LiquidGlassTabBar] the bar runs two views and places
/// the slots by renderer. On Impeller they sit in its outer view, over the
/// bar's cells and the moving pill, so the order above holds. On Skia they
/// ride its **inner** view — over the captured body, above the bar's
/// capsule but below its cells and the pill — and the outer view holds the
/// pill and nothing else: that view captures the whole screen a second
/// time, and keeping the chrome out of it is what lets the capture sleep
/// whenever the pill is at rest. So on Skia the bar's cells and pill paint
/// over a `lenses` entry that overlaps them.
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

  /// A standalone glass action that floats at the bottom-end corner —
  /// bottom-right in LTR, bottom-left in RTL — the common "tab bar + side
  /// action" pairing. Typically a
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

  /// Gap between [bottomNavigationBarAction] and the end edge of the
  /// screen: the right edge in LTR, the left in RTL.
  final double bottomNavigationBarActionMargin;

  /// Space kept between [floatingActionButton] and every screen edge, on
  /// top of the safe-area insets.
  final double floatingActionButtonMargin;

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

  /// See [LiquidGlassView.batch]. `true` (the default) puts the glass in
  /// [body] on one shared read of the backdrop and the chrome — app bar,
  /// action, FAB, [lenses] — on another. It is the one chrome
  /// batch on both tab bar paths, and the tab bar is never in it: on
  /// either path the bar's glass takes a read of its own. A
  /// `showLiquidGlassSheet` or a `showLiquidGlassDialog` opened from a
  /// context inside this scaffold can join that batch too, with
  /// `batch: true` on the call, so the sheet or the dialog costs no read
  /// of its own — the same read the tab bar takes. Off by default: each
  /// takes a read of its own.
  final bool batch;

  /// The palettes this scaffold's glass chrome wears, the OS bars it
  /// drives, and the strips that judge them — see
  /// [LiquidGlassScaffoldAdaptivity]. `null` (the default) means
  /// nothing adapts unless a widget opts in itself, and the system bars
  /// are left untouched.
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
    this.lenses = const [],
    this.backgroundColor,
    this.safeArea = true,
    this.appBarTopMargin = 0,
    this.bottomNavigationBarActionMargin = 16,
    this.floatingActionButtonMargin = 16,
    this.controller,
    this.pixelRatio = 1.0,
    this.realTimeCapture = true,
    this.useSync = true,
    this.refreshRate = LiquidGlassRefreshRate.deviceRefreshRate,
    this.useImpellerBackdrop,
    this.batch = true,
    this.adaptivity,
  });

  /// The key of the chrome batch of the nearest enclosing scaffold, or
  /// `null` outside one or with its [batch] off.
  ///
  /// What `showLiquidGlassSheet` and `showLiquidGlassDialog` read from the
  /// context they are called with when asked to batch, to put what they
  /// present on the scaffold's chrome read — see [batch]. Library-internal.
  static int? chromeBatchIdOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ChromeBatchScope>()?.backdropId;

  @override
  State<LiquidGlassScaffold> createState() => _LiquidGlassScaffoldState();
}

/// Publishes the scaffold's chrome batch key over the whole scaffold — the
/// body included, which is where a sheet or a dialog is presented from.
class _ChromeBatchScope extends InheritedWidget {
  const _ChromeBatchScope({required this.backdropId, required super.child});

  final int? backdropId;

  @override
  bool updateShouldNotify(_ChromeBatchScope oldWidget) =>
      backdropId != oldWidget.backdropId;
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

  /// Which bars the config asks for. `null` config — no adaptivity —
  /// means no strip and no annotation: there would be no pixels to
  /// judge from, only a guess to impose on the OS bars.
  LiquidGlassSystemChrome get _chrome =>
      _cfg?.systemChrome ?? LiquidGlassSystemChrome.none;

  bool get _chromeStatusSide =>
      _chrome == LiquidGlassSystemChrome.statusBar ||
      _chrome == LiquidGlassSystemChrome.both;

  bool get _chromeNavSide =>
      _chrome == LiquidGlassSystemChrome.navigationBar ||
      _chrome == LiquidGlassSystemChrome.both;

  /// Whether the sampler runs — **[adaptivity] alone decides**.
  ///
  /// A descendant cannot switch it on: a tab bar carrying its own
  /// `style.adaptivity` used to opt the whole view in automatically,
  /// which meant a scaffold that never asked for adaptivity could still
  /// be running captures every frame. Surfaces that want a background
  /// verdict now need the scaffold to say so — and so do the system
  /// bars, whose `systemChrome` rides on this same config.
  ///
  /// Without it they still resolve a verdict, just not from pixels:
  /// `permanentBrightness`, then a followed link, then the platform
  /// brightness — none of which costs a capture.
  bool get _needsSampling => _cfg != null;

  /// The chrome batch's key: one read for every glass slot over the body.
  /// Owned here rather than by a view because the tab bar's glass-pill
  /// path draws the chrome in one of the bar's own two views, and the
  /// sheets and dialogs presented over this scaffold are outside any view.
  late final int _chromeBatchId = liquidGlassAllocateBackdropId();

  int? get _chromeBatch => widget.batch ? _chromeBatchId : null;

  @override
  Widget build(BuildContext context) {
    return _ChromeBatchScope(
      backdropId: _chromeBatch,
      child: _buildPipeline(context),
    );
  }

  Widget _buildPipeline(BuildContext context) {
    // Safe-area insets. The bars are shifted off the system UI, while the
    // body keeps filling the whole window behind the glass.
    final EdgeInsets pad =
        widget.safeArea ? MediaQuery.of(context).padding : EdgeInsets.zero;

    final LiquidGlassAdaptiveSampling? sampling = _needsSampling
        ? (_cfg?.sampling ?? const LiquidGlassAdaptiveSampling())
        : null;

    // Glass-pill morph path: the bar owns the whole-screen dual pipeline,
    // so the scaffold hands it the body plus the composed slots.
    final nav = widget.bottomNavigationBar;
    if (nav is LiquidGlassTabBar &&
        nav.resolveGlassPill(useImpellerBackdrop: widget.useImpellerBackdrop)) {
      return nav.buildGlassPillBar(
        // Themed like the plain path below wraps its own background: the
        // body sits outside any Material here, so bare Text/Icon in it
        // would inherit MaterialApp's red/yellow `_errorTextStyle`. A
        // Text that overrides colour and size still keeps that style's
        // `fontFamily: 'monospace'`, which reads as "the font changed"
        // rather than as an error. A transparent Material paints nothing
        // but installs the theme's DefaultTextStyle/IconTheme — the same
        // fix `_chromeSlots` applies to the glass slots.
        body: Material(type: MaterialType.transparency, child: widget.body),
        backgroundColor: widget.backgroundColor,
        bottomInset: pad.bottom,
        // Every slot is handed over as the bar's
        // chrome; the bar places it by renderer. On Impeller it paints
        // over the bar in the outer view, as it always has. On Skia it
        // rides the INNER view, refracting the body on the capture the bar
        // already takes, so the outer view — which captures the whole
        // screen again — carries the pill alone; nothing of ours is up
        // there, `outerNeedsRealtime` stays off, and that capture sleeps
        // whenever the pill is at rest.
        chromeChild: _chromeSlots(context, pad, includeNavBar: false),
        pixelRatio: widget.pixelRatio,
        useSync: widget.useSync,
        useImpellerBackdrop: widget.useImpellerBackdrop,
        // The bar keeps its own glass out of this batch; only the chrome
        // slots share it.
        batch: widget.batch,
        foregroundBatchId: _chromeBatch,
        realTimeCapture: widget.realTimeCapture,
        adaptiveSampling: sampling,
        // The chrome strips (and any adaptive slot) sample the bar's single
        // INNER sampler (the pre-glass body image) — through that view's
        // own scope on Skia, through the bar's redirect on Impeller — so
        // the whole pipeline runs exactly one sampler and nothing ever
        // reads its own glass back. This is also what opens the inner
        // sampler for the slots when the bar itself has no reason to sample.
        outerAdaptiveSampling: sampling,
        // The bar judges its OWN capsule rect like every other surface;
        // the system navigation bar is driven by the bottom strip in
        // `chromeChild`, not by the bar's verdict.
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
      batch: widget.batch,
      foregroundBatchId: _chromeBatch,
      adaptiveSampling: sampling,
      backgroundWidget: background,
      child: _chromeSlots(context, pad, includeNavBar: true),
    );
  }

  /// The glass overlays float outside any Scaffold/Material, so bare
  /// Text/Icon in the app bar, nav, side action, or `lenses` would inherit
  /// Flutter's yellow error text style. A transparent Material paints
  /// nothing but installs the theme's DefaultTextStyle/IconTheme, so every
  /// overlay slot is themed normally. Cheap and side-effect-free.
  ///
  /// Then the config WITHOUT the link: every chrome surface inherits the
  /// palettes and samples its own backdrop. A surface follows a strip
  /// only by carrying that strip's link itself.
  Widget _themedSlots(Widget stack) {
    Widget slots = Material(type: MaterialType.transparency, child: stack);
    final LiquidGlassAdaptivity? inherited = _inheritedChromeAdaptivity;
    if (inherited != null) {
      slots = LiquidGlassAdaptiveAreaScope(adaptivity: inherited, child: slots);
    }
    return slots;
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
    required Brightness fallbackBrightness,
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
                    fallbackBrightness,
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
  ///
  /// [includeNavBar] adds the bottom bar itself (the plain path; on the
  /// glass-pill path the bar draws its own, and this whole stack is handed
  /// to it as its chrome).
  Widget _chromeSlots(
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
    final TextDirection direction =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    final bool rtl = direction == TextDirection.rtl;
    final Alignment fabAlignment =
        widget.floatingActionButtonAlignment.resolve(direction);

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
    // Strips only exist while there IS a config, so this fallback is
    // just a non-null default for the build — `_chromeStatusSide` and
    // `_chromeNavSide` are both false without one.
    final LiquidGlassAdaptivity stripAdaptivity =
        cfg?.adaptivity ?? const LiquidGlassAdaptivity();
    final Brightness stripFallback =
        liquidGlassFallbackBrightness(context, stripAdaptivity);
    final bool stripDebug = cfg?.debugBounds ?? false;
    final Widget? topStrip = _systemStrip(
      adaptivity: stripAdaptivity,
      debugBounds: stripDebug,
      top: true,
      height: topStripH,
      driveChrome: _chromeStatusSide,
      followLink: cfg?.topFollowLink,
      fallbackBrightness: stripFallback,
    );
    final Widget? bottomStrip = _systemStrip(
      adaptivity: stripAdaptivity,
      debugBounds: stripDebug,
      top: false,
      height: bottomStripH,
      driveChrome: _chromeNavSide,
      followLink: cfg?.bottomFollowLink,
      fallbackBrightness: stripFallback,
    );

    return _themedSlots(
      Stack(
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
                  // Its own read, never the chrome batch's.
                  child: LiquidGlassBatch.exclude(
                    child: widget.bottomNavigationBar!,
                  ),
                ),
              ),
            ),
          if (widget.bottomNavigationBarAction != null)
            // The end side: right in LTR, left in RTL.
            Positioned(
              bottom: pad.bottom + navMargin.bottom,
              left: rtl ? widget.bottomNavigationBarActionMargin : null,
              right: rtl ? null : widget.bottomNavigationBarActionMargin,
              child: widget.bottomNavigationBarAction!,
            ),
          if (widget.floatingActionButton != null)
            Positioned(
              top: pad.top + widget.floatingActionButtonMargin,
              bottom: pad.bottom +
                  widget.floatingActionButtonMargin +
                  navClearance,
              left: widget.floatingActionButtonMargin,
              right: widget.floatingActionButtonMargin,
              child: Align(
                alignment: fabAlignment,
                child: widget.floatingActionButton!,
              ),
            ),
        ],
      ),
    );
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
