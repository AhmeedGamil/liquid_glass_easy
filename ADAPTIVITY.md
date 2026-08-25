# Adaptivity

Glass reads as glass by **agreeing with what is behind it**. A pane over a dark photo should be smoked, not milky; the icons on it should be light. Move it over a white page and both have to invert — and Liquid Glass does that for you, by looking at the actual pixels behind each surface.

```dart
LiquidGlassLens(
  style: LiquidGlassStyle(
    adaptivity: LiquidGlassAdaptivity(
      glassColorOnDark: Color(0x33000000),
      contentColorOnDark: Colors.white,
      glassColorOnLight: Color(0x66FFFFFF),
      contentColorOnLight: Color(0xFF1C1C1E),
    ),
  ),
  child: const Icon(Icons.favorite_rounded),   // no colour — it adapts
)
```

Two things flip together: the **glass tint** (overriding `appearance.color` while adaptivity is on) and the **content colour**, installed over the child as an `IconTheme` + `DefaultTextStyle`. Any `Icon` or `Text` that doesn't hardcode a colour follows automatically. Both animate over `duration` on every flip.

---

## The pieces

| Piece | What it is |
|---|---|
| `LiquidGlassAdaptivity` | The config: palettes, thresholds, and where the verdict comes from. Goes on `style.adaptivity`. |
| `LiquidGlassAdaptiveArea` | Samples **one** region and hands that verdict to everything inside it. The group form. |
| `LiquidGlassAdaptivityLink` | A channel. An area **publishes** to it; consumers given the same link **follow** it. |
| `LiquidGlassAdaptivityController` | Pause / resume, plus `adaptOnce()` for event-driven adaptation. |
| `LiquidGlassAdaptiveContent` | Makes bare `Text`/`Icon` — with no glass behind them — adapt like a lens child. |
| `LiquidGlassAdaptiveSampling` | Tuning for the capture that feeds all of it. Lives on `LiquidGlassView.adaptiveSampling`. |
| `LiquidGlassScaffoldAdaptivity` | The scaffold's config: palettes for its chrome, plus the system-bar strips. |
| `LiquidGlassSystemChrome` | Which OS bars a verdict also drives. |
| `LiquidGlassBrightnessFallback` | What to guess when there is nothing to sample. |

---

## Turning sampling on

**Nothing samples pixels unless a view opts in.** A config alone is not enough — it describes what to do with a verdict, not where the verdict comes from.

```dart
LiquidGlassView(
  adaptiveSampling: const LiquidGlassAdaptiveSampling(),   // ← the switch
  ...
)

LiquidGlassScaffold(
  adaptivity: const LiquidGlassScaffoldAdaptivity(myPalettes),  // opens it for you
  ...
)
```

For the scaffold, **`adaptivity` alone decides**. A descendant cannot switch the sampler on: a tab bar carrying its own `style.adaptivity` will *not* start captures. If you leave `LiquidGlassScaffold.adaptivity` null, every surface on the page still resolves a verdict — just not from pixels (see the chain below), and typically that means they all sit on one palette forever, and the OS bars are left alone entirely.

Without a sampler the package prints a one-time warning naming the reason, so a silently-frozen page is diagnosable.

### What it costs

`LiquidGlassAdaptiveSampling` defaults to a deliberately tiny capture:

| Field | Default | Meaning |
|---|---|---|
| `pixelRatio` | `0.05` | A 400 px-wide background becomes a ~20 px sample. |
| `frameLimit` | `8` | Captures per second, self-paced. |
| `minimumRegionSamples` | `8` | Floor on the shortest side of any registered region, so a small lens never decides from three texels. The sampler raises `pixelRatio` if needed. |

One sampler serves every registered client in a view, and each client is asked for its own region on every pass — so a moving or scrolling lens stays accurate for free, and ten adaptive surfaces cost one capture, not ten.

---

## How the verdict is decided

**1. Per pixel — sRGB to relative luminance.** Channels go through the sRGB transfer function *first* (via a lookup table), then the Rec. 709 weights. Applying the weights to raw bytes is the common shortcut and it is wrong for saturated colours.

