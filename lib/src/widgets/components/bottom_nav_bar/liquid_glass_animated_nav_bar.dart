import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../../../controllers/liquid_glass_view_controller.dart';
import 'liquid_glass_tab_bar.dart';
import '../liquid_glass_adaptive_area.dart';
import '../liquid_glass_tab_item.dart' show LiquidGlassTabBarItem;
import '../../lens/liquid_glass_batch.dart';
import '../../lens/liquid_glass_lens.dart';
import '../../lens/liquid_glass_lens_scope.dart';
import '../../utils/liquid_glass_adaptivity.dart';
import '../../utils/liquid_glass_adaptivity_driver.dart';
import '../../liquid_glass.dart';
import '../../utils/liquid_glass_light.dart';
import '../../liquid_glass_config.dart';
import '../../liquid_glass_style.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_spring.dart' show liquidGlassSpringStep;
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_refresh_rate.dart';
import '../../utils/liquid_glass_shape.dart';
import '../../utils/liquid_glass_lens_motion.dart';
import 'liquid_glass_nav_bar_motion_pill.dart';
import 'liquid_glass_tab_pill_behavior.dart';
import '../liquid_glass_shadow.dart';

/// Self-contained **animated** liquid-glass bottom nav bar — the
/// "morphing glass pill" that slides between tabs, grows out of the rest
/// highlight, lifts under a finger and can be scrubbed along the bar, and
/// reveals the selected icon as it passes.
///
/// This is the internal machinery behind
/// [LiquidGlassTabBar.glassPill]: it owns the entire dual
/// `LiquidGlassView` pipeline and is built by
/// [LiquidGlassTabBar.buildGlassPillBar] (which
/// `LiquidGlassScaffold` calls when the bar's `glassPill` mode resolves
/// for the active renderer). Prefer configuring it through
/// [LiquidGlassTabBar] — constructing it directly still works, but
/// it will be hidden from the public API in 3.0.
///
/// ## How the pill deforms
///
/// The BAR runs [LiquidGlassLensMotion], not the glass widget: its drawn
/// position is sampled every frame in PIXELS, differentiated twice, and
/// the averaged acceleration scales it oppositely on the two axes —
///
///     scaleX = 1 + d      scaleY = 1 − d
///
/// Force, not speed: the pill deforms hardest as it launches off a tab
/// and as it brakes into the next, and sits undeformed at constant
/// speed. There is no lean term, so it deforms about its centre and
/// travels on the spring alone.
///
/// Under a **finger** the sign is the force's own, so the pill answers
/// the hand: push it right and it stretches wide, push it left and it
/// squashes narrow and tall.
///
/// A **travel** takes the same magnitudes but keys the sign to the
/// direction it is going ([_travelSign]) — a tap to the left stretches
/// the pill for the whole trip, a tap to the right holds it narrow and
/// tall. Signed on the force, a journey contradicted itself: the launch
/// pulled one way and the braking the other, and only the braking was
/// still on screen when you looked at the tab you had chosen. The
/// landing is unchanged; the launch now agrees with it.
///
/// Because the model reads the position the pill is actually drawn at,
/// every motion feeds it and none needs special-casing: a drag-release
/// snap genuinely IS a travel, and its braking is exactly the landing
/// deformation you want.
///
/// It lives on the bar because the deformation belongs to the selection
/// pill as a thing, not to whichever widget is drawing it this frame. The
/// glass and the plain pill are both drawn at the size it produces, so it
/// runs unbroken across the hand-off between them — and it outlives the
/// glass, which is where the landing squash actually happens.
///
/// ## How the deformation is drawn
///
/// The pill is a [LiquidGlassNavBarMotionPill] — a lens widget — in the
/// outer view's `child:` slot. Its shape is evaluated at the ENVELOPE
/// (rest) size and the deformation rides the shader's `u_shapeScale` with
/// matching elliptical clips, so the outline STRETCHES as one body and
/// the end caps go elliptical rather than the capsule being re-rounded at
/// each new size. The outer view's capture is the inner stack, so the
/// pill still bends the bar's own glass.
///
/// A host's chrome — everything else it floats over the page — goes in
/// [chromeChild], and the bar decides which view draws it by renderer.
/// On **Impeller** it sits in the outer view's `child:` slot, after the
/// pill, exactly as it always has: no capture exists there, so the outer
/// view costs nothing at rest, and the chrome paints over the bar's cells
/// and the pill. On **Skia** the outer view captures the whole screen
/// again, and a settled bar unmounts the glass and puts that capture to
/// sleep — so there the chrome rides the inner view's own slot instead,
/// where it refracts the captured body directly and never wakes the
/// outer view. [outerChild] is the explicit outer slot for a host that
/// needs one on both renderers; it pairs with [outerNeedsRealtime].
///
/// Two layering notes. On Skia, [chromeChild] paints above the bar
/// capsule but below the icon shell and the pill, so glass placed over
/// the bar's own cells sits under them there (and over them on Impeller).
/// And the outer view paints its `child:` slot BELOW its positioned
/// `children:`, so the pill sits under [outerLenses] rather than over
/// them. Nothing overlaps a bottom-anchored pill in practice — an app bar
/// is at the top, a side action sits beside the bar.
///
/// ## Events, timing and travel
///
/// [behavior] holds the numbers (see [LiquidGlassTabPillBehavior]); the
/// defaults:
///
///  * A press lifts the pill **at once** — no hold — and sends it to the
///    pressed tab on the press itself.
///  * A finger that moves past `dragThreshold` scrubs: the pill keeps
///    the gap it had to the finger at that moment and moves with the
///    finger from there, on the follow spring, kept within the first and
///    last tab. Letting go selects the tab nearest where the finger is
///    pulling the pill (a tie keeps the current tab), and the pill travels
///    there from the position and velocity the scrub left it with.
///  * The travel is one spring for every distance (`travelDuration`,
///    `travelBounce`), ended once under a fifth of a point remains past
///    its overshoot.
///  * The lift rises on a critically damped `liftDuration` spring, holds
///    for as long as the finger is down and the pill is travelling, and is
///    released once the pill is within `dropDistance` of its tab, falling on
///    the same spring. So the pill arrives at full size and comes down
///    where it stands.
///
/// ## How the pill grows
///
/// The raised size is [pillGrowHeight] / [pillGrowWidth] over the resting
/// pill. The glass material rides the same lift,
/// so the pill looks like glass as it rises and stops looking like it as
/// it comes down.
///
/// ## Handing over to the plain pill
///
/// A settled bar draws no glass at all — no shader pass, no clip, no
/// outer capture, no dual-layer icon reveal. The glass gets there by
/// **becoming** the plain pill rather than being cross-faded with one.
///
/// From the lift's release the lens sheds its glass as the grey platter
/// returns — a critically damped `glassFadeDuration` spring — while
/// everything else keeps running: the rim and its contact shadow go
/// first, then the refraction band narrows to nothing behind them. The
/// deflation and the squash are untouched throughout — the pill is still
/// shrinking and still deforming while it stops looking like glass.
///
/// Only once there is nothing left in it to see — no glass, no lift, no
/// deformation — is the lens dropped and
/// `LiquidGlassBottomNavPillStatic` put in its place. By then the lens is
/// drawing a flat fill at rest size, which is exactly what the plain pill
/// draws, so the exchange is two identical pictures. That is what keeps
/// the plain pill plain: it never needs the deformation, the stretched
/// outline or an opacity, because it only ever appears once all three
/// have finished. A press mid-hand-over lifts the glass straight back.
///
/// [body] is the page content, captured behind the glass. [chromeChild]
/// is the host's chrome (e.g. the app bar and the side action button),
/// placed by renderer as described above; [outerLenses] and [outerChild]
/// are always in the outer view, over the bar and the pill.
class LiquidGlassAnimatedNavBar extends StatefulWidget {
  final Widget body;
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// A tap on the tab that is already selected, with its index: no scrub
  /// and not cancelled. `null` (the default) ignores it.
  final ValueChanged<int>? onReselected;

  /// Icon + label styling for every tab cell.
  final LiquidGlassTabItemStyle itemStyle;

  /// Whether the persistent selection glass pill is drawn.
  final bool showSelectionPill;

  /// Whether the OUTER pipeline must keep capturing independently of the
  /// selection pill. Hosts that put lenses in [outerChild] must pass
  /// `true` while those lenses are showing; [chromeChild] never needs it.
  final bool outerNeedsRealtime;

  /// Bar geometry (size, position, padding). The bottom margin should
  /// already include any safe-area inset.
  final LiquidGlassTabBarLayout layout;

  /// The host's chrome: a full-screen `Stack` of lens-anywhere widgets —
  /// app bar, side action, floating button, extra lenses. The bar
  /// places it by renderer. On Impeller it goes in the **outer** view's
  /// `child:` slot after the pill, over the bar's cells, as the outer slot
  /// always did. On Skia it goes in the **inner** view's `child:` slot,
  /// above the bar capsule and below the icon shell and the pill, so it
  /// refracts the body on the capture the bar already takes and the outer
  /// capture can sleep while the pill is at rest. Adaptive areas and
  /// lenses in it reach the inner view's sampler either way.
  final Widget? chromeChild;

  /// Lenses composited in the **outer** view, above the bar.
  final List<LiquidGlass> outerLenses;

  /// Widget subtree composited in the **outer** view's `child:` slot,
  /// above the captured bar/body and above the moving pill, which lives
  /// in that same slot. Reserved for what must paint over the bar's cells
  /// and the pill (a modal barrier); pair it with [outerNeedsRealtime].
  final Widget? outerChild;

  /// Optional solid color behind [body].
  final Color? backgroundColor;

  /// Custom placement for the bar.
  final LiquidGlassPosition? barPosition;

