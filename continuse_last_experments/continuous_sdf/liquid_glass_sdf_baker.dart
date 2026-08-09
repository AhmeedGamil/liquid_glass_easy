// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — bakes a shape Path into a signed-distance-field ui.Image.
//
// Output encoding (RGBA, 8-bit per channel):
//   R = signed distance, normalized:  sd = (R*2 - 1) * maxDistance
//        (R = 0.5 on the edge, <0.5 inside, >0.5 outside)
//   G = normal.x, encoded:  nx = G*2 - 1
//   B = normal.y, encoded:  ny = B*2 - 1
//   A = coverage (0 = fully outside, 1 = fully inside)
//
// This mirrors Kyant's SdfShader bitmap layout so the sampling shader reads
// distance + outward normal directly. CPU 8SSEDT keeps it dependency-free.
//
// Deleting the `continuous_sdf/` folder removes the whole feature.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A baked SDF plus the geometry needed to map shader coords into it.
class BakedSdf {
  BakedSdf({
    required this.image,
    required this.padding,
    required this.maxDistance,
    required this.size,
    required this.textureLogicalSize,
  });

  /// RGBA SDF texture. Its pixel size is `textureLogicalSize * resolution`.
  final ui.Image image;

  /// Empty border (logical px) baked around the shape so the in-shader
  /// gradient taps just outside the edge stay valid. The shape's top-left
  /// sits at (padding, padding) in logical space.
  final double padding;

  /// Distance (logical px) that maps to R = 0 or R = 1. Beyond is clamped.
  final double maxDistance;

  /// Logical lens size the SDF was baked for (px, without padding).
  final ui.Size size;

  /// The texture's extent in LOGICAL px (= size + 2*padding). Used for the
  /// uv mapping in the shader — independent of the supersample factor, so the
  /// texel count never enters the coordinate math.
  final ui.Size textureLogicalSize;

  void dispose() => image.dispose();
}

/// Bakes [path] (expressed in a [size]-sized box) into a [BakedSdf].
///
/// [maxDistance] is the half-width of the representable distance band; pick it
/// a bit larger than the lens's distortion width so the refraction band is
/// fully covered.
///
/// [resolution] is the supersample factor — texels per LOGICAL pixel. Higher
/// = smoother field (kills blockiness), at more memory/bake cost. 3 is a good
/// default for high-density screens. The distance values are always stored in
/// logical px regardless of [resolution], so the shader math is unaffected.
///
/// [padding] is the empty logical-px border around the shape. It only needs to
/// cover the gradient taps just outside the edge, so it can be small (8).
Future<BakedSdf> bakeSdf(
  ui.Path path,
  ui.Size size, {
  double maxDistance = 48.0,
  double resolution = 3.0,
  double padding = 8.0,
}) async {
  final double pad = padding;
  final double ss = resolution;
  final double logicalW = size.width + 2 * pad;
  final double logicalH = size.height + 2 * pad;
  final int w = (logicalW * ss).ceil();
  final int h = (logicalH * ss).ceil();

  // 1) Rasterize coverage at supersampled resolution: white shape on black.
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF000000));
  canvas.scale(ss);
  canvas.translate(pad, pad);
  canvas.drawPath(
      path, ui.Paint()..color = const ui.Color(0xFFFFFFFF)..isAntiAlias = true);
  final picture = recorder.endRecording();
  final raster = await picture.toImage(w, h);
  picture.dispose();
  final byteData = await raster.toByteData(format: ui.ImageByteFormat.rawRgba);
  raster.dispose();
  if (byteData == null) {
    throw StateError('SDF bake: failed to read rasterized coverage');
  }
  final rgba = byteData.buffer.asUint8List();

  // 2) Coverage (0..1) from the red channel.
  final int n = w * h;
  final Float32List coverage = Float32List(n);
  for (int i = 0; i < n; i++) {
    coverage[i] = rgba[i * 4] / 255.0;
  }

  // 3) Signed distance via 8SSEDT — distances in TEXELS, then to logical px.
  final Float32List sdfTexels = _signedDistanceField(coverage, w, h);
  final double toLogical = 1.0 / ss;

  // 4) Encode RGBA: distance + normal (gradient, for the demo viz) + coverage.
  final Uint8List out = Uint8List(n * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int idx = y * w + x;
      final double sd = sdfTexels[idx] * toLogical;

      final double dx =
          sdfTexels[idx + (x < w - 1 ? 1 : 0)] - sdfTexels[idx - (x > 0 ? 1 : 0)];
      final double dy =
          sdfTexels[idx + (y < h - 1 ? w : 0)] - sdfTexels[idx - (y > 0 ? w : 0)];
      final double gl = _len(dx, dy);
      final double nx = gl > 1e-5 ? dx / gl : 0.0;
      final double ny = gl > 1e-5 ? dy / gl : 0.0;

      final double rNorm = (sd / maxDistance) * 0.5 + 0.5;
      final int o = idx * 4;
      out[o] = _u8(rNorm);
      out[o + 1] = _u8(nx * 0.5 + 0.5);
      out[o + 2] = _u8(ny * 0.5 + 0.5);
      out[o + 3] = _u8(coverage[idx]);
    }
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888, completer.complete);
  final image = await completer.future;

  return BakedSdf(
    image: image,
    padding: pad,
    maxDistance: maxDistance,
    size: size,
    textureLogicalSize: ui.Size(logicalW, logicalH),
  );
}

