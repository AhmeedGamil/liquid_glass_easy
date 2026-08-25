import 'package:flutter/widgets.dart';

import '../liquid_glass_style.dart';
import 'liquid_glass_blender.dart';

/// Draws every `LiquidGlassLens` beneath it as **one** sheet of glass.
///
/// The members keep their own layout, their own shape and their own child;
/// what they give up is their individual glass pass. In its place the group
/// paints a single surface covering all of them — one backdrop read and one
/// material for the whole set, instead of one of each per lens.
///
/// ```dart
/// LiquidGlassGroup(
///   style: LiquidGlassStyle(adaptivity: myPalette),
///   child: Column(children: [ ...lenses... ]),
/// )
/// ```
///
/// **[smoothness] decides whether they also fuse, and defaults to `null`:
/// they do not.** The group still draws them as one surface with one read,
/// but each member keeps its own hard outline, and the shader skips the
/// smooth-union entirely rather than running it and finding nothing to blend.
/// Give it a radius and members that come within about half of it flow
/// together through a metaball bridge.
///
/// **Adaptivity is per member.** Each lens judges the background behind
/// itself and paints its own verdict into the shared sheet; where two of them
/// fuse, their colours cross over inside the bridge, on the same falloff that
/// shapes it. A member that is not adaptive takes the group's colour. Put
/// `adaptivity` on the group's [style] as well and it supplies the fallback
/// colour and the content palette for the subtree.
///
/// Two to [maxLensCount] members. Place the group inside a `LiquidGlassView`
/// for the Skia / web capture path; on Impeller it reads the live backdrop.
class LiquidGlassGroup extends StatelessWidget {
  const LiquidGlassGroup({
    super.key,
    required this.child,
    this.style = const LiquidGlassStyle(),
    this.smoothness,
    this.useImpellerBackdrop,
    this.useEngineBlur = true,
    this.debugClipBounds = false,
  }) : assert(smoothness == null || smoothness > 0);

  /// Fewest members the shared surface is meant for.
  static const int minLensCount = LiquidGlassBlender.minLensCount;

  /// Most members one group can hold.
  static const int maxLensCount = LiquidGlassBlender.maxLensCount;

  /// A subtree holding [minLensCount] to [maxLensCount] `LiquidGlassLens`
  /// descendants.
  final Widget child;

  /// The shared material: shape, appearance, refraction, and the group-level
  /// adaptivity that members without one of their own fall back to.
  final LiquidGlassStyle style;

  /// Radius, in logical pixels, over which nearby members flow together —
  /// or **`null` (the default) to switch the fusing off**.
  ///
  /// With a radius, two members bridge once the gap between them drops to
  /// roughly `smoothness / 2`, and their tints cross over across that same
  /// bridge. Further apart than that and the radius costs a little maths per
  /// fragment for a blend that never happens.
  ///
  /// With `null` the group is a plain union: nearest member wins each
  /// fragment outright, no smooth-union, no per-member influence weights, no
  /// blended gradient. That is the default because sharing one surface and
  /// one backdrop read is what the group is FOR — fusing is the extra, and
  /// members laid out apart (a row of buttons, a column of pills) should not
  /// pay for a blend that never happens. Ask for a radius when you want the
  /// members to touch.
  ///
  /// Prefer `null` over a tiny radius. A near-zero radius gets the outline
  /// right but leaves the influence weights as a 0/1 indicator, so two
  /// OVERLAPPING members weigh the same and their colours average with a hard
  /// step at each outline. `null` resolves that tie by distance instead.
  final double? smoothness;

  /// Overrides renderer detection. Null inherits from `LiquidGlassView`, then
  /// falls back to Flutter's shader-filter capability.
  final bool? useImpellerBackdrop;

  /// On Impeller, blur the backdrop with the engine's Gaussian before the
  /// refraction shader instead of blurring in-shader. Cheaper and cleaner;
  /// `false` falls back to the in-shader blur. No effect on the Skia path.
  final bool useEngineBlur;

  /// Debug: outline the backdrop clip region in magenta. Costs performance —
  /// diagnostic only.
  final bool debugClipBounds;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassBlender(
      style: style,
      smoothness: smoothness,
      useImpellerBackdrop: useImpellerBackdrop,
      useEngineBlur: useEngineBlur,
      debugClipBounds: debugClipBounds,
      child: child,
    );
  }
}
