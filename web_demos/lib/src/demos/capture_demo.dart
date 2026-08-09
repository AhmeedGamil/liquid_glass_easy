import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Capture once** — one snapshot, then drag forever.
///
/// The background here is painted and completely static, so
/// `realTimeCapture: false` rasterizes it **once** after the first frame and
/// the lens refracts that snapshot for the rest of the session. Moving the
/// lens costs a shader pass and nothing else: nothing behind it re-rasterizes,
/// however far you throw it.
///
/// ## Why the palette chips are here
///
/// A frozen capture is only free because it is frozen. Swap the backdrop and
/// the page underneath repaints immediately while the glass keeps bending the
/// *old* pixels — the capture and the widget tree have drifted apart. That is
/// not a bug to hide, it is the whole contract of `realTimeCapture: false`,
/// and `controller.captureOnce()` is how you settle it.
///
/// On Impeller none of this exists: the lens samples the live backdrop, so
/// there is no snapshot to go stale and the button would have nothing to do.
class CaptureDemo extends StatefulWidget {
  const CaptureDemo({super.key});

  @override
  State<CaptureDemo> createState() => _CaptureDemoState();
}

enum _Palette {
  dusk('dusk'),
  ember('ember');

  const _Palette(this.label);
  final String label;

  Widget get backdrop => switch (this) {
        _Palette.dusk => const GlassBackdrop.dusk(),
        _Palette.ember => const GlassBackdrop.ember(),
      };
}

class _CaptureDemoState extends State<CaptureDemo> {
  final LiquidGlassViewController _view = LiquidGlassViewController();

  /// Fractional top-left, 0..1 of the space the lens can occupy, so a resize
  /// keeps it where you left it instead of throwing it off-screen.
  Offset _pos = const Offset(0.5, 0.34);

  /// What the tree is painting now, and what the snapshot actually holds.
  /// They start equal, and a chip is the only thing that parts them.
  _Palette _painted = _Palette.dusk;
  _Palette _captured = _Palette.dusk;

  /// Snapshots taken, including the automatic one after the first frame.
  /// The counter is the point: drag for a minute and it stays where it is.
  int _snapshots = 1;

  bool get _stale => _painted != _captured;

  Future<void> _recapture() async {
    await _view.captureOnce();
    if (!mounted) return;
    setState(() {
      _captured = _painted;
      _snapshots += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassView(
      controller: _view,
      // Static backdrop: one snapshot is all the lens will ever need.
      realTimeCapture: false,
      backgroundWidget: _painted.backdrop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size box = Size(constraints.maxWidth, constraints.maxHeight);
          final double side = (box.shortestSide * 0.46).clamp(150.0, 210.0);

          // The lens stays clear of the controls: its travel is the box minus
          // the strip they occupy, so it can never be dragged underneath them.
          final double freeX = (box.width - side).clamp(1.0, double.infinity);
          final double freeY =
              (box.height - side - 168).clamp(1.0, double.infinity);

          return Stack(
            children: [
              Positioned(
                left: _pos.dx * freeX,
                top: _pos.dy * freeY,
                width: side,
                height: side,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (e) => setState(() {
                    _pos = Offset(
                      (_pos.dx + e.delta.dx / freeX).clamp(0.0, 1.0),
                      (_pos.dy + e.delta.dy / freeY).clamp(0.0, 1.0),
                    );
                  }),
                  child: const LiquidGlassLens(
                    style: LiquidGlassStyle(
                      shape: LiquidGlassShape.squircle(
                        cornerRadius: 52,
                        borderWidth: 1.4,
                        lightIntensity: 1.15,
                        lightDirection: 42,
                      ),
                      // Clear glass, no blur: the rings and hairlines under it
                      // are the evidence that the capture is being bent.
                      appearance: LiquidGlassAppearance(
                        color: Color(0x0FFFFFFF),
                        saturation: 1.06,
                      ),
                      refraction: LiquidGlassRefraction(
                        distortion: 0.13,
                        distortionWidth: 34,
                      ),
                    ),
                    child: Center(child: _LensLabel()),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DemoHint(
                          _stale
                              ? 'The backdrop changed, the snapshot did not — '
                                  'the lens is still bending the old one'
                              : 'Drag it anywhere. The background behind it was '
                                  'rasterized once and never again.',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in _Palette.values)
                              DemoChip(
                                label: p.label,
                                selected: _painted == p,
                                onTap: () => setState(() => _painted = p),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DemoPanel(
                          padding:
                              const EdgeInsets.fromLTRB(14, 10, 10, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                  label: 'snapshots taken',
                                  value: '$_snapshots',
                                ),
                              ),
                              DemoChip(
                                label: 'captureOnce()',
                                selected: _stale,
                                onTap: _recapture,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 12.5,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _LensLabel extends StatelessWidget {
  const _LensLabel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.drag_indicator_rounded, color: Colors.white70, size: 20),
        SizedBox(height: 6),
        Text(
          'Drag me',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
