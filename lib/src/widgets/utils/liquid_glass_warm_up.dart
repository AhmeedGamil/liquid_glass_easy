import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../components/liquid_glass_shadow.dart';
import '../components/slider/liquid_glass_slider.dart';
import '../components/switch/liquid_glass_switch.dart';
import '../lens/liquid_glass_lens.dart';
import '../lens/liquid_glass_shaders.dart';
import '../liquid_glass_config.dart' show LiquidGlassAppearance;
import '../liquid_glass_style.dart';
import '../liquid_glass_view.dart';

/// Compiles the glass GPU programs during launch, so the first touch of a
/// glass control does not pay for them.
///
/// ## The problem this solves
///
/// On the Skia backend every distinct draw configuration needs a GLSL
/// program that the **driver** compiles, on the raster thread, the first
/// time that configuration is drawn. The components hide their glass
/// until they are touched — a switch's thumb is a solid pill until your
/// finger lands, and its contact shadow is not in the tree at all — so
/// the compile happens under the finger and stalls the raster thread for
/// 100-250 ms.
///
/// It happens exactly once per install: the engine writes the compiled
/// programs to a persistent on-disk cache and reloads them on every
/// later launch. So the fix is not to avoid the work but to **move** it
/// — into app start, where a hitch is invisible and a splash usually
/// covers it anyway. From the second launch onwards this widget finds
/// everything already cached and costs nothing.
///
/// Impeller compiles its pipelines ahead of time and has no such stall,
/// so on an Impeller engine this is a no-op that adds nothing to the
/// tree.
///
/// ## Using it
///
/// Wrap the first screen the app shows:
///
/// ```dart
/// home: const LiquidGlassWarmUp(child: HomePage()),
/// ```
///
/// It must go **inside** your `MaterialApp`/`CupertinoApp`, not around
/// it: the glass it renders reads `MediaQuery`, which only exists below
/// the app widget.
///
/// ## What it warms
///
/// A real [LiquidGlassSwitch] and a real [LiquidGlassSlider], mounted
/// and driven, rather than stand-in shapes. Each owns its own
/// `LiquidGlassView`, so this compiles the capture, the glass shader,
/// the blur and the border pass at the sizes and styles those two
/// components genuinely use — which a generic lens only approximates.
///
/// Alongside them sits one lens wearing [LiquidGlassSwitch.defaultStyle]
/// — shadow included — swept across the thumb's morph range. That
/// covers the two draws a control only ever makes once a finger is on
/// it, and which mounting one at rest therefore misses:
///
///  * the contact shadow, a `MaskFilter.blur` under `BlendMode.multiply`
///  * the `saveLayer` an `Opacity` pushes as the rest pill fades out
///
/// The sweep matters because those offscreens are sized to the lens, and
/// a control's lens is a different size on every frame of its morph.
/// Redrawing one fixed box would warm one cache bucket; sweeping walks
/// the range the morph will actually ask for.
///
/// ## Why it renders real glass
///
/// Painted for real, for [duration], and then removed — not drawn into
/// an offscreen picture. A backdrop filter is a compositor concept with
/// no `Canvas` equivalent, so the blur pass **cannot** be warmed from a
/// recorded `ui.Picture` at all; it has to be a mounted subtree.
///
/// It is painted underneath [child], so an opaque first screen hides it
/// completely. It cannot be hidden with `Offstage`, `Opacity(0)` or a
/// clip — all of those skip the draw, and a draw that is skipped
/// compiles nothing.
class LiquidGlassWarmUp extends StatefulWidget {
  /// The app's own subtree. Painted over the warm-up, and left alone
  /// once the warm-up is done.
  final Widget child;

  /// How long the warm glass is held for.
  ///
  /// Time rather than a frame count, so the run lasts as long on a
  /// 120 Hz screen as on a 60 Hz one — the faster screen simply steps
  /// the sweep more finely, which is free.
  ///
  /// It needs to span more than a frame or two: a view captures its
  /// background after the first frame paints, and a lens with no
  /// capture yet skips its glass entirely, so the earliest frames
  /// compile nothing at all.
  final Duration duration;

  /// Set false to skip the warm-up entirely.
  final bool enabled;

  const LiquidGlassWarmUp({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 3),
    this.enabled = true,
  });

  @override
  State<LiquidGlassWarmUp> createState() => _LiquidGlassWarmUpState();
}

class _LiquidGlassWarmUpState extends State<LiquidGlassWarmUp> {
  /// Whether the warm glass is currently mounted.
  bool _warming = false;

  /// Whether the warm-up has finished (or was never needed). Once true
  /// this widget is a pass-through forever.
  bool _done = false;

  /// Runs from the frame the warm glass is mounted, not from
  /// [initState] — the shader programs load asynchronously first, and
  /// the wait for them is not warm-up time.
  final Stopwatch _elapsed = Stopwatch();

