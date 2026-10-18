import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../utils/liquid_glass_shape.dart';

/// Blurs the backdrop once for every glass surface beneath it.
///
/// Each `LiquidGlassLens` and `LiquidGlassBlender` under the layer gives up
/// its own blur pass. The layer paints **one** blur in its place, clipped to
/// the union of the members' outlines, and each member then runs only its
/// shader, which refracts the already-blurred backdrop:
///
///  * without the layer, a lens with blur costs two backdrop reads (blur,
///    then shader) and runs its own blur;
///  * under it, N members cost one blur pass plus one shader read each.
///
/// Members with different blur values get one pass per value.
///
/// ```dart
/// LiquidGlassLayer(
///   child: Stack(children: [ ...lenses... ]),
/// )
/// ```
///
/// What the blur reads is what was painted **before** the layer: content
/// painted inside it, under a member, is refracted but not blurred. Only
/// the outlines are blurred, so a refracted sample that lands outside a
/// member's outline, or inside a blender's bridge, reads sharp.
///
/// It sets how the blur is shared and nothing else. `LiquidGlassBatch` is a
/// different mechanism and is not used here: a lens under a layer ignores an
/// enclosing batch. A disabled layer leaves its subtree as if no layer were
/// above it, which also takes the subtree out of an enclosing one.
///
/// Impeller only. On the Skia / web capture path the members blur as before.
class LiquidGlassLayer extends StatefulWidget {
  const LiquidGlassLayer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  /// The subtree whose glass shares the layer's blur.
  final Widget child;

  /// Whether the members share the blur. `false` leaves every member on its
  /// own blur pass.
  final bool enabled;

  /// The group of the nearest enclosing layer, or `null` when there is none
  /// or it is disabled. Library-internal.
  @internal
  static LiquidGlassLayerGroup? groupOf(BuildContext context) {
    if (!ui.ImageFilter.isShaderFilterSupported) return null;
    return context
        .dependOnInheritedWidgetOfExactType<_LiquidGlassLayerScope>()
        ?.group;
  }

  @override
  State<LiquidGlassLayer> createState() => _LiquidGlassLayerState();
}

class _LiquidGlassLayerState extends State<LiquidGlassLayer> {
  final LiquidGlassLayerGroup _group = LiquidGlassLayerGroup._();

  @override
  Widget build(BuildContext context) {
    final LiquidGlassLayerGroup? group = widget.enabled ? _group : null;
    return _LiquidGlassLayerScope(
      group: group,
      child: _LiquidGlassLayerHost(group: group, child: widget.child),
    );
  }
}

class _LiquidGlassLayerScope extends InheritedWidget {
  const _LiquidGlassLayerScope({required this.group, required super.child});

  final LiquidGlassLayerGroup? group;

  @override
  bool updateShouldNotify(_LiquidGlassLayerScope oldWidget) =>
      group != oldWidget.group;
}

/// What a glass render object hands the layer it belongs to.
///
/// Library-internal.
@internal
abstract interface class LiquidGlassLayerMember {
  /// The member's render box: its outline is mapped from here.
  RenderBox get layerBox;

  /// The blur, in logical px.
  double get layerBlurSigma;

  /// Where the member's glass is, in [layerBox]'s coordinates.
  Path get layerBlurOutline;
}

/// The members of one [LiquidGlassLayer]. Library-internal.
@internal
class LiquidGlassLayerGroup {
  LiquidGlassLayerGroup._();

  final LinkedHashSet<LiquidGlassLayerMember> _members =
      LinkedHashSet<LiquidGlassLayerMember>.identity();

  /// Called from the member's paint, while it wants the shared blur.
  void join(LiquidGlassLayerMember member) => _members.add(member);

  /// Called when the member paints without it, and on detach.
  void leave(LiquidGlassLayerMember member) => _members.remove(member);
}

/// [shape]'s blur outline at [size]: the exact curve where the shape asks
/// for one, otherwise its rounded rect. The same choice the lens makes for
/// its own blur clip.
@internal
Path liquidGlassLayerOutline(LiquidGlassShape shape, Size size, Offset scale) {
  if (liquidGlassUsesExactClipPath(shape)) {
    return liquidGlassOutlinePath(shape, size, scale);
  }
  final double r = liquidGlassClipCornerRadius(shape);
  final double sx = scale.dx <= 0 ? 1.0 : scale.dx;
  final double sy = scale.dy <= 0 ? 1.0 : scale.dy;
  return Path()
    ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size, Radius.elliptical(r * sx, r * sy)));
}

class _LiquidGlassLayerHost extends SingleChildRenderObjectWidget {
  const _LiquidGlassLayerHost({required this.group, super.child});

  final LiquidGlassLayerGroup? group;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLiquidGlassLayerHost(group: group);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLiquidGlassLayerHost renderObject,
  ) {
    renderObject.group = group;
  }
}

class _RenderLiquidGlassLayerHost extends RenderProxyBox {
  _RenderLiquidGlassLayerHost({required LiquidGlassLayerGroup? group})
      : _group = group;

  LiquidGlassLayerGroup? _group;
  set group(LiquidGlassLayerGroup? value) {
    if (_group == value) return;
    _group = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  final LayerHandle<_LiquidGlassLayerBlurLayer> _layer =
      LayerHandle<_LiquidGlassLayerBlurLayer>();

  @override
  bool get alwaysNeedsCompositing => _group != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_group == null) {
      _layer.layer = null;
      super.paint(context, offset);
      return;
    }
    final _LiquidGlassLayerBlurLayer layer =
        _layer.layer ??= _LiquidGlassLayerBlurLayer();
    layer
      ..host = this
      ..offset = offset;
    context.pushLayer(layer, super.paint, Offset.zero);
  }

  /// The blur passes, one per sigma, each clipped to the union of the
  /// outlines of the members that use it, in this box's coordinates.
  ///
  /// Read at compositing time, after every member has painted this frame,
  /// so a member that moved without repainting is still where it is now.
  Map<double, Path> _passes() {
    final Map<double, Path> passes = <double, Path>{};
    final LiquidGlassLayerGroup? group = _group;
    if (group == null) return passes;
    for (final LiquidGlassLayerMember member in group._members) {
      final RenderBox box = member.layerBox;
      final double sigma = member.layerBlurSigma;
      if (!box.attached || !box.hasSize || sigma <= 0) continue;
      final Path outline = member.layerBlurOutline
          .transform(box.getTransformTo(this).storage);
      // Same winding for every member: under the default non-zero fill the
      // added contours read as their union.
      (passes[sigma] ??= Path()).addPath(outline, Offset.zero);
    }
    return passes;
  }

  @override
  void detach() {
    _layer.layer?.host = null;
    super.detach();
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

/// Pushes the layer's blur passes ahead of its children: the members'
/// shader passes come after, and read the blurred backdrop.
class _LiquidGlassLayerBlurLayer extends OffsetLayer {
  _RenderLiquidGlassLayerHost? host;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    engineLayer = builder.pushOffset(
      offset.dx,
      offset.dy,
      oldLayer: engineLayer as ui.OffsetEngineLayer?,
    );
    final _RenderLiquidGlassLayerHost? h = host;
    if (h != null && h.attached) {
      h._passes().forEach((double sigma, Path clip) {
        builder.pushClipPath(clip);
        builder.pushBackdropFilter(
          ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        );
        builder.pop();
        builder.pop();
      });
    }
    addChildrenToScene(builder);
    builder.pop();
  }
}
