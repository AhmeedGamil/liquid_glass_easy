import 'package:flutter/widgets.dart';

import 'demos/app_bar_demo.dart';
import 'demos/blending_demo.dart';
import 'demos/button_demo.dart';
import 'demos/capture_demo.dart';
import 'demos/controls_demo.dart';
import 'demos/draggable_demo.dart';
import 'demos/jelly_demo.dart';
import 'demos/nav_bar_demo.dart';
import 'demos/nav_demo.dart';
import 'demos/slider_demo.dart';
import 'demos/tab_bar_demo.dart';
import 'demos/toggle_demo.dart';
import 'demos/touch_demo.dart';

/// One entry in the docs site.
///
/// [id] is the value of the `?d=` query parameter, so a docs page can embed a
/// specific demo by URL and the link stays stable even if the title changes.
class DemoEntry {
  final String id;
  final String title;
  final String blurb;
  final String code;
  final WidgetBuilder builder;

  const DemoEntry({
    required this.id,
    required this.title,
    required this.blurb,
    required this.code,
    required this.builder,
  });
}

/// Every demo the site can show. Add one here and it appears on the landing
/// page and becomes addressable as `?d=<id>` — there is no second list to
/// keep in sync.
const List<DemoEntry> kDemos = [
  DemoEntry(
    id: 'touch',
    title: 'Touch',
    blurb: 'Pass a touch: and the lens becomes a soft body. Press it and it '
        'swells under your finger; drag it and it elongates along the pull, '
        'pinches in the cross axis, leans after your thumb, then springs back '
        'with a wobble.\n\n'
        'The card never moves — its footprint in layout is unchanged, so '
        'nothing around it shifts. The four edges spring independently, so '
        'the half nearest your finger deforms more than the far half: the '
        'asymmetry a scale transform cannot produce.\n\n'
        'Four presets ship with the package, and the only honest way to pick '
        'one is to feel them against each other — the chips swap the spec on '
        'the same card, so the feel is the only thing that changes.\n\n'
        'The rows inside are ordinary widgets. They are the lens child, so '
        'the deformation carries them instead of each one deforming on its '
        'own — that is childFollow, and it is why the text never re-wraps '
        'mid-gesture.',
    code: '''LiquidGlassLens(
  touch: const LiquidGlassTouch(
    // .subtle() · .pronounced() · .uniform()
    flex: LiquidGlassFlex(),
  ),
  style: const LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 30,
    ),
  ),
  child: myCard,
)''',
    builder: _touch,
  ),
  DemoEntry(
    id: 'blend',
    title: 'Blend',
    blurb: 'Two lenses in a LiquidGlassBlender — the minimum the metaball '
        'field needs, and the clearest way to watch it work. Bring them close '
        'and a smooth bridge grows between them; pull them apart and it '
        'snaps. Each member keeps its own corner style through the merge: the '
        'circle stays a circle, the squircle stays a squircle.\n\n'
        'The rim toggle drops borderWidth to zero on the group style. One '
        'unbroken outline around two bodies and the bridge between them is '
        'what makes the fusion legible — turn it off and the union is still '
        'there in the refraction, just much harder to read.\n\n'
        'The page is inside a LiquidGlassView, which is what lets it run in '
        'your browser at all: on Skia the merged surface refracts the view\'s '
        'captured background, on Impeller it would read the live backdrop and '
        'take no capture. Outside a view, a blend is Impeller-only — on Skia '
        'the members fall back to frosted glass and stop fusing.\n\n'
        'The backdrop is painted and static, so it is captured ONCE. The '
        'rings and hairlines under the glass are there on purpose: a smooth '
        'gradient bends into another smooth gradient, but a straight line '
        'visibly bows.',
    code: '''LiquidGlassView(
  // Static background? Snapshot it once.
  realTimeCapture: false,
  backgroundWidget: myBackdrop,
  child: LiquidGlassBlender(
    smoothness: 58,
    style: LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 36,
        borderWidth: rim ? 1.4 : 0,   // the merged outline
      ),
    ),
    child: Stack(
      children: [
        Positioned(left: 40, top: 80, child: myCircleLens),
        Positioned(left: 150, top: 150, child: mySquircleLens),
      ],
    ),
  ),
)''',
    builder: _blend,
  ),
  DemoEntry(
    id: 'capture',
    title: 'Capture once',
    blurb: 'On Skia and the web a lens has no live backdrop to read, so a '
        'LiquidGlassView rasterizes its backgroundWidget and hands the lens '
        'that image. This backdrop is painted and never changes, so it is '
        'captured ONCE (realTimeCapture: false) after the first frame — and '
        'the counter stays at one no matter how long you drag.\n\n'
        'Dragging is free. Moving a lens over a fixed capture re-runs the '
        'shader and nothing else: no rasterization, no page repaint, no cost '
        'that scales with what is behind the glass. Live capture only earns '
        'its price when the background genuinely moves.\n\n'
        'A frozen snapshot is only free because it is frozen. Swap the '
        'palette: the page repaints immediately while the glass keeps bending '
        'the old pixels, because the capture and the tree have drifted apart. '
        'captureOnce() is how you settle it — one snapshot on demand, at the '
        'moment the background actually changed.\n\n'
        'None of this exists on Impeller. There the lens samples the live '
        'backdrop per frame, no capture is ever taken, and there is nothing '
        'to go stale — the same widget tree, with the view costing nothing.',
    code: '''final view = LiquidGlassViewController();

LiquidGlassView(
  controller: view,
  // Static backdrop: snapshot it once, refract it forever.
  realTimeCapture: false,
  backgroundWidget: myBackdrop,
  child: Stack(children: [
    Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (e) => setState(() {
          x += e.delta.dx;
          y += e.delta.dy;
        }),
        child: const SizedBox.square(
          dimension: 180,
          child: LiquidGlassLens(
            style: LiquidGlassStyle(
              shape: LiquidGlassShape.squircle(cornerRadius: 52),
            ),
          ),
        ),
      ),
    ),
  ]),
)

// The background really changed? Take a new snapshot.
await view.captureOnce();''',
    builder: _capture,
  ),
  DemoEntry(
    id: 'nav',
    title: 'Scaffold + glass nav',
    blurb: 'LiquidGlassScaffold owns the glass pipeline: it captures its own '
        'body and hands it to the bar, so the floating nav refracts your page '
        'on both backends — including the web.\n\n'
        'Four real tabs, wired the way an app actually needs. The body is an '
        'IndexedStack, so every tab stays mounted and only the visible one '
        'paints: scroll the feed, switch away, come back, and you are exactly '
        'where you left off. Swapping the body widget per tap — the obvious '
        'wiring — throws that away on every tap.\n\n'
        'Bookmarks live above the tabs and the filter chips live inside '
        'Browse, which is the split that matters: shared state goes to the '
        'parent, tab-local state stays put. Save something in Home and it is '
        'already in Saved.\n\n'
        'The trade is that all four build up front — right for four cheap '
        'pages, wrong for a dozen expensive ones, where you would want '
        'AutomaticKeepAliveClientMixin instead. And note IndexedStack keeps '
        'tab STATE, not a navigation stack: if a tab needs push/pop history, '
        'give it its own Navigator.\n\n'
        'The selection is the single-pipeline bar. The glass morph pill adds '
        'a SECOND full-page capture on top of this one, and on Skia — all a '
        'browser gives you — that is too much beside a scrolling feed. On '
        'Impeller nothing is captured at all, so there it is free.',
    code: '''LiquidGlassScaffold(
  // Every tab stays mounted; only the visible one paints.
  // Scroll position and tab state survive a switch.
  body: IndexedStack(
    index: index,
    children: const [HomeTab(), BrowseTab(), SavedTab(), YouTab()],
  ),
  bottomNavigationBar: LiquidGlassBottomNavBar(
    items: myItems,
    selectedIndex: index,
    onChanged: (i) => setState(() => index = i),
    width: 300,
    pillStyle: const LiquidGlassNavPillStyle(
      // mode stays `none` — one capture, not two.
      // LiquidGlassPillMode.both adds the glass morph pill.
      animated: true,
    ),
  ),
)''',
    builder: _nav,
  ),
  DemoEntry(
    id: 'controls',
    title: 'Slider + toggle',
    blurb: 'The drop-in controls, wired to something real. Brightness dims '
        'the wall, warmth shifts its palette, night mode locks the sliders it '
        'overrides and greys them out. A panel where nothing is connected '
        'shows you what a widget looks like; this one lets you feel the '
        'jelly while watching the value land.\n\n'
        'Drag a thumb quickly and let go: it stretches toward its travel and '
        'recoils on settle, with the squash weighted to the side it came '
        'from. That is the shared jelly spring, the same one behind the nav '
        'pill.\n\n'
        'There is no LiquidGlassView on this page and no capture at all. '
        'Both controls are self-contained — each supplies its own background '
        'and refracts its own track — so they work anywhere on both engines '
        'with no pipeline around them.',
    code: '''LiquidGlassSlider(
  value: brightness,
  onChanged: (v) => setState(() => brightness = v),
  layout: const LiquidGlassSliderLayout(width: 280),
)

LiquidGlassToggle(
  value: nightMode,
  activeColor: const Color(0xFF7C5CFF),
  onChanged: (v) => setState(() => nightMode = v),
)''',
    builder: _controls,
  ),

  // ── one per component, embedded on that component's docs page ──────
  DemoEntry(
    id: 'slider',
    title: 'Slider',
    blurb: 'The control on its own. LiquidGlassSlider is self-contained — it '
        'owns its background and refracts its own track — so there is no '
        'LiquidGlassView on this page and no capture anywhere. It behaves '
        'exactly like this on both engines.\n\n'
        'The chips swap the whole LiquidGlassSliderLayout on the same slider: '
        'track height, thumb size, and how far the thumb may stretch and '
        'squeeze past that size while it moves.\n\n'
        'The readout shows the live value and the committed one, because that '
        'is the whole reason onChangeEnd exists — commit expensive work to '
        'the value you land on, not to the six hundred you passed on the way.',
    code: '''LiquidGlassSlider(
  value: value,
  onChanged: (v) => setState(() => value = v),
  onChangeEnd: (v) => save(v),         // once, on release
  activeColor: Colors.white,
  layout: const LiquidGlassSliderLayout(
    width: 280,
    trackHeight: 8,
    thumbWidth: 35,
  ),
)''',
    builder: _slider,
  ),
  DemoEntry(
    id: 'toggle',
    title: 'Toggle',
    blurb: 'Self-contained like the slider: its own background, its own '
        'refracted track, no view and no capture. Colour is activeColor / '
        'inactiveColor and geometry is LiquidGlassToggleLayout — the chips '
        'swap that descriptor on every switch at once.\n\n'
        'At rest the handle is a solid pill. Press it and the solid dissolves '
        'as the lens underneath comes up — frost falls away, refraction and '
        'the rim ramp in together — so the glass arrives as a state change '
        'instead of sitting there pretending. Hold one down and watch the '
        'track bend through it.\n\n'
        'Airplane mode owns the radios here, so the switches actually govern '
        'each other rather than flipping in isolation.',
    code: '''LiquidGlassToggle(
  value: wifi,
  onChanged: (v) => setState(() => wifi = v),
  activeColor: const Color(0xFF34C759),
  layout: const LiquidGlassToggleLayout(
    width: 64,
    height: 28,
  ),
)''',
    builder: _toggle,
  ),
  DemoEntry(
    id: 'button',
    title: 'Button',
    blurb: 'A lens shaped like a button: one glass surface around an icon and '
        'a label, refracting whatever is behind it. That is also its one '
        'requirement on Skia and the web — an ancestor LiquidGlassView, which '
        'is what wraps this page. On Impeller it works anywhere with no '
        'setup.\n\n'
        'Pass a touch: and it becomes a soft body — it swells under the '
        'finger and springs back, with its footprint in layout unchanged, so '
        'nothing around it shifts. The rounded-rectangle button leaves touch '
        'off for the comparison, and the last one drops onPressed to show the '
        'disabled state.\n\n'
        'LiquidGlassButton.custom replaces the icon-and-label row with your '
        'own widget: an avatar, two lines of text, an SVG, a badge.',
    code: '''LiquidGlassButton(
  label: 'Continue',
  icon: Icons.arrow_forward_rounded,
  width: 220,
  touch: const LiquidGlassTouch(
    flex: LiquidGlassFlex.subtle(),
  ),
  onPressed: () => next(),
)

LiquidGlassButton.custom(
  onPressed: () => switchAccount(),
  child: myAvatarRow,
)''',
    builder: _button,
  ),
  DemoEntry(
    id: 'appbar',
    title: 'App bar',
    blurb: 'One lens wrapped around leading, title and actions. It refracts '
        'your page, which is the one thing it needs from you on Skia: an '
        'ancestor LiquidGlassView whose backgroundWidget is that page. Here '
        'the scrolling feed IS the background, so the rows bend as they pass '
        'under the bar.\n\n'
        'This is the case that earns a per-frame capture. The content moves, '
        'so realTimeCapture stays true — freezing the snapshot would leave '
        'the bar refracting a page that is no longer there.\n\n'
        'Foreground colour reaches the slots through an IconTheme and a '
        'DefaultTextStyle, so a plain Icon or Text picks it up without being '
        'told.',
    code: '''LiquidGlassView(
  backgroundWidget: myScrollingPage,   // captured per frame
  child: Align(
    alignment: Alignment.topCenter,
    child: LiquidGlassAppBar(
      leading: const Icon(Icons.menu_rounded),
      title: const Text('Library'),
      actions: const [Icon(Icons.search_rounded)],
      centerTitle: true,
      width: 356,
    ),
  ),
)''',
    builder: _appBar,
  ),
  DemoEntry(
    id: 'tabbar',
    title: 'Tab bar',
    blurb: 'The bar without a scaffold: you place it, you keep the index, you '
        'decide what the page does with it. Like the app bar it is a single '
        'lens, so on Skia it wants an ancestor LiquidGlassView whose '
        'background is the page it should refract.\n\n'
        'showSelectionPill draws a plain translucent capsule behind the '
        'selected tab — one lens, no second pipeline. That is the difference '
        'from the bottom nav bar’s glass morph pill, which is a whole '
        'extra refracting surface.\n\n'
        'The last tab is drawn by a builder instead of an IconData. It is '
        'handed the colour the bar already resolved, the glyph box size and '
        'whether this layer is the selected one, so custom art follows the '
        'palette exactly like an icon would.',
    code: '''LiquidGlassTabBar(
  items: const [
    LiquidGlassTabBarItem(
      icon: Icons.today_outlined,
      selectedIcon: Icons.today_rounded,
      label: 'Today',
    ),
    // …
  ],
  selectedIndex: index,
  onChanged: (i) => setState(() => index = i),
  width: 330,
  showSelectionPill: true,
)''',
    builder: _tabBar,
  ),
  DemoEntry(
    id: 'navbar',
    title: 'Bottom nav bar',
    blurb: 'The bar itself, and its two selection tiers. LiquidGlassScaffold '
        'is what feeds it a page to refract, so that pairing is what runs '
        'here — a small static page in the body, so the only thing changing '
        'on screen is the bar.\n\n'
        'Highlight (pillStyle.mode: none) is one lens for the whole bar and a '
        'translucent capsule that jumps to the selected tab, or slides there '
        'with animated: true. Cheap everywhere.\n\n'
        'The glass pill (mode: both) makes the selection a second refracting '
        'surface that morphs between tabs and bends the bar itself. It is a '
        'whole second pipeline: free on Impeller, a second full capture on '
        'Skia — which is what impellerOnly is for. Switch tiers below and '
        'watch what the selection does to the icons underneath it.',
    code: '''LiquidGlassScaffold(
  body: myPage,
  bottomNavigationBar: LiquidGlassBottomNavBar(
    items: items,
    selectedIndex: index,
    onChanged: (i) => setState(() => index = i),
    width: 310,
    pillStyle: const LiquidGlassNavPillStyle(
      animated: true,
      // mode: LiquidGlassPillMode.impellerOnly,
    ),
  ),
)''',
    builder: _navBar,
  ),
  DemoEntry(
    id: 'jelly',
    title: 'Jelly',
    blurb: 'The soft-body spring the controls are built on, on its own. '
        'LiquidGlassJelly takes a value from 0 to 1 and deforms its child '
        'from how that value MOVES, not from what it is: push the slider fast '
        'and the box elongates along the travel and pinches across it, then '
        'recoils past rest and settles. Hold it still and the box is exactly '
        'its declared size again.\n\n'
        'This is the same spring inside the slider thumb and the nav pill, so '
        'it is worth meeting on its own. It deforms anything — a solid pill, '
        'an icon, a lens.\n\n'
        'pinchExtrude extrudes along the axis of travel and pinches the cross '
        'axis; squashStretch is the classic uniform-volume squash. The rest '
        'is spring tuning: stiffness and damping decide how it settles, '
        'stretchWidth and squashHeight how far it may go.',
    code: '''LiquidGlassJelly(
  value: fraction,        // 0..1 — its motion drives the deform
  width: 84,
  height: 84,
  config: const LiquidGlassJellyConfig(
    stiffness: 320,
    damping: 22,
    stretchWidth: 14,
    squashHeight: 5,
  ),
  child: myThumb,
)''',
    builder: _jelly,
  ),
  DemoEntry(
    id: 'draggable',
    title: 'Draggable',
    blurb: 'The drag wiring, so you do not write it again. '
        'LiquidGlassDraggable wraps any widget, moves it with the finger, '
        'keeps the offset and reports it through onChanged. Ordinary '
        'GestureDetector plumbing done once and correctly: the child keeps '
        'its layout slot, so nothing around it reflows as it travels.\n\n'
        'enabled: false freezes it without unwrapping anything — for a lens '
        'that is arrangeable in one mode of your UI and fixed in another.\n\n'
        'The lens inside is the point of the pairing: drag glass over a '
        'background captured once and the cost is a shader pass, wherever it '
        'ends up.',
    code: '''LiquidGlassDraggable(
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
)''',
    builder: _draggable,
  ),
];

Widget _touch(BuildContext _) => const TouchDemo();
Widget _blend(BuildContext _) => const BlendingDemo();
Widget _capture(BuildContext _) => const CaptureDemo();
Widget _nav(BuildContext _) => const NavDemo();
Widget _controls(BuildContext _) => const ControlsDemo();
Widget _slider(BuildContext _) => const SliderDemo();
Widget _toggle(BuildContext _) => const ToggleDemo();
Widget _button(BuildContext _) => const ButtonDemo();
Widget _appBar(BuildContext _) => const AppBarDemo();
Widget _tabBar(BuildContext _) => const TabBarDemo();
Widget _navBar(BuildContext _) => const NavBarDemo();
Widget _jelly(BuildContext _) => const JellyDemo();
Widget _draggable(BuildContext _) => const DraggableDemo();

/// The demo matching [id], or null when the URL names something unknown.
DemoEntry? demoById(String? id) {
  if (id == null) return null;
  for (final d in kDemos) {
    if (d.id == id) return d;
  }
  return null;
}