  /// Overrides the bar-capsule glass shape.
  final LiquidGlassShape? barShape;

  /// The bar capsule's border lights; `null` keeps [barShape]'s own, or the
  /// tuned defaults.
  final LiquidGlassLight? barSpecular;
  final LiquidGlassLight? barGlow;

  /// The bar capsule's second highlight; `null` draws none.
  final LiquidGlassLight? barSecondSpecular;

  /// Refraction of the bar capsule.
  final LiquidGlassRefraction? barRefraction;

  /// Appearance (tint + blur) of the bar capsule.
  final LiquidGlassAppearance? barAppearance;

  /// Draws the bar capsule as lite glass (see `LiquidGlassStyle.liteGlass`).
  final bool barLiteGlass;

  /// How the whole bar grows while the glass pill is lifted — capsule,
  /// pills and items, as one scale. `null` keeps the bar its size.
  final LiquidGlassTabBarSwell? barSwell;

  /// Whether the bar capsule joins an enclosing batch, such as the host's
  /// chrome. Off, it takes a read of its own.
  final bool capsuleJoinsBatch;

  /// iOS-style adaptivity for the whole bar (same contract as
  /// `LiquidGlassStyle.adaptivity`): the bar capsule's tint follows the
  /// adaptive glass color and the shell's **unselected** icons/labels
  /// the adaptive content color, flipping together as the background
  /// behind the bar turns dark or light (the selected item keeps
  /// [itemStyle]'s fixed `selectedColor`). The verdict comes from
  /// sampling the captured [body] through the inner view (see
  /// [sampleBackground]), a manual `permanentBrightness`, or a followed
  /// link. `null` (default) disables the feature entirely.
  final LiquidGlassAdaptivity? adaptivity;

  /// Tuning for the body-luminance sampling behind [adaptivity]. `null`
  /// uses the standard tuning (pixelRatio 0.05, frameLimit 8).
  final LiquidGlassAdaptiveSampling? adaptiveSampling;

  /// Sampling opt-in for adaptive areas/lenses a host places in
  /// [chromeChild] or [outerChild] (e.g. `LiquidGlassScaffold`'s system
  /// strips and shared adaptivity groups). All register with the
  /// **inner** view's sampler — the pre-glass body image — through that
  /// view's own scope when drawn inside it, through a redirect when drawn
  /// in the outer view — so the whole pipeline runs ONE sampler and no
  /// widget ever reads its own glass back. `null` (the default) leaves
  /// slot clients without sampling.
  final LiquidGlassAdaptiveSampling? outerAdaptiveSampling;

  /// The host's area context for the bar — the adaptivity group (e.g. a
  /// scaffold's shared-edges area or bottom band) the bar should behave
  /// as if it sat inside. The bar renders in its own pipeline, so it can
  /// never be a real descendant of that area; this is the explicit
  /// stand-in. Used as the fallback palettes when [adaptivity] is null.
  final LiquidGlassAdaptivity? areaAdaptivity;

  /// The link that area publishes its verdict on. When the bar's
  /// resolved adaptivity carries no link of its own, the bar follows
  /// this one instead of sampling its own region — one shared verdict,
  /// and the bar's own sampler stays off.
  final LiquidGlassAdaptivityLink? areaLink;

  /// Whether [adaptivity] may sample [body] through the inner view.
  /// Pass `false` when [body] is an empty stand-in (the bodyless
  /// standalone bar) — the verdict then falls back to the adaptivity's
  /// `permanentBrightness`, its followed link, or platform brightness.
  final bool sampleBackground;

  /// Also drive the system navigation bar's icon brightness from this
  /// bar's verdict (see [LiquidGlassSystemChrome]). The bar is a
  /// full-screen widget, so it covers the navigation bar's probe point
  /// by construction. Only the navigation-bar side applies on this path
  /// (`both` acts as `navigationBar`; `statusBar` is ignored — a top
  /// band here would have to sample the bar's own glass). Requires
  /// [adaptivity]. Off by default.
  final LiquidGlassSystemChrome systemChrome;

  /// Contact shadow around the **bar capsule** — the soft dark band that
  /// hugs its rim and pools underneath, so the bar reads as sitting in
  /// the page rather than floating on it. `null` (the default) draws
  /// none.
  ///
  /// It is drawn into the INNER stack, above the capsule's glass and
  /// below the icons, which puts it in the outer view's capture — so the
  /// moving pill refracts the bar's shadow along with its glass. Its
  /// corner follows [barShape] when one is set.
  final LiquidGlassShadow? barShadow;

  /// Blur behind the moving glass pill. Defaults to none.
  final double pillBlur;

  /// How much taller than the bar the glass pill stands while it is
  /// lifted — which is the whole travel, not a peak it passes through.
  final double pillGrowHeight;

  /// How much wider than the resting pill the glass pill is while it is
  /// lifted. `null` keeps the resting pill's proportions.
  final double? pillGrowWidth;

  /// Whether the drawn pill stays inside the bar's left and right edges,
  /// whatever its lift, squash or overshoot.
  final bool confineToBar;

  /// Refraction strength of the moving glass pill.
  final double pillRefractionIndex;

  /// Width of the glass pill's refraction band.
  final double pillRefractionWidth;

  /// Complete refraction configuration for the moving pill. When set,
  /// this supersedes [pillRefractionIndex], [pillRefractionWidth] and
  /// [pillMagnification].
  final LiquidGlassRefraction? pillRefraction;

  /// Magnification of the content seen through the glass pill.
  final double pillMagnification;

  /// Overrides the moving glass pill's shape. When `null` the pill is a
  /// continuous capsule-style shape whose radius tracks the pill's ENVELOPE
  /// height — the size before the acceleration deformation, since the
  /// shader stretches the authored outline rather than re-rounding it.
  final LiquidGlassShape? pillShape;

  /// The glass pill's border lights; `null` keeps [pillShape]'s own, or the
  /// pill's defaults.
  final LiquidGlassLight? pillSpecular;
  final LiquidGlassLight? pillGlow;

  /// The glass pill's second highlight; `null` draws none.
  final LiquidGlassLight? pillSecondSpecular;

  /// Fill tint of the moving glass pill.
  final Color pillColor;

  /// Contact shadow around the **moving pill**. `null` (the default)
  /// draws none.
  ///
  /// It wraps the pill's lens rather than living inside it, so the arc
  /// that pools below the pill is not clipped off at the outline, and it
  /// is handed the live envelope corner and outline stretch so the ring
  /// stays on the rim while the pill squashes. It fades with the pill.
  final LiquidGlassShadow? pillShadow;

  /// Draws the moving glass pill as lite glass (see
  /// `LiquidGlassStyle.liteGlass`), its Impeller magnifier with it.
  final bool pillLiteGlass;

  /// Resting material endpoint of the same persistent glass pill.
  final LiquidGlassStyle restStyle;

  /// The pill's acceleration squash/stretch tuning, applied on both
  /// finger-drags and tap-travel.
  ///
  /// The default caps the deformation at ±12 % rather than the free-floating
  /// ±30 % a slider thumb can afford: this pill lives inside the bar
  /// capsule, and a third of its height in overhang would climb out of it.
  final LiquidGlassLensMotionSpec motion;

  /// The events, timing and travel both models run on, and the landing
  /// deformation and bar-swell values.
  final LiquidGlassTabPillBehavior behavior;

  // Render pipeline knobs forwarded to both views.
  final double pixelRatio;
  final bool useSync;
  final bool? useImpellerBackdrop;

  /// See `LiquidGlassView.batch`, forwarded to both views. The bar's own
  /// capsule joins an enclosing batch only with [capsuleJoinsBatch]. The moving
  /// pill and the magnifier pill are kept out regardless: each takes a
  /// read of its own, so they refract the capsule, which a shared copy
  /// does not hold.
  final bool batch;

  /// See `LiquidGlassView.batchMode`, forwarded to both views.
  final LiquidGlassBatchMode? batchMode;

  /// See `LiquidGlassView.foregroundBatchId`, handed to both views: with it
  /// the [chromeChild] slots are one batch whichever view draws them — how
  /// the scaffold puts the sheets and dialogs presented over it, when they
  /// ask for it, on a single read. Library-internal.
  final int? foregroundBatchId;

  /// Whether the **inner** view (body + bar capsule) captures every frame.
  final bool realTimeCapture;

  /// The Impeller-only magnifier pill under the glass one — see
  /// [LiquidGlassTabMagnifierPillStyle].
  final LiquidGlassTabMagnifierPillStyle magnifierPill;

  const LiquidGlassAnimatedNavBar({
    super.key,
    required this.body,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.onReselected,
    required this.layout,
    this.itemStyle = const LiquidGlassTabItemStyle(),
    this.showSelectionPill = true,
    this.outerNeedsRealtime = false,
    this.chromeChild,
    this.outerLenses = const [],
    this.outerChild,
    this.backgroundColor,
    this.barPosition,
    this.barShape,
    this.barSpecular,
    this.barGlow,
    this.barSecondSpecular,
    this.barRefraction,
    this.barAppearance,
    this.barLiteGlass = false,
    this.barSwell,
    this.capsuleJoinsBatch = false,
    this.barShadow,
    this.pillShadow,
    this.pillLiteGlass = false,
    this.pillBlur = 0,
    this.pillGrowHeight = 12,
    this.pillGrowWidth,
    this.confineToBar = false,
    this.pillRefractionIndex = 1.025,
    this.pillRefractionWidth = 10,
    this.pillRefraction,
    this.pillMagnification = 1,
    this.pillShape,
    this.pillSpecular,
    this.pillGlow,
    this.pillSecondSpecular,
    this.pillColor = const Color(0x1CFFFFFF),
    // Inert at rest: the moving pill hands over to a non-refracting
    // static pill, so any glass left here would pop off at the swap.
    this.restStyle = const LiquidGlassStyle(
      color: Color(0x26FFFFFF),
      blur: 0,
      refractionIndex: 1.0,
      refractionWidth: 0,
      dispersion: 0,
    ),
    this.motion = const LiquidGlassLensMotionSpec(
      sampleWindow: 0.3,
      sensitivity: 0.00007,
      maxDeformation: 0.12,
      responseTime: 0.18,
    ),
    this.behavior = const LiquidGlassTabPillBehavior(),
    this.pixelRatio = 1.0,
    this.useSync = true,
    this.useImpellerBackdrop,
    this.batch = true,
    this.batchMode,
    this.foregroundBatchId,
    this.realTimeCapture = true,
    this.magnifierPill = const LiquidGlassTabMagnifierPillStyle(),
    this.adaptivity,
    this.adaptiveSampling,
    this.outerAdaptiveSampling,
    this.areaAdaptivity,
    this.areaLink,
    this.sampleBackground = true,
    this.systemChrome = LiquidGlassSystemChrome.none,
  });

