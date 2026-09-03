# LiquidGlassMorph — experimental

Glass that **morphs to fit whatever you put in it**.

Swap the child; the glass measures the new one and flows to its size. You never
type a dimension:

```dart
LiquidGlassMorph(
  alignment: Alignment.bottomRight,
  child: open
      ? const Menu(key: ValueKey('menu'))
      : const Icon(Icons.more_horiz, key: ValueKey('dots')),
)
```

That is the whole API. **Add a row to `Menu` and the glass grows to match** —
there is one truth about how big the menu is, and the glass reads it instead of
being told it a second time.

This is Apple's model, not `AnimatedContainer`'s. In SwiftUI you write

```swift
GlassEffectContainer(spacing: 40) {
    HStack {
        Image(systemName: "scribble").glassEffect().glassEffectID("a", in: ns)
        if expanded {
            Image(systemName: "eraser").glassEffect().glassEffectID("b", in: ns)
        }
    }
}
```

and note what is absent: no width, no height, no anchor, no duration. You change
what is *in the tree* and the framework morphs the geometry, because it already
knows the layout on both sides. Here, `Key` is the identity and the child's own
layout is the size.

> `GlassEffectContainer` has a counterpart too: `LiquidGlassBlender`, where
> members close enough together merge. Its `spacing` is our `smoothness`.

### When you do own the dimension

`width` and `height` are **overrides**, not inputs. Set one and that axis is
pinned while the other is still measured — the common fixed-width menu whose
height follows its rows:

```dart
LiquidGlassMorph(width: 260, child: Menu(key: menuKey))
```

Set both and nothing is measured at all.

### The one rule for the child

It has to be able to size itself. Whatever it reports under a loose constraint
is what the glass becomes, so a `Column` of rows works, and a `Column` with
`crossAxisAlignment: stretch` will report the full width it is offered — which
is probably not what you meant. Wrap it in a `SizedBox` if you want to state the
width in one place.

---

## Why not just `AnimatedContainer`

Because a resize is convex on every frame, and a liquid is not.

The morph is **two blobs of one liquid**, drawn as a single surface by
`LiquidGlassBlender`. Nothing here is a box changing size:

| | |
|---|---|
| **Two blobs, one surface** | The destination blob carries the new shape and content; the source blob carries the old. The blender's smooth union joins them, so mid-morph the outline has a **waist** — the one thing a tween can never produce and the thing the eye reads as liquid. |
| **Growing: centre leads, size follows** | The new blob's centre leaps toward where it is going while its size catches up a beat later, so it pulls a neck out of the source. The source lingers, then drains to nothing where it stood. |
| **Shrinking: size leads, centre follows** | The same film run backwards. The surface deflates around its centre, then slides into the destination — which is already there, small and inside it, waiting. |
| **Each blob keeps its own corners** | The source is drawn as the source's curve and radius until it is gone; the destination as its own from the moment it appears. Nothing is interpolated and nothing is swapped mid-travel. |
| **Content materialises** | The old child blurs, fades and shrinks out in the first 40% of the swap. The new one blurs in over the second half, pinned where the glass will finally sit — so it lands as the glass does, and is never chopped by a travelling edge. |
| **The rest is exact** | At rest the two blobs coincide and the union is switched off, so the resting outline is the plain shape, never inflated by the neck radius. |

`smoothness` is the neck radius — the same quantity as the blender's. It is
keyed to how far apart the blobs are: nothing while they coincide, full once
they have parted, so the resting outline is never inflated by it.

---

## `alignment` is the parameter people regret

The widget **fills the box it is given** and places the glass inside it. It has
to: a size on its own does not say which way a surface should grow.

> Centred, both edges move and every direction looks correct — which is exactly
> why getting this wrong stays invisible until you move the thing.

- `Alignment.centerLeft` → the left edge **holds**, it opens rightward.
- `Alignment.bottomRight` → that corner **holds**, it opens up and to the left.
- `Alignment.center` → both edges move.

Grow symmetrically at an edge and the surface walks across the screen, or
straight off it.

### It is continuous, not nine positions

An axis at `x` sends `(1 + x) / 2` of any size change out one side and the rest
out the other. `-1` and `+1` are just where one of those fractions reaches zero.
`Alignment(-0.37, 0.12)` is as valid as `centerLeft`.

So if your surface is positioned by something that *isn't* an alignment — a
`Positioned`, a list, a drag — recover the one its own rect implies:

```dart
alignment: LiquidGlassMorph.alignmentFor(cardRect, pageRect),
```

That is the exact inverse of `Alignment.inscribe`: a rect inside a field implies
the alignment that would have placed it there.

---

## Motion

Pick a preset. That is the whole choice:

```dart
motion: LiquidGlassMorphMotion.fluid        // the default: a blob that leaps and drags a neck
motion: LiquidGlassMorphMotion.anchoredPop  // pops open from the corner that holds, no neck
motion: LiquidGlassMorphMotion.droplet      // born small, leaps hard, long neck
motion: LiquidGlassMorphMotion.calm         // no bounce, for sheets and large cards
```

Behind them are three numbers — the spring (`spring(duration:bounce:)`
takes a SwiftUI `Spring` straight from a design spec), `stretch` (how far the
leading blob runs ahead of its own size) and `anchor` (the point the new
shape grows around: the centre makes it leap and drag a neck, `null` uses the
widget's own `alignment` so it simply pops open from that corner, the way
Apple's menus grow from a toolbar button). Everything set once and left alone
is in `LiquidGlassMorphAdvanced`, behind `advanced`.

The model is what Apple's documentation describes: a matched-geometry
transition inside a glass container, whose `spacing` is the distance at which
"paths start to blend" — our `smoothness`; content that "materializes" rather
than fades; and a material that thickens as the glass grows.

---

## Gotchas

- **Key your children.** A child that keeps its type without a key is not seen
  as new — it will neither cross-fade nor be re-measured as a swap.
- **The first frame is measured, not painted.** A content-sized surface needs
  one frame to measure before it knows how big it is, so it is transparent for
  that frame rather than springing up from nothing. Pin both axes and there is
  nothing to measure and no warm-up frame.
- **Bound the constraints.** Under unbounded constraints there is no box to
  anchor inside, so the widget shrinks to the glass and `alignment` stops
  mattering. Put it in a `Stack`, a `SizedBox`, or a `Padding` inside one.
- **The style's shape is the destination's.** Its corner curve and radius are
  what the glass arrives as; the source blob keeps the shape it had. Border,
  light, tint, blur and refraction pass through to the blender untouched.
- **It is a blender.** On Skia/web it needs an ancestor `LiquidGlassView` with
  a `backgroundWidget`, or the two blobs fall back to two separate lenses and
  double-refract where they overlap; on Impeller it works standalone. One
  backdrop read per frame either way.

## Try it

```
flutter run -t lib/experimental/liquid_glass_morph/example.dart
```

---

Not in the package's `lib/` yet — lift the folder in as one unit when it has
earned it. It has no imports from the rest of the example on purpose, right
down to carrying its own private spring.
