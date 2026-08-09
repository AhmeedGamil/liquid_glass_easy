import 'doc_model.dart';

/// Every documentation page, in reading order.
///
/// The order here is the order in the sidebar and the order the prev/next
/// links follow, so there is no second list to keep in sync.
const List<DocPage> kDocs = [
  _start,
  _engines,
  _lens,
  _touch,
  _blend,
  _components,
  // One page per component, each with that component's own live demo. They
  // sit under `components` in the sidebar and in reading order here.
  _slider,
  _toggle,
  _button,
  _appBar,
  _tabBar,
  _navBar,
  _scaffold,
  _jelly,
  _draggable,
  _performance,
];

/// The page with [id], or null when the URL names something unknown.
DocPage? docById(String? id) {
  if (id == null) return null;
  for (final p in kDocs) {
    if (p.id == id) return p;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────
// 1 · Getting started
// ─────────────────────────────────────────────────────────────────────

const _start = DocPage(
  id: 'start',
  title: 'Getting started',
  tagline: 'Install it, and get one lens on screen.',
  blocks: [
    Prose(
      "Liquid Glass Easy brings Apple's **Liquid Glass** — the material "
      "behind iOS 26 and iOS 27 — to Flutter: a shader lens that refracts, "
      "magnifies, tints and bends whatever is behind it, and answers touch "
      "like a soft body. Not a blur with a white overlay — the content "
      "underneath actually bends.",
    ),
    Prose(
      "There is one widget you need, `LiquidGlassLens`. Everything else on "
      "this site is either a way to style it, a way to make it respond, or a "
      "ready-made control with it already wired in.",
    ),
    Heading('Install'),
    Code(
      'dependencies:\n'
      '  liquid_glass_easy: ^3.5.0',
      caption: 'pubspec.yaml',
    ),
    Code('flutter pub get'),
    Code("import 'package:liquid_glass_easy/liquid_glass_easy.dart';"),
    Heading('A lens, anywhere'),
    Prose(
      "On Impeller — Flutter's default renderer on modern iOS and Android — "
      "a lens needs no setup at all. Drop it over your UI and it refracts "
      "whatever your app already painted behind it.",
    ),
    Code('''Stack(
  fit: StackFit.expand,
  children: [
    Image.asset('assets/bg.jpg', fit: BoxFit.cover),
    Center(
      child: SizedBox(
        width: 260,
        height: 150,
        child: LiquidGlassLens(
          style: const LiquidGlassStyle(
            shape: LiquidGlassShape.squircle(cornerRadius: 44),
            refraction: LiquidGlassRefraction(
              distortion: 0.13,
              distortionWidth: 34,
            ),
          ),
          child: const Center(child: Text('Liquid Glass')),
        ),
      ),
    ),
  ],
)'''),
    Prose(
      "The lens takes its size from layout, so give it one — a `SizedBox`, a "
      "`Positioned`, or a child with an intrinsic size. The child is always "
      "clipped to the glass shape; add your own `Padding` to inset it.",
    ),
    Heading('The same lens on Skia and the web'),
    Prose(
      "Skia has no live-backdrop shader, so the lens has nothing to read "
      "unless you hand it something. Wrap your content in a "
      "`LiquidGlassView` and give it a `backgroundWidget` — the view captures "
      "that background, and every lens inside its `child` refracts the "
      "capture.",
    ),
    Code('''LiquidGlassView(
  backgroundWidget: const MyBackground(),
  child: Center(
    child: SizedBox(
      width: 300,
      height: 160,
      child: LiquidGlassLens(
        style: const LiquidGlassStyle(
          shape: LiquidGlassShape.squircle(cornerRadius: 40),
        ),
        child: const Center(child: Text('refracts the capture')),
      ),
    ),
  ),
)'''),
    Prose(
      "That same tree is safe to ship on Impeller, and it is the reason you "
      "only write one. The view detects the engine itself — no flag, no "
      "`if (Platform...)` — and on Impeller it takes **no captures at all**: "
      "the `backgroundWidget` simply paints where it always would, and the "
      "lenses inside `child` go straight to the Impeller backdrop pipeline "
      "and refract the live pixels behind them. The capture path exists only "
      "on the engine that has no other option.",
    ),
    Note(
      "The lens code is identical in both samples. You never branch on the "
      "engine — the lens resolves the path for the one it is running on. The "
      "view is the only thing you add for Skia, and it costs Impeller "
      "nothing.",
      kind: NoteKind.tip,
    ),
    Heading('Without a view on Skia'),
    Prose(
      "Nothing breaks. A lens with no background to refract degrades to a "
      "frosted surface — backdrop blur, tint and rim — and logs a one-time "
      "debug notice telling you which lens it was. You get a plausible glass "
      "panel instead of an empty rectangle.",
    ),
    TryIt('touch', label: 'See a lens running'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 2 · Engines and the view
// ─────────────────────────────────────────────────────────────────────

const _engines = DocPage(
  id: 'engines',
  title: 'Engines and the view',
  tagline: 'Impeller reads the backdrop. Skia needs a capture. Same widgets.',
  blocks: [
    Prose(
      "Refraction needs the pixels behind the glass. Impeller can hand a "
      "shader the live backdrop; Skia cannot. That single difference is the "
      "whole story, and `LiquidGlassView` is the answer to it.",
    ),
    DocTable(
      headers: ['Setup', 'What the lens does'],
      flex: [4, 6],
      rows: [
        [
          '**Impeller** — iOS/Android default',
          'Refracts the **live backdrop**: whatever your app painted behind '
              'it. No view, no background widget, no setup.',
        ],
        [
          '**Skia** inside a `LiquidGlassView`',
          'Refracts the view’s **captured** `backgroundWidget`, wherever '
              'the lens sits inside the view’s `child`.',
        ],
        [
          '**Skia** with no view',
          'Degrades to a **frosted** surface — blur, tint, rim — and logs a '
              'one-time debug notice.',
        ],
      ],
    ),
    Note(
      "The web is always Skia. CanvasKit and the HTML renderer both lack the "
      "backdrop shader, so every web page that wants real refraction needs a "
      "`LiquidGlassView`. Every demo on this site is inside one.",
    ),
    Heading('LiquidGlassView'),
    Code('''LiquidGlassView({
  required Widget backgroundWidget,   // what gets captured
  Widget? child,                      // your UI, containing the lenses
  LiquidGlassViewController? controller,
  double pixelRatio = 1.0,
  bool realTimeCapture = true,
  bool useSync = true,
  LiquidGlassRefreshRate refreshRate =
      LiquidGlassRefreshRate.deviceRefreshRate,
  bool? useImpellerBackdrop,
})'''),
    DocTable(
      headers: ['Parameter', 'Default', 'What it controls'],
      flex: [3, 2, 6],
      rows: [
        [
          '`backgroundWidget`',
          '—',
          'The layer being captured. Lenses refract this, not the `child`.',
        ],
        [
          '`child`',
          '`null`',
          'Your UI. Anything here can hold a lens, at any depth.',
        ],
        [
          '`pixelRatio`',
          '`1.0`',
          'Resolution of the capture. Below `1` is cheaper and softer; the '
              'glass hides a surprising amount of it.',
        ],
        [
          '`realTimeCapture`',
          '`true`',
          'Re-capture every frame. Turn it **off** for a background that does '
              'not move.',
        ],
        [
          '`useSync`',
          '`true`',
          'Keeps the capture in step with the frame being built. Off is '
              'cheaper and can lag by a frame.',
        ],
        [
          '`refreshRate`',
          '`deviceRefreshRate`',
          'Caps how often the capture runs, independent of the display.',
        ],
        [
          '`useImpellerBackdrop`',
          '`null`',
          'Overrides engine auto-detection. Leave it null unless you are '
              'testing the other path on purpose.',
        ],
      ],
    ),
    Heading('Capture once, or every frame'),
    Prose(
      "`realTimeCapture: true` rasterizes the background every frame. That is "
      "right for a scrolling feed, a video, an animating gradient — anything "
      "genuinely moving. It is pure waste for a background that never "
      "changes.",
    ),
    Prose(
      "When the background is static, take **one** snapshot and refract it "
      "forever. Moving a lens over a fixed image costs nothing extra: the "
      "shader re-runs, but nothing re-rasterizes.",
    ),
    Code('''final controller = LiquidGlassViewController();

LiquidGlassView(
  controller: controller,
  backgroundWidget: const MyBackground(),
  realTimeCapture: false,
  child: const MyGlassUI(),
);

// Re-snapshot by hand after the background actually changes:
await controller.captureOnce();'''),
    Prose(
      "This page's demo counts its snapshots. Drag the lens as long as you "
      "like and the count stays at **one** — only the shader re-runs. Swap "
      "the palette and you can see the other half of the bargain: the page "
      "repaints at once while the glass keeps bending the old capture, until "
      "`captureOnce()` settles it.",
    ),
    Prose(
      "Live capture is for a background that genuinely moves — a scrolling "
      "feed under a floating bar, a video, an animating gradient. Anything "
      "painted and deterministic wants one snapshot instead.",
    ),
    Note(
      "On Impeller none of this applies — the lens reads the backdrop "
      "directly and no capture exists to configure. Capture settings are a "
      "Skia concern only.",
    ),
    Heading('Recommended settings'),
    Bullets([
      '**General:** `useSync: true`, `pixelRatio: 0.8`–`1.0`.',
      '**Performance-first:** `useSync: false`, `pixelRatio: 0.5`–`0.7`.',
      '**Static background:** `realTimeCapture: false` beats every other '
          'tuning knob combined.',
    ]),
    TryIt('capture', label: 'One snapshot, dragged over'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 3 · The lens and its style
// ─────────────────────────────────────────────────────────────────────

const _lens = DocPage(
  id: 'lens',
  title: 'The lens and its style',
  tagline: 'One widget, one style object: shape, appearance, refraction.',
  blocks: [
    Code('''LiquidGlassLens({
  LiquidGlassStyle style = const LiquidGlassStyle(),
  bool visibility = true,
  LiquidGlassTouch? touch,
  bool? useImpellerBackdrop,
  Widget? child,
})'''),
    Prose(
      "Size comes from layout, never from the lens. The `child` is clipped to "
      "the glass shape. `visibility: false` switches the glass off instantly "
      "— no backdrop cost, no child — so it is the cheap way to hide a lens "
      "you will show again.",
    ),
    Heading('LiquidGlassStyle'),
    Prose(
      "Everything about how a lens looks lives in one object, so a look "
      "travels as a single value. `copyWith(...)` and `merge(other)` are "
      "there for theme and override patterns.",
    ),
    Code('''LiquidGlassStyle({
  LiquidGlassShape? shape,          // null → continuous rounded rect
  LiquidGlassAppearance appearance = const LiquidGlassAppearance(),
  LiquidGlassRefraction refraction = const LiquidGlassRefraction(),
})'''),
    Heading('Shape'),
    DocTable(
      headers: ['Constructor', 'Corner curve'],
      flex: [5, 5],
      rows: [
        [
          '`LiquidGlassShape.roundedRectangle(...)`',
          'Plain **circular** corners. The cheapest to clip.',
        ],
        [
          '`LiquidGlassShape.squircle(...)`',
          '**Lⁿ squircle** — iOS-style continuous curvature.',
        ],
        [
          '`LiquidGlassShape.continuousRoundedRectangle(...)`',
          '**Apple capsule-style** continuous corners. The **default**; '
              'collapses to a clean capsule at full radius.',
        ],
      ],
    ),
    Prose(
      "All three share `cornerRadius`, `borderWidth`, `borderColor`, "
      "`lightColor`, `lightIntensity`, `lightDirection`, `borderType` and "
      "`clipQuality`.",
    ),
    Note(
      "**Picking `clipQuality`.** For `squircle` it is worth setting "
      "`LiquidGlassClipQuality.exact` — the squircle has a shader-matched "
      "`ClipPath`, so the child and blur silhouette follow the true curve. "
      "For `continuousRoundedRectangle` leave it at the default: a "
      "rounded-rect clip already hugs the continuous corner so closely that "
      "`exact` only buys you an extra save layer.",
      kind: NoteKind.tip,
    ),
    Heading('Appearance'),
    DocTable(
      headers: ['Property', 'Default', 'What it does'],
      flex: [4, 3, 6],
      rows: [
        [
          '`color`',
          '`transparent`',
          'Base tint. Usually a low-alpha white or black.',
        ],
        [
          '`blur`',
          '`LiquidGlassBlur()`',
          'Blur applied to what shows through the glass.',
        ],
        [
          '`saturation`',
          '`1.0`',
          '`1.0` unchanged, `0.0` grayscale, above `1` more vivid.',
        ],
        [
          '`enableInnerRadiusTransparent`',
          '`false`',
          'Makes the inner, undistorted region fully transparent.',
        ],
      ],
    ),
    Heading('Refraction'),
    DocTable(
      headers: ['Property', 'Default', 'What it does'],
      flex: [4, 3, 6],
      rows: [
        [
          '`distortion`',
          '`0.1`',
          'How hard the edge band bends content, `0.0`–`1.0`.',
        ],
        [
          '`distortionWidth`',
          '`30`',
          'Thickness of that band around the perimeter, in px.',
        ],
        [
          '`magnification`',
          '`1.0`',
          'Zoom of what is seen through the glass. `1.0` is none.',
        ],
        [
          '`chromaticAberration`',
          '`0.003`',
          'Colour-channel separation at the rim. `0.0` disables it.',
        ],
        [
          '`refractionMode`',
          '`shapeRefraction`',
          '`shapeRefraction` follows the outline; `radialRefraction` bends in '
              'a circular pattern.',
        ],
        [
          '`refractionType`',
          '`null`',
          'Swap the model itself — e.g. `OpticalRefraction(refraction:, '
              'refractionWidth:, depth:)` for a thickness-based lens.',
        ],
      ],
    ),
    Heading('Borders'),
    Prose(
      "The rim is part of the shape, set through `borderType`. There are two "
      "models and they are genuinely different ideas, not two presets.",
    ),
    DocTable(
      headers: ['Mode', 'What it is'],
      flex: [3, 7],
      rows: [
        [
          '`OpticalBorder`',
          '**Default.** An SDF rim light that falls out of the glass shape: '
              'background-tinted highlights, dual-sided speculars, a height '
              'profile. The rim colour adapts to whatever is behind the lens.',
        ],
        [
          '`ClassicBorder`',
          'Light and shadow sweep the outline by the angle between surface '
              'normal and light direction. Stylized, and you control the '
              'colours directly.',
        ],
      ],
    ),
    Code('''// Optical: borderSaturation, ambientIntensity, borderSolidity
shape: LiquidGlassShape.squircle(
  cornerRadius: 36,
  borderType: OpticalBorder(
    borderSaturation: 1.5,
    ambientIntensity: 1.0,
    borderSolidity: 0.0,
  ),
)

// Classic: borderSoftness, shadowColor
shape: LiquidGlassShape.roundedRectangle(
  lightColor: Color(0xB2FFFFFF),
  borderType: ClassicBorder(
    borderSoftness: 2.5,
    shadowColor: Color(0x1A000000),
  ),
)'''),
    TryIt('blend', label: 'Three shapes, one style'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 4 · Touch
// ─────────────────────────────────────────────────────────────────────

const _touch = DocPage(
  id: 'touch',
  title: 'Touch',
  tagline: 'Glass that answers a finger — and never moves.',
  blocks: [
    Prose(
      "Pass a `touch:` and the lens becomes a soft body. Press it and it "
      "swells under your finger; drag it and it elongates along the pull, "
      "pinches in the cross axis, leans after your thumb, then springs back "
      "with a wobble.",
    ),
    Prose(
      "The lens never *moves*. Its footprint in layout is unchanged, so "
      "nothing around it shifts and no parent relayouts — only its shape and "
      "its content deform.",
    ),
    Code('''LiquidGlassLens(
  touch: const LiquidGlassTouch(
    flex: LiquidGlassFlex(),
  ),
  style: const LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 26),
  ),
  child: myContent,
)'''),
    Prose(
      "`LiquidGlassTouch` is a **group**, not a single effect: it carries the "
      "whole response a surface has to a finger, the way `LiquidGlassStyle` "
      "carries its whole look. Today it holds `flex`. Anything that lands "
      "later lands as a field on the group, not as a new parameter on every "
      "component that accepts touch.",
    ),
    Note(
      "`touch` defaults to `null`, and null adds **nothing** to the tree — no "
      "listener, no ticker, no cost. You opt into the machinery by asking for "
      "it.",
    ),
    Heading('Four independent edges'),
    Prose(
      "A scale transform can only grow symmetrically around one anchor. This "
      "moves left, right, top and bottom **independently**, so the half "
      "nearest your finger deforms more than the far half — the asymmetry is "
      "what reads as soft.",
    ),
    Prose(
      "Volume is preserved rather than gained: whatever the pull axis gains, "
      "the cross axis gives back, so an elongated lens genuinely gets "
      "thinner.",
    ),
    Heading('LiquidGlassFlex'),
    DocTable(
      headers: ['Knob', 'Default', 'What it does'],
      flex: [3, 2, 6],
      rows: [
        [
          '`stretch`',
          '`13`',
          'Peak elongation along the pull, in px, reached as the drag '
              'saturates at `maxPull`.',
        ],
        [
          '`squeeze`',
          '`0.70`',
          'How much of the along-axis gain comes back out of the cross axis. '
              '`1` preserves area exactly, `0` just grows.',
        ],
        [
          '`lean`',
          '`0.50`',
          'How far the whole body slides after the finger, as a fraction of '
              '`stretch`. The "it is attached to my thumb" cue.',
        ],
        [
          '`grip`',
          '`0.70`',
          'How local the deformation is. `0` — every edge shares it equally '
              'wherever you touched. `1` — the near edges take all of it.',
        ],
        [
          '`compressInward`',
          '`true`',
          'Pushing an edge *into* the body squashes it. `false` restores the '
              'older behaviour where any pull grew the shape.',
        ],
        [
          '`holdScale`',
          '`0.030`',
          'Signed size change **while the finger is down**, as a fraction of '
              'the lens. Positive swells, negative yields inward.',
        ],
        [
          '`tapScale`',
          '`0.020`',
          'One-shot pop fired when a tap *completes*, so a quick click still '
              'reads as a click.',
        ],
        [
          '`maxPull`',
          '`48`',
          'Drag distance in px at which the deformation saturates.',
        ],
        [
          '`lockAxis`',
          '`null`',
          'Constrain deformation to `Axis.horizontal` or `Axis.vertical`.',
        ],
        [
          '`advanced`',
          '`LiquidGlassFlexAdvanced()`',
          'The set-once knobs. See below.',
        ],
      ],
    ),
    Heading('Presets'),
    Prose(
      "Three tuned starting points ship alongside the default. The only "
      "honest way to choose is to feel them against each other on the same "
      "surface.",
    ),
    Code('''LiquidGlassFlex()             // the default
LiquidGlassFlex.subtle()      // barely there
LiquidGlassFlex.pronounced()  // loose and rubbery
LiquidGlassFlex.uniform()     // ignores where you grabbed it'''),
    Heading('LiquidGlassFlexAdvanced'),
    Prose(
      "Five things you set once and forget. They live behind `advanced` so "
      "they stay out of the way without being out of reach.",
    ),
    DocTable(
      headers: ['Knob', 'Default', 'What it does'],
      flex: [4, 2, 6],
      rows: [
        [
          '`childFollow`',
          '`1`',
          'How much the child rides the deformation. `1` carries it fully, '
              '`0` leaves the content rigid inside moving glass.',
        ],
        [
          '`refractionBoost`',
          '`0.15`',
          'Extra refraction while pressed — what makes it read as glass being '
              'compressed rather than rubber.',
        ],
        [
          '`magnificationBoost`',
          '`0`',
          'Extra magnification while pressed.',
        ],
        ['`stiffness`', '`320`', 'Spring constant of the edges.'],
        ['`damping`', '`24`', 'Damping while the finger is down.'],
        [
          '`releaseDamping`',
          '`17`',
          'Damping after release — lower than `damping`, which is where the '
              'wobble comes from.',
        ],
      ],
    ),
    Heading('Multiple fingers'),
    Prose(
      "A lens is owned by the finger that grabbed it. A second pointer "
      "landing on the same lens is ignored until the first lifts, so two "
      "thumbs on two lenses each drive their own, and two thumbs on one lens "
      "do not fight over it.",
    ),
    Note(
      "The gesture listener is translucent: it never joins the arena, so taps "
      "and drags still reach the widgets inside your lens. A deforming card "
      "can hold real buttons.",
    ),
    TryIt('touch', label: 'Press and drag it'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 5 · Blend
// ─────────────────────────────────────────────────────────────────────

const _blend = DocPage(
  id: 'blend',
  title: 'Blend',
  tagline: 'Two to six lenses, fused into one liquid surface.',
  blocks: [
    Prose(
      "Wrap lenses in a `LiquidGlassBlender` and their silhouettes merge. As "
      "two neighbours approach, a smooth metaball bridge grows between them; "
      "pull them apart and it snaps. Each member keeps its own corner style "
      "through the merge — a circle stays a circle, a squircle stays a "
      "squircle — while the **group** owns the material: one style, one rim, "
      "one piece of glass.",
    ),
    Code('''LiquidGlassView(
  backgroundWidget: myBackground,
  child: LiquidGlassBlender(
    smoothness: 56,
    style: const LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 36,
      ),
    ),
    child: Stack(
      children: const [
        Positioned(
          left: 40,
          top: 80,
          child: SizedBox(
            width: 120,
            height: 120,
            child: LiquidGlassLens(),
          ),
        ),
        Positioned(
          left: 120,
          top: 110,
          child: SizedBox(
            width: 100,
            height: 100,
            child: LiquidGlassLens(),
          ),
        ),
      ],
    ),
  ),
)'''),
    DocTable(
      headers: ['Parameter', 'Default', 'What it does'],
      flex: [3, 2, 6],
      rows: [
        [
          '`child`',
          '—',
          'The subtree holding the member lenses. They can be at any depth.',
        ],
        [
          '`style`',
          '`LiquidGlassStyle()`',
          'The look of the merged surface. The group is one piece of glass, '
              'so it has one style.',
        ],
        [
          '`smoothness`',
          '`48`',
          'How eagerly neighbours fuse — the headline knob. Low keeps shapes '
              'distinct until they nearly touch; high grows a bridge from '
              'further away.',
        ],
        [
          '`useEngineBlur`',
          '`true`',
          'Let the engine blur the merged surface instead of the shader.',
        ],
      ],
    ),
    Prose(
      "Members are found by walking the subtree, so the lenses do not need to "
      "be direct children. Anything that is not a `LiquidGlassLens` — the "
      "controls in the demo, for instance — simply is not a member and never "
      "joins the merge.",
    ),
    Heading('The rim is the evidence'),
    Prose(
      "The group's `style.shape.borderWidth` draws one outline around the "
      "**merged** silhouette, not around each member. That single unbroken "
      "line running around two bodies and the bridge between them is what "
      "makes the fusion legible; set it to `0` and the rim is suppressed "
      "outright rather than drawn as a hairline. Turn it off in the demo and "
      "the union is still there in the refraction — just much harder to read.",
    ),
    Heading('Where a blend can run'),
    Prose(
      "This is the same rule the whole package follows, and blending is the "
      "strictest case of it: the merged surface is a shader that samples the "
      "pixels behind the group, so it can only exist where those pixels can "
      "be reached.",
    ),
    DocTable(
      headers: ['Where the blender sits', 'What happens'],
      flex: [4, 6],
      rows: [
        [
          'Inside a `LiquidGlassView` — **anywhere**: iOS, Android, web, '
              'desktop',
          'Works, and you write it once. The view resolves the engine for '
              'you: on Impeller the members read the **live backdrop** and no '
              'capture is taken at all; on Skia they refract the view\'s '
              '**captured** `backgroundWidget`. Same widget tree, no branch.',
        ],
        [
          'No view, on **Impeller**',
          'Works. The live backdrop is always available there, so the group '
              'fuses over whatever your app painted behind it.',
        ],
        [
          'No view, on **Skia / web**',
          'There is nothing to sample, so **the merge cannot happen**. Each '
              'member degrades to its own frosted glass — blur, tint, rim — '
              'and they stop fusing. A one-time debug notice says so.',
        ],
      ],
    ),
    Note(
      "The web is always Skia. If a page is meant to blend in a browser, the "
      "blender has to be inside a `LiquidGlassView` with a `backgroundWidget` "
      "— that is not a tuning choice, it is the difference between a merged "
      "surface and two frosted blobs.",
      kind: NoteKind.warn,
    ),
    Prose(
      "The shader itself also differs per engine, and that is handled for "
      "you: Impeller loads a derivative-based one-tap gradient, Skia loads a "
      "five-tap variant with no `dFdx` in it, because Skia cannot compile the "
      "first. Flipping backend reloads the right program.",
    ),
    Note(
      "**Blur on the Skia capture path costs.** Large lenses with large blur "
      "are the expensive case, and blur above roughly `7` stops matching the "
      "look of a real backdrop blur. It is deliberately not clamped, so you "
      "can push it — just expect it to diverge from the Impeller look. The "
      "demo runs with no blur at all: clear glass shows the bend, and the "
      "bend is the point.",
      kind: NoteKind.warn,
    ),
    TryIt('blend', label: 'Two shapes, one surface'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6 · Components
// ─────────────────────────────────────────────────────────────────────

const _components = DocPage(
  id: 'components',
  title: 'Components',
  tagline: 'Drop-in controls with the blocks already wired.',
  blocks: [
    Prose(
      "Each component is a lens with a style, a touch response and — where it "
      "needs one — a view already assembled. They take the same "
      "`LiquidGlassStyle` vocabulary, so a component and a hand-built lens "
      "can be given the same look.",
    ),
    Heading('One page each'),
    Prose(
      "Every component has its own page, with its own running example on it:",
    ),
    Bullets([
      '[Slider](slider.html) — `LiquidGlassSlider`, self-contained.',
      '[Toggle](toggle.html) — `LiquidGlassToggle`, self-contained.',
      '[Button](button.html) — `LiquidGlassButton`, a lens that answers a '
          'press.',
      '[App bar](appbar.html) — `LiquidGlassAppBar`, floating over your page.',
      '[Tab bar](tabbar.html) — `LiquidGlassTabBar`, tabs without a scaffold.',
      '[Bottom nav bar](navbar.html) — `LiquidGlassBottomNavBar`, and the '
          'glass morph pill.',
      '[Scaffold](scaffold.html) — `LiquidGlassScaffold`, the page that '
          'captures itself.',
      '[Jelly](jelly.html) — `LiquidGlassJelly`, the spring the controls are '
          'built on.',
      '[Draggable](draggable.html) — `LiquidGlassDraggable`, drag wiring for '
          'anything.',
    ]),
    Heading('What each one needs'),
    Prose(
      "On Impeller everything refracts the live backdrop and works anywhere "
      "with no setup. The difference shows on Skia: some refract your **app** "
      "content and so need an ancestor view, while others supply their own "
      "background and work anywhere on both engines.",
    ),
    DocTable(
      headers: ['Component', 'Skia requirement'],
      flex: [4, 6],
      rows: [
        [
          '`LiquidGlassSlider`',
          '**None.** Self-contained — it owns its background and refracts its '
              'own track.',
        ],
        [
          '`LiquidGlassToggle`',
          '**None.** Self-contained, same as the slider.',
        ],
        [
          '`LiquidGlassScaffold`',
          '**None.** It *is* the pipeline — its bars and lenses refract the '
              'body on both engines.',
        ],
        [
          '`LiquidGlassButton`',
          'An ancestor `LiquidGlassView`; frosted fallback without one.',
        ],
        ['`LiquidGlassAppBar`', 'An ancestor `LiquidGlassView`.'],
        ['`LiquidGlassTabBar`', 'An ancestor `LiquidGlassView`.'],
        [
          '`LiquidGlassBottomNavBar`',
          'Use it inside a `LiquidGlassScaffold`. For a standalone bar on '
              'Impeller, use `.withImpeller(...)`.',
        ],
        [
          '`LiquidGlassJelly`, `LiquidGlassDraggable`',
          'Whatever the lens or content they wrap requires.',
        ],
      ],
    ),
    Heading('One vocabulary'),
    Prose(
      "Every component takes a `style:` of the same `LiquidGlassStyle` used "
      "by a hand-built lens, and the ones you press take a `touch:`. A look "
      "authored once travels across all of them — and across your own lenses "
      "— as a single value.",
    ),
    TryIt('controls', label: 'Slider and toggle, wired up'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6.1 · Slider
// ─────────────────────────────────────────────────────────────────────

const _slider = DocPage(
  id: 'slider',
  parent: 'components',
  title: 'Slider',
  tagline: 'Self-contained glass, and the callback you should commit on.',
  blocks: [
    Prose(
      "`LiquidGlassSlider` is a track with a glass thumb that refracts it. It "
      "is **self-contained**: it supplies its own background and refracts its "
      "own track, so it needs no `LiquidGlassView` and takes no capture of "
      "your page. Drop it anywhere, on either engine.",
    ),
    Code('''LiquidGlassSlider(
  value: volume,
  onChanged: (v) => setState(() => volume = v),
  onChangeEnd: (v) => savePreference(v),
  activeColor: Colors.white,
  layout: const LiquidGlassSliderLayout(width: 280),
)'''),
    DocTable(
      headers: ['Parameter', 'Default', 'What it does'],
      flex: [3, 3, 6],
      rows: [
        ['`value`', '—', 'Position, `0.0`–`1.0`.'],
        ['`onChanged`', '—', 'Fires on every pixel of the drag.'],
        [
          '`onChangeStart` / `onChangeEnd`',
          '`null`',
          'Fire once, on grab and on release.',
        ],
        ['`activeColor`', '`white`', 'The filled part of the track.'],
        ['`inactiveColor`', '`0x3CFFFFFF`', 'The rest of the track.'],
        [
          '`layout`',
          '`LiquidGlassSliderLayout()`',
          'All geometry: width, track height, thumb size and travel.',
        ],
        ['`style`', '`null`', 'Overrides the thumb glass.'],
        [
          '`jelly`',
          'tuned default',
          'The thumb spring — squash, stretch, how it settles.',
        ],
      ],
    ),
    Heading('Geometry'),
    Prose(
      "Everything about the size lives in one descriptor, including how far "
      "the thumb may deform **past** its declared size while it moves. The "
      "extra room is reserved in layout, so a stretching thumb never pushes "
      "its neighbours around.",
    ),
    Code('''const LiquidGlassSliderLayout(
  width: 280,
  trackHeight: 8,
  thumbWidth: 35,
  thumbHeight: 23,
  thumbExtraWidth: 14,      // room for the stretch
  thumbExtraHeight: 10,
  thumbSqueezeWidth: 6,     // how far it may pinch
  thumbStretchHeight: 10,
)'''),
    Note(
      "`onChanged` can fire hundreds of times in one drag. Anything "
      "expensive — a write, a network call, a rebuild of something big — "
      "belongs in `onChangeEnd`, which fires once on release.",
      kind: NoteKind.tip,
    ),
    TryIt('slider', label: 'Layouts, colours and both callbacks'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6.2 · Toggle
// ─────────────────────────────────────────────────────────────────────

const _toggle = DocPage(
  id: 'toggle',
  parent: 'components',
  title: 'Toggle',
  tagline: 'A switch whose handle becomes glass under your thumb.',
  blocks: [
    Prose(
      "`LiquidGlassToggle` is self-contained in the same way as the slider — "
      "its own background, its own refracted track, no view and no capture "
      "anywhere near it.",
    ),
    Code('''LiquidGlassToggle(
  value: wifi,
  onChanged: (v) => setState(() => wifi = v),
  activeColor: const Color(0xFF0A84FF),
  layout: const LiquidGlassToggleLayout(width: 64, height: 28),
)'''),
    DocTable(
      headers: ['Parameter', 'Default', 'What it does'],
      flex: [3, 3, 6],
      rows: [
        ['`value`', '—', 'On or off.'],
        ['`onChanged`', '—', 'Fires on tap and on drag-release.'],
        ['`activeColor`', '`0xFF34C759`', 'Track colour when on.'],
        ['`inactiveColor`', '`0x66808080`', 'Track colour when off.'],
        [
          '`layout`',
          '`LiquidGlassToggleLayout()`',
          'Track and thumb size, padding, and the press geometry.',
        ],
        ['`style`', '`null`', 'Overrides the handle glass.'],
        [
          '`reserveSwellRoom`',
          '`false`',
          'Reserves layout room for the press swell instead of letting it '
              'paint outside.',
        ],
      ],
    ),
    Heading('The handle is not a picture of glass'),
    Prose(
      "At rest the thumb is a solid pill and the lens beneath it contributes "
      "nothing — fully frosted, no bend, no rim. Press it and the solid "
      "dissolves as the optics come up together, so the glass **arrives** as "
      "a state change instead of being revealed behind a fading white. Hold "
      "one down and the track bends through it.",
    ),
    TryIt('toggle', label: 'Switches that govern each other'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6.3 · Button
// ─────────────────────────────────────────────────────────────────────

const _button = DocPage(
  id: 'button',
  parent: 'components',
  title: 'Button',
  tagline: 'A lens shaped like a button, with a press that answers.',
  blocks: [
    Prose(
      "`LiquidGlassButton` is one lens around an icon-and-label row. Because "
      "it refracts what is behind it, it has the lens's requirement: on Skia "
      "and the web it needs an ancestor `LiquidGlassView` — without one it "
      "degrades to a frosted pill. On Impeller it works anywhere.",
    ),
    Code('''LiquidGlassButton(
  label: 'Continue',
  icon: Icons.arrow_forward_rounded,
  width: 220,
  touch: const LiquidGlassTouch(flex: LiquidGlassFlex.subtle()),
  onPressed: () => next(),
)'''),
    DocTable(
      headers: ['Parameter', 'Default', 'What it does'],
      flex: [3, 3, 6],
      rows: [
        ['`label`', '—', 'Button text. Ignored when `child` is set.'],
        ['`icon`', '`null`', 'Leading icon.'],
        [
          '`onPressed`',
          '`null`',
          'Null disables the button — it dims and stops taking a press.',
        ],
        ['`width` / `height`', '`null` / `48`', 'Size. Null width hugs.'],
        ['`touch`', '`null`', 'Give it one and the glass gives under a press.'],
        ['`style`', '`null`', 'Shape, tint, refraction.'],
        [
          '`foregroundColor`, `fontSize`, `fontWeight`, `iconSize`',
          '`white`, `16`, `w600`, `20`',
          'The label row, without reaching for a theme.',
        ],
      ],
    ),
    Heading('Your own content'),
    Prose(
      "`LiquidGlassButton.custom` replaces the icon-and-label row entirely — "
      "an avatar, two lines of text, an `SvgPicture`, a badge row.",
    ),
    Code('''LiquidGlassButton.custom(
  width: 260,
  height: 62,
  onPressed: () => switchAccount(),
  child: myAvatarRow,
)'''),
    TryIt('button', label: 'Press one and it gives'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6.4 · App bar
// ─────────────────────────────────────────────────────────────────────

const _appBar = DocPage(
  id: 'appbar',
  parent: 'components',
  title: 'App bar',
  tagline: 'A floating capsule with your page running under it.',
  blocks: [
    Prose(
      "`LiquidGlassAppBar` is a single lens wrapped around `leading`, `title` "
      "and `actions`. Place it in a top-aligned `Stack` child, or in the "
      "`appBar:` slot of a `LiquidGlassScaffold`.",
    ),
    Code('''LiquidGlassView(
  backgroundWidget: myScrollingPage,   // what the bar refracts
  child: Align(
    alignment: Alignment.topCenter,
    child: LiquidGlassAppBar(
      leading: const Icon(Icons.menu_rounded),
      title: const Text('Library'),
      actions: const [Icon(Icons.search_rounded)],
      width: 356,
    ),
  ),
)'''),
    DocTable(
      headers: ['Parameter', 'Default', 'What it does'],
      flex: [3, 3, 6],
      rows: [
        ['`leading`', '`null`', 'Start slot — a menu or back button.'],
        ['`title`', '`null`', 'Usually a `Text`; inherits the bar style.'],
        ['`actions`', '`[]`', 'End slot, laid out in order.'],
        ['`centerTitle`', '`true`', 'False left-aligns it beside `leading`.'],
        [
          '`height` / `width`',
          '`56` / `360`',
          'Height also sets the default corner radius (`height / 2`).',
        ],
        [
          '`foregroundColor`',
          '`white`',
          'Reaches icons and text through an `IconTheme` and a '
              '`DefaultTextStyle`.',
        ],
        ['`touch`', '`null`', 'Makes the bar itself answer a press.'],
      ],
    ),
    Note(
      "This is the component that earns a per-frame capture on Skia. The page "
      "under the bar moves, so the snapshot has to keep up — leave "
      "`realTimeCapture` at `true` on the view around it. On Impeller nothing "
      "is captured either way.",
    ),
    TryIt('appbar', label: 'Scroll the feed under the bar'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6.5 · Tab bar
// ─────────────────────────────────────────────────────────────────────

const _tabBar = DocPage(
  id: 'tabbar',
  parent: 'components',
  title: 'Tab bar',
  tagline: 'Tabs in one glass capsule, no scaffold required.',
  blocks: [
    Prose(
      "`LiquidGlassTabBar` is the bar on its own: you place it, you keep the "
      "index, you decide what the page does with it. Like the app bar it is a "
      "single lens, so on Skia it wants an ancestor `LiquidGlassView` whose "
      "background is the page it should refract.",
    ),
    Code('''LiquidGlassTabBar(
  items: const [
    LiquidGlassTabBarItem(
      icon: Icons.today_outlined,
      selectedIcon: Icons.today_rounded,
      label: 'Today',
    ),
    LiquidGlassTabBarItem(icon: Icons.bar_chart_rounded, label: 'Charts'),
  ],
  selectedIndex: index,
  onChanged: (i) => setState(() => index = i),
  width: 330,
  showSelectionPill: true,
)'''),
    DocTable(
      headers: ['Parameter', 'Default', 'What it does'],
      flex: [3, 3, 6],
      rows: [
        ['`items`', '—', '`LiquidGlassTabBarItem`s: icon, selected icon, label.'],
        ['`selectedIndex` / `onChanged`', '—', 'You own the index.'],
        ['`height` / `width`', '`64` / `320`', 'The capsule.'],
        [
          '`showSelectionPill`',
          '`true`',
          'A plain translucent capsule behind the selected tab — one lens, no '
              'second pipeline.',
        ],
        [
          '`selectionColor`, `selectionBorderColor`',
          '`0x32FFFFFF`, `0x50FFFFFF`',
          'That capsule’s fill and rim.',
        ],
        [
          '`selectedItemColor`, `unselectedItemColor`, `iconSize`, `fontSize`',
          '`white`, `white70`, `24`, `10.5`',
          'The items.',
        ],
      ],
    ),
    Heading('Custom glyphs'),
    Prose(
      "Tabs are not limited to `IconData`. `LiquidGlassTabBarItem.custom` "
      "draws through a builder, so an `SvgPicture`, an `Image` or a "
      "`CustomPaint` all work.",
    ),
    Code('''LiquidGlassTabBarItem.custom(
  label: 'Home',
  iconBuilder: (context, i) => SvgPicture.asset(
    i.selected ? 'assets/home_fill.svg' : 'assets/home.svg',
    width: i.size,
    height: i.size,
    colorFilter: ColorFilter.mode(i.color, BlendMode.srcIn),
  ),
)'''),
    Prose(
      "The builder is handed the colour the bar already resolved for the "
      "layer being drawn, the glyph box size, and whether that layer is the "
      "selected one. Tint with `i.color` and your artwork follows the palette "
      "*and* the morph pill's reveal — a glass-pill bar draws each tab twice "
      "per frame and calls the builder for each. Multi-colour art can ignore "
      "the colour entirely.",
    ),
    TryIt('tabbar', label: 'Tabs over a page that changes'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6.6 · Bottom nav bar
// ─────────────────────────────────────────────────────────────────────

const _navBar = DocPage(
  id: 'navbar',
  parent: 'components',
  title: 'Bottom nav bar',
  tagline: 'Two selection tiers: a highlight, or a second piece of glass.',
  blocks: [
    Prose(
      "`LiquidGlassBottomNavBar` is the floating bar. It expects a page to "
      "refract, and `LiquidGlassScaffold` is what hands it one — that pairing "
      "works on both engines, including the web.",
    ),
    Code('''LiquidGlassScaffold(
  body: myPage,
  bottomNavigationBar: LiquidGlassBottomNavBar(
    items: items,
    selectedIndex: index,
    onChanged: (i) => setState(() => index = i),
    width: 310,
    margin: const EdgeInsets.only(bottom: 22),
    pillStyle: const LiquidGlassNavPillStyle(animated: true),
  ),
)'''),
    DocTable(
      headers: ['Parameter', 'Default', 'What it does'],
      flex: [3, 3, 6],
      rows: [
        ['`items`', '—', 'The same `LiquidGlassTabBarItem`s as the tab bar.'],
        ['`selectedIndex` / `onChanged`', '—', 'You own the index.'],
        ['`width` / `height`', '`300` / `64`', 'The capsule.'],
        ['`margin`', '`bottom: 24`', 'How far it floats off the edge.'],
        [
          '`itemStyle`',
          '`LiquidGlassNavItemStyle()`',
          'Icon and label colours, sizes, weights.',
        ],
        [
          '`pillStyle`',
          '`LiquidGlassNavPillStyle()`',
          'The selection — see below.',
        ],
        ['`style`', '`null`', 'The bar capsule’s own glass.'],
      ],
    ),
    Heading('The two tiers'),
    DocTable(
      headers: ['`pillStyle.mode`', 'What the selection is'],
      flex: [3, 7],
      rows: [
        [
          '`none` *(default)*',
          'A translucent highlight inside the bar’s single lens. Instant, or '
              'a soft slide with `animated: true`. Cheap everywhere.',
        ],
        [
          '`impellerOnly`',
          'The glass **morph pill** where it is free, the highlight on Skia.',
        ],
        [
          '`both`',
          'The morph pill on both engines — a second refracting surface that '
              'bends the bar itself.',
        ],
      ],
    ),
    Note(
      "The morph pill is a second full pipeline. On Skia that is a second "
      "full-page capture: fine over a still page, heavy over a scrolling one. "
      "`impellerOnly` is the setting that gives you the pill where it costs "
      "nothing and the light bar everywhere else.",
      kind: NoteKind.warn,
    ),
    Heading('Standalone bar on Impeller'),
    Code('''Stack(
  children: [
    MyPage(),
    LiquidGlassBottomNavBar.withImpeller(
      items: items,
      selectedIndex: index,
      onChanged: (i) => setState(() => index = i),
    ),
  ],
)'''),
    Prose(
      "`.withImpeller` is the bodyless bar: no scaffold, no page handed in. "
      "It expands to fill, so drop it as the **last** child of a `Stack`. On "
      "Skia it falls back to a frosted bar that still shows content through "
      "it.",
    ),
    TryIt('navbar', label: 'Switch tiers, then switch tabs'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6.7 · Scaffold
// ─────────────────────────────────────────────────────────────────────

const _scaffold = DocPage(
  id: 'scaffold',
  parent: 'components',
  title: 'Scaffold',
  tagline: 'The page that captures itself.',
  blocks: [
    Prose(
      "`LiquidGlassScaffold` is the pipeline with the slots already wired. It "
      "captures its own `body` and hands that to everything floating over it, "
      "so bars and lenses refract your page on **both** engines — including "
      "the web, where nothing else can.",
    ),
    Code('''LiquidGlassScaffold(
  body: IndexedStack(
    index: index,
    children: const [HomeTab(), BrowseTab(), SavedTab(), YouTab()],
  ),
  appBar: const LiquidGlassAppBar(title: Text('Library')),
  bottomNavigationBar: LiquidGlassBottomNavBar(
    items: items,
    selectedIndex: index,
    onChanged: (i) => setState(() => index = i),
  ),
)'''),
    DocTable(
      headers: ['Slot / knob', 'What goes in it'],
      flex: [4, 6],
      rows: [
        ['`body`', 'Your page. This is what gets captured and refracted.'],
        ['`appBar`', 'A `LiquidGlassAppBar`, floated over the body.'],
        ['`bottomNavigationBar`', 'The bar, floated over the bottom.'],
        [
          '`bottomNavigationBarAction`',
          'A trailing action beside the bar — a compose or record button.',
        ],
        ['`lenses`', 'Free-floating lenses positioned over the body.'],
        [
          '`realTimeCapture`, `pixelRatio`, `useSync`, `refreshRate`',
          'The same capture knobs a `LiquidGlassView` takes, for the same '
              'reasons.',
        ],
      ],
    ),
    Note(
      "Keep tab state by swapping the *index* of an `IndexedStack`, not the "
      "`body` widget. Rebuilding the body on every tap throws away scroll "
      "position, form input and loaded data — the demo below keeps all four "
      "tabs mounted.",
      kind: NoteKind.tip,
    ),
    TryIt('nav', label: 'A four-tab app under a floating bar'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6.8 · Jelly
// ─────────────────────────────────────────────────────────────────────

const _jelly = DocPage(
  id: 'jelly',
  parent: 'components',
  title: 'Jelly',
  tagline: 'The spring under the thumb and the pill, on its own.',
  blocks: [
    Prose(
      "`LiquidGlassJelly` deforms its child from how a value **moves**, not "
      "from what it is. Push the value fast and the child elongates along the "
      "travel and pinches across it, then recoils past rest and settles. Hold "
      "it still at any value and the child is exactly its declared size "
      "again.",
    ),
    Prose(
      "This is the same spring inside the slider's thumb and the nav bar's "
      "pill. It deforms anything you hand it — a solid pill, an icon, a lens.",
    ),
    Code('''LiquidGlassJelly(
  value: fraction,       // 0..1, its motion drives the deform
  width: 84,
  height: 84,
  axis: Axis.horizontal,
  config: const LiquidGlassJellyConfig(),
  child: myThumb,
)'''),
    DocTable(
      headers: ['LiquidGlassJellyConfig', 'Default', 'What it does'],
      flex: [3, 2, 6],
      rows: [
        [
          '`style`',
          '`pinchExtrude`',
          'Extrude along the travel and pinch across it, or `squashStretch` '
              'for the classic uniform-volume squash.',
        ],
        ['`stiffness` / `damping`', '`320` / `22`', 'How it settles.'],
        [
          '`stretchWidth` / `squashHeight`',
          '`14` / `5`',
          'How far it may go, in logical pixels.',
        ],
        [
          '`anchorBias`',
          '`-0.6`',
          'Which side of the child the deformation is weighted to.',
        ],
        [
          '`recoilScale` / `recoilAnchor`',
          '`1.5` / `1.0`',
          'The overshoot after the travel stops.',
        ],
        [
          '`maxVelocity`, `velocityClamp`, `directionTau`',
          '`1.5`, `12`, `0.12`',
          'Input conditioning: how fast it can be driven, and how quickly it '
              'accepts a change of direction.',
        ],
      ],
    ),
    TryIt('jelly', label: 'Throw the value and watch it settle'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 6.9 · Draggable
// ─────────────────────────────────────────────────────────────────────

const _draggable = DocPage(
  id: 'draggable',
  parent: 'components',
  title: 'Draggable',
  tagline: 'Drag wiring you do not have to write again.',
  blocks: [
    Prose(
      "`LiquidGlassDraggable` wraps any widget, moves it with the finger, "
      "keeps the offset itself and reports it through `onChanged`. The child "
      "keeps its layout slot, so nothing around it reflows as it travels.",
    ),
    Code('''LiquidGlassDraggable(
  enabled: true,
  initialOffset: Offset.zero,
  onChanged: (o) => setState(() => offset = o),
  child: const SizedBox.square(
    dimension: 190,
    child: LiquidGlassLens(
      style: LiquidGlassStyle(
        shape: LiquidGlassShape.squircle(cornerRadius: 56),
      ),
    ),
  ),
)'''),
    DocTable(
      headers: ['Parameter', 'Default', 'What it does'],
      flex: [3, 3, 6],
      rows: [
        ['`child`', '—', 'Anything. A lens is the usual one.'],
        [
          '`enabled`',
          '`true`',
          'False freezes it in place without unwrapping anything.',
        ],
        ['`initialOffset`', '`Offset.zero`', 'Where it starts.'],
        ['`onChanged`', '`null`', 'Called with the offset as it moves.'],
      ],
    ),
    Note(
      "Dragging a lens over a background captured **once** costs a shader "
      "pass and nothing else. It is the cheapest interesting thing you can do "
      "with glass on Skia.",
      kind: NoteKind.tip,
    ),
    TryIt('draggable', label: 'Drag it, and watch the offset'),
  ],
);

// ─────────────────────────────────────────────────────────────────────
// 7 · Performance
// ─────────────────────────────────────────────────────────────────────

const _performance = DocPage(
  id: 'performance',
  title: 'Performance',
  tagline: 'What actually costs, and what only looks like it should.',
  blocks: [
    Prose(
      "There are two cost models, and they are not alike. On Impeller a lens "
      "is a shader pass over the backdrop — adding one is cheap and adding a "
      "second is nearly free. On Skia the expensive thing is not the shader "
      "at all; it is **rasterizing the background** so the shader has "
      "something to read.",
    ),
    Prose(
      "So on Skia the question is never “how many lenses”. It is "
      "**how many captures, how large, how often**.",
    ),
    Heading('The big lever'),
    Prose(
      "If your background does not move, do not capture it every frame. "
      "`realTimeCapture: false` plus a single `captureOnce()` beats every "
      "other tuning knob put together, and the lenses can move freely over "
      "the snapshot.",
    ),
    Bullets([
      'A painted gradient, an image, a static illustration → capture once.',
      'A scrolling list, a video, an animating background → keep it live.',
      'A background that changes rarely → capture once, then '
          '`captureOnce()` again when it actually changes.',
    ]),
    Heading('Then the cheap knobs'),
    Bullets([
      '`pixelRatio: 0.5`–`0.8` — the glass is bending and blurring what it '
          'reads, so it hides a soft capture well.',
      '`useSync: false` — cheaper, at the price of a possible frame of lag.',
      '`refreshRate` — cap the capture below the display rate when the '
          'background moves slowly.',
    ]),
    Heading('Blur is the expensive appearance knob'),
    Prose(
      "In-shader blur on the Skia capture path costs real time when the lens "
      "is large or the sigma is high, and above roughly `7` it stops looking "
      "like a real backdrop blur anyway. If you are hunting frames on the "
      "web, drop blur before you drop anything else.",
    ),
    Note(
      "The Blend demo on this site runs with **no blur at all** — deliberately. "
      "Blur softens exactly the rings and hairlines that prove the content is "
      "bending, so it costs the most and hides the point.",
      kind: NoteKind.tip,
    ),
    Heading('Two pipelines are two captures'),
    Prose(
      "The bottom nav's glass morph pill runs a second capture on top of the "
      "scaffold's own: one to give the bar the page, one to give the pill the "
      "bar. On Impeller neither capture exists and the pill is free. On Skia "
      "the second one is real, and beside a scrolling feed it is the "
      "difference you feel.",
    ),
    Prose(
      "`LiquidGlassPillMode.impellerOnly` is the honest default for a "
      "cross-platform app: the full pill where it costs nothing, the "
      "lightweight sliding highlight everywhere else.",
    ),
    Heading('Lenses inside scrollables'),
    Note(
      "**Not recommended.** Liquid glass is designed to *float above* content "
      "— a bar, a panel, an overlay that refracts the list passing behind it. "
      "A lens placed as a list item scrolls with the thing it should be "
      "refracting.",
      kind: NoteKind.warn,
    ),
    Prose(
      "If you do need one there on Impeller, disable the overscroll "
      "indicator. Android's stretch overscroll isolates the scrollable into "
      "its own layer, which can make a backdrop lens render **black** at the "
      "scroll edges.",
    ),
    Code('''ScrollConfiguration(
  behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
  child: ListView(children: [ /* ...LiquidGlassLens... */ ]),
)'''),
    Heading('Free by construction'),
    Bullets([
      '`touch: null` — the default — adds no listener and no ticker.',
      '`visibility: false` removes the backdrop cost instantly, and the '
          'child with it.',
      '`LiquidGlassSlider` and `LiquidGlassToggle` capture only their own '
          'small track, not your page.',
    ]),
    TryIt('nav', label: 'A live capture under a scrolling feed'),
  ],
);
