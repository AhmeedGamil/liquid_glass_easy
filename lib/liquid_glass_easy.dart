export 'package:liquid_glass_easy/src/widgets/liquid_glass_view.dart';
// The classic, position-driven lens config (`LiquidGlass`,
// `LiquidGlassGeometry`, `LiquidGlassBehavior`) is intentionally NOT
// exported: it is the package's internal engine. App developers use
// `LiquidGlassLens` (the layout-driven lens-anywhere widget) instead.
// Only the two look groups reused by `LiquidGlassStyle` stay public.
export 'package:liquid_glass_easy/src/widgets/liquid_glass_config.dart'
    show LiquidGlassRefraction, LiquidGlassAppearance;
// The shared styling descriptor (shape + appearance + refraction) used
// across the lens, the LiquidGlass config and the components.
export 'package:liquid_glass_easy/src/widgets/liquid_glass_style.dart'
    show LiquidGlassStyle;

// ── Lens-anywhere API ───────────────────────────────────────
// Layout-driven lens widget: place it anywhere in the tree. Works
// standalone on Impeller (no background needed); inside a
// LiquidGlassView's `child` it also refracts the captured background
// on Skia / Web.
export 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_lens.dart'
    show LiquidGlassLens;
// Group: DEPRECATED — `LiquidGlassBlender(smoothness: 0)` is the same
// widget with a different default, and says the same thing.
export 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_group.dart'
    show LiquidGlassGroup;
// Batch: wrap a subtree and let every LiquidGlassLens inside it share ONE
// read of the backdrop — the same glass, any number of them, at the cost of
// a single lens. Members must not overlap each other.
export 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_batch.dart'
    show LiquidGlassBatch;
// Blender: wrap a subtree and merge 2–6 descendant LiquidGlassLens
// widgets into one smooth metaball glass surface.
export 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_blender.dart'
    show LiquidGlassBlender;
export 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_shaders.dart'
    show LiquidGlassShaders;
// Renderer switches: `LiquidGlassEngine.liteGlassOnSkia` and
// `liteGlassOnImpeller` put every lens on the shader-free lite glass.
export 'package:liquid_glass_easy/src/widgets/liquid_glass_engine.dart'
    show LiquidGlassEngine;
// Lite: the shader-free glass — frost, tint and a rim lit from the backdrop
// — for surfaces that are not lenses, and what every lens wears under the
// engine switches above and `LiquidGlassStyle.liteGlass`.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_lite.dart'
    show LiquidGlassLite, LiquidGlassLitePickup;

export 'package:liquid_glass_easy/src/controllers/liquid_glass_controller.dart';
export 'package:liquid_glass_easy/src/controllers/liquid_glass_view_controller.dart';

// Adaptivity: glass tint + content color flip with the background behind
// the lens (LiquidGlassStyle.adaptivity + LiquidGlassView.adaptiveSampling).
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_adaptivity.dart'
    show
        LiquidGlassAdaptivity,
        LiquidGlassAdaptiveSampling,
        LiquidGlassAdaptivityLink,
        LiquidGlassAdaptivityController,
        LiquidGlassBrightnessFallback,
        LiquidGlassSystemChrome;
// Adaptive area: an invisible region that samples once and drives the
// verdict for every adaptive widget inside it (the group form of
// adaptivity — no link wiring needed).
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_adaptive_area.dart'
    show LiquidGlassAdaptiveArea, LiquidGlassAdaptiveAreaScope;
// Adaptive content: makes bare icons/text (no glass behind them) follow
// the animated adaptive content color, like a lens child would.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_adaptive_content.dart'
    show LiquidGlassAdaptiveContent;
// Scroll edge treatment: an adaptive fading dim band pinned over a
// scrollable's edge, keeping floating glass elements legible (the
// dimming variant of iOS 26's scroll edge effect).
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_scroll_edge.dart'
    show LiquidGlassScrollEdge, LiquidGlassEdge, LiquidGlassScrollEdgeStyle;
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_blur.dart';
// The two clip helpers are shared between the widget-level clip and the
// render object's own, so they are library-wide but not API.
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart'
    hide liquidGlassOutlinePath, liquidGlassUsesExactClipPath;
// Custom glyphs: the builder every icon slot accepts (SVG, PNG,
// CustomPaint) and the state it is handed — resolved color, box size,
// and whether this layer draws the selected state.
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_glyph.dart'
    show
        LiquidGlassGlyph,
        LiquidGlassGlyphBuilder,
        LiquidGlassLabel,
        LiquidGlassLabelBuilder;
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_draggable.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_light_mode.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_border_mode.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_mode.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_type.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_spring.dart';
// How a surface answers a finger. LiquidGlassTouch is the group; today it
// carries the flex — press a lens and it compresses, drag it and it
// elongates along the pull while pinching in the cross axis, four edges
// sprung independently and anchored at the grab point.
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_touch.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_flex.dart'
    show
        LiquidGlassFlex,
        LiquidGlassFlexDeform,
        LiquidGlassFlexAdvanced,
        // Debug-only A/B for the stretched outline; ships as `full`.
        LiquidGlassFlexOutline,
        debugLiquidGlassFlexOutline;

