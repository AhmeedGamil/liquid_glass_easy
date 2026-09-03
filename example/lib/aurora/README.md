# Aurora

A small music app built on `liquid_glass_easy`. Eight pages, no assets,
no network — every backdrop and every cover is painted from a seed
string, so it runs offline and each record arrives in its own colour.

```bash
cd example
flutter run -t lib/aurora/main.dart
```

## The pages

| | Page | What it is there to show |
|---|---|---|
| 1 | **Home** (`pages/home_page.dart`) | One hero card of rim on a page of plain frost, rimmed buttons inside it |
| 2 | **Browse** (`pages/browse_page.dart`) | Seven rimmed surfaces on one screen, for zero backdrop reads |
| 3 | **Search** (`pages/search_page.dart`) | A plain `TextField` on a glass lens, where the glass *is* the decoration |
| 4 | **Library** (`pages/library_page.dart`) | A summary card that stays while the list under it changes |
| 5 | **You** (`pages/profile_page.dart`) | `showLiquidGlassDialog` |
| 6 | **Album** (`pages/album_page.dart`) | A second `LiquidGlassScaffold` shape: no tab bar, an extended `LiquidGlassFab` |
| 7 | **Player** (`pages/player_page.dart`) | Two `LiquidGlassSlider`s, `showLiquidGlassSheet` |
| 8 | **Settings** (`pages/settings_page.dart`) | `LiquidGlassSwitch`, and a sheet that is really `showModalBottomSheet` |

The first five are tabs of one `LiquidGlassScaffold` in `shell.dart`; the
last three are pushed over it.

## Two rules the whole app follows

**Scrolling content goes in `body`, chrome goes in `lenses`.** The
scaffold's `body` is the layer the glass captures, and the named slots
(`appBar`, `bottomNavigationBar`, `floatingActionButton`) plus `lenses`
are the overlay above it. Put a page's content in `lenses` instead and
it paints *over* the tab bar rather than sliding under it — with a glass
selection pill the bar owns the whole pipeline and draws beneath those
slots. The same ordering is why the bottom fade band lives in `body`:
there, the bar floats above it and refracts it, instead of it blurring
the bar out of existence.

**Surfaces wear a rim; only chrome and controls are lenses.** Every
card, tile and button in a page's content is a `LiquidGlassBorder` in
`blend` pickup — the same optical rim the shader lights, from a
triangle mesh, with no fragment shader and no read of the backdrop
under it. `blend` is the mode that matters here: the rim's light is
mixed *into* what is behind it, so a card over the violet corner of a
page takes the violet up and one over the teal corner takes the teal,
for a blend mode and nothing else.

A real lens is left to the things that need to bend what moves behind
them — the bars, the mini player, the dialog, the sheets, the search
field's lens, and the two controls (`LiquidGlassSlider`,
`LiquidGlassSwitch`) whose whole behaviour is the glass. Those run
capture pipelines of their own, which is why the player holds exactly
two sliders and settings two switches.

Surfaces have no such budget, and Browse is the page that says so:
seven lit surfaces on one screen, where as lenses that is seven
backdrop reads and the grid would have needed a `LiquidGlassBatch` to
survive. Three weights carry all of it — `GlassPanel` (a fill under a
rim) for cards, `GlassButton` for the buttons on them, and `FrostPanel`
(a fill and a hairline, no rim) for rows and anything that repeats. The
rim is what makes a card read as an object, so spending one on every
list row is how a page stops having a foreground.

## Files

- `theme.dart` — the palettes, `auroraGlass()` for everything that is a
  lens, and `auroraRim()`, which is the same border settings at the
  same numbers for everything that only wears one.
- `backdrop.dart` — the painters: page light, and seeded cover artwork.
  Both lay hard structure (contour rings, a star field, a motif on every
  cover) over the colour, because a lens over a smooth gradient has
  nothing to bend.
- `common.dart` — the shared pieces, and the `AuroraTab` contract.
- `data.dart` — the invented catalogue.
