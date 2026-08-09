// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — visual sanity check for the continuous-curvature shape and
// its baked SDF. Not wired into the glass pipeline. Throwaway / removable.
//
// Push `ContinuousSdfDemo()` onto a route to eyeball:
//   • left:  the squircle outline (Bézier path) vs a plain circular RRect
//   • right: the baked SDF texture (grayscale = distance, tinted = normals)
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'continuous_corner_path.dart';
import 'liquid_glass_sdf_baker.dart';

class ContinuousSdfDemo extends StatefulWidget {
  const ContinuousSdfDemo({super.key});

  @override
  State<ContinuousSdfDemo> createState() => _ContinuousSdfDemoState();
}

class _ContinuousSdfDemoState extends State<ContinuousSdfDemo> {
  double _radius = 60;
  static const Size _size = Size(240, 160);
  BakedSdf? _baked;
  bool _baking = false;

  @override
  void initState() {
    super.initState();
    _rebake();
  }

  Future<void> _rebake() async {
    if (_baking) return;
    _baking = true;
    final path = continuousRoundedRectanglePath(_size, _radius);
    final baked = await bakeSdf(path, _size, maxDistance: 40);
    if (!mounted) {
      baked.dispose();
      return;
    }
    setState(() {
      _baked?.dispose();
      _baked = baked;
      _baking = false;
    });
  }

  @override
  void dispose() {
    _baked?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Continuous squircle + SDF')),
      backgroundColor: const Color(0xFF202024),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Squircle vs circular',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  CustomPaint(
                    size: _size,
                    painter: _OutlinePainter(_radius),
                  ),
                  const SizedBox(height: 32),
                  const Text('Baked SDF',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: _size.width,
                    height: _size.height,
                    child: _baked == null
                        ? const Center(child: CircularProgressIndicator())
                        : RawImage(image: _baked!.image, fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text('radius', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: Slider(
                    value: _radius,
                    min: 0,
                    max: 80,
                    onChanged: (v) {
                      setState(() => _radius = v);
                      _rebake();
                    },
                  ),
                ),
                Text(_radius.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.radius);
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // circular reference (red)
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x88FF5252));

    // continuous squircle (green)
    final path = continuousRoundedRectanglePath(size, radius);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF69F0AE));
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter old) => old.radius != radius;
}

/// Tiny helper so callers can open the demo from anywhere.
Route<void> continuousSdfDemoRoute() =>
    MaterialPageRoute<void>(builder: (_) => const ContinuousSdfDemo());