**2. Luminance to normalized CIE L\*.** This is the step that matters. Luminance is linear in *light*; L\* is linear in *perceived* lightness. Mid-grey `#808080` is luminance **0.216** but L\* **0.53** — thresholding raw luminance at 0.5 would call almost every photograph dark.

**3. Across the region — a plain mean.** Every pixel across every rect a client reports averages into one area-weighted `meanLightness`. A client reporting several rects gets *one* pooled vote, not one per rect.

**4. Temporal smoothing.** An exponential moving average weighted `0.65` to the newest sample — enough to track a scroll without chattering on one odd frame. Bypassed for the first verdict and for `adaptOnce()`, so neither waits for the filter to converge.

**5. The threshold.**

```dart
if (lightness < darkBelow)       → dark
else if (lightness > lightAbove) → light
else                             → hold the current verdict
```

`darkBelow` and `lightAbove` are **two thresholds on that one average**, not a centre and a width:

- `0.60 / 0.60` — the default. No band, just a split at 0.60.
- `0.50 / 0.50` — a strictly neutral split at the perceptual middle.
- `0.45 / 0.55` — a hysteresis band; inside it the current verdict holds, so a background parked near the split cannot strobe.

To **move** the split you move both together. `darkBelow` may never exceed `lightAbove` (it asserts). Comparisons are strict, so a value landing exactly on a threshold holds; when there is no previous verdict to hold, a first sample inside a band picks the side of the band's midpoint.

The default sits above the neutral 0.5 on purpose: over a genuinely mid-grey backdrop the smoked palette carries content better than the milky one, so the 0.5–0.6 range is handed to dark rather than divided.

**6. Two confirming samples.** Even outside the band, *changing* a verdict needs two consecutive agreeing samples; a disagreeing one resets the count. The first verdict and `adaptOnce()` are exempt.

So there are three layers of anti-strobe defence — the EMA, the hysteresis band, and the two-sample persistence — and only the middle one is off by default.

---

## Where a verdict comes from

Resolved in this order, first match wins:

1. **`permanentBrightness`** — a manual verdict. Sampling is switched off entirely for that surface.
2. **A followed `link`** — on a consumer, a link always means *follow it*.
3. **The enclosing `LiquidGlassAdaptiveArea`** — consumers inside an area follow it with no link needed.
4. **Its own sampling** — the surface's own bounds, through the view's sampler.
5. **`initialBrightness`** — the pre-verdict guess, until a real one lands.
6. **`brightnessFallback`** — `appTheme` (default) or `platform`.

Three of those look similar and are not:

- **`permanentBrightness`** is a verdict that never yields, and the only one that stops captures. Use it when you already know what is behind the glass and don't want to pay to rediscover it, or to drive the palette from your own state.
- **`initialBrightness`** is a *guess*. It holds only until sampling produces something, then yields. A matching guess means nothing moves on entry; a wrong one animates into the truth. Leave it null and the fallback fills the same role.
- **`brightnessFallback`** is the bottom of the chain — what a surface uses when it cannot read pixels at all. `LiquidGlassBrightnessFallback.appTheme` (the default) reads `Theme.of(context).brightness`; `.platform` reads `MediaQuery.platformBrightness`, the OS setting, which `MaterialApp.themeMode` does **not** affect.

> **Outside a `MaterialApp`, use `.platform`.** `Theme` has no `maybeOf`, so with no `Theme` ancestor `Theme.of` silently returns Flutter's fallback theme and `appTheme` reads light instead of following the device.

Separately, `LiquidGlassAdaptivity.none` opts a surface **out entirely** — it keeps its plain `appearance.color` and no palette is installed, even inside an area. That is different from pinning: `permanentBrightness` still uses the palettes, just on one side.

---

## `LiquidGlassAdaptiveArea` — one verdict, shared

Per-surface verdicts are right until two surfaces sit over different pixels and must still agree — a header and a footer, a bar and a floating button. An area samples **one** region and hands that verdict to its whole subtree.

```dart
LiquidGlassAdaptiveArea(
  adaptivity: myPalettes,
  child: MyHeader(),      // every lens inside follows — no link
)
```

| Parameter | What it does |
|---|---|
| `adaptivity` | The config the area samples with and shares. |
| `systemChrome` | Also drive the OS status / navigation bar icons from this verdict. |
| `debugBounds` | Outline the sampled region, so it is obvious which pixels decided. |

