import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../lens/liquid_glass_blender.dart';
import '../lens/liquid_glass_lens.dart';
import '../lens/liquid_glass_shaders.dart';
import '../liquid_glass_style.dart';
import '../liquid_glass_view.dart';

/// Compiles the glass GPU programs during launch, so the first page that
/// shows glass does not pay for them.
///
/// ## The problem this solves
///
/// A custom program is compiled on its first draw, on the raster thread —
/// for the blender's merged surface that is the better part of a second
/// the first time a page with one opens. So this draws a plain lens and a
/// two-member [LiquidGlassBlender] for a few frames at app start: one
/// draw of each program is all it needs.
///
/// On Skia the lenses sit in a [LiquidGlassView] of their own, since a
/// Skia lens samples its view's capture. On Impeller they read the
/// backdrop directly and need no view.
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
/// ## Why it renders real glass
///
/// Painted for real for a few frames and then removed — not drawn into
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

  /// Set false to skip the warm-up entirely.
  final bool enabled;

  const LiquidGlassWarmUp({
    super.key,
    required this.child,
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

  static bool get _impeller => ui.ImageFilter.isShaderFilterSupported;

  /// Frames the warm glass stays up. Counted rather than timed: the
  /// first of them can itself take the better part of a second. Skia
  /// gets more, because its view captures after the first frame paints
  /// and a lens with no capture yet skips its glass entirely.
  static int get _warmFrames => _impeller ? 4 : 8;

  /// Frames painted since the warm glass was mounted.
  int _frames = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _done = true;
      return;
    }
    // Nothing can be compiled until the fragment programs themselves are
    // loaded — a lens without them draws the frosted fallback, which is
    // not the pipeline we are here to warm.
    LiquidGlassShaders.ensureLoaded(_impeller).then((_) {
      if (!mounted) return;
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
      _frames++;
      if (_frames >= _warmFrames) {
        setState(() {
          _warming = false;
          _done = true;
        });
        return;
      }
      // The Skia view's own pump asks for frames while it captures, but
      // this does not rely on that staying true.
      WidgetsBinding.instance.scheduleFrame();
      _nextFrame();
    });
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
        // top hides it while the draws still execute, because Flutter
        // does not cull what is overdrawn.
        if (_warming)
          Positioned(
            left: 0,
            top: 0,
            width: _panelWidth,
            height: _panelHeight,
            child: _impeller
                ? const _WarmGlass()
                : const LiquidGlassView(
                    realTimeCapture: true,
                    backgroundWidget: ColoredBox(color: Color(0xFF808080)),
                    child: _WarmGlass(),
                  ),
          ),
        widget.child,
      ],
    );
  }
}

const double _panelWidth = 120;
const double _panelHeight = 90;

/// One draw of each custom program. Blurred like real glass, so the
/// blender takes the same blur + shader pass the pages do.
class _WarmGlass extends StatelessWidget {
  const _WarmGlass();

  static const LiquidGlassStyle _style = LiquidGlassStyle(blur: 3);

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          // A lone lens: the main program, plus the border pass on Skia.
          Positioned(
            left: 0,
            top: 0,
            width: 60,
            height: 40,
            child: LiquidGlassLens(style: _style),
          ),
          // The merged-surface program. A blender paints nothing with
          // fewer than two members, so it gets two, overlapping.
          Positioned(
            left: 0,
            top: 50,
            width: 120,
            height: 40,
            child: LiquidGlassBlender(
              style: _style,
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: 60,
                    height: 40,
                    child: LiquidGlassLens(style: _style),
                  ),
                  Positioned(
                    left: 50,
                    top: 0,
                    width: 60,
                    height: 40,
                    child: LiquidGlassLens(style: _style),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
