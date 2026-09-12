import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Draws every `LiquidGlassLens` beneath it from **one** read of the backdrop.
///
/// A lens on Impeller works by reading back what is already painted behind it
/// and running the glass shader over that copy. The read is the expensive
/// part, and it is per lens: twenty glass cards in a list mean twenty
/// readbacks a frame (forty with blur, which adds a second pass of its own).
/// A batch tags all of its lenses with one shared backdrop key, so the engine
/// takes the copy **once** and every member samples it.
///
/// ```dart
/// LiquidGlassBatch(
///   child: ListView.builder(
///     itemCount: 40,
///     itemBuilder: (context, i) => LiquidGlassLens(
///       style: cardStyle,
///       child: Card(i),
///     ),
///   ),
/// )
/// ```
///
/// Nothing else about the members changes: each keeps its own shape, its own
/// style, its own child, its own adaptivity, its own touch response. They are
/// still separate sheets of glass — the batch only makes them share the read.
///
/// ## Batch or blender?
///
/// `LiquidGlassBlender` draws two to eight lenses with **one shader**: one
/// silhouette, one material, one read — optionally flowing into each other
/// through a metaball bridge, and with `smoothness: 0` not even that, just the
/// one pass for the set (what the deprecated `LiquidGlassGroup` was).
/// Everything it can draw has to fit in that shader, which is where its
/// eight-member ceiling comes from.
///
/// `LiquidGlassBatch` shares nothing but the read. Members stay separate
/// passes, keep their own looks, and there is **no limit on how many** there
/// can be. Reach for the blender when the lenses should read as one piece of
/// glass, and for the batch when there are simply a lot of them.
///
/// The two nest. A blender inside a batch is a
/// member like any other: it is already one pass, and in a batch that pass
/// shares the batch's read instead of taking its own. So a page of glass
/// cards with one fused pair among them is still a single read.
///
/// ## It works on the components too
///
/// Every component that draws its glass through a `LiquidGlassLens` — the
/// button, the FAB, the app bar, the sheet, the dialog, the tab bar's
/// capsule, the draggable — joins a batch by being inside it. There is
/// nothing to pass: the lens finds the batch from its own context, however
/// deep in a component's tree it sits. So does the scroll edge, whose blur
/// is a backdrop pass of its own: inside a batch it takes the batch's copy
/// instead of a read of its own.
///
/// ```dart
/// LiquidGlassBatch(
///   child: Wrap(
///     spacing: 12,
///     children: <Widget>[
///       for (final String label in labels)
///         LiquidGlassButton(label: label, onPressed: () {}),
///     ],
///   ),
/// )
/// ```
///
/// A component that stacks glass **on** glass is an overlap like any other,
/// and the rule below applies to it: the tab bar's moving pill refracts the
/// capsule under it, so a tab bar inside a batch loses that — the pill reads
/// the page instead. Keep one out of the batch, or wrap it in
/// [LiquidGlassBatch.exclude], which puts that subtree back on reads of its
/// own while the rest of the batch stays shared.
///
/// The switch and the slider do this for themselves: each thumb refracts
/// the track it rides, which a shared copy taken before the control painted
/// would not hold, so both keep their thumb on a read of its own whatever
/// batch they sit in. The rest of the control — the track, the fill — is
/// plain paint and costs a batch nothing either way.
///
/// ```dart
/// LiquidGlassBatch(
///   child: Column(
///     children: <Widget>[
///       Expanded(child: cards),
///       LiquidGlassBatch.exclude(child: LiquidGlassTabBar(...)),
///     ],
///   ),
/// )
/// ```
///
/// ## The one rule: members must not overlap
///
/// Every member reads the same copy of the backdrop, taken before any of them
/// painted — so a member cannot see another member's glass. Where two of them
/// overlap, the one on top refracts what was *behind* the one below instead of
/// the glass itself, and the stack reads as a single lens. Lay members out
/// side by side (lists, grids, rows of controls, a keyboard) and this never
/// comes up. Two lenses that must overlap belong in different batches, or in
/// no batch at all.
///
/// A scroll edge is the member most likely to overlap: it is pinned over the
/// content that scrolls under it. Batched, it blurs the copy taken before the
/// cards painted, so a card passing through the band loses its glass there —
/// at the band's sigma the difference is small, and it is nothing where the
/// band has faded out. If it shows, keep the edge out with
/// [LiquidGlassBatch.exclude] and it reads the cards as before.
///
/// ## The view and the scaffold batch on their own
///
/// `LiquidGlassView` and `LiquidGlassScaffold` do this without being asked
/// (`batch: true`, the default): one batch over the background — the
/// scaffold's body — and another over what floats above it. Two, because
/// the chrome refracts the body and could not see it from the body's copy.
/// A glass pill tab bar keeps its moving pill and its magnifier out of
/// both. The scaffold's chrome batch can reach further than its own tree:
/// a `showLiquidGlassSheet` or `showLiquidGlassDialog` opened from inside
/// the scaffold with `batch: true` joins it, so the sheet or the dialog
/// shares the tab bar's read — by default each takes a read of its own.
/// Pass `batch: false` to the scaffold to get every lens back on a read of
/// its own.
///
/// ## Where it applies
///
/// The shared key is an Impeller mechanism, so the batch is what changes the
/// cost there. On the Skia / web capture path a `LiquidGlassView` already
/// captures its background once for every lens inside it, so the batch is
/// inert rather than wrong — the same tree runs on both backends.
class LiquidGlassBatch extends StatefulWidget {
  const LiquidGlassBatch({
    super.key,
    required this.child,
    this.enabled = true,
  });