A surface inside the area can still override — its own `style.adaptivity` wins, and `LiquidGlassAdaptivity.none` escapes.

### Links — for followers that cannot sit inside

Some followers can't be in the subtree: a different branch of the tree, or a component with its own render pipeline (`LiquidGlassTabBar` in glass-pill mode). Give the area a link and hand the same link to them.

```dart
final link = LiquidGlassAdaptivityLink();

LiquidGlassAdaptiveArea(                              // PUBLISHER
  adaptivity: myPalettes.copyWith(link: link),
  child: MyHeader(),
)

LiquidGlassLens(                                      // FOLLOWER
  style: LiquidGlassStyle(
    adaptivity: myPalettes.copyWith(link: link),
  ),
  ...
)
```

**On an area a link means publish; on a consumer it means follow.** Use one publisher per link. A follower never samples — it mirrors, flipping on the same frame. Give publisher and followers the same `duration` and the transitions run in lockstep.

The link is a plain `ValueNotifier<Brightness?>`, so your app can read it — or drive a whole group by setting `value` itself. It also carries a `lightness` notifier, which followers running `continuousGlassColor` glide from.

An area given **no** link still works; it mints a private one for its own subtree.

> Runnable version: `example/lib/adaptivity_advanced_page.dart` (over a real
> feed).

---

## `LiquidGlassAdaptivityController` — hold, and adapt on cue

Sampling every frame of a fling is wasted work, and palettes flipping mid-scroll can look busy. A controller pauses the whole group and lets you take a single look on your own cue.

```dart
final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);

// …palettes hold, sampling stops…

NotificationListener<ScrollEndNotification>(
  onNotification: (_) { adaptCtrl.adaptOnce(); return false; },
  child: myFeed,
)
```

`adaptOnce()` gives every widget holding the controller exactly one look — it samples, animates to the result, and freezes again; `enabled` stays false throughout. `enable()` / `disable()` toggle continuous adaptation.

> Runnable version: `example/lib/adaptivity_controller_page.dart`, which fires `adaptOnce()` when scroll *speed* decays rather than on finger-up.

---

## `LiquidGlassAdaptiveContent` — for content with no glass

A lens installs the adaptive content colour for its own child. Text sitting directly on the page — a hero title over a photo, a floating caption — has no lens to inherit from. This closes that gap:

```dart
LiquidGlassAdaptiveContent(
  child: Text('Adaptivity'),   // no colour set — it adapts
)
```

With `adaptivity` null it inherits the enclosing area's config entirely. It also takes a `builder` — `(context, color, brightness)` — for content that ignores `IconTheme`/`DefaultTextStyle`, like an `SvgPicture` or a `CustomPaint`.

---

## The scaffold

`LiquidGlassScaffoldAdaptivity` does two independent jobs.

**Chrome palettes.** `adaptivity` is handed down to the app bar, bottom bar, action button and any `lenses`, each of which resolves its **own** verdict from the background directly behind itself. One config, one verdict per surface. The config's own `link` is deliberately never inherited — otherwise every surface would follow it by accident.

**System bars.** For each side `systemChrome` names, the scaffold pins an invisible strip along that screen edge, samples it, and drives that bar's icon brightness from the result. A strip judges nothing but its own system bar. It defaults to `statusBar` — the bar the glass chrome sits under on every screen — so an adaptive scaffold drives it without being asked; pass `LiquidGlassSystemChrome.none` to leave the OS bars alone.

```dart
LiquidGlassScaffold(
  adaptivity: const LiquidGlassScaffoldAdaptivity(
    myPalettes,
    systemChrome: LiquidGlassSystemChrome.both,   // statusBar by default
  ),
  ...
)
```

Because it lives on the config, a scaffold with no `adaptivity` never touches the system bars: a strip is only worth pinning where there are pixels to judge it from.

| Field | Default | What it does |
|---|---|---|
| `adaptivity` | — | Palettes for the chrome and the strips. **Also the sampler switch.** |
| `systemChrome` | `statusBar` | Which OS bars this scaffold's strips drive. `none` pins nothing. |
| `sampling` | standard | Capture tuning for the whole view. |
| `topFollowLink` / `bottomFollowLink` | `null` | Make a strip **stop sampling** and mirror an area's link instead. |
| `topHeight` / `bottomHeight` | safe-area inset | How tall a band the bar is judged from. Ignored while following. |
| `debugBounds` | `false` | Outline each pinned strip. |