  @override
  State<LiquidGlassAnimatedNavBar> createState() =>
      _LiquidGlassAnimatedNavBarState();
}

class _LiquidGlassAnimatedNavBarState extends State<LiquidGlassAnimatedNavBar>
    with TickerProviderStateMixin, LiquidGlassAdaptiveClient {
  // Inner pipeline captures wallpaper + bar capsule; outer composites
  // the moving glass pill on top so it refracts the bar's own glass.
  final _outerViewController = LiquidGlassViewController();
  final _innerViewController = LiquidGlassViewController();

  // ===== Adaptivity (widget.adaptivity) =====
  // The shared verdict machine (see [LiquidGlassAdaptivityDriver]) does
  // all deciding/animating. The sampling itself runs in the INNER view
  // (it owns the captured body); a registrar in that view's child slot
  // enrolls this state as the sampler's client, and every sample is
  // forwarded to the driver.
  late final LiquidGlassAdaptivityDriver _adaptDriver =
      LiquidGlassAdaptivityDriver(vsync: this);

  // Identity-stable redirect functions for the outer slots' adaptive
  // clients (clients re-register whenever the function identity
  // changes, so these are created exactly once). They forward to the
  // inner view's sampler through its controller.
  late final void Function(LiquidGlassAdaptiveClient) _outerAdaptiveRegister =
      _innerViewController.registerAdaptiveClient;
  late final void Function(LiquidGlassAdaptiveClient) _outerAdaptiveUnregister =
      _innerViewController.unregisterAdaptiveClient;

  /// An outer-view slot with its adaptive clients redirected to the inner
  /// sampler — or the slot as given when the host asked for no sampling.
  Widget _outerRedirected(Widget slot) => widget.outerAdaptiveSampling == null
      ? slot
      : LiquidGlassAdaptiveSamplerScope(
          register: _outerAdaptiveRegister,
          unregister: _outerAdaptiveUnregister,
          child: slot,
        );

  /// Effective adaptivity for this build: the widget's own, else the
  /// enclosing [LiquidGlassAdaptiveArea]'s. Resolved in [build].
  LiquidGlassAdaptivity? _effAdaptivity;

  /// The link the bar follows this build (explicit link, else the
  /// enclosing area's). Null when the bar resolves its own verdict.
  LiquidGlassAdaptivityLink? _adaptFollow;

  /// Whether the verdict comes from sampling the captured body: no
  /// manual override, no link/area to follow, and the body is real
  /// (see [LiquidGlassAnimatedNavBar.sampleBackground]).
  bool get _adaptSamples => _adaptDriver.samplingWanted(_effAdaptivity,
      following: _adaptFollow != null, canRegister: widget.sampleBackground);

  /// The sampling config the HOST handed down — this bar's own slot
  /// first, then the outer pipeline's. Null means the host did not ask
  /// for adaptive sampling, and the bar does not start one for itself.
  LiquidGlassAdaptiveSampling? get _hostSampling =>
      widget.adaptiveSampling ?? widget.outerAdaptiveSampling;

  /// The adaptivity controller flipped: rebuild so sampling
  /// registration and the driver's verdict source follow the switch.
  void _adaptResync() {
    if (mounted) setState(() {});
  }

  @override
  Rect? adaptiveRegion(RenderBox backgroundBox) {
    if (!mounted) return null;
    // The bar's rect in the inner background's coordinate space, from
    // the same geometry the capsule lens is positioned with. (The inner
    // background and the outer overlay share the full-screen size, so
    // the build-time [_barLeft]/[_effBottomMargin] apply directly.)
    final Size size = backgroundBox.size;
    final double top = size.height - _effBottomMargin - _layout.height;
    return Rect.fromLTWH(_barLeft, top, _layout.width, _layout.height);
  }

  @override
  ui.Path? adaptiveMaskPath(RenderBox backgroundBox, Rect region) {
    final LiquidGlassShape shape = widget.barShape ??
        const LiquidGlassShape.roundedRectangle(cornerRadius: 40);
    return liquidGlassOutlinePath(shape, region.size, const Offset(1, 1))
        .shift(region.topLeft);
  }

  @override
  void onAdaptiveSample(LiquidGlassBackdropSample sample) {
    if (!mounted) return;
    _adaptDriver.onBackdropSample(sample);
  }

  /// Live selection driving the animation (source of truth internally).
  late int _tabIndex;

  /// Index the static UI (shell icons, rest pill) shows as selected.
  /// Flips only AFTER the glass finishes travelling.
  late int _tabIndexCommitted;

  /// Fractional pill position (0..itemCount-1). While a finger scrubs
  /// this is its target; the pill is drawn at [_dragFollow], the follow
  /// spring's chase of it.
  double _tabPillFracIndex = 0;
  double _dragFollow = 0;
  bool _tabDragging = false;

  // ── Travel spring ────────────────────────────────────────────────
  double _travelPos = 0;
  double _travelVel = 0;
  double _travelTarget = 0;
  double _travelFrom = 0;

  /// True from the moment a travel starts until the spring settles.
  bool _travelActive = false;

  /// Whether the pill is currently held up at its raised size. It goes
  /// up the instant a finger lands or a travel starts, stays up for the
  /// whole journey and for as long as the finger is down, and comes down
  /// once the pill is within the release distance of its tab.
  bool _lifted = false;

  /// The pill's acceleration squash/stretch — owned by the BAR, not by
  /// the glass pill.
  ///
  /// The deformation belongs to the selection pill as a thing, not to
  /// whichever widget happens to be drawing it. Both the glass and the
  /// plain pill are drawn at the size this produces, so a hand-off in the
  /// middle of a squash is invisible; and it keeps running after the
  /// glass is gone, which is where the landing squash actually lands.
  late final LiquidGlassLensMotion _pillMotion =
      LiquidGlassLensMotion(spec: widget.motion);
  double _deviation = 0;

  /// Which way the current travel is headed — `-1` left, `1` right, `0`
  /// while a finger is driving the pill instead.
  ///
  /// A travel deforms by where it is GOING, not by which way the force
  /// happens to point this instant. The raw model is signed on the
  /// force, so a journey used to contradict itself: the launch and the
  /// braking pull the pill opposite ways, and only the second of the two
  /// is still on screen when you look. Keyed to the travel instead, the
  /// launch agrees with the landing — a tap to the left stretches the
  /// pill wide for the whole trip, a tap to the right holds it narrow
  /// and tall — and the landing itself is the deformation it always was.
  ///
  /// Only the travel is keyed this way. A finger keeps the raw force,
  /// where pushing right stretches and pushing left squashes: a drag is
  /// something you are doing to the pill, and it should answer the hand.
  double _travelSign = 0;

  /// The key the deformation is actually drawn with, which crosses
  /// between the two directions rather than switching.
  ///
  /// Tapping a tab on the other side mid-flight reverses [_travelSign]
  /// in one frame, and with it the entire deformation — a pill squashed
  /// narrow would be stretched wide on the very next frame. Crossing
  /// instead takes it through `0`, where the pill is drawn on the raw
  /// force it always was, so a reversal passes through undeformed
  /// instead of turning inside out. A travel starting from rest has
  /// nothing to cross and takes its key at once.
  double _travelSignEased = 0;

  /// How far the pill has shed its glass. `0` = the full material, `1` =
  /// a flat fill indistinguishable from the plain pill.
  double _handover = 1;

  /// Pill centre, recomputed on the ticker so the motion model samples
  /// the position the pill is drawn at this frame — not last frame's.
  Offset _pillCenter = Offset.zero;
  bool _pillCenterValid = false;

  /// The bar's press scale above its size (`0` at rest) and its spring
  /// velocity, and where across the bar it grows from, `0`..`1`.
  double _press = 0, _pressVel = 0;
  double _pressAnchorX = 0.5;

  // ===== Events, timing and travel (see [LiquidGlassTabPillBehavior]).

  /// The events', timing's and travel's values.
  LiquidGlassTabPillBehavior get _m => widget.behavior;

  /// The bar's clock in seconds, carried across ticker restarts (a
  /// ticker's `elapsed` starts over each time it is started).
  double _mNow = 0;

  /// The finger on the bar: which pointer, whether it is down, where it
  /// pressed and where it is now, in row x.
  int _pointerId = -1;
  bool _fingerDown = false;
  double _pressRowX = 0;
  double _fingerRowX = 0;

  /// Whether the finger has moved past the drag threshold and scrubs the
  /// pill.
  bool _scrubbing = false;

  /// Whether the press landed on the tab that was already selected.
  bool _pressedSelected = false;

  /// The scrub follow spring's velocity; its position is [_dragFollow].
  double _dragVel = 0;

  /// The grab: how far the pill's centre sat from the finger, in row x,
  /// when the scrub began. The pill keeps that gap and moves 1:1 with the
  /// finger from there, rather than jumping under it.
  double _grabOffsetX = 0;

  /// When the lift was last released on the clock — the landing — kept
  /// until the next gesture: the landing wobble runs from here.
  double? _landedAt;

  /// The one lift, size and material alike, and its velocity.
  double _mLift = 0, _mLiftVel = 0;

  /// The grey platter's return spring velocity; its position is
  /// [_handover].
  double _mHandoverVel = 0;

  /// The vertical half of the deformation: `scaleY = 1 − _devY`. The
  /// horizontal half rides [_deviation]. Equal to it except through the
  /// landing wobble, whose two axes are independent.
  double _devY = 0;

  /// The pill centre's offset along the travel, in cells (the wobble's).
  double _leadFrac = 0;

  /// Logical pixels per point of the timing: the bar's height over the
  /// behaviour's 62 pt bar.
  double get _ptScale => _layout.height / _m.barHeight;

  /// Where the pill is drawn this frame, in cells: the travel or the scrub
  /// follow, plus the landing wobble's small centre offset.
  double get _drawFrac => (_tabDragging ? _dragFollow : _travelPos) + _leadFrac;

  /// The press as a map, set each build: everything on the bar scales by
  /// [_swellScale] about [_swellAnchor] (the outer view's coordinates).
  double _swellScale = 1;
  Offset _swellAnchor = Offset.zero;

  // Untouched at rest: mapping through a scale of 1 could still move the
  // point by a rounding error, and the pills sit on the pixel grid.
  Offset _swellPoint(Offset p) =>
      _swellScale == 1 ? p : _swellAnchor + (p - _swellAnchor) * _swellScale;

  /// Single ticker driving the travel spring, the motion sampling and
  /// the settle-grow decay.
  Ticker? _ticker;
  Duration? _tickerLast;

  /// Absolute left edge of the bar in the parent, recomputed each build.
  double _barLeft = 0;

  /// Effective bottom inset of the bar.
  double _effBottomMargin = 0;

  /// True when the lenses render on the Impeller BackdropFilter path —
  /// the same resolution [LiquidGlassView] applies. Only there do
  /// stacked lenses chain (each samples everything painted beneath it),
  /// which is what the under-pill magnifier needs; the Skia capture
  /// path keeps the single glass pill exactly as it is.
  late final bool _useImpeller = (widget.useImpellerBackdrop ?? true) &&
      ui.ImageFilter.isShaderFilterSupported;

  LiquidGlassTabBarLayout get _layout => widget.layout;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.selectedIndex;
    _tabIndexCommitted = widget.selectedIndex;
    _tabPillFracIndex = widget.selectedIndex.toDouble();
    _travelPos = widget.selectedIndex.toDouble();
    _travelTarget = _travelPos;
    _travelFrom = _travelPos;
    _ticker = createTicker(_onTick);
  }

  /// Starts the shared ticker if it isn't already running.
  void _startTicker() {
    if (_ticker?.isActive != true) {
      _tickerLast = null;
      _ticker?.start();
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassAnimatedNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Live tuning: the squash and stretch takes it from the next frame.
    _pillMotion.spec = widget.motion;
    // External (programmatic) selection change — animate to it without
    // re-notifying the parent.
    if (widget.selectedIndex != _tabIndex &&
        widget.selectedIndex != oldWidget.selectedIndex) {
      _animateTo(widget.selectedIndex, notify: false);
    }
  }

  @override
  void dispose() {
    // (Sampler unregistration is owned by the registrar widget inside
    // the inner view — it unmounts with this subtree.)
    _adaptDriver.dispose();
    _ticker?.dispose();
    _outerViewController.detach();
    _innerViewController.detach();
    super.dispose();
  }

  // ── Capture lifecycle ────────────────────────────────────────────
  void _startCapture() {
    if (!widget.realTimeCapture) _innerViewController.startRealtimeCapture();
    // The OUTER view is the one the moving pill samples on Skia, and it
    // sleeps at rest — so it is woken here, at the gesture, rather than
    // being left to the rebuilt widget's `realTimeCapture` flag alone.
    // The wake retires the sleep-time capture with it, so the pill's
    // first frame refracts the live bar and not the snapshot from
    // whenever the bar last settled. Idempotent when already live.
    if (!widget.outerNeedsRealtime) {
      _outerViewController.startRealtimeCapture();
    }
  }

  void _maybeStopCapture() {
    if (!_travelActive && !_tabDragging) {
      if (!widget.realTimeCapture) _innerViewController.stopRealtimeCapture();
      if (!widget.outerNeedsRealtime) {
        _outerViewController.stopRealtimeCapture();
      }
    }
  }

  // ── Selection / animation ────────────────────────────────────────
  /// A programmatic selection: the pill travels there as a tap's would.
  void _animateTo(int next, {required bool notify}) {
    if (next == _tabIndex) return;
    _travelTo(next, notify: notify);
  }

  // ── Gesture geometry ─────────────────────────────────────────────
  // The overlay spans the row, so its local x is already row-relative —
  // and stays right wherever the bar sits on the screen.
  double _xToTabFrac(double rowDx) => _layout.fracAt(rowDx);

  // ── The gestures: a zero-delay press, a scrub
  // past the drag threshold, a release on the tab nearest the finger ──
  void _onPointerDown(PointerDownEvent e) {
    if (_fingerDown) return;
    final double rowX = e.localPosition.dx;
    // A disabled tab ignores the press.
    if (!widget.items[_layout.indexAt(rowX)].enabled) return;
    _pointerId = e.pointer;
    _fingerDown = true;
    _scrubbing = false;
    _pressRowX = rowX;
    _fingerRowX = rowX;
    _lifted = true;
    _landedAt = null;
    _startCapture();
    _startTicker();
    // The lens leaves for the pressed tab on the press itself, not on
    // the release.
    final int next = _layout.indexAt(rowX);
    _pressedSelected = next == _tabIndex;
    if (next != _tabIndex) {
      _travelTo(next, notify: true);
    } else {
      setState(() {});
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_fingerDown || e.pointer != _pointerId) return;
    final double rowX = e.localPosition.dx;
    _fingerRowX = rowX;
    if (!_scrubbing &&
        (rowX - _pressRowX).abs() > _m.dragThreshold * _ptScale) {
      // The pill leaves its tap motion from where it is, keeping its
      // speed, and follows the finger from here.
      _scrubbing = true;
      _tabDragging = true;
      _travelActive = false;
      _dragFollow = _travelPos;
      _dragVel = _travelVel;
      // Grabbed where it is GOING: the gap between the travel's target
      // and the finger is kept, so a scrub that starts mid-flight carries
      // the pill on to the pressed tab and moves it by what the finger
      // moves from there — not from wherever the flight had got to. At
      // rest the target is where the pill is, and it doesn't jump under
      // the finger.
      _grabOffsetX =
          _layout.pillOffset(_travelTarget) + _layout.pillWidth / 2 - rowX;
      // The hand takes the deformation back off the travel's key.
      _travelSign = 0;
      _landedAt = null;
    }
    if (_scrubbing) {
      setState(() => _tabPillFracIndex = _xToTabFrac(rowX + _grabOffsetX));
    }
  }

  void _onPointerEnd(int pointer, {bool cancelled = false}) {
    if (!_fingerDown || pointer != _pointerId) return;
    _fingerDown = false;
    if (!_scrubbing && !cancelled && _pressedSelected) {
      widget.onReselected?.call(_tabIndex);
    }
    if (_scrubbing) {
      _scrubbing = false;
      // The tab nearest where the finger is PULLING the pill (the finger
      // plus the grab gap), not the pill itself, which can be well behind
      // after a flick; a tie keeps the current tab.
      final double frac = _layout.fracAt(_fingerRowX + _grabOffsetX);
      final double half = frac - frac.floorToDouble();
      final int next = _nearestEnabled(
          ((half - 0.5).abs() < 1e-3 ? _tabIndex : frac.round())
              .clamp(0, _layout.itemCount - 1));
      final bool notify = next != _tabIndex;
      // The pill travels there on the tap's own spring, from the position
      // and velocity the scrub left it with; the lift drops as it lands.
      setState(() {
        _tabDragging = false;
        _tabIndex = next;
        _travelActive = true;
        _travelPos = _dragFollow;
        _travelVel = _dragVel;
        _travelFrom = _dragFollow;
        _travelTarget = next.toDouble();
        _travelSign = _signOfTravel(_travelTarget - _travelFrom);
      });
      if (notify) widget.onChanged(next);
    }
    _startTicker();
  }

  /// [i] when it is enabled, else the nearest enabled tab (the lower on a
  /// tie), else the current tab.
  int _nearestEnabled(int i) {
    final List<LiquidGlassTabBarItem> items = widget.items;
    for (int d = 0; d < items.length; d++) {
      if (i - d >= 0 && items[i - d].enabled) return i - d;
      if (i + d < items.length && items[i + d].enabled) return i + d;
    }
    return _tabIndex;
  }

  /// Starts a tap travel to [next]: the travel spring from wherever the
  /// pill is, keeping its velocity, with the deformation keyed to the new
  /// direction.
  void _travelTo(int next, {required bool notify}) {
    setState(() {
      _tabIndex = next;
      _travelActive = true;
      _lifted = true;
      _landedAt = null;
      _tabDragging = false;
      _scrubbing = false;
      _travelFrom = _travelPos;
      _travelTarget = next.toDouble();
      _travelSign = _signOfTravel(_travelTarget - _travelFrom);
    });
    _startCapture();
    _startTicker();
    if (notify) widget.onChanged(next);
  }

  void _onTick(Duration elapsed) {
    final last = _tickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _tickerLast = elapsed;
    _stepFrame(dt);
  }

  /// One frame of the pill's physics, all of which the bar owns: the
  /// travel spring, the follow spring under a finger, the lift, the glass
  /// hand-over, the deformation and the bar's press. The pill widget is
  /// handed the results and draws them. The timing is in
  /// [LiquidGlassTabPillBehavior].
  void _stepFrame(double dt) {
    _mNow += dt;
    final double step = _layout.itemStep;
    final double s = _ptScale;
    // Cells to points along the row.
    final double cell = step / s;

    // 1) The travel spring: 0.4 s, bounce 0.15, ended once under
    // `settleDistance` remains past the overshoot.
    bool travelSettled = !_travelActive;
    if (_travelActive) {
      final r = liquidGlassSpringStep(
        x: _travelPos,
        vel: _travelVel,
        target: _travelTarget,
        dt: dt,
        stiffness: _m.travelStiffness,
        damping: _m.travelDamping,
      );
      _travelPos = r.$1;
      _travelVel = r.$2;
      final double remaining = (_travelPos - _travelTarget).abs() * cell;
      final double speed = (_travelVel * cell).abs();
      travelSettled =
          remaining < LiquidGlassTabPillBehavior.settleDistance && speed < 15;
      if (travelSettled) {
        _travelPos = _travelTarget;
        _travelVel = 0;
      }
    }

    // 2) The scrub follow: the pill after the finger, within the tabs.
    if (_tabDragging) {
      final r = liquidGlassSpringStep(
        x: _dragFollow,
        vel: _dragVel,
        target: _tabPillFracIndex,
        dt: dt,
        stiffness: _m.dragStiffness,
        damping: _m.dragDamping,
      );
      _dragFollow = r.$1;
      _dragVel = r.$2;
    }

    // 3) The lift: held while the finger is down, released once the pill
    // is within `dropDistance` of its tab, falling on the same spring.
    final double remaining = _tabDragging
        ? double.infinity
        : (_travelActive ? (_travelTarget - _travelPos).abs() * cell : 0);
    if (_lifted && !_fingerDown && remaining <= _m.dropDistance) {
      _lifted = false;
      _mHandoverVel = -_mLiftVel;
      _landedAt = _mNow;
    }
    final lr = liquidGlassSpringStep(
      x: _mLift,
      vel: _mLiftVel,
      target: _lifted ? 1 : 0,
      dt: dt,
      stiffness: _m.liftStiffness,
      damping: _m.liftDamping,
    );
    _mLift = lr.$1;
    _mLiftVel = lr.$2;
    if (_lifted && _mLift >= LiquidGlassTabPillBehavior.liftSnap) {
      _mLift = 1;
      _mLiftVel = 0;
    }
    if (!_lifted && _mLift < 0.003 && _mLiftVel.abs() < 0.05) {
      _mLift = 0;
      _mLiftVel = 0;
    }
    _mLift = _mLift = _mLift = _mLift;
    final bool liftSettled = !_lifted && _mLift == 0;

    // 4) Commit once the travel and the lift are both done.
    if (_travelActive && travelSettled && liftSettled && !_tabDragging) {
      _travelActive = false;
      _tabIndexCommitted = _tabIndex;
    }

    // 5) The grey platter under the lens: gone as the lift rises, back on a
    // 0.4 s spring from wherever the release caught it. It is the glass
    // hand-over here: the rim and refraction shed as the platter returns.
    if (_lifted) {
      _handover = (1 - _mLift).clamp(0.0, 1.0);
      _mHandoverVel = -_mLiftVel;
    } else {
      final hr = liquidGlassSpringStep(
        x: _handover,
        vel: _mHandoverVel,
        target: 1,
        dt: dt,
        stiffness: _m.platterStiffness,
        damping: _m.platterDamping,
      );
      _handover = hr.$1;
      _mHandoverVel = hr.$2;
      if (_handover > 0.998 && _mHandoverVel.abs() < 0.05) {
        _handover = 1;
        _mHandoverVel = 0;
      }
    }

    // 6) The deformation: the acceleration squash, sampled where the pill
    // is drawn THIS frame, in pixels — so the model never reads a
    // frame-old position, and keeps running once the glass is gone.
    bool deformSettled;
    {
      if (_pillCenterValid) {
        _pillCenter = _resolvePillCenter();
        if (!_pillMotion.isTracking) _pillMotion.start();
        _pillMotion.track(_pillCenter, now: _mNow, dt: dt);
        double dev = _pillMotion.deviation;

        // A key of zero is a destination like any other — grabbing a pill
        // mid-flight hands it back to the raw force, and that hand-back
        // crosses too.
        if (_travelSignEased == 0) {
          _travelSignEased = _travelSign;
        } else if (_travelSignEased != _travelSign) {
          const signTau = 0.25;
          _travelSignEased +=
              (_travelSign - _travelSignEased) * (1 - math.exp(-dt / signTau));
          if ((_travelSign - _travelSignEased).abs() < 0.01) {
            _travelSignEased = _travelSign;
          }
        }

        // Keep the force's MAGNITUDE — the launch peak, the lull at
        // constant speed, the braking peak — and take its sign from the
        // direction of travel, so the pill deforms one way for the whole
        // journey instead of turning itself inside out at the halfway
        // mark. A part-way key is a blend of the two, which is what makes
        // a reversal cross rather than switch. See [_travelSign].
        final double key = _travelSignEased;
        if (key != 0) dev = dev * (1 - key.abs()) - key * dev.abs();
        _deviation = dev;
      }
      _devY = _deviation;
      _leadFrac = 0;

      // Landed: the braking squash fades out and the landing wobble
      // takes over, so the pill rings where it stands instead of
      // squashing into its tab. The squash stays for the launch, the
      // travel and the finger.
      bool wobbling = false;
      if (_landedAt != null) {
        final double t = _mNow - _landedAt!;
        final double fade = _m.landingSquashFadeDuration <= 0
            ? 0.0
            : math.exp(-t / _m.landingSquashFadeDuration);
        _deviation *= fade;
        _devY *= fade;
        final double tw = t - _m.landingWobbleDelay;
        wobbling = tw < LiquidGlassTabPillBehavior.wobbleSeconds &&
            _m.landingWobbleStrength != 0;
        if (tw >= 0) {
          final LiquidGlassTabDeform w = _m.landingWobble(tw);
          _deviation += w.scaleX;
          _devY -= w.scaleY;
          final double dir = _travelSign == 0 ? 1 : _travelSign;
          _leadFrac = step <= 0 ? 0 : w.lead * dir * s / step;
        }
      }
      deformSettled = !wobbling &&
          _deviation.abs() < 0.0005 &&
          _devY.abs() < 0.0005 &&
          _leadFrac.abs() < 1e-4;
    }

    // 7) The bar's press under the finger.
    final bool pressSettled = _stepPress(dt);

    // Everything must be finished — not just the travel. The deflation,
    // the hand-over and the squash all outlive the spring (the squash's
    // sampling window has to drain), so stopping on the spring
    // alone would freeze the pill mid-shrink, mid-deformation or mid-fade.
    if (!_travelActive &&
        !_tabDragging &&
        !_fingerDown &&
        liftSettled &&
        deformSettled &&
        _handover >= 1 &&
        pressSettled) {
      _pillMotion.stop();
      _deviation = _devY = _leadFrac = 0;
      // Held until here, not dropped at the end of the travel: the
      // deformation drains after the spring does, on the sense it was
      // drawn with.
      _travelSign = _travelSignEased = 0;
      _maybeStopCapture();
      _ticker?.stop();
    }

    if (mounted) setState(() {});
  }

  /// One frame of [LiquidGlassAnimatedNavBar.barSwell]'s spring: toward its scale while a finger is on the bar, back to none
  /// once it lifts, about a point that follows the pill. Returns whether
  /// it has settled.
  bool _stepPress(double dt) {
    final LiquidGlassTabBarSwell? press = widget.barSwell;
    if (press == null) {
      _press = _pressVel = 0;
      return true;
    }
    if (_lifted) {
      // The pill's centre across the bar, mirrored and pulled toward the
      // middle by grip: the side the pill is on grows the most.
      final LiquidGlassTabBarLayout layout = _layout;
      final double frac = _tabDragging ? _dragFollow : _travelPos;
      final double pillX = layout.width <= 0
          ? 0.5
          : ((layout.padding + layout.pillOffset(frac) + layout.pillWidth / 2) /
                  layout.width)
              .clamp(0.0, 1.0);
      final double grip = press.grip.clamp(0.0, 1.0);
      _pressAnchorX = 0.5 + (0.5 - pillX) * grip;
    }
    final r = liquidGlassSpringStep(
      x: _press,
      vel: _pressVel,
      target: _lifted ? press.scale : 0.0,
      dt: dt.clamp(0.0, 1 / 30),
      stiffness: press.stiffness,
      damping: _lifted ? press.damping : press.releaseDamping,
    );
    _press = r.$1;
    _pressVel = r.$2;
    if (!_lifted && _press.abs() < 0.0005 && _pressVel.abs() < 0.005) {
      _press = _pressVel = 0;
    }
    return _press == 0 && _pressVel == 0;
  }

  /// The direction key for a travel of [span] cells. A travel with no
  /// distance in it has no direction either, and keeps the raw force.
  double _signOfTravel(double span) => span.abs() < 1e-6 ? 0 : span.sign;

  /// The pill's centre in the outer view's coordinates, from the current
  /// spring/drag state and the geometry the last build resolved.
  Offset _resolvePillCenter() {
    final layout = _layout;
    final double frac = _drawFrac;
    return Offset(
      _confinePillX(
          _barLeft +
              layout.padding +
              layout.pillOffset(frac) +
              layout.pillWidth / 2,
          layout),
      _pillCenter.dy,
    );
  }

  /// [cx] moved in just far enough that the pill, at the width it is
  /// drawn this frame, stays inside the bar's ends — with
  /// [LiquidGlassAnimatedNavBar.confineToBar] only.
  double _confinePillX(double cx, LiquidGlassTabBarLayout layout) {
    if (!widget.confineToBar) return cx;
    final double pillW = layout.pillWidth;
    final double liftedW = _pillLiftedSize(layout).width;
    final double half =
        (pillW + (liftedW - pillW) * _mLift) * (1 + _deviation) / 2;
    final double lo = _barLeft + half;
    final double hi = _barLeft + layout.width - half;
    return lo > hi ? _barLeft + layout.width / 2 : cx.clamp(lo, hi);
  }

  /// The raised glass pill's size: a touch taller than the bar, with either
  /// the resting w:h ratio or its own extra width.
  Size _pillLiftedSize(LiquidGlassTabBarLayout layout) {
    final double pillW = layout.pillWidth;
    final double liftedH = layout.height + widget.pillGrowHeight;
    return Size(
        widget.pillGrowWidth == null
            ? liftedH * (pillW / layout.cellHeight)
            : pillW + widget.pillGrowWidth!,
        liftedH);
  }

  @override
  Widget build(BuildContext context) {
    // Adaptivity: resolve the effective config (own, else the enclosing
    // area's) and sync the driver's verdict source. Its controller only
    // drives the INNER stack (capsule tint + shell content color), which
    // watches it through its own AnimatedBuilder in [_buildInner] —
    // idle between flips.
    final LiquidGlassAdaptiveAreaScope? areaScope =
        LiquidGlassAdaptiveArea.maybeOf(context);
    final LiquidGlassAdaptivity? resolvedAdapt =
        widget.adaptivity ?? areaScope?.adaptivity ?? widget.areaAdaptivity;
    _effAdaptivity = (resolvedAdapt?.isNone ?? false) ? null : resolvedAdapt;
    _adaptFollow = _effAdaptivity == null
        ? null
        : (_effAdaptivity!.link ?? areaScope?.link ?? widget.areaLink);
    _adaptDriver.onResync = _adaptResync;
    _adaptDriver.sync(
      _effAdaptivity,
      follow: _adaptFollow,
      canSample: widget.sampleBackground,
      fallbackBrightness:
          liquidGlassFallbackBrightness(context, _effAdaptivity),
    );

    final Widget bar = LayoutBuilder(builder: (context, constraints) {
      final parentWidth = constraints.maxWidth;
      final parentHeight = constraints.maxHeight;

      // Resolve the bar's placement.
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
      final layout = _layout.copyWith(bottomMargin: _effBottomMargin);

      // The two ends of the lift: the cell the pill rests in, and the
      // raised glass it stands at while it is up: a touch taller than the
      // bar, and either the resting w:h ratio or its own extra width.
      final Size pillRest = Size(layout.pillWidth, layout.cellHeight);
      final Size pillLifted = _pillLiftedSize(layout);

      // How much of the glass is on. Its own spring, so the material
      // can be all the way in before the size is.
      final double morphProgress = _mLift.clamp(0.0, 1.0);

      final double pillFrac = _drawFrac;

      // The pill's centre in the outer view's coordinates. Horizontally
      // it rides its cell; vertically the centre never moves, since the
      // morph is symmetric about the bar's row.
      final double pillCX = _confinePillX(
          _barLeft +
              layout.padding +
              layout.pillOffset(pillFrac) +
              layout.pillWidth / 2,
          layout);
      final double pillCY = parentHeight -
          (_effBottomMargin + layout.padding + layout.cellHeight / 2);
      // Hand the row's Y to the ticker, which re-derives X itself each
      // frame. Until layout has run once there is no centre to sample, so
      // the model stays parked rather than tracking a bogus origin.
      _pillCenter = Offset(pillCX, pillCY);
      _pillCenterValid = true;

      // The size the pill would be with no deformation, and the size it is
      // actually drawn at. The deformation is the BAR's, so it applies to
      // whichever pill is on screen — including both at once, mid-hand-off.
      //
      // The envelope is the two lift springs, one per axis, rather than
      // one progress along a line between the two sizes: they overshoot
      // past the raised size and dip under the resting one, and they do
      // it by slightly different amounts.
      final Size envelopeSize = Size(
        pillRest.width + (pillLifted.width - pillRest.width) * _mLift,
        pillRest.height + (pillLifted.height - pillRest.height) * _mLift,
      );
      // A mirrored pair except through the landing wobble, whose axes
      // are independent.
      final double dev = _deviation;
      final double devY = _devY;
      final Size liveSize = Size(
        envelopeSize.width * (1 + dev),
        envelopeSize.height * (1 - devY),
      );

      // How much of the pill still reads as glass. It sheds the rim, its
      // shadow and its refraction on this, and keeps everything else —
      // the travel, the lift, the squash — running underneath.
      final double glassPresence = (1 - _handover).clamp(0.0, 1.0);

      // The bar's press, which the capsule, the pills and the items all
      // take on: one scale about a point on the bar's middle row.
      _swellScale = 1 + _press;
      _swellAnchor = Offset(
        _barLeft + layout.width * _pressAnchorX,
        parentHeight - _effBottomMargin - layout.height / 2,
      );
      final Offset pillCenter = _swellPoint(Offset(pillCX, pillCY));
      final bool swollen = _swellScale != 1;
      final Size pillRestDrawn = swollen ? pillRest * _swellScale : pillRest;
      final Size pillLiftedDrawn =
          swollen ? pillLifted * _swellScale : pillLifted;
      final Size envelopeDrawn =
          swollen ? envelopeSize * _swellScale : envelopeSize;

      // The lens stays until there is nothing left in it to see: no glass,
      // no lift and no deformation. By then it is drawing a flat fill at
      // rest size — exactly what the plain pill draws — so handing over is
      // a swap of two identical pictures and needs no cross-fade, and the
      // plain pill never has to know about the motion.
      final bool pillIsFlat = glassPresence <= 0 &&
          morphProgress <= 0 &&
          _mLift == 0 &&
          _mLift == 0 &&
          dev.abs() < 0.0005 &&
          devY.abs() < 0.0005 &&
          !_travelActive &&
          !_tabDragging &&
          !_fingerDown;
      final bool glassMounted = widget.showSelectionPill && !pillIsFlat;

      // The icon shell's reveal is cut to the size the pill says it is
      // drawing, so the selected colour wipes on exactly under the glass.
      final double? hlFrac = glassMounted ? pillFrac : null;
      final double? hlW = glassMounted ? liveSize.width : null;
      final double? hlH = glassMounted ? liveSize.height : null;

      // Impeller only: a pill-shaped magnifier that lives INSIDE the
      // inner stack, above the bar capsule but BELOW the icon shell —
      // same silhouette, same lift, travel, squash and shed as the
      // glass pill, but transparent, unblurred, undistorted, rimless
      // and shadowless. Painted there, its backdrop sample contains
      // only the page and the capsule, so under the pill the BAR reads
      // pushed back while the icons keep their size; the glass pill
      // above then refracts the receded bar and the crisp icons alike.
      // The Skia capture path cannot chain lenses and is untouched.
      final Widget? magnifierPill =
          (glassMounted && _useImpeller && widget.magnifierPill.enabled)
              ? Positioned.fill(
                  key: const ValueKey('lg-motion-nav-pill-magnifier'),
                  child: IgnorePointer(
                    // Its own read, never a batch's: it sits on the capsule
                    // to push it back, and a shared copy has no capsule in
                    // it. It also paints INSIDE the outer view's background,
                    // where joining a batch would take that batch's copy
                    // before the icon shell above it had painted.
                    child: LiquidGlassBatch.exclude(
                      child: LiquidGlassNavBarMotionPill(
                        center: pillCenter,
                        active: _lifted,
                        morphProgress: morphProgress,
                        envelopeSize: envelopeDrawn,
                        restSize: pillRestDrawn,
                        activeSize: pillLiftedDrawn,
                        style: _magnifierStyle(
                          baseShape: widget.pillShape,
                          fallbackRadius: pillLiftedDrawn.height / 2,
                          magnification: widget.magnifierPill.magnification,
                        ),
                        restStyle: _magnifierStyle(
                          baseShape: widget.restStyle.shape,
                          fallbackRadius: pillRestDrawn.height / 2,
                          magnification: 1,
                        ),
                        deviation: dev,
                        deviationY: devY,
                        glassPresence: glassPresence,
                        honorBackdropAlpha: false,
                      ),
                    ),
                  ),
                )
              : null;

      return Stack(
        fit: StackFit.expand,
        children: [
          // OUTER view: captures the inner stack and composites the
          // moving glass pill + the developer's outer lenses on top.
          LiquidGlassView.withPositionedLenses(
            controller: _outerViewController,
            pixelRatio: widget.pixelRatio,
            useSync: widget.useSync,
            // Only capture while there is something to composite — which is
            // now only while the glass pill is actually mounted.
            realTimeCapture: glassMounted || widget.outerNeedsRealtime,
            refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
            useImpellerBackdrop: widget.useImpellerBackdrop,
            batch: widget.batch,
            batchMode: widget.batchMode,
            foregroundBatchId: widget.foregroundBatchId,
            backgroundWidget: _buildInner(
              layout: layout,
              pillFrac: hlFrac,
              pillW: hlW,
              pillH: hlH,
              pillGlass: glassPresence,
              magnifier: magnifierPill,
            ),
            children: [
              // Stable, role-based keys so each outer lens keeps its own
              // `State`. The pill no longer lives in this list, so the
              // list's length is now invariant.
              for (int i = 0; i < widget.outerLenses.length; i++)
                widget.outerLenses[i].key != null
                    ? widget.outerLenses[i]
                    : widget.outerLenses[i]
                        .copyWith(key: ValueKey('lg-nav-outer-$i')),
            ],
            // The pill is a lens WIDGET now, in the view's `child:` slot —
            // the only place an externally-driven deformation can be
            // rendered (a positioned `LiquidGlass` can only deform from
            // its own internal touch driver). It refracts the same
            // capture the positioned pill did: this view's background,
            // which is the inner stack.
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (glassMounted)
                  Positioned.fill(
                    child: IgnorePointer(
                      // Its own read, never a batch's: the pill exists to
                      // refract the capsule and whatever the outer slots
                      // paint around it, none of which a shared copy holds.
                      child: LiquidGlassBatch.exclude(
                        // Same resolved fill the flat pill paints — the
                        // glass pill lerps INTO it, so a mismatch here
                        // shows up as a colour pop at the hand-over.
                        child: _withRestStyle(
                          (LiquidGlassStyle rest) =>
                              LiquidGlassNavBarMotionPill(
                            center: pillCenter,
                            active: _lifted,
                            // The bar owns the size as well as the squash;
                            // the pill's own morph spring stays out of it.
                            morphProgress: morphProgress,
                            envelopeSize: envelopeDrawn,
                            restSize: pillRestDrawn,
                            activeSize: pillLiftedDrawn,
                            style: _pillStyle(),
                            restStyle: rest,
                            // The bar owns the model; the pill just draws it.
                            deviation: dev,
                            deviationY: devY,
                            glassPresence: glassPresence,
                            shadow: widget.pillShadow,
                            honorBackdropAlpha: false,
                          ),
                        ),
                      ),
                    ),
                  )
                // Flat: the same rect the glass just vacated, painted as a
                // plain fill. Placed from the pill's own centre rather than
                // re-derived from the committed index, so the two can never
                // disagree by a pixel at the hand-off.
                else if (widget.showSelectionPill)
                  Positioned(
                    key: const ValueKey('lg-motion-nav-pill-static'),
                    left: pillCenter.dx - pillRestDrawn.width / 2,
                    top: pillCenter.dy - pillRestDrawn.height / 2,
                    child: _restPill(pillRestDrawn),
                  ),
                // The host's chrome, on Impeller only: no capture up here
                // to keep awake, so it paints over the cells and the pill
                // exactly as the outer slot always has. (On Skia it is in
                // the inner view instead — see `_buildInnerStack`.)
                if (_useImpeller && widget.chromeChild != null)
                  _outerRedirected(widget.chromeChild!),
                // Adaptive areas/lenses in the outer slots sample through
                // the INNER view (the pre-glass body image) via this
                // redirect — one sampler for the whole pipeline.
                if (widget.outerChild != null)
                  _outerRedirected(widget.outerChild!),
              ],
            ),
          ),
          // The gesture overlay, reading the raw pointer: a press lifts the
          // pill at once, a move past the drag threshold scrubs it, and the
          // release lands it on the tab nearest the finger.
          Positioned(
            key: const ValueKey('lg-animated-nav-gesture-overlay'),
            left: _barLeft + layout.padding,
            bottom: _effBottomMargin + layout.padding,
            width: layout.width - 2 * layout.padding,
            height: layout.cellHeight,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: (e) => _onPointerEnd(e.pointer),
              onPointerCancel: (e) => _onPointerEnd(e.pointer, cancelled: true),
            ),
          ),
        ],
      );
    });

    // System chrome: annotate the (full-screen) bar so the navigation
    // bar's icons flip with the verdict. Before any verdict the chrome
    // sits on the same entry guess the palettes use.
    final LiquidGlassAdaptivity? chromeAdaptivity = _effAdaptivity;
    if (chromeAdaptivity != null &&
        (widget.systemChrome == LiquidGlassSystemChrome.navigationBar ||
            widget.systemChrome == LiquidGlassSystemChrome.both)) {
      final Brightness guess = chromeAdaptivity.permanentBrightness ??
          chromeAdaptivity.initialBrightness ??
          liquidGlassFallbackBrightness(context, chromeAdaptivity);
      return AnimatedBuilder(
        animation: _adaptDriver.listenable!,
        builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: liquidGlassSystemChromeStyle(_adaptDriver.verdict ?? guess,
              LiquidGlassSystemChrome.navigationBar),
          child: bar,
        ),
      );
    }
    return bar;
  }

  /// The moving pill's look, assembled from the bar's pill-* knobs.
  ///
  /// A null [pillShape] is left null on purpose: the pill then builds a
  /// capsule whose radius tracks its own morphing height, and scales the
  /// refraction band with it — both of which it is better placed to do,
  /// since it owns the size.
  LiquidGlassStyle _pillStyle() {
    final LiquidGlassRefraction refraction = widget.pillRefraction ??
        LiquidGlassRefraction(
          magnification: widget.pillMagnification,
          refractionIndex: widget.pillRefractionIndex,
          refractionWidth: widget.pillRefractionWidth,
          dispersion: 1.32,
        );
    return LiquidGlassStyle(
      shape: widget.pillShape,
      specular: widget.pillSpecular,
      glow: widget.pillGlow,
      color: widget.pillColor,
      blur: widget.pillBlur,
      refractionIndex: refraction.refractionIndex,
      refractionWidth: refraction.refractionWidth,
      // On Impeller the under-pill magnifier lens owns the magnification;
      // the glass pill on top must not compound it (m² in the middle).
      magnification: _useImpeller ? 1 : refraction.magnification,
      dispersion: refraction.dispersion,
      liteGlass: widget.pillLiteGlass,
    );
  }

  /// Whether the moving pill draws lite glass: its glass or its rest style
  /// asks for it. The magnifier under it follows, so the two always match.
  bool get _pillLite => widget.pillLiteGlass || widget.restStyle.liteGlass;

  /// The magnifier's silhouette: the shape the glass pill draws with at
  /// this end of the morph, stripped of everything visible — no rim, no
  /// glint. [base] mirrors the pill's own shape resolution ([fallbackRadius]
  /// is the capsule radius used when the host authored no shape).
  LiquidGlassShape _magnifierShape(
      LiquidGlassShape? base, double fallbackRadius) {
    final LiquidGlassLitShape lit = LiquidGlassLitShape.of(base ??
        LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: fallbackRadius,
            clipQuality: LiquidGlassClipQuality.exact));
    return lit.copyWith(
      specular: lit.specular.copyWith(thickness: 0, intensity: 0),
      glow: lit.glow.copyWith(thickness: 0),
      secondSpecular: lit.secondSpecular?.copyWith(thickness: 0),
    );
  }

  /// One end of the Impeller under-pill magnifier's material: pure
  /// magnification — fully transparent, zero blur, no distortion, no
  /// dispersion, no rim. The lifted end carries
  /// [_magnifierMagnification]; the rest end carries `1`, so the
  /// magnification lerps in with the lift and back out through the
  /// handover on exactly the curve the glass material runs.
  LiquidGlassStyle _magnifierStyle({
    required LiquidGlassShape? baseShape,
    required double fallbackRadius,
    required double magnification,
  }) {
    return LiquidGlassStyle(
      shape: _magnifierShape(baseShape, fallbackRadius),
      color: Color(0x00000000),
      blur: 0,
      refractionIndex: 1.0,
      refractionWidth: 0,
      magnification: magnification,
      dispersion: 0,
      liteGlass: _pillLite,
    );
  }

  /// Inner stack the outer view captures: wallpaper/body + bar capsule
  /// lens, with the icon shell drawn on top. [magnifier] (Impeller only)
  /// slots between the capsule and the icons, so it recedes the bar
  /// without touching the icons drawn above it.
  ///
  /// The flat rest pill.
  ///
  /// When the bar is adaptive its fill rides the bar's OWN verdict — the
  /// pill sits on the capsule, so sampling its own rect would read the
  /// capsule's tint back instead of the page. It gets its own
  /// AnimatedBuilder because this pill is built in [build], outside the
  /// one wrapping the inner stack; without it the fill would settle only
  /// on the next rebuild, arriving after the capsule it sits on.
  /// Builds [child] with [restStyle]'s fill resolved against the bar's
  /// verdict.
  ///
  /// A bar that adapts brings its pill along on the shipped palette,
  /// whether that adaptivity is the bar's OWN or inherited from an
  /// enclosing area/scaffold. The source does not change what the pill
  /// has to do: it sits on the capsule, and a capsule that darkens over
  /// a dark page leaves a fixed light fill reading as a light pill on a
  /// dark bar. `rest.adaptivity` overrides this palette, and
  /// `LiquidGlassAdaptivity.none` opts a caller-chosen fill out of the
  /// flip entirely.
  ///
  /// Both the flat rest pill and the MOVING pill's resting endpoint go
  /// through here, and they have to: the glass pill lerps toward this
  /// fill and the flat pill is painted in it, so if only one adapted the
  /// hand-over would swap one colour for another in a single frame.
  ///
  /// Its own [AnimatedBuilder] because both callers are built in
  /// [build], outside the one wrapping the inner stack — without it the
  /// fill would settle a rebuild late, arriving after the capsule.
  Widget _withRestStyle(Widget Function(LiquidGlassStyle rest) child) {
    final LiquidGlassAdaptivity palette = widget.restStyle.adaptivity ??
        LiquidGlassTabPillStyle.defaultRestAdaptivity;
    if (_effAdaptivity == null || palette.isNone) {
      return child(widget.restStyle);
    }
    return AnimatedBuilder(
      animation: _adaptDriver.listenable!,
      builder: (context, _) => child(
        widget.restStyle.copyWith(color: _adaptDriver.glassColor(palette)),
      ),
    );
  }

  Widget _restPill(Size size) => _withRestStyle(
        (LiquidGlassStyle rest) => LiquidGlassBottomNavPillStatic(
          width: size.width,
          height: size.height,
          color: rest.appearance.color,
          shape: rest.shape,
        ),
      );

  /// With adaptivity active the stack is rebuilt through an
  /// [AnimatedBuilder] on the flip controller, so the capsule tint and
  /// the shell's content color animate together on every verdict
  /// change — and cost nothing between flips.
  Widget _buildInner({
    required LiquidGlassTabBarLayout layout,
    double? pillFrac,
    double? pillW,
    double? pillH,
    double pillGlass = 0,
    Widget? magnifier,
  }) {
    final LiquidGlassAdaptivity? adaptivity = _effAdaptivity;
    if (adaptivity == null) {
      return _buildInnerStack(
        layout: layout,
        pillFrac: pillFrac,
        pillW: pillW,
        pillH: pillH,
        pillGlass: pillGlass,
        magnifier: magnifier,
      );
    }
    return AnimatedBuilder(
      animation: _adaptDriver.listenable!,
      builder: (context, _) => _buildInnerStack(
        layout: layout,
        pillFrac: pillFrac,
        pillW: pillW,
        pillH: pillH,
        pillGlass: pillGlass,
        magnifier: magnifier,
        adaptivity: adaptivity,
      ),
    );
  }

  Widget _buildInnerStack({
    required LiquidGlassTabBarLayout layout,
    double? pillFrac,
    double? pillW,
    double? pillH,
    double pillGlass = 0,
    Widget? magnifier,
    LiquidGlassAdaptivity? adaptivity,
  }) {
    final Widget background = widget.backgroundColor == null
        ? widget.body
        : ColoredBox(color: widget.backgroundColor!, child: widget.body);

    // The bar capsule's material: the caller's groups over the tuned
    // defaults, with the bar's contact shadow riding the appearance
    // (`appearance.shadow`) — the lens wraps itself in the ring, so it
    // paints behind the glass, lands inside the outer view's capture,
    // and the moving pill refracts it too. A shadow already carried by
    // [barAppearance] is honored when [barShadow] is unset.
    LiquidGlassAppearance capsuleAppearance = widget.barAppearance ??
        LiquidGlassAppearance(
          color: Colors.white.withAlpha(22),
          blur: 2,
        );
    // Resolve the adaptive palette for this frame: the capsule tint
    // overrides the bar appearance's color, the content color reaches
    // the shell's cells through IconTheme (see LiquidGlassNavTabCell).
    Color? adaptiveContent;
    if (adaptivity != null) {
      adaptiveContent = _adaptDriver.contentColor(adaptivity);
      capsuleAppearance = capsuleAppearance.copyWith(
          color: _adaptDriver.glassColor(adaptivity));
    }
    final LiquidGlassShape capsuleShape = widget.barShape ??
        LiquidGlassLitShape(
          cornerStyle: LiquidGlassCornerStyle.roundedRectangle,
          cornerRadius: 40,
          specular: const LiquidGlassLight.specular(),
        );
    final LiquidGlassStyle capsuleStyle = LiquidGlassStyle.groups(
      // Corners scale with the press, so the capsule keeps its shape.
      shape: _swellScale == 1
          ? capsuleShape
          : capsuleShape.copyWith(
              cornerRadius: capsuleShape.cornerRadius * _swellScale),
      specular: widget.barSpecular,
      glow: widget.barGlow,
      secondSpecular: widget.barSecondSpecular,
      appearance: widget.barShadow == null
          ? capsuleAppearance
          : capsuleAppearance.copyWith(shadow: widget.barShadow),
      refraction: widget.barRefraction ??
          const LiquidGlassRefraction(
            refractionIndex: 1.1,
            refractionWidth: 12,
          ),
      liteGlass: widget.barLiteGlass,
    );

    Widget shell = LiquidGlassAnimatedBottomNavBarShell(
      items: widget.items,
      selectedIndex: _tabIndexCommitted,
      itemStyle: widget.itemStyle,
      layout: layout,
      left: _barLeft,
      bottom: _effBottomMargin,
      highlightFrac: pillFrac,
      highlightWidth: pillW,
      highlightHeight: pillH,
      underGlass: pillGlass,
      adaptive: adaptivity != null,
    );
    if (adaptiveContent != null) {
      // Same ambient contract as the lens child: the animated content
      // color rides IconTheme/DefaultTextStyle and the adaptive cells
      // resolve their selected/unselected strengths from it.
      shell = IconTheme.merge(
        data: IconThemeData(color: adaptiveContent),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: adaptiveContent),
          child: shell,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        LiquidGlassView.withPositionedLenses(
          controller: _innerViewController,
          pixelRatio: widget.pixelRatio,
          useSync: widget.useSync,
          realTimeCapture: widget.realTimeCapture,
          refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
          useImpellerBackdrop: widget.useImpellerBackdrop,
          batch: widget.batch,
          batchMode: widget.batchMode,
          foregroundBatchId: widget.foregroundBatchId,
          backgroundWidget: background,
          // Body-luminance sampling for adaptivity: the inner view owns
          // the captured body, so it hosts the sampler; the registrar in
          // its child slot enrolls this state as the sampling client.
          // The pipeline's SINGLE sampler: serves the bar's own verdict,
          // the inner-slot areas/lenses through this view's own scope, and
          // any outer-slot ones redirected here through the outer view's
          // sampler scope.
          // The HOST decides whether a sampler exists at all. A bar
          // carrying its own `style.adaptivity` used to fall back on a
          // default config and open one here — which meant a scaffold
          // that never asked for adaptivity still got captures, through
          // this view, because of what its nav bar happened to carry.
          // Now: no config from above, no sampler, and the bar's verdict
          // falls back like any other unsampled surface.
          adaptiveSampling: _hostSampling != null &&
                  (_adaptSamples || widget.outerAdaptiveSampling != null)
              ? _hostSampling
              : null,
          children: const [],
          // The capsule is a layout-driven [LiquidGlassLens] in the
          // view's child slot: on Skia it refracts this view's captured
          // background, on Impeller the live backdrop. Placed off the
          // same [_barLeft]/[_effBottomMargin] the shell, the gesture
          // overlay and the pill already use, so the four can never
          // disagree by a pixel.
          child: Stack(
            children: [
              // Grown by the press about its anchor, as the items are.
              Positioned(
                left: _swellPoint(Offset(_barLeft, 0)).dx,
                bottom:
                    _effBottomMargin + layout.height * (1 - _swellScale) / 2,
                width: layout.width * _swellScale,
                height: layout.height * _swellScale,
                child: IgnorePointer(
                  // Joins an enclosing batch, such as the host's chrome,
                  // only when asked; otherwise a read of its own.
                  child: widget.capsuleJoinsBatch
                      ? LiquidGlassLens(style: capsuleStyle)
                      : LiquidGlassBatch.exclude(
                          child: LiquidGlassLens(style: capsuleStyle),
                        ),
                ),
              ),
              // The host's chrome, on Skia only, on THIS view's capture: it
              // refracts the body the way the capsule does, joins the same
              // foreground batch, and never asks the outer view to stay
              // awake. Above the capsule, below the shell and the pill. (On
              // Impeller it is in the outer view instead — see the build.)
              if (!_useImpeller && widget.chromeChild != null)
                Positioned.fill(child: widget.chromeChild!),
              // The bar's state lives OUTSIDE this view, so it cannot
              // reach the scope itself — this registrar does it from in
              // here and forwards every sample to the driver.
              if (_adaptSamples) _AdaptiveClientRegistrar(client: this),
            ],
          ),
        ),
        // Impeller-only magnifier pill: painted here its backdrop sample
        // is the page + capsule (+ shadow) alone — the icon shell above
        // stays out of it, so the bar recedes under the pill while the
        // icons keep their size.
        if (magnifier != null) magnifier,
        // Cosmetic only — taps are owned by the outer gesture overlay.
        IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            // The items grow with the bar. They are not glass, so a
            // plain transform carries them.
            child: _swellScale == 1
                ? shell
                : Transform.scale(
                    scale: _swellScale,
                    alignment: Alignment.topLeft,
                    origin: _swellAnchor,
                    child: shell,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Enrolls a [LiquidGlassAdaptiveClient] with the enclosing view's
/// luminance sampler for as long as it is mounted. Placed in the inner
/// view's `child:` slot so the animated bar's state — which lives
/// OUTSIDE that view — can receive samples of the captured body.
class _AdaptiveClientRegistrar extends StatefulWidget {
  final LiquidGlassAdaptiveClient client;

  const _AdaptiveClientRegistrar({required this.client});

  @override
  State<_AdaptiveClientRegistrar> createState() =>
      _AdaptiveClientRegistrarState();
}

class _AdaptiveClientRegistrarState extends State<_AdaptiveClientRegistrar> {
  /// The register tear-off doubles as the identity of "who we're
  /// registered with" (same contract as the lens's bookkeeping).
  void Function(LiquidGlassAdaptiveClient)? _registeredWith;
  void Function(LiquidGlassAdaptiveClient)? _unregister;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LiquidGlassLensScope? scope = LiquidGlassLensScope.maybeOf(context);
    final void Function(LiquidGlassAdaptiveClient)? register =
        scope?.registerAdaptiveClient;
    if (!identical(register, _registeredWith)) {
      _unregister?.call(widget.client);
      _unregister = null;
      _registeredWith = register;
      if (register != null) {
        register(widget.client);
        _unregister = scope!.unregisterAdaptiveClient;
      }
    }
  }

  @override
  void didUpdateWidget(covariant _AdaptiveClientRegistrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client)) {
      _unregister?.call(oldWidget.client);
      _registeredWith?.call(widget.client);
    }
  }

  @override
  void dispose() {
    _unregister?.call(widget.client);
    _unregister = null;
    _registeredWith = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
