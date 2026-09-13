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

/// The clip a layer imposes on everything beneath it, in the space its own
/// bounds are expressed in (its parent's children's space): the rect of a
/// [ClipRectLayer], the outer rect of a [ClipRRectLayer], the bounds of a
/// [ClipPathLayer]. Null for any other layer, and for a clip layer set to
/// [Clip.none].
///
/// These are the only layers that reach the engine as clip operations, so
/// they are the only ones that bound a backdrop pass through the clip stack.
/// Subpasses — image filters, opacity, backdrop filters — bound it too, but
/// through the pass texture; see [liquidGlassFilterSubpassAncestor].
Rect? liquidGlassLayerClipBounds(Layer layer) {
  if (layer is ClipRectLayer) {
    return layer.clipBehavior == Clip.none ? null : layer.clipRect;
  }
  if (layer is ClipRRectLayer) {
    return layer.clipBehavior == Clip.none ? null : layer.clipRRect?.outerRect;
  }
  if (layer is ClipPathLayer) {
    return layer.clipBehavior == Clip.none
        ? null
        : layer.clipPath?.getBounds();
  }
  return null;
}

/// What [liquidGlassAncestorLayerClip] found above a layer.
class LiquidGlassLayerClip {
  const LiquidGlassLayerClip({required this.clip, required this.toTop});

  /// Every clip on the path, intersected, in the top space — null when no
  /// layer on the path clips.
  final Rect? clip;

  /// Maps the space the starting layer's own bounds are expressed in (its
  /// parent's children's space) into the top space.
  final Matrix4 toTop;
}

/// Every clip the layers above [from] push, intersected, in the **top
/// space**: the children's space of [until] when it is an ancestor, else
/// the root layer's children's space — the window in logical pixels, the
/// root layer itself being the scale to physical pixels and left out.
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
/// This walks the LAYER tree, not the render tree. A render object's
/// `describeApproximatePaintClip` is a semantics estimate: a viewport
/// reports its bounds always but pushes the clip only while its content
/// overflows, so a short list mid-slide "clips" at the page's moving edge
/// for the estimate and at nothing for the engine — and the glass ran ahead
/// of its page by the difference. The clip layers are what the engine gets,
/// so they are what counts, read at compositing time when the tree is final.
LiquidGlassLayerClip liquidGlassAncestorLayerClip(Layer from, {Layer? until}) {
  // Nearest first, stopping under [until]. A walk that runs out at the root
  // drops the root: its transform is the physical-pixel scale, and the
  // window's logical space is its children's.
  final List<ContainerLayer> chain = <ContainerLayer>[];
  bool cappedByUntil = false;
  for (ContainerLayer? layer = from.parent;
      layer != null;
      layer = layer.parent) {
    if (identical(layer, until)) {
      cappedByUntil = true;
      break;
    }
    chain.add(layer);
  }
  if (!cappedByUntil && chain.isNotEmpty) chain.removeLast();

  // Top-down, so [toTop] grows one layer at a time: a layer's bounds live
  // in its parent's space, so they map through the layers ABOVE it only,
  // and the transform is extended by the layer itself after its clip is
  // taken. Composed the way `getTransformTo` composes render objects.
  final Matrix4 toTop = Matrix4.identity();
  Rect? clip;
  for (int i = chain.length - 1; i >= 0; i--) {
    final ContainerLayer layer = chain[i];
    final Rect? own = liquidGlassLayerClipBounds(layer);
    if (own != null) {
      final Rect inTop = MatrixUtils.transformRect(toTop, own);
      clip = clip == null ? inTop : clip.intersect(inTop);
    }
    layer.applyTransform(i > 0 ? chain[i - 1] : from, toTop);
  }
  return LiquidGlassLayerClip(clip: clip, toTop: toTop);
}
