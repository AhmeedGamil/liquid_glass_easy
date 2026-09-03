# Vitrine

A shop built on `liquid_glass_easy`. Nine pages, no assets, no network
— every object in the catalogue is drawn from a hue and a silhouette,
so it runs offline and each product arrives in its own colour.

```bash
cd example
flutter run -t lib/vitrine/main.dart
```

## Why it is light

Aurora, next door, is this package over a near-black page with additive
lamps. Vitrine is the other half of the argument: a **light** app, where
almost every decision has to go the other way.

- The tint carries the surface, not the blur. On black, glass reads as a
  darker patch you can see through; on paper there is nothing darker to
  be, so the white tint runs at 35–55% and does most of the work.
- The rim cannot separate on its own, so the chrome has a **shadow**.
  Over a near-black page a lit rim is enough; over bone it is invisible.
- Type on glass is ink, not white — which means the plates under it have
  to stay mid-tone. `PlateTone` measures its own luminance and says
  which, rather than trusting the hue.
- The status bar runs dark glyphs, because the top of every page is
  either paper or a mid-tone plate.

## Two surfaces, and they are not interchangeable

**Paper** is the room: warm, close to white, and separated by hairlines
and nothing else. No cards, no shadows, no glass. A lens over paper has
nothing to bend and reads as a smudge.

**Plates** are the things. Every product is a full field of colour with
a studio disc behind it, a floor, and an object standing on it casting a
shadow. That is where the glass goes.

The composition is not only taste. Each plate lays three hard edges
under the glass on purpose — the disc's rim, the wall/floor horizon, and
the object's own silhouette — because those are the lines you can see
bow when a bar slides over them.

## The lens budget, and how the app lives inside it

Four active lenses is where a mid-range phone starts dropping frames, so
Vitrine is designed around **two**: the app bar and the tab bar. That is
the entire chrome, and it never changes.

Everything else with a glass edge on it is a `LiquidGlassBorder` in
`blend` pickup — the same optical rim the shader lights, drawn from a
triangle mesh, with no fragment shader and **no read of the backdrop**.
Browse puts fourteen of them on one screen. `blend` is what makes that
worth doing: the rim's light is mixed into the plate under it, so the
same `Rim` widget comes out warm on a clay plate and cold on a blue one
without being told which it is on.

Three pages spend a third lens, and each one says why in its header:

| Page | The third lens | Why it earns it |
|---|---|---|
| Search | the search field's lens | a plain `TextField` on glass, so what you type sits on refracted content |
| Account | two `LiquidGlassSwitch`es | each runs its own capture pipeline, which is why there are two and the rest are paper |
| Product | the buy bar | the one surface that lives over *moving* content, which is what a lens is for |

And Checkout spends it on the thing the whole app builds toward: you do
not press a button to pay, you **drag a glass thumb across a plate** and
it refracts the plate as it goes. A `LiquidGlassSlider` used as a
confirm rather than as a value. Under 92% it springs back.

## The pages

| | Page | What it is there to show |
|---|---|---|
| 1 | **Shop** (`pages/shop_page.dart`) | A full-bleed hero the app bar stands on — glass over saturated colour from the first frame |
| 2 | **Browse** (`pages/browse_page.dart`) | Fourteen rims on one screen, for zero backdrop reads |
| 3 | **Search** (`pages/search_page.dart`) | A plain `TextField` on a glass lens, and an empty state that draws a plate for whatever you typed |
| 4 | **Saved** (`pages/saved_page.dart`) | An empty state made of three fanned plates instead of a grey icon |
| 5 | **Bag** (`pages/bag_page.dart`) | A receipt on a plate whose hue is the *average* of what is in the bag |
| 6 | **Product** (`pages/product_page.dart`) | Picking a finish re-lights the room: plate, paper wash and both lenses, off one number |
| 7 | **Collection** (`pages/collection_page.dart`) | A masthead that scrolls out from under the bar — watch the rim change colour as it goes |
| 8 | **Checkout** (`pages/checkout_page.dart`) | Slide-to-pay, on glass, over a plate |
| 9 | **Account** (`pages/account_page.dart`) | Two switches, an order tracker, `showLiquidGlassDialog` |

The first five are tabs of one `LiquidGlassScaffold` in `shell.dart`;
the rest are pushed over it.

## One more rule

**Scrolling content goes in `body`, chrome goes in the named slots.**
The scaffold's `body` is the layer the glass captures. Every plate a
page draws therefore passes *under* the bars and gets bent by them. Put
the content up in `lenses` instead and it paints over the tab bar rather
than sliding beneath it — the product page uses `lenses` for exactly one
thing, the buy bar, which is meant to float.

## Files

- `theme.dart` — the paper, the type, `PlateTone` (a whole colour family
  from one hue), and the three materials: `vitrineGlass()` for lenses,
  `vitrineChrome()` for the bars, `vitrineRim()` for everything else.
- `plate.dart` — the painters. Ten object silhouettes, one light source
  for all of them, and the room the pages stand in.
- `common.dart` — the shared pieces, `Rim`, and the `VitrineTab`
  contract.
- `data.dart` — the catalogue, and the `Bag` every page reads.
