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
// Blender: wrap a subtree and merge 2–6 descendant LiquidGlassLens
// widgets into one smooth metaball glass surface.
export 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_blender.dart'
    show LiquidGlassBlender;
export 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_shaders.dart'
    show LiquidGlassShaders;

export 'package:liquid_glass_easy/src/controllers/liquid_glass_controller.dart';
export 'package:liquid_glass_easy/src/controllers/liquid_glass_view_controller.dart';

export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_blur.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';
// Custom glyphs: the builder every icon slot accepts (SVG, PNG,
// CustomPaint) and the state it is handed — resolved color, box size,
// and whether this layer draws the selected state.
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_glyph.dart'
    show LiquidGlassGlyph, LiquidGlassGlyphBuilder;
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_draggable.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_light_mode.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_border_mode.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_mode.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_type.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_jelly_spring.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_jelly_config.dart';

// ── Public, customizable developer components ──────────────
// Generic glass UI atoms a developer composes into their app.
// Each is a single LiquidGlass lens placed in a LiquidGlassView.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_button.dart';
// Jelly: a reusable squash/stretch wrapper driven by a 1-D value — the
// slider/nav-bar jelly physics exposed as a drop-in widget.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_jelly.dart';
// Drop-in glass form controls. Only the high-level widgets + their
// layout descriptors are public; the low-level track/thumb builders stay
// internal.
export 'package:liquid_glass_easy/src/widgets/components/slider/liquid_glass_slider.dart'
    show LiquidGlassSlider, LiquidGlassSliderLayout;
export 'package:liquid_glass_easy/src/widgets/components/toggle/liquid_glass_toggle.dart'
    show LiquidGlassToggle, LiquidGlassToggleLayout;
// Scaffold: a Scaffold-style layout that owns the LiquidGlassView
// pipeline and composes the app bar + bottom nav + side action slots.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_scaffold.dart';
// App bar: a floating glass top bar (leading / title / actions).
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_app_bar.dart';
// Tab bar: only the non-animated [LiquidGlassTabBar] is public. The
// animated variant ([LiquidGlassAnimatedTabBar]) is hidden while its
// motion work is still being finished.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_tab_bar.dart'
    show LiquidGlassTabBar, LiquidGlassTabBarItem, LiquidGlassTabBarAction;
// Bottom nav: only the single drop-in [LiquidGlassBottomNavBar] is
// public. The lower-level building blocks (shell / capsule / static
// pill / layout) and the animated pieces are hidden — the drop-in
// widget supersedes them for app developers.
export 'package:liquid_glass_easy/src/widgets/components/bottom_nav_bar/liquid_glass_bottom_nav_bar.dart'
    show
        LiquidGlassBottomNavBar,
        LiquidGlassPillMode,
        LiquidGlassNavItemStyle,
        LiquidGlassNavPillStyle;

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
//     [LiquidGlassBottomNavBar] builds via buildGlassPillBar; configure
//     it through [LiquidGlassBottomNavBar] instead.
// The example app still drives all of these in its showcase and
// imports them directly from 'src' (with an implementation_imports
// ignore) instead of relying on the public barrel.

// LiquidGlassShowcase + LiquidGlassPlayground are UNDER MAINTENANCE and
// temporarily not exported. Re-enable these once their rework lands.
// export 'package:liquid_glass_easy/src/demos/liquid_glass_showcase.dart';
// export 'package:liquid_glass_easy/src/demos/liquid_glass_playground.dart';