  /// Impeller precompiles its pipelines, so there is nothing to warm.
  static bool get _impeller => ui.ImageFilter.isShaderFilterSupported;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled || _impeller) {
      _done = true;
      return;
    }
    // Nothing can be compiled until the fragment programs themselves are
    // loaded — a lens without them draws the frosted fallback, which is
    // not the pipeline we are here to warm.
    LiquidGlassShaders.ensureLensLoaded(false).then((_) {
      if (!mounted) return;
      _elapsed.start();
      setState(() => _warming = true);
      _nextFrame();
    }).catchError((Object _) {
      // Shaders unavailable (broken build, unsupported environment).
      // Nothing to warm and nothing to report — the components degrade
      // on their own.
      if (mounted) setState(() => _done = true);
    });
  }

  void _nextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _done) return;
      if (_elapsed.elapsed >= widget.duration) {
        _elapsed.stop();
        setState(() {
          _warming = false;
          _done = true;
        });
        return;
      }
      // Redraw at the next step of the sweep. Repeating one identical
      // draw would recompile nothing; it is the CHANGING geometry that
      // earns the extra frames.
      setState(() {});
      // The views' own pumps are already asking for frames while they
      // capture, but this does not rely on that staying true.
      WidgetsBinding.instance.scheduleFrame();
      _nextFrame();
    });
  }

  /// How far through the run, `0`..`1`.
  double get _progress {
    final int total = widget.duration.inMicroseconds;
    if (total <= 0) return 1;
    return (_elapsed.elapsed.inMicroseconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      // Never AlignmentDirectional: this can sit above the first
      // Directionality in some app shells.
      alignment: Alignment.topLeft,
      // The child keeps the constraints it would have had without this
      // widget in the tree.
      fit: StackFit.passthrough,
      children: [
        // First child = painted first = underneath. An opaque screen on
        // top hides it while Skia still executes the draws, because
        // Flutter does not cull what is overdrawn.
        if (_warming)
          Positioned(
            left: 0,
            top: 0,
            width: _panelWidth,
            height: _panelHeight,
            child: _WarmControls(progress: _progress),
          ),
        widget.child,
      ],
    );
  }
}

const double _panelWidth = 300;
const double _panelHeight = 130;

/// The real components, plus the thumb glass they only draw under a
/// finger.
class _WarmControls extends StatelessWidget {
  /// `0`..`1` across the run.
  final double progress;

  const _WarmControls({required this.progress});

  /// The switch thumb's two boxes. The lens below sweeps between them,
  /// which is the range a real morph walks.
  static const Size _thumbRest = Size(37, 24);
  static const Size _thumbSwollen = Size(58, 38.333);

  @override
  Widget build(BuildContext context) {
    // The switch flips a few times across the run so its track redraws,
    // its colour cross-fades and its capture keeps refreshing, rather
    // than sitting on one static frame.
    final bool on = (progress * 4).floor().isEven;
    // The slider sweeps its whole travel, so its fill, its track and its
    // pill are drawn at a spread of positions and widths.
    final double slid = progress;

    final double t = _sweep(progress);
    final Size thumb = Size(
      _thumbRest.width + (_thumbSwollen.width - _thumbRest.width) * t,
      _thumbRest.height + (_thumbSwollen.height - _thumbRest.height) * t,
    );
    // Never exactly 1.0: at full opacity RenderOpacity drops the layer
    // and the saveLayer pipeline goes unwarmed.
    final double cover = 0.05 + 0.9 * t;

    return IgnorePointer(
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          // The real controls, each carrying its own view and capture.
          // onChanged is a sink: nothing here is interactive, the values
          // are driven by the sweep above.
          Positioned(
            left: 0,
            top: 0,
            child: LiquidGlassSwitch(value: on, onChanged: _ignore),
          ),
          Positioned(
            left: 0,
            top: 44,
            width: 280,
            child: LiquidGlassSlider(value: slid, onChanged: _ignore),
          ),
          // The thumb's own glass, at the sizes a morph passes through
          // and wearing the shadow the components only draw once
          // touched. Needs a view of its own: a lens samples its
          // ancestor view's capture, and the controls' views are theirs.
          Positioned(
            left: 0,
            top: 88,
            width: _thumbSwollen.width,
            height: _thumbSwollen.height,
            child: LiquidGlassView(
              realTimeCapture: true,
              backgroundWidget: const ColoredBox(color: Color(0xFF808080)),
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: thumb.width,
                    height: thumb.height,
                    child: LiquidGlassLens(
                      style: LiquidGlassSwitch.defaultStyle,
                      child: Opacity(
                        opacity: cover,
                        child: const ColoredBox(color: Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The slider pill's style is a different shape and refraction
          // from the switch's, so it is its own program configuration.
          Positioned(
            left: 70,
            top: 88,
            width: 60,
            height: 34,
            child: LiquidGlassView(
              realTimeCapture: true,
              backgroundWidget: const ColoredBox(color: Color(0xFF808080)),
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: thumb.width,
                    height: thumb.height,
                    child: LiquidGlassLens(
                      style: _sliderPillWithShadow,
                      child: Opacity(
                        opacity: cover,
                        child: const ColoredBox(color: Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A triangle wave: 0 → 1 → 0 twice across the run, so the sweep
  /// covers the size range in both directions rather than once.
  static double _sweep(double p) {
    final double x = (p * 2) % 1.0;
    return x < 0.5 ? x * 2 : (1 - x) * 2;
  }

  static void _ignore(Object? _) {}

  /// The slider's own pill look, wearing a contact shadow so the mask
  /// blur is compiled for this configuration too.
  static final LiquidGlassStyle _sliderPillWithShadow = LiquidGlassStyle(
    shape: LiquidGlassSlider.defaultStyle.shape,
    appearance: LiquidGlassAppearance(
      saturation: LiquidGlassSlider.defaultStyle.appearance.saturation,
      blur: LiquidGlassSlider.defaultStyle.appearance.blur,
      color: LiquidGlassSlider.defaultStyle.appearance.color,
      enableInnerRadiusTransparent: LiquidGlassSlider
          .defaultStyle.appearance.enableInnerRadiusTransparent,
      shadow: LiquidGlassSlider.defaultStyle.appearance.shadow ??
          const LiquidGlassShadow(inset: 3),
    ),
    refraction: LiquidGlassSlider.defaultStyle.refraction,
  );
}