/// 8-points Signed Sequential Euclidean Distance Transform.
/// Returns signed distance in px (negative inside the shape, positive outside).
Float32List _signedDistanceField(Float32List coverage, int w, int h) {
  final int n = w * h;
  // Two grids of nearest-opposite-edge offset vectors.
  final inside = _Grid(w, h);
  final outside = _Grid(w, h);

  for (int i = 0; i < n; i++) {
    if (coverage[i] >= 0.5) {
      // inside the shape: 0 distance for the inside field, far for outside
      inside.dx[i] = 0;
      inside.dy[i] = 0;
      outside.dx[i] = _far;
      outside.dy[i] = _far;
    } else {
      inside.dx[i] = _far;
      inside.dy[i] = _far;
      outside.dx[i] = 0;
      outside.dy[i] = 0;
    }
  }

  inside.transform();
  outside.transform();

  final Float32List sdf = Float32List(n);
  for (int i = 0; i < n; i++) {
    // Signed distance: negative inside, positive outside.
    //   inside.dist  = distance to nearest inside pixel (0 when inside)
    //   outside.dist = distance to nearest outside pixel (0 when outside)
    // inside pixel  -> dIn 0, dOut >0  -> negative
    // outside pixel -> dIn >0, dOut 0  -> positive
    final double dOut = outside.dist(i);
    final double dIn = inside.dist(i);
    sdf[i] = dIn - dOut;
  }
  return sdf;
}

const double _far = 1e9;

class _Grid {
  _Grid(this.w, this.h)
      : dx = Float32List(w * h),
        dy = Float32List(w * h);
  final int w, h;
  final Float32List dx, dy;

  double dist(int i) {
    final double x = dx[i], y = dy[i];
    if (x >= _far) return _far;
    return _len(x, y);
  }

  void _compare(int x, int y, int ox, int oy) {
    final int nx = x + ox, ny = y + oy;
    if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
    final int ni = ny * w + nx;
    if (dx[ni] >= _far) return;
    final double cx = dx[ni] + ox;
    final double cy = dy[ni] + oy;
    final int i = y * w + x;
    final double cur = dx[i] >= _far ? _far : dx[i] * dx[i] + dy[i] * dy[i];
    final double cand = cx * cx + cy * cy;
    if (cand < cur) {
      dx[i] = cx;
      dy[i] = cy;
    }
  }

  void transform() {
    // Forward pass
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        _compare(x, y, -1, 0);
        _compare(x, y, 0, -1);
        _compare(x, y, -1, -1);
        _compare(x, y, 1, -1);
      }
      for (int x = w - 1; x >= 0; x--) {
        _compare(x, y, 1, 0);
      }
    }
    // Backward pass
    for (int y = h - 1; y >= 0; y--) {
      for (int x = w - 1; x >= 0; x--) {
        _compare(x, y, 1, 0);
        _compare(x, y, 0, 1);
        _compare(x, y, 1, 1);
        _compare(x, y, -1, 1);
      }
      for (int x = 0; x < w; x++) {
        _compare(x, y, -1, 0);
      }
    }
  }
}

double _len(double x, double y) {
  final double v = x * x + y * y;
  return v <= 0 ? 0 : math.sqrt(v);
}

int _u8(double v) {
  int r = (v * 255.0).round();
  if (r < 0) return 0;
  if (r > 255) return 255;
  return r;
}