  /// Keeps [child] out of the enclosing batch.
  ///
  /// Every lens under it — bare or inside a component — goes back to a
  /// backdrop read of its own, exactly as if no batch were above it. Use it
  /// for the member that must overlap another, or the component that stacks
  /// glass on glass, without taking the rest of the batch apart. Same as
  /// `LiquidGlassBatch(enabled: false)`, named for what it is for.
  const LiquidGlassBatch.exclude({
    super.key,
    required this.child,
  }) : enabled = false;

  /// The subtree whose `LiquidGlassLens` descendants share the read.
  final Widget child;

  /// Whether the members are actually batched. `false` leaves every lens on
  /// its own backdrop read — the pre-batch behaviour — which is also what a
  /// disabled batch nested inside an enabled one restores for its own
  /// subtree.
  final bool enabled;

  /// The shared backdrop key for the nearest enclosing batch, or `null` when
  /// there is none (or the nearest one is disabled).
  static int? backdropIdOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LiquidGlassBatchScope>()
        ?.backdropId;
  }

  @override
  State<LiquidGlassBatch> createState() => _LiquidGlassBatchState();
}

/// Keys are handed to the engine as plain ints and share one namespace with
/// Flutter's own `BackdropKey`, which counts up from zero. Starting high
/// keeps a batch from ever colliding with an app's `BackdropGroup`.
int _nextBackdropId = 1 << 20;

/// A fresh backdrop key, never handed out before.
///
/// [LiquidGlassBatch] takes one per batch. A host that spreads **one** batch
/// over subtrees no single widget can wrap takes one here and publishes it
/// over each through a [LiquidGlassBatchScope] — that is how the scaffold's
/// chrome batch covers its tab bar and its `dialog` slot, and the sheets
/// and dialogs presented over it that ask to join.
///
/// Library-internal.
int liquidGlassAllocateBackdropId() => _nextBackdropId++;

class _LiquidGlassBatchState extends State<LiquidGlassBatch> {
  late final int _backdropId = liquidGlassAllocateBackdropId();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassBatchScope(
      backdropId: widget.enabled ? _backdropId : null,
      child: widget.child,
    );
  }
}

/// Carries the batch's shared backdrop key down to the lenses.
///
/// Library-internal: apps use [LiquidGlassBatch], which owns the key's
/// lifetime, rather than publishing one of their own.
class LiquidGlassBatchScope extends InheritedWidget {
  const LiquidGlassBatchScope({
    super.key,
    required this.backdropId,
    required super.child,
  });

