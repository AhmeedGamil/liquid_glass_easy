import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// ignore: implementation_imports
import 'package:liquid_glass_easy/experimental/liquid_glass_morph.dart';

// =============================================================
// EXPERIMENTAL — component-to-component morphing.
//
// One glass body changes what it is. Two variants:
//   • Button → List   — a glass button unfolds into a menu panel.
//   • Toolbar → Menu  — an icon capsule becomes an album list while the
//                       standalone circles beside it stay put.
//
//   flutter run -t lib/morph_page.dart   (standalone)
// =============================================================

void main() => runApp(const _MorphApp());

class _MorphApp extends StatelessWidget {
  const _MorphApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MorphPage(),
    );
  }
}

enum _Variant { button, toolbar }

/// The two motion models, side by side so the bounce can be judged on a
/// device rather than argued about.
enum _Motion {
  /// Height rings past its target; the body thins at the peak to spend
  /// the overshoot across the whole shape instead of the free edge.
  bounce('Bounce', LiquidGlassMorphSpec()),

  /// Every spring critically damped. Spring timing, no ringing.
  settle('Settle', LiquidGlassMorphSpec.settle);

  const _Motion(this.label, this.spec);
  final String label;
  final LiquidGlassMorphSpec spec;
}

class MorphPage extends StatefulWidget {
  const MorphPage({super.key});

  @override
  State<MorphPage> createState() => _MorphPageState();
}

class _MorphPageState extends State<MorphPage> {
  final _controller = LiquidGlassMorphController();
  _Variant _variant = _Variant.button;
  _Motion _motion = _Motion.bounce;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchTo(_Variant variant) {
    if (_variant == variant) return;
    _controller.close();
    setState(() => _variant = variant);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: const _Wallpaper(),
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: Stack(
                  children: [
                    // The morph resizes for real, so it lives in a Stack:
                    // it grows over the page instead of shoving it.
                    Positioned(
                      top: 24,
                      left: 0,
                      right: 0,
                      child: switch (_variant) {
                        _Variant.button => _ButtonMorph(
                            controller: _controller,
                            spec: _motion.spec,
                          ),
                        _Variant.toolbar => _ToolbarMorph(
                            controller: _controller,
                            spec: _motion.spec,
                          ),
                      },
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MotionPicker(
                            value: _motion,
                            onChanged: (m) {
                              _controller.close();
                              setState(() => _motion = m);
                            },
                          ),
                          _VariantPicker(
                            value: _variant,
                            onChanged: _switchTo,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Variant 1: a button unfolds into a list ─────────────────

class _ButtonMorph extends StatelessWidget {
  final LiquidGlassMorphController controller;
  final LiquidGlassMorphSpec spec;
  const _ButtonMorph({required this.controller, required this.spec});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: LiquidGlassMorph(
        controller: controller,
        spec: spec,
        sourceStyle: _buttonStyle,
        destinationStyle: _panelStyle,
        source: const SizedBox(
          width: 190,
          height: 52,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined, size: 20),
                SizedBox(width: 10),
                Text(
                  'Albums',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        destination: _AlbumList(onPick: (_) => controller.close()),
      ),
    );
  }
}

// ── Variant 2: the toolbar capsule becomes the menu ─────────

class _ToolbarMorph extends StatelessWidget {
  final LiquidGlassMorphController controller;
  final LiquidGlassMorphSpec spec;
  const _ToolbarMorph({required this.controller, required this.spec});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 16),
        // Siblings that do not take part: their own lenses, untouched by
        // the morph. In the reference these hold position while the
        // group between them inflates.
        const _CircleButton(icon: Icons.chevron_left),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: LiquidGlassMorph(
              controller: controller,
              spec: spec,
              sourceStyle: _capsuleStyle,
              destinationStyle: _panelStyle,
              source: const SizedBox(
                height: 44,
                width: 168,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.ios_share, size: 20),
                    Icon(Icons.favorite_border, size: 20),
                    Icon(Icons.photo_album_outlined, size: 20),
                  ],
                ),
              ),
              destination: _AlbumList(onPick: (_) => controller.close()),
            ),
          ),
        ),
        const _CircleButton(icon: Icons.info_outline),
        const SizedBox(width: 16),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  const _CircleButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: LiquidGlassLens(
        style: _capsuleStyle,
        child: Center(child: Icon(icon, size: 20)),
      ),
    );
  }
}

// ── The destination content, shared by both variants ────────

