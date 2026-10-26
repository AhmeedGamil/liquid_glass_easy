import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// One baked shape: a texture the glass shaders read in place of their SDF.
///
/// The shape is baked in its own space, so it is keyed on what it looks like
/// and never on where it is: a lens or a blender that moves without changing
/// shape keeps its bake, and only the uniforms that place it change. Change
/// the shape — a size, a radius, a member moving against the others — and a
/// new one is baked. `liquid_glass_renderer` bakes its geometry into a
/// texture too.
///
/// Library-internal.
@internal
class LiquidGlassShapeBake {
  LiquidGlassShapeBake._(this.key, this.images, this.width, this.height);

  /// What was baked; equal keys share one bake.
  final Object key;

  /// The textures, in the order the shader binds them.
  final List<ui.Image> images;

  /// Texture size in fragment px.
  final int width;
  final int height;

  int _refs = 0;
}

/// The bakes in use, shared by everything that asks for the same shape.
///
/// Library-internal.
@internal
class LiquidGlassShapeCache {
  LiquidGlassShapeCache._();

  /// Whether the shaders read baked shapes at all. `false` evaluates every
  /// shape per pixel, every frame, as before. Read at paint time.
  static bool enabled = true;

  /// A texture larger than this, in fragment px, is not baked: the shape is
  /// evaluated per pixel instead.
  static const int maxTexels = 4 << 20;

  static final Map<Object, LiquidGlassShapeBake> _bakes =
      <Object, LiquidGlassShapeBake>{};

  static ui.Image? _empty;

  /// A 1x1 image for a sampler with nothing baked: every declared sampler
  /// has to be bound.
  static ui.Image get empty {
    final ui.Image? image = _empty;
    if (image != null) return image;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image created = picture.toImageSync(1, 1);
    picture.dispose();
    return _empty = created;
  }

  /// Whether someone holds a bake for [key], so acquiring it costs nothing.
  static bool holds(Object key) => _bakes.containsKey(key);

  /// The bake for [key], baked by [bake] if no one holds it yet. Pair every
  /// call with a [release].
  static LiquidGlassShapeBake acquire(
    Object key,
    int width,
    int height,
    List<ui.Image> Function() bake,
  ) {
    final LiquidGlassShapeBake entry =
        _bakes[key] ??= LiquidGlassShapeBake._(key, bake(), width, height);
    entry._refs++;
    return entry;
  }

  /// Gives back a bake from [acquire]; the last holder disposes it.
  static void release(LiquidGlassShapeBake? entry) {
    if (entry == null) return;
    if (--entry._refs > 0) return;
    if (identical(_bakes[entry.key], entry)) _bakes.remove(entry.key);
    for (final ui.Image image in entry.images) {
      image.dispose();
    }
  }

  /// Draws [shader] over a [width] x [height] texture with its output stored
  /// as it is, and returns the image.
  static ui.Image draw(ui.FragmentShader shader, int width, int height) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.src,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  /// [value] rounded up to a multiple of [step]: bands that only move a
  /// little keep their bake.
  static double ceilTo(double value, double step) =>
      math.max(step, (value / step).ceil() * step);

  /// [value] rounded to 1/64 px, so float noise in a layout does not rebake.
  static double snap(double value) => (value * 64).roundToDouble() / 64;
}

/// Keeps the lenses under it out of the shape cache: their shape is drawn per
/// pixel every frame, as with the cache off.
///
/// For glass that changes shape whenever it is seen, where a bake taken on
/// settle is thrown away by the next touch.
///
/// Library-internal.
@internal
class LiquidGlassShapeCacheExclude extends InheritedWidget {
  const LiquidGlassShapeCacheExclude({super.key, required super.child});

  /// Whether [context] sits under an exclusion.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LiquidGlassShapeCacheExclude>() !=
      null;

  @override
  bool updateShouldNotify(LiquidGlassShapeCacheExclude oldWidget) => false;
}
