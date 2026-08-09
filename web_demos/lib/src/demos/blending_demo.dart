import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Blend** — drag the two shapes together and their outlines fuse.
///
/// Two lenses, one [LiquidGlassBlender] — the minimum the metaball field
/// needs, and the clearest way to watch it work. Bring them close and a smooth
/// bridge grows between them; pull apart and it snaps. Each member keeps its
/// own corner curve through the merge: the circle stays a circle, the squircle
/// stays a squircle.
///
/// ## The rim
///
/// The toggle drops `borderWidth` to zero on the group style. The merged body
/// is still there — same refraction, same tint — but the outline that bounds
/// it is gone, and with it the clearest evidence of where the two silhouettes
/// became one. It is worth seeing the union without it once.
///
/// ## Captured once, not every frame
///
/// The backdrop is painted, deterministic and completely static, so
/// `realTimeCapture: false` takes **one** snapshot and the lenses refract it
/// forever. Live capture only earns its cost when the background moves; here
/// it would rasterize an identical page sixty times a second. The shapes are
/// what move, and moving a lens over a fixed image is free.
class BlendingDemo extends StatefulWidget {
  const BlendingDemo({super.key});

  @override
  State<BlendingDemo> createState() => _BlendingDemoState();
}

class _BlendingDemoState extends State<BlendingDemo> {
  // Fractional top-left, 0..1 across the space each shape can occupy, so a
  // resize keeps the composition instead of throwing shapes off-screen.
  // Apart at rest — the demo asks you to drag one into the other, so it must
  // not open already fused — but both over the lit middle of the backdrop,
  // where there is structure to bend. The corners are vignetted, and clear
  // glass over a dark corner looks like nothing at all.
  Offset _circle = const Offset(0.10, 0.20);
  Offset _squircle = const Offset(0.82, 0.50);

  /// How eagerly neighbours fuse. The blender's headline knob, on a slider
  /// because the value only means anything once you have felt it.
  double _smoothness = 58;

  /// The rim around the merged silhouette. Off drops `borderWidth` to zero.
  bool _rim = true;

  static const double _minSmooth = 10;
  static const double _maxSmooth = 90;

  /// The merged material: **clear** glass, no blur at all. The whole point
  /// here is that content bends — any blur softens the rings and hairlines
  /// underneath, which is precisely the evidence of the bend. It is also the
  /// most expensive thing on the Skia capture path, so dropping it costs
  /// nothing and gains everything.
  ///
  /// One shape descriptor for the whole group: the members contribute their
  /// silhouettes, the group decides what the merged surface is made of.
  LiquidGlassStyle get _groupStyle => LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: 36,
          // Zero suppresses the rim outright rather than drawing a hairline.
          borderWidth: _rim ? 1.4 : 0,
          lightIntensity: 1.15,
          lightDirection: 42,
        ),
        appearance: const LiquidGlassAppearance(
          color: Color(0x10FFFFFF),
          saturation: 1.08,
        ),
        refraction: const LiquidGlassRefraction(
          refractionType: OpticalRefraction(
            refraction: 1.6,
            refractionWidth: 26,
            depth: 0.75,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LiquidGlassView(
      // One snapshot, then never again. See the class doc.
      realTimeCapture: false,
      backgroundWidget: const GlassBackdrop.dusk(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size box = Size(constraints.maxWidth, constraints.maxHeight);
          final double unit = box.shortestSide;

          // Shapes scale with the box, so the composition survives from a
          // 360px phone to a full-bleed window.
          final double circle = (unit * 0.38).clamp(112.0, 168.0);
          final double squircle = (unit * 0.44).clamp(128.0, 196.0);

          return Stack(
            children: [
              Positioned.fill(
                child: LiquidGlassBlender(
                  smoothness: _smoothness,
                  style: _groupStyle,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _blob(
                        box: box,
                        frac: _circle,
                        size: Size.square(circle),
                        shape: LiquidGlassShape.roundedRectangle(
                          cornerRadius: circle / 2,
                        ),
                        onMove: (f) => setState(() => _circle = f),
                        child: const _BlobLabel(
                          icon: Icons.bolt_rounded,
                          text: 'Drag me',
                        ),
                      ),
                      _blob(
                        box: box,
                        frac: _squircle,
                        size: Size.square(squircle),
                        shape: const LiquidGlassShape.squircle(
                          cornerRadius: 44,
                        ),
                        onMove: (f) => setState(() => _squircle = f),
                        child: const _BlobLabel(
                          icon: Icons.auto_awesome_rounded,
                          text: 'into this',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Controls sit OUTSIDE the blender: they are ordinary widgets,
              // not members, so they never join the merge.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DemoHint('Drag one shape into the other'),
                        const SizedBox(height: 10),
                        DemoPanel(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DemoSlider(
                                label: 'smoothness',
                                value: _smoothness,
                                min: _minSmooth,
                                max: _maxSmooth,
                                readout: _smoothness.toStringAsFixed(0),
                                onChanged: (v) =>
                                    setState(() => _smoothness = v),
                              ),
                              // A component controlling the raw material it is
                              // made of: the toggle sets borderWidth on the
                              // group style.
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 6, 2, 10),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 76,
                                      child: Text(
                                        'rim',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.78),
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _rim
                                            ? 'borderWidth: 1.4'
                                            : 'borderWidth: 0',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 11.5,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    LiquidGlassToggle(
                                      value: _rim,
                                      onChanged: (v) =>
                                          setState(() => _rim = v),
                                      activeColor: const Color(0xFF34C759),
                                    ),
                                  ],
                                ),
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

  /// One draggable member. The drag is converted back into fractional space
  /// and clamped, so a shape can be thrown at an edge but never past it.
  Widget _blob({
    required Size box,
    required Offset frac,
    required Size size,
    required LiquidGlassShape shape,
    required ValueChanged<Offset> onMove,
    required Widget child,
  }) {
    final double freeX = (box.width - size.width).clamp(1.0, double.infinity);
    final double freeY = (box.height - size.height).clamp(1.0, double.infinity);

    return Positioned(
      left: frac.dx * freeX,
      top: frac.dy * freeY,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (e) => onMove(Offset(
          (frac.dx + e.delta.dx / freeX).clamp(0.0, 1.0),
          (frac.dy + e.delta.dy / freeY).clamp(0.0, 1.0),
        )),
        child: LiquidGlassLens(
          style: LiquidGlassStyle(shape: shape),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// What a member carries. Ordinary widgets: the merge is a glass pass under
/// them, so the icon and the words are never part of the metaball field.
class _BlobLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BlobLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 26),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}