class _AlbumList extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _AlbumList({required this.onPick});

  static const _albums = [
    ('Towering Peaks', false),
    ('2023 Trip', false),
    ('Sweet Deserts', true),
    ('Icy Wonderland', false),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 248,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          for (final (name, selected) in _albums)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(name),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      child: selected
                          ? const Icon(Icons.check,
                              size: 18, color: Color(0xFF1E1B17))
                          : null,
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Color(0xFF1E1B17),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Glass looks: the two ends of the one lens ───────────────

const _capsuleStyle = LiquidGlassStyle(
  shape: LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: 22,
    borderWidth: 1,
  ),
  appearance: LiquidGlassAppearance(
    color: Color(0x24FFFFFF),
    blur: LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
    saturation: 1.3,
  ),
  refraction: LiquidGlassRefraction(distortion: 0.09, magnification: 1.04),
);

const _buttonStyle = LiquidGlassStyle(
  shape: LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: 26,
    borderWidth: 1,
  ),
  appearance: LiquidGlassAppearance(
    color: Color(0x24FFFFFF),
    blur: LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
    saturation: 1.3,
  ),
  refraction: LiquidGlassRefraction(distortion: 0.09, magnification: 1.04),
);

// A panel full of text cannot be see-through: the tint thickens and the
// blur deepens as the glass grows, and refraction backs off so the rows
// stay readable.
const _panelStyle = LiquidGlassStyle(
  shape: LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: 30,
    borderWidth: 1,
  ),
  appearance: LiquidGlassAppearance(
    color: Color(0xD6F6EEE6),
    blur: LiquidGlassBlur(sigmaX: 18, sigmaY: 18),
    saturation: 1.1,
  ),
  refraction: LiquidGlassRefraction(distortion: 0.03, magnification: 1.0),
);

// ── Page chrome ─────────────────────────────────────────────

class _MotionPicker extends StatelessWidget {
  final _Motion value;
  final ValueChanged<_Motion> onChanged;
  const _MotionPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final motion in _Motion.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: TextButton(
              onPressed: () => onChanged(motion),
              style: TextButton.styleFrom(
                backgroundColor: value == motion
                    ? const Color(0x33FFFFFF)
                    : const Color(0x14000000),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(motion.label, style: const TextStyle(fontSize: 13)),
            ),
          ),
      ],
    );
  }
}

class _VariantPicker extends StatelessWidget {
  final _Variant value;
  final ValueChanged<_Variant> onChanged;
  const _VariantPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final variant in _Variant.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: TextButton(
                onPressed: () => onChanged(variant),
                style: TextButton.styleFrom(
                  backgroundColor: value == variant
                      ? const Color(0x33FFFFFF)
                      : const Color(0x14000000),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: Text(
                  variant == _Variant.button ? 'Button → List' : 'Toolbar → Menu',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A warm, high-contrast backdrop so the refraction has something to
/// bend. Painted, not an asset — the demo runs with no downloads.
class _Wallpaper extends StatelessWidget {
  const _Wallpaper();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WallpaperPainter(), child: const SizedBox.expand());
  }
}

class _WallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2B3A5B),
          Color(0xFF7C5A66),
          Color(0xFFD98A4E),
          Color(0xFFF3C169),
        ],
        stops: [0.0, 0.34, 0.58, 0.72],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    // Sun.
    final sunCenter = Offset(size.width * 0.74, size.height * 0.62);
    canvas.drawCircle(
      sunCenter,
      size.width * 0.11,
      Paint()..color = const Color(0xFFFFE9AE),
    );
    canvas.drawCircle(
      sunCenter,
      size.width * 0.24,
      Paint()
        ..color = const Color(0x33FFD98A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48),
    );

    // Mesas: hard silhouettes give the glass sharp edges to distort.
    void mesa(double cx, double w, double top, Color color) {
      final left = cx - w / 2;
      final path = Path()
        ..moveTo(left, size.height * 0.72)
        ..lineTo(left + w * 0.08, top)
        ..lineTo(left + w * 0.92, top)
        ..lineTo(left + w, size.height * 0.72)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    mesa(size.width * 0.12, size.width * 0.3, size.height * 0.44,
        const Color(0xFF8B4A33));
    mesa(size.width * 0.52, size.width * 0.22, size.height * 0.5,
        const Color(0xFF6E3626));
    mesa(size.width * 0.93, size.width * 0.34, size.height * 0.41,
        const Color(0xFF7A3D2B));

    // Ground.
    final ground = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB4713F), Color(0xFF4A2A1D)],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      ground,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
