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
/// `bottomNavigationBarAction` → `floatingActionButton` → `dialog`.
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
            dialog != null ||
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
          // Last, so the barrier covers the bars as a route's would.
          _LiquidGlassScaffoldDialog(
            dialog: dialog,
            barrierColor: dialogBarrierColor,
            barrierDismissible: dialogBarrierDismissible,
            onDismissed: onDialogDismissed,
            duration: dialogTransitionDuration,
            useSafeArea: safeArea,
          ),
        ],
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
