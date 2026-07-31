import 'package:flutter/foundation.dart';

import 'liquid_glass_flex.dart';

/// How a glass surface **answers a finger**, bundled as one descriptor.
///
/// Touch response is not one effect. Apple's own description of Liquid Glass
/// is that a control can "lift, flex, and energize" the moment you touch it —
/// a deformation and a light, two separate things that fire on the same
/// gesture. This is the group that holds them, so a surface's whole feel
/// travels as a single value the way its whole look travels as a
/// `LiquidGlassStyle`.
///
/// Today it carries [flex]. `null` means the surface does not respond at all
/// — no gesture listener, no ticker, nothing added to the tree.
///
/// ```dart
/// LiquidGlassLens(
///   touch: const LiquidGlassTouch(
///     flex: LiquidGlassFlex(stretch: 22, lean: 0.5),
///   ),
///   child: const Center(child: Text('press me')),
/// )
/// ```
@immutable
class LiquidGlassTouch {
  /// Soft-body deformation under the finger: press and it compresses, drag
  /// and it elongates along the pull, pinches in the cross axis and leans
  /// after the finger, then springs back with a wobble.
  ///
  /// `null` leaves the surface rigid.
  final LiquidGlassFlex? flex;

  const LiquidGlassTouch({this.flex});

  /// A response that is only a deformation — the common case, without the
  /// nesting.
  const LiquidGlassTouch.flexing(LiquidGlassFlex this.flex);

  /// Whether anything at all happens on touch. False for a group whose
  /// every member is unset, which callers treat exactly like a `null` group.
  bool get isEmpty => flex == null;

  LiquidGlassTouch copyWith({LiquidGlassFlex? flex}) =>
      LiquidGlassTouch(flex: flex ?? this.flex);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassTouch && other.flex == flex;

  @override
  int get hashCode => flex.hashCode;
}