Note the direction: a strip never captures the chrome. The app bar is judged by the pixels behind the app bar, not by the status bar's strip. To couple them, publish from an area and point the strip at that link with `topFollowLink` — useful when the status bar should track your header rather than the thin band behind itself.

`LiquidGlassSystemChrome` only ever sets **icon brightness** (plus iOS's `statusBarBrightness`); bar colours are never touched. With `none` — the default — no `AnnotatedRegion` exists in the tree at all.

---

## `LiquidGlassGroup` — many lenses, one surface

Not adaptivity, but it belongs next to it: the group is how you keep many adaptive lenses affordable.

Every lens is its own glass pass and its own backdrop read. A group draws every `LiquidGlassLens` beneath it as **one** sheet — one read and one material for the whole set, however many members.

```dart
LiquidGlassGroup(
  style: const LiquidGlassStyle(),
  child: Column(children: [ ...lenses... ]),
)
```

Members keep their own layout, shape and child. What they give up is the individual glass pass.

**Two to eight members** (`minLensCount` / `maxLensCount`). Place the group inside a `LiquidGlassView` for the Skia / web capture path; on Impeller it reads the live backdrop.

### `smoothness` — whether they also fuse

Defaults to **`null`: they do not.** The group is still one surface and one read, but each member keeps its own hard outline, and the shader skips the smooth-union entirely rather than running it and finding nothing to blend. That is the right default for members laid out apart — a row of buttons, a column of pills — which should not pay for a bridge that never forms.

Give it a radius and members that come within roughly `smoothness / 2` flow together through a metaball bridge, their tints crossing over inside it.

> Prefer `null` over a tiny radius. A near-zero radius gets the outline right but leaves the influence weights as a 0/1 indicator, so two *overlapping* members weigh the same and their colours average with a hard step at each outline. `null` resolves that tie by distance instead.

### Adaptivity in a group is per member

Each lens judges the background behind **itself** and paints its own verdict into the shared sheet; where two fuse, their colours cross over inside the bridge on the same falloff that shapes it. A member that is not adaptive takes the group's colour. Put `adaptivity` on the group's own `style` and it supplies both the fallback colour and the content palette for the subtree.

---

## Recipes

**Every surface judges itself** — the default. Set `adaptivity` on the scaffold (or each style) and nothing else.

**Two surfaces must agree, same subtree** — wrap them in a `LiquidGlassAdaptiveArea`.

**Two surfaces must agree, different subtrees or pipelines** — area with a `link`, same link on the followers.

**The OS bars should follow the glass** — on by default for the status bar; name the sides with `systemChrome` on the scaffold's config, and add `topFollowLink` to lock a bar to a specific area.

**Don't adapt during motion** — a shared `LiquidGlassAdaptivityController(enabled: false)` plus `adaptOnce()` when things settle.

**You already know the backdrop** — `permanentBrightness`. No captures at all.

**Bare text over a photo** — `LiquidGlassAdaptiveContent`.

**Many small adaptive lenses** — put them in a `LiquidGlassGroup`.

---

## Gotchas

- **No sampler, no pixels.** `LiquidGlassScaffold.adaptivity` (or `LiquidGlassView.adaptiveSampling`) is the only thing that starts captures. A descendant's own config cannot.
- **`initialBrightness` outranks the fallback.** Set it, and a surface that cannot sample sits on your guess forever rather than following the app theme.
- **The threshold pair is (low, high), not (centre, width).** Setting only `darkBelow` higher than `lightAbove` asserts.
- **The verdict is a *mean*.** It cannot tell uniformly mid-grey from half-black-half-blown-out; both land near the middle, which is exactly where the decision is least stable. Widen the band for content like that.
- **A link on a consumer means follow, not publish.** Only a `LiquidGlassAdaptiveArea` publishes.
- **Outside a `MaterialApp`,** set `brightnessFallback: LiquidGlassBrightnessFallback.platform`.
