// -----------------------------------------------------------------------------
// STYLED ANIMATED BOTTOM NAV BAR  (experimental / sandbox)
// -----------------------------------------------------------------------------
// A self-contained copy of `LiquidGlassAnimatedNavBar` that is driven by the
// shared style GROUPS in `liquid_glass_styles.dart` instead of hardcoded
// constants. It exists so the grouped/categorized API can be exercised in
// isolation WITHOUT modifying any shipping component.
//
// What it proves:
//   • the previously-dropped fields (capsule glass look, item icon/label
//     colors + sizes, selection color, animation timing) are now wired all
//     the way through to the capsule / shell / rest-pill / animator;
//   • a single `LiquidGlassSurfaceStyle` + `LiquidGlassMotion` vocabulary is
//     enough to style the bar — the same groups future components reuse.
//
// It REUSES (read-only) the existing layout/item/envelope types from the
// shipping nav-bar files, and recreates the few private helpers (clippers)
// locally so nothing existing has to change. Defaults reproduce today's look.
// -----------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../controllers/liquid_glass_view_controller.dart';
import '../../liquid_glass.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_border_mode.dart';
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_shape.dart';
import '../bottom_nav_bar/liquid_glass_nav_bar_layout.dart'
    show LiquidGlassTabBarLayout;
import '../liquid_glass_morph_pill.dart' show liquidGlassMorphEnvelope;
import '../liquid_glass_tab_item.dart'
    show
        LiquidGlassTabBarItem,
        buildLiquidGlassNavGlyph,
        buildLiquidGlassNavLabel;
import 'liquid_glass_styles.dart';

/// Self-contained, drop-in **styled** animated liquid-glass bottom nav bar —
/// the iOS-26 "morphing glass pill" bar, but configured through the shared
/// existing config groups ([LiquidGlassRefraction], [LiquidGlassAppearance],
/// [LiquidGlassShape]) plus [LiquidGlassMotion] / [LiquidGlassNavBarItemStyle].
///
/// The capsule's glass groups are **optional overrides**: leave one `null` to
/// keep the bar's supplied default, or pass a config group to take it over.
/// This is the same merge the rest of the package uses — the config wins where
/// the caller sets it, the default fills in everywhere else.
///
/// Owns the entire dual `LiquidGlassView` pipeline internally, exactly like
/// `LiquidGlassAnimatedNavBar`. Use it directly (no scaffold needed):
///
/// ```dart
/// LiquidGlassStyledNavBar(
///   body: myPageContent,
///   items: items,
///   selectedIndex: index,
///   onChanged: (i) => setState(() => index = i),
///   layout: LiquidGlassTabBarLayout(itemCount: items.length, width: 300),
///   refraction: const LiquidGlassRefraction(distortion: 0.10), // override
///   // appearance / shape left null -> bar defaults are used
///   itemStyle: const LiquidGlassNavBarItemStyle(),
///   motion: const LiquidGlassMotion(),
/// )
/// ```
class LiquidGlassStyledNavBar extends StatefulWidget {
  final Widget body;
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Bar geometry (size, position, padding). The bottom margin should
  /// already include any safe-area inset.
  final LiquidGlassTabBarLayout layout;

  /// Lenses composited in the **outer** view, above the bar (app bar, side
  /// action, extra glass).
  final List<LiquidGlass> outerLenses;

  /// Optional solid color behind [body].
  final Color? backgroundColor;

  /// Custom placement for the bar. `null` = bottom-center via [layout].
  final LiquidGlassPosition? barPosition;

  // ── Capsule glass look: optional config-group overrides ──
  // Each is `null` by default → the bar's supplied default is used. Set one
  // to take it over (the config wins where the caller specifies it).
  /// Overrides how the capsule bends light. `null` → bar default.
  final LiquidGlassRefraction? refraction;

  /// Overrides the capsule's tint/blur/saturation. `null` → bar default.
  final LiquidGlassAppearance? appearance;

  /// Overrides the capsule's shape (rim + corner). `null` → bar default
  /// (a capsule derived from the bar height).
  final LiquidGlassShape? shape;

