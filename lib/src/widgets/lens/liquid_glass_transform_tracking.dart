import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// A zero-content layer that watches its render object's **global
/// transform** and fires a callback when it changes between frames.
///
/// Why this exists: a lens's shader uniforms encode its on-screen
/// position, but when an ancestor moves the lens (scroll, slide
/// transition, drag of a parent) the lens's own `paint()` is usually
/// NOT re-run — the compositor just shifts the retained layers. Nothing
/// widget-side observes "my global position changed".
///
/// This layer closes that gap at the latest possible moment: layers are
/// re-added to the scene every frame the surrounding tree changes
/// ([alwaysNeedsAddToScene]), and [addToScene] runs *after* all layout
/// and paint, when `getTransformTo(null)` is final for the frame. When
/// the transform differs from the previous frame's, [onTransformChanged]
/// (typically `markNeedsPaint`) schedules a repaint so the next frame's
/// uniforms are correct.
///
/// The detection lags the movement by one frame by construction — the
/// stale frame has already been built when we detect it. During
/// continuous movement (scrolling) this self-corrects every frame;
/// after movement stops the final frame is exact.
class LensTransformTrackingLayer extends OffsetLayer {
  LensTransformTrackingLayer();

  /// The render object whose global transform is watched.
  RenderObject? renderObject;

  /// Invoked (during scene building) when the transform changed since
  /// the last frame. Keep it cheap — typically just `markNeedsPaint`.
  VoidCallback? onTransformChanged;

  Matrix4? _lastTransform;

  /// The enclosing filtered subpass's origin, `null` when there is none.
  Offset? _lastSubpassOrigin;

  /// Whether a frame has been recorded yet. Not `_lastTransform == null`:
  /// the subpass origin is legitimately null most of the time, so the two
  /// need one shared flag rather than one standing in for the other.
  bool _sampled = false;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    // Intentionally does NOT call super: this layer contributes nothing
    // visual to the scene; it exists purely for the transform probe.
    final RenderObject? ro = renderObject;
    if (ro == null || !ro.attached) return;
    final Matrix4 current = ro.getTransformTo(null);
    // Watched separately because it moves the lens WITHOUT moving any
    // transform: an ancestor image filter re-bases the shader's fragments
    // onto its own texture, which `getTransformTo` cannot see. Android's
    // stretch overscroll switches one on for the length of a pull, so
    // without this a resting lens would never learn the pull began.
    final RenderObject? subpass = liquidGlassFilterSubpassAncestor(ro);
    final Offset? subpassOrigin = subpass == null
        ? null
        : MatrixUtils.transformPoint(subpass.getTransformTo(null), Offset.zero);
    if (!_sampled) {
      // First frame: just record. The frame being built was painted
      // with this same transform, so there is nothing to correct.
      _sampled = true;
      _lastTransform = current;
      _lastSubpassOrigin = subpassOrigin;
      return;
    }
    if (!MatrixUtils.matrixEquals(current, _lastTransform) ||
        subpassOrigin != _lastSubpassOrigin) {
      _lastTransform = current;
      _lastSubpassOrigin = subpassOrigin;
      onTransformChanged?.call();
    }
  }
}

/// Mixin for a [RenderProxyBox] that needs to repaint whenever its
/// global transform changes — even when the change originates from an
/// ancestor and would normally not repaint this subtree.
///
/// Call [pushTransformTracking] at the start of `paint()`.
mixin LensTransformTrackingMixin on RenderProxyBox {
  final LayerHandle<LensTransformTrackingLayer> _trackingLayerHandle =
      LayerHandle<LensTransformTrackingLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  /// Pushes (and lazily creates) the tracking layer into the current
  /// painting context. Call first thing in `paint()`.
  void pushTransformTracking(PaintingContext context, Offset offset) {
    final layer = _trackingLayerHandle.layer ??= LensTransformTrackingLayer();
    layer
      ..renderObject = this
      ..onTransformChanged = () {
        if (attached) onGlobalTransformChanged();
      };
    context.pushLayer(
        layer, (PaintingContext context, Offset offset) {}, offset);
  }

  /// Called when this render object's global transform changed between
  /// frames. Default behavior repaints; override to add bookkeeping.
  void onGlobalTransformChanged() => markNeedsPaint();

  @override
  void detach() {
    _trackingLayerHandle.layer?.renderObject = null;
    super.detach();
  }

  @override
  void dispose() {
    _trackingLayerHandle.layer = null;
    super.dispose();
  }
}

/// The nearest ancestor that renders this subtree into its own **filtered
/// subpass**, or null when the lens composites straight into the window.
///
/// Android's stretch overscroll is one, for exactly as long as the pull
/// lasts: Flutter's `StretchEffect` wraps the whole scrollable in an
/// `ImageFiltered` whose `enabled` follows the stretch. Inside it,
/// `ImageFilter.shader`'s `FlutterFragCoord()` starts at THAT texture's
/// corner rather than the window's — so a lens that placed itself in
/// screen space draws offset from where its own clip lands, by the
/// subpass's origin.
///
/// Nothing widget-side can see this. An image filter is not a transform,
/// so `getTransformTo(null)` still reports the window position and every
/// transform probe stays silent; the composited layer is the only tell.
///
/// Pass the result straight to `getTransformTo`: the lens's geometry then
/// runs in the subpass's space, which is the space its fragments arrive
/// in. A null result is the ordinary case and means the window.
RenderObject? liquidGlassFilterSubpassAncestor(RenderObject from) {
  for (RenderObject? node = from.parent; node != null; node = node.parent) {
    // The layer is the detector, not the render object's type: it exists
    // only while the filter is actually enabled, which is what decides
    // whether the subpass is there at all.
    // ignore: invalid_use_of_protected_member
    if (node.layer is ImageFilterLayer) return node;
  }
  return null;
}

/// Every clip the ancestors between [from] and [surface] impose on it,
/// intersected, in [surface]'s coordinates — null when nothing on the path
/// clips. A null [surface] means the window.
///
/// A lens asks the engine for a backdrop pass inside a rect it chose; what
/// it gets is that rect INTERSECTED with every clip already on the stack.
/// Where the pass's frame is the screen's that difference is invisible, but
/// a composed (batched, blurred) pass reads an intermediate bounded by the
/// result, and counts `FlutterFragCoord()` from ITS top-left. Cut on the
/// right or the bottom, a rect keeps its origin and nothing moves; cut on
/// the LEFT or the TOP, the origin shifts and the glass is drawn that far
/// from the outline it belongs to.
///
/// The clips are what a scroll viewport, a `ClipRect` or any other clipping
/// ancestor already reports for semantics — approximate in the sense of
/// never being tighter than the real one.
Rect? liquidGlassAncestorPaintClip(RenderObject from, RenderObject? surface) {
  Rect? clip;
  RenderObject child = from;
  RenderObject? parent = child.parent;
  while (parent != null && parent != surface) {
    final Rect? own = parent.describeApproximatePaintClip(child);
    if (own != null) {
      // Only the clippers pay for a transform; every other ancestor costs
      // one null-returning call.
      final Rect inSurface =
          MatrixUtils.transformRect(parent.getTransformTo(surface), own);
      clip = clip == null ? inSurface : clip.intersect(inSurface);
    }
    child = parent;
    parent = parent.parent;
  }
  return clip;
}