  /// The key every member passes to its backdrop pass, or `null` where the
  /// batch is disabled.
  final int? backdropId;

  @override
  bool updateShouldNotify(covariant LiquidGlassBatchScope oldWidget) {
    return backdropId != oldWidget.backdropId;
  }
}

/// A backdrop pass that carries a plain int key.
///
/// A stock `BackdropFilterLayer` only takes a framework `BackdropKey`, whose
/// number is private, while a [LiquidGlassBatch] hands out ints. This layer
/// pushes [filter] with that int directly, the way the single lens's layer
/// does, so anything built on it joins the batch's read.
///
/// Library-internal.
class LiquidGlassBatchBackdropLayer extends ContainerLayer {
  ui.ImageFilter? _filter;
  ui.ImageFilter? get filter => _filter;
  set filter(ui.ImageFilter? value) {
    if (value == _filter) return;
    _filter = value;
    markNeedsAddToScene();
  }

  int? _backdropId;
  int? get backdropId => _backdropId;
  set backdropId(int? value) {
    if (value == _backdropId) return;
    _backdropId = value;
    markNeedsAddToScene();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final ui.ImageFilter? filter = _filter;
    if (filter == null) {
      addChildrenToScene(builder);
      return;
    }
    engineLayer = builder.pushBackdropFilter(
      filter,
      oldLayer: engineLayer as ui.BackdropFilterEngineLayer?,
      backdropId: _backdropId,
    );
    addChildrenToScene(builder);
    builder.pop();
  }
}

/// A `BackdropFilter` that joins the enclosing [LiquidGlassBatch].
///
/// Same contract as the framework widget — [filter] is applied to what is
/// already painted behind it, and [child] paints into that same layer — but
/// inside a batch, on the Impeller path, the pass carries the batch's key and
/// reads the batch's copy instead of taking one of its own. Outside a batch
/// (or on the capture path) it is a plain backdrop filter.
///
/// Library-internal: the components use it for the passes they push
/// themselves, such as the scroll edge's blur.
class LiquidGlassBatchBackdropFilter extends SingleChildRenderObjectWidget {
  const LiquidGlassBatchBackdropFilter({
    super.key,
    required this.filter,
    super.child,
  });

  /// What the pass filters the backdrop through.
  final ui.ImageFilter filter;

  /// The batch key this pass should carry, if any. Like the lens, only the
  /// Impeller path joins: the capture path has no read to share.
  static int? _backdropIdFor(BuildContext context) =>
      ui.ImageFilter.isShaderFilterSupported
          ? LiquidGlassBatch.backdropIdOf(context)
          : null;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLiquidGlassBatchBackdropFilter(
      filter: filter,
      backdropId: _backdropIdFor(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidGlassBatchBackdropFilter renderObject,
  ) {
    renderObject
      ..filter = filter
      ..backdropId = _backdropIdFor(context);
  }
}

/// Render object for [LiquidGlassBatchBackdropFilter].
class RenderLiquidGlassBatchBackdropFilter extends RenderProxyBox {
  RenderLiquidGlassBatchBackdropFilter({
    required ui.ImageFilter filter,
    required int? backdropId,
  })  : _filter = filter,
        _backdropId = backdropId;

  final LayerHandle<LiquidGlassBatchBackdropLayer> _layer =
      LayerHandle<LiquidGlassBatchBackdropLayer>();

  ui.ImageFilter _filter;
  ui.ImageFilter get filter => _filter;
  set filter(ui.ImageFilter value) {
    if (_filter == value) return;
    _filter = value;
    markNeedsPaint();
  }

  int? _backdropId;
  int? get backdropId => _backdropId;
  set backdropId(int? value) {
    if (_backdropId == value) return;
    _backdropId = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final LiquidGlassBatchBackdropLayer layer =
        _layer.layer ??= LiquidGlassBatchBackdropLayer();
    layer
      ..filter = _filter
      ..backdropId = _backdropId;
    context.pushLayer(layer, super.paint, offset);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}