// ── Public, customizable developer components ──────────────
// Generic glass UI atoms a developer composes into their app.
// Each is a single LiquidGlass lens placed in a LiquidGlassView.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_button.dart';
// Floating action button (circular FAB & extended FAB).
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_fab.dart';
// Dialogs & dialog presenter helper.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_dialog.dart';
// Sheets. `showLiquidGlassSheet` is Flutter's own `showModalBottomSheet`
// with the glass where its filled Material used to be — every parameter
// of theirs forwarded, plus the style. The panel itself is a plain
// widget: place one bottom-aligned, or inside anything else that owns
// the motion.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_sheet.dart'
    show showLiquidGlassSheet, LiquidGlassSheet, LiquidGlassSheetAnchor;
// Drop-in glass form controls. Only the high-level widgets + their
// layout descriptors are public; the low-level track/thumb builders stay
// internal.
export 'package:liquid_glass_easy/src/widgets/components/slider/liquid_glass_slider.dart'
    show LiquidGlassSlider, LiquidGlassSliderLayout;
// The moving glass pill the slider's thumb is built from, its
// acceleration squash/stretch, and the contact shadow that can wrap any
// lens — all usable on their own.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_motion_pill.dart'
    show LiquidGlassMotionPill;
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_shadow.dart'
    show LiquidGlassShadow;
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_lens_motion.dart'
    show LiquidGlassLensMotion, LiquidGlassLensMotionSpec;
export 'package:liquid_glass_easy/src/widgets/components/switch/liquid_glass_switch.dart'
    show LiquidGlassSwitch, LiquidGlassSwitchLayout;
// Scaffold: a Scaffold-style layout that owns the LiquidGlassView
// pipeline and composes the app bar + bottom nav + side action slots.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_scaffold.dart';
// App bar: a floating glass top bar (leading / title / actions).
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_app_bar.dart';
// Tab items + the side-floating action that pairs with the tab bar.
// The tab bar widget itself lives below, in the bottom_nav_bar export.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_tab_item.dart'
    show LiquidGlassTabBarItem, LiquidGlassTabBarAction;
// Tab bar: only the single drop-in [LiquidGlassTabBar] is
// public. The lower-level building blocks (shell / capsule / static
// pill / layout) and the animated pieces are hidden — the drop-in
// widget supersedes them for app developers.
export 'package:liquid_glass_easy/src/widgets/components/bottom_nav_bar/liquid_glass_tab_bar.dart'
    show
        LiquidGlassTabBar,
        LiquidGlassPillMode,
        LiquidGlassTabItemStyle,
        LiquidGlassTabPillStyle,
        LiquidGlassTabMagnifierPillStyle;
// Morph: glass that measures its child and flows to the new size —
// two blender blobs drawn as one surface, so mid-morph it has a waist.
export 'package:liquid_glass_easy/src/widgets/components/morph/liquid_glass_morph.dart';
export 'package:liquid_glass_easy/src/widgets/components/morph/liquid_glass_morph_motion.dart';

// ── Internal / showcase-only / animation-in-progress ───────
// The following are intentionally NOT exported:
//   • liquid_glass_control_tile.dart — showcase-only demo widget,
//     not a generic developer component.
//   • liquid_glass_segmented.dart (LiquidGlassSegmented + styles),
//     liquid_glass_app_icon.dart (LiquidGlassAppIcon) and
//     liquid_glass_dock.dart (LiquidGlassDock) — intentionally not
//     exported; the example still imports them directly from 'src'.
//   • liquid_glass_segmented_control.dart,
//     liquid_glass_morph_segmented.dart, liquid_glass_morph_pill.dart —
//     they animate, and these stay hidden until their motion work is
//     finalized. (The slider/toggle now expose finished drop-in widgets
//     — see the exports above — while their low-level builders remain
//     internal.)
//   • the lower-level bottom-nav building blocks and the animated
//     tab bar / bottom nav shells, including the dual-pipeline
//     [LiquidGlassAnimatedNavBar] — it is internal machinery that
//     [LiquidGlassTabBar] builds via buildGlassPillBar; configure
//     it through [LiquidGlassTabBar] instead.
// The example app still drives all of these in its showcase and
// imports them directly from 'src' (with an implementation_imports
// ignore) instead of relying on the public barrel.