  /// Icon/label colors + sizes and the selection highlight.
  final LiquidGlassNavBarItemStyle itemStyle;

  /// Slide animation timing.
  final LiquidGlassMotion motion;

  /// The moving glass pill's look + size.
  final LiquidGlassTabPillStyle pill;

  /// Capture/render pipeline settings forwarded to both internal views.
  final LiquidGlassRenderConfig render;

  const LiquidGlassStyledNavBar({
    super.key,
    required this.body,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.layout,
    this.outerLenses = const [],
    this.backgroundColor,
    this.barPosition,
    this.refraction,
    this.appearance,
    this.shape,
    this.itemStyle = const LiquidGlassNavBarItemStyle(),
    this.motion = const LiquidGlassMotion(),
    this.pill = const LiquidGlassTabPillStyle(),
    this.render = const LiquidGlassRenderConfig(),
  });

  @override
  State<LiquidGlassStyledNavBar> createState() =>
      _LiquidGlassStyledNavBarState();
}

class _LiquidGlassStyledNavBarState extends State<LiquidGlassStyledNavBar>
    with TickerProviderStateMixin {
  final _outerViewController = LiquidGlassViewController();
  final _innerViewController = LiquidGlassViewController();

  late int _tabIndex;
  late int _tabIndexCommitted;

  late final AnimationController _tabAnim;
  late Animation<double> _tabIndexTween =
      const AlwaysStoppedAnimation<double>(0.0);

  bool _pillGlassActive = false;
  bool _settlingFromDrag = false;

  double _tabPillFracIndex = 0;
  bool _tabDragging = false;

  // Jelly spring state.
  double _tabPillStretch = 0;
  double _tabPillStretchVel = 0;
  double _tabPillStretchTarget = 0;
  double _tabPillJellyLastFrac = 0;
  DateTime _tabPillJellyLastTs = DateTime.now();
  Ticker? _tabPillJellyTicker;
  Duration? _tabPillJellyTickerLast;

  double _barLeft = 0;
  double _effBottomMargin = 0;

  LiquidGlassTabBarLayout get _layout => widget.layout;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.selectedIndex;
    _tabIndexCommitted = widget.selectedIndex;
    _tabPillFracIndex = widget.selectedIndex.toDouble();
    _tabAnim =
        AnimationController(vsync: this, duration: widget.motion.duration);
    _tabIndexTween = AlwaysStoppedAnimation<double>(_tabIndex.toDouble());
    _tabAnim.addListener(() => setState(() {}));
    _tabAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _pillGlassActive = false;
            _settlingFromDrag = false;
            _tabIndexCommitted = _tabIndex;
          });
        }
        _maybeStopCapture();
      }
    });
    _tabPillJellyTicker = createTicker(_onTabPillJellyTick);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassStyledNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion.duration != widget.motion.duration) {
      _tabAnim.duration = widget.motion.duration;
    }
    if (widget.selectedIndex != _tabIndex &&
        widget.selectedIndex != oldWidget.selectedIndex) {
      _animateTo(widget.selectedIndex, notify: false);
    }
  }

  @override
  void dispose() {
    _tabPillJellyTicker?.dispose();
    _tabAnim.dispose();
    _outerViewController.detach();
    _innerViewController.detach();
    super.dispose();
  }

  // ── Capture lifecycle ──
  void _startCapture() {
    if (!widget.render.realTimeCapture) {
      _innerViewController.startRealtimeCapture();
    }
  }

  void _maybeStopCapture() {
    if (widget.render.realTimeCapture) return;
    if (!_tabAnim.isAnimating && !_tabDragging) {
      _innerViewController.stopRealtimeCapture();
    }
  }

  // ── Selection / animation ──
  void _animateTo(int next, {required bool notify}) {
    if (next == _tabIndex) return;
    final from = _tabIndexTween.value;
    setState(() {
      _tabIndex = next;
      _pillGlassActive = true;
      _tabIndexTween = Tween<double>(begin: from, end: next.toDouble())
          .chain(CurveTween(curve: widget.motion.curve))
          .animate(_tabAnim);
    });
    _startCapture();
    _tabAnim
      ..duration = widget.motion.duration
      ..reset()
      ..forward();
    if (notify) widget.onChanged(next);
  }

  // ── Gesture geometry ──
  double _xToTabFrac(double globalDx) {
    final cell0Center = _barLeft + _layout.padding + _layout.cellWidth / 2;
    final cellW = _layout.cellWidth;
    final raw = (globalDx - cell0Center) / cellW;
    return raw.clamp(0.0, (_layout.itemCount - 1).toDouble());
  }

  void _onTabBarTapUp(TapUpDetails d) {
    final cellW = _layout.cellWidth;
    final raw = d.localPosition.dx / cellW;
    final idx = raw.floor().clamp(0, _layout.itemCount - 1);
    _animateTo(idx, notify: true);
  }

  // ── Drag handlers ──
  void _onTabPillDragStart(DragStartDetails d) {
    _tabDragging = true;
    _pillGlassActive = true;
    _startCapture();
    final frac = _xToTabFrac(d.globalPosition.dx);
    _tabPillJellyLastFrac = frac;
    _tabPillJellyLastTs = DateTime.now();
    _tabPillStretch = 0;
    _tabPillStretchVel = 0;
    _tabPillStretchTarget = 0;
    _tabPillJellyTickerLast = null;
    if (_tabPillJellyTicker?.isActive != true) {
      _tabPillJellyTicker?.start();
    }
    setState(() => _tabPillFracIndex = frac);
  }

  void _onTabPillDragUpdate(DragUpdateDetails d) {
    if (!_tabDragging) return;
    final frac = _xToTabFrac(d.globalPosition.dx);
    _pumpTabPillJelly(frac);
    setState(() => _tabPillFracIndex = frac);
  }

  void _onTabPillDragEnd(DragEndDetails d) => _releaseTabPillDrag();

  void _onTabPillDragCancel() {
    if (!_tabDragging) return;
    _releaseTabPillDrag();
  }

  void _releaseTabPillDrag() {
    final from = _tabPillFracIndex;
    final next = from.round().clamp(0, _layout.itemCount - 1);
    final notify = next != _tabIndex;
    final fromTween = from;
    setState(() {
      _tabDragging = false;
      _settlingFromDrag = true;
      _tabIndex = next;
      _pillGlassActive = true;
      _tabIndexTween = Tween<double>(begin: fromTween, end: next.toDouble())
          .chain(CurveTween(curve: widget.motion.curve))
          .animate(_tabAnim);
    });
    _tabAnim
      ..duration = const Duration(milliseconds: 140)
      ..reset()
      ..forward();
    if (notify) widget.onChanged(next);
  }

  void _pumpTabPillJelly(double newFrac) {
    final now = DateTime.now();
    final dt = now.difference(_tabPillJellyLastTs).inMicroseconds / 1e6;
    if (dt > 0) {
      const kMaxVelocity = 8.0;
      final signedVel =
          ((newFrac - _tabPillJellyLastFrac) / dt).clamp(-60.0, 60.0);
      _tabPillStretchTarget = (signedVel / kMaxVelocity).clamp(-1.0, 1.0);
    }
    _tabPillJellyLastFrac = newFrac;
    _tabPillJellyLastTs = now;
  }

  void _onTabPillJellyTick(Duration elapsed) {
    final last = _tabPillJellyTickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _tabPillJellyTickerLast = elapsed;

    if (_tabDragging) {
      final timeSincePump =
          DateTime.now().difference(_tabPillJellyLastTs).inMicroseconds / 1e6;
      if (timeSincePump > 0.032) {
        const targetTau = 0.08;
        final targetAlpha = 1 - math.exp(-dt / targetTau);
        _tabPillStretchTarget *= (1 - targetAlpha);
      }
    } else {
      _tabPillStretchTarget = 0;
    }

    final result = _springStep(
      x: _tabPillStretch,
      vel: _tabPillStretchVel,
      target: _tabPillStretchTarget,
      dt: dt,
      stiffness: 320,
      damping: 22,
    );
    _tabPillStretch = result.$1;
    _tabPillStretchVel = result.$2;

    if (!_tabDragging &&
        _tabPillStretch.abs() < 0.005 &&
        _tabPillStretchVel.abs() < 0.05 &&
        _tabPillStretchTarget.abs() < 0.005) {
      _tabPillStretch = 0;
      _tabPillStretchVel = 0;
      _tabPillStretchTarget = 0;
      _tabPillJellyTicker?.stop();
    }
    if (mounted) setState(() {});
  }

  static (double, double) _springStep({
    required double x,
    required double vel,
    required double target,
    required double dt,
    double stiffness = 280,
    double damping = 18,
  }) {
    var t = dt;
    var px = x;
    var pv = vel;
    while (t > 0) {
      final step = t > 1 / 240.0 ? 1 / 240.0 : t;
      final accel = -stiffness * (px - target) - damping * pv;
      pv += accel * step;
      px += pv * step;
      t -= step;
    }
    return (px, pv);
  }

  bool get _pillGlassVisible => _tabAnim.isAnimating || _tabDragging;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final parentWidth = constraints.maxWidth;
      final parentHeight = constraints.maxHeight;

      final centeredLeft = (parentWidth - _layout.width) / 2;
      if (widget.barPosition != null) {
        final off = widget.barPosition!.resolve(
          Size(parentWidth, parentHeight),
          Size(_layout.width, _layout.height),
        );
        _barLeft = off.dx;
        _effBottomMargin = parentHeight - off.dy - _layout.height;
      } else {
        _barLeft = centeredLeft;
        _effBottomMargin = _layout.bottomMargin;
      }
      final dx = _barLeft - centeredLeft;
      final layout = _layout.copyWith(bottomMargin: _effBottomMargin);

      final t = _tabAnim.value.clamp(0.0, 1.0);
      final cellW = layout.cellWidth;

      final glassOverflowPx = widget.pill.growHeight;
      final restRatio = layout.pillWidth / layout.cellHeight;
      final targetGlassH = layout.height + glassOverflowPx;
      final targetGlassW = targetGlassH * restRatio;

      final double growT;
      if (_tabDragging) {
        growT = 1.0;
      } else if (_settlingFromDrag) {
        growT = (1.0 - t).clamp(0.0, 1.0);
      } else {
        growT = liquidGlassMorphEnvelope(t);
      }

      final glassH =
          layout.cellHeight + (targetGlassH - layout.cellHeight) * growT;
      final glassW =
          layout.pillWidth + (targetGlassW - layout.pillWidth) * growT;
      final pillExtraH = glassH - layout.cellHeight;

      final pillFrac = _tabDragging ? _tabPillFracIndex : _tabIndexTween.value;

      final staticPillLeft =
          _barLeft + layout.padding + _tabIndexCommitted * cellW;
      final staticBottom = _effBottomMargin + layout.padding;

      final tabStretchMag = _tabPillStretch.abs().clamp(0.0, 1.2);
      final tabSqueezeW = -layout.pillWidth * 0.18 * tabStretchMag;
      final tabStretchH = layout.pillExtraHeight * 0.18 * tabStretchMag;

      final bool glassOn = _pillGlassVisible;
      final double? hlFrac = glassOn ? pillFrac : null;
      final double? hlW = glassOn
          ? layout.pillWidth + (glassW - layout.pillWidth) + tabSqueezeW
          : null;
      final double? hlH =
          glassOn ? layout.cellHeight + pillExtraH + tabStretchH : null;

      return Stack(
        fit: StackFit.expand,
        children: [
          LiquidGlassView.withPositionedLenses(
            controller: _outerViewController,
            pixelRatio: widget.render.pixelRatio,
            useSync: widget.render.useSync,
            realTimeCapture: true,
            refreshRate: widget.render.refreshRate,
            useImpellerBackdrop: widget.render.useImpellerBackdrop,
            backgroundWidget: _buildInner(
              layout: layout,
              pillFrac: hlFrac,
              pillW: hlW,
              pillH: hlH,
            ),
            children: [
              if (glassOn)
                _buildStyledNavPill(
                  key: const ValueKey('lg-styled-nav-morph-pill'),
                  layout: layout,
                  animatedIndex: pillFrac,
                  parentWidth: parentWidth,
                  dx: dx,
                  blur: widget.pill.blur,
                  distortion: widget.pill.distortion,
                  distortionWidth: widget.pill.distortionWidth,
                  refraction: widget.pill.refraction,
                  magnification: widget.pill.magnification,
                  enableInnerRadiusTransparent:
                      widget.pill.enableInnerRadiusTransparent,
                  extraHeight: pillExtraH + tabStretchH,
                  extraWidth: (glassW - layout.pillWidth) + tabSqueezeW,
                ),
              for (int i = 0; i < widget.outerLenses.length; i++)
                widget.outerLenses[i].key != null
                    ? widget.outerLenses[i]
                    : widget.outerLenses[i]
                        .copyWith(key: ValueKey('lg-styled-nav-outer-$i')),
            ],
          ),
          if (widget.itemStyle.showSelectionPill &&
              !_pillGlassActive &&
              !_tabDragging)
            Positioned(
              key: const ValueKey('lg-styled-nav-pill-static'),
              left: staticPillLeft,
              bottom: staticBottom,
              child: _StyledRestPill(
                width: layout.pillWidth,
                height: layout.cellHeight,
                color: widget.itemStyle.selectionColor,
              ),
            ),
          Positioned(
            key: const ValueKey('lg-styled-nav-gesture-overlay'),
            left: _barLeft + layout.padding,
            bottom: staticBottom,
            width: layout.width - 2 * layout.padding,
            height: layout.cellHeight,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (instance) => instance.onTapUp = _onTabBarTapUp,
                ),
                HorizontalDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                  (instance) => instance
                    ..onStart = _onTabPillDragStart
                    ..onUpdate = _onTabPillDragUpdate
                    ..onEnd = _onTabPillDragEnd
                    ..onCancel = _onTabPillDragCancel,
                ),
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildInner({
    required LiquidGlassTabBarLayout layout,
    double? pillFrac,
    double? pillW,
    double? pillH,
  }) {
    final Widget background = widget.backgroundColor == null
        ? widget.body
        : ColoredBox(color: widget.backgroundColor!, child: widget.body);

    return Stack(
      fit: StackFit.expand,
      children: [
        LiquidGlassView.withPositionedLenses(
          controller: _innerViewController,
          pixelRatio: widget.render.pixelRatio,
          useSync: widget.render.useSync,
          realTimeCapture: widget.render.realTimeCapture,
          refreshRate: widget.render.refreshRate,
          useImpellerBackdrop: widget.render.useImpellerBackdrop,
          backgroundWidget: background,
          children: [
            _buildStyledNavCapsule(
              layout: layout,
              refraction: widget.refraction,
              appearance: widget.appearance,
              shape: widget.shape,
              position: widget.barPosition,
            ),
          ],
        ),
        IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: _StyledNavShell(
              items: widget.items,
              selectedIndex: _tabIndexCommitted,
              layout: layout,
              itemStyle: widget.itemStyle,
              left: _barLeft,
              bottom: _effBottomMargin,
              highlightFrac: pillFrac,
              highlightWidth: pillW,
              highlightHeight: pillH,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Builders (styled copies of the shipping nav-bar builders)
// ─────────────────────────────────────────────────────────────────────────

/// The long bar-capsule lens. Mirrors `buildLiquidGlassBottomNavCapsule`, but
/// each config group is an optional override merged over the bar default: a
/// `null` group keeps the default, a supplied group wins.
LiquidGlass _buildStyledNavCapsule({
  required LiquidGlassTabBarLayout layout,
  LiquidGlassRefraction? refraction,
  LiquidGlassAppearance? appearance,
  LiquidGlassShape? shape,
  LiquidGlassPosition? position,
}) {
  return LiquidGlass(
    geometry: LiquidGlassGeometry(
      position: position ??
          LiquidGlassAlignPosition(
            alignment: Alignment.bottomCenter,
            margin: EdgeInsets.only(bottom: layout.bottomMargin),
          ),
      width: layout.width,
      height: layout.height,
    ),
    shape: shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: layout.height / 2,
          borderWidth: 1.2,
          lightIntensity: 1.1,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.2,
            ambientIntensity: 1.0,
            borderSolidity: 0.35,
          ),
        ),
    refraction: refraction ??
        const LiquidGlassRefraction(
          distortion: 0.07,
          distortionWidth: 28,
          chromaticAberration: 0.002,
        ),
    appearance: appearance ??
        const LiquidGlassAppearance(
          color: Color(0x16FFFFFF), // white, alpha 22
          blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
        ),
  );
}

/// The moving liquid-glass selection pill. Mirrors
/// `buildLiquidGlassBottomNavPill` (its own optical-rim look is kept; the pill
/// surface is intentionally not exposed as a group in this sandbox).
LiquidGlass _buildStyledNavPill({
  required LiquidGlassTabBarLayout layout,
  required double animatedIndex,
  required double parentWidth,
  Key? key,
  double? extraHeight,
  double extraWidth = 0,
  double dx = 0,
  LiquidGlassBlur blur = const LiquidGlassBlur(),
  double distortion = 0.06,
  double distortionWidth = 10,
  LiquidGlassRefraction? refraction,
  double magnification = 1,
  bool enableInnerRadiusTransparent = false,
}) {
  final extra = extraHeight ?? layout.pillExtraHeight;
  final cellW = layout.cellWidth;
  final barLeft = (parentWidth - layout.width) / 2 + dx;
  final pillLeft = barLeft + layout.padding + animatedIndex * cellW;
  final pillBottom = layout.bottomMargin + layout.padding - extra / 2;
  final pillH = layout.cellHeight + extra;
  final pillW = layout.pillWidth + extraWidth;
  final adjustedLeft = pillLeft - extraWidth / 2;

  return LiquidGlass(
    key: key,
    geometry: LiquidGlassGeometry(
      position:
          LiquidGlassOffsetPosition(left: adjustedLeft, bottom: pillBottom),
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
    refraction: refraction ??
        LiquidGlassRefraction(
          distortion: distortion,
          distortionWidth: distortionWidth,
          magnification: magnification,
          chromaticAberration: 0.002,
        ),
    appearance: LiquidGlassAppearance(
      color: Colors.white.withAlpha(28),
      blur: blur,
      enableInnerRadiusTransparent: enableInnerRadiusTransparent,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Styled shell + rest pill + clippers (local copies, parameterized by style)
// ─────────────────────────────────────────────────────────────────────────

/// Plain (non-shader) rest pill, styled by [color]. Mirrors
/// `LiquidGlassBottomNavPillStatic` but honors the item style's selection
/// color.
class _StyledRestPill extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _StyledRestPill({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Styled animated shell: the iOS-26 "icon highlights through the moving
/// pill" reveal, with icon/label colors + sizes taken from [itemStyle].
class _StyledNavShell extends StatelessWidget {
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final LiquidGlassTabBarLayout layout;
  final LiquidGlassNavBarItemStyle itemStyle;
  final double? highlightFrac;
  final double? highlightWidth;
  final double? highlightHeight;
  final double? left;
  final double? bottom;

  const _StyledNavShell({
    required this.items,
    required this.selectedIndex,
    required this.layout,
    required this.itemStyle,
    this.highlightFrac,
    this.highlightWidth,
    this.highlightHeight,
    this.left,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final hasHighlight = highlightFrac != null &&
        highlightWidth != null &&
        highlightHeight != null;

    final Widget innerStack = SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        children: [
          if (hasHighlight)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: _OutsidePillClipper(
                    pillRect: _pillRect(),
                    pillRadius: highlightHeight! / 2,
                  ),
                  child: _StyledIconRow(
                    items: items,
                    layout: layout,
                    itemStyle: itemStyle,
                    forceUnselected: true,
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: IgnorePointer(
                child: _StyledIconRow(
                  items: items,
                  layout: layout,
                  itemStyle: itemStyle,
                  selectedIndex: selectedIndex,
                ),
              ),
            ),
          if (hasHighlight)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: _InsidePillClipper(
                    pillRect: _pillRect(),
                    pillRadius: highlightHeight! / 2,
                  ),
                  child: _StyledIconRow(
                    items: items,
                    layout: layout,
                    itemStyle: itemStyle,
                    forceSelected: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final double effBottom = bottom ?? layout.bottomMargin;
    if (left != null) {
      return Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(left: left!, bottom: effBottom),
          child: innerStack,
        ),
      );
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: effBottom),
        child: innerStack,
      ),
    );
  }

  Rect _pillRect() {
    final pillW = highlightWidth!;
    final pillH = highlightHeight!;
    final cellW = layout.cellWidth;
    final cellCenterX = layout.padding + (highlightFrac! + 0.5) * cellW;
    final cellCenterY = layout.height / 2;
    return Rect.fromCenter(
      center: Offset(cellCenterX, cellCenterY),
      width: pillW,
      height: pillH,
    );
  }
}

class _StyledIconRow extends StatelessWidget {
  final List<LiquidGlassTabBarItem> items;
  final LiquidGlassTabBarLayout layout;
  final LiquidGlassNavBarItemStyle itemStyle;
  final int? selectedIndex;
  final bool forceSelected;
  final bool forceUnselected;

  const _StyledIconRow({
    required this.items,
    required this.layout,
    required this.itemStyle,
    this.selectedIndex,
    this.forceSelected = false,
    this.forceUnselected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(layout.padding),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: _StyledShellTab(
                item: items[i],
                itemStyle: itemStyle,
                selected: forceSelected
                    ? true
                    : forceUnselected
                        ? false
                        : i == selectedIndex,
              ),
            ),
        ],
      ),
    );
  }
}

class _StyledShellTab extends StatelessWidget {
  final LiquidGlassTabBarItem item;
  final LiquidGlassNavBarItemStyle itemStyle;
  final bool selected;

  const _StyledShellTab({
    required this.item,
    required this.itemStyle,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? itemStyle.selectedItemColor : itemStyle.unselectedItemColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildLiquidGlassNavGlyph(
            context,
            item,
            color: color,
            size: itemStyle.iconSize,
            selected: selected,
          ),
          if (item.hasLabel) ...[
            const SizedBox(height: 2),
            buildLiquidGlassNavLabel(
              context,
              item,
              color: color,
              fontSize: itemStyle.labelFontSize,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              selected: selected,
            ),
          ],
        ],
      ),
    );
  }
}

/// Clips its child to the inside of the moving pill's rounded rect.
class _InsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;

  const _InsidePillClipper({required this.pillRect, required this.pillRadius});

  @override
  Path getClip(Size size) {
    return Path()
      ..addRRect(
          RRect.fromRectAndRadius(pillRect, Radius.circular(pillRadius)));
  }

  @override
  bool shouldReclip(_InsidePillClipper oldClipper) {
    return oldClipper.pillRect != pillRect ||
        oldClipper.pillRadius != pillRadius;
  }
}

/// Clips its child to "everything except the moving pill".
class _OutsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;

  const _OutsidePillClipper({required this.pillRect, required this.pillRadius});

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final pill = Path()
      ..addRRect(
          RRect.fromRectAndRadius(pillRect, Radius.circular(pillRadius)));
    return Path.combine(PathOperation.difference, full, pill);
  }

  @override
  bool shouldReclip(_OutsidePillClipper oldClipper) {
    return oldClipper.pillRect != pillRect ||
        oldClipper.pillRadius != pillRadius;
  }
}
