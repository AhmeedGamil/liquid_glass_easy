/// The demos the site links to and embeds.
///
/// Deliberately a plain-Dart copy of the ids in `web_demos`' registry: that
/// one imports Flutter, and the generator must run under bare `dart run`.
/// Only the id has to match — it is the `?d=` value in the embed URL.
library;

class SiteDemo {
  final String id;
  final String title;
  final String blurb;

  /// Whether the landing page lists this demo.
  ///
  /// The per-component demos are `false`: they are the example on their own
  /// docs page, and a landing grid of thirteen cards would bury the five that
  /// show what the package is.
  final bool feature;

  const SiteDemo(this.id, this.title, this.blurb, {this.feature = true});

  /// The full app, with its notes column beside the demo.
  String get href => 'demos/index.html?d=$id';

  /// The bare demo, for an `<iframe>`.
  String get embedHref => 'demos/index.html?d=$id&amp;embed=1';
}

const List<SiteDemo> kSiteDemos = [
  SiteDemo('touch', 'Touch',
      'Press and drag a glass card — it deforms, and never moves.'),
  SiteDemo('blend', 'Blend',
      'Drag two lenses together and watch their outlines fuse into one.'),
  SiteDemo('capture', 'Capture once',
      'Drag a lens over a background that was rasterized exactly once.'),
  SiteDemo('nav', 'Scaffold + glass nav',
      'A real four-tab app under a floating bar that refracts it.'),
  SiteDemo('controls', 'Slider + toggle',
      'The drop-in controls, wired to something that actually changes.'),

  // One per component page. Reachable from the docs, not from the index.
  SiteDemo('slider', 'Slider',
      'The slider alone: layouts, colours, and the two value callbacks.',
      feature: false),
  SiteDemo('toggle', 'Toggle',
      'Switches that govern each other, in three sizes.',
      feature: false),
  SiteDemo('button', 'Button',
      'Glass buttons that give under a press — labels, custom children.',
      feature: false),
  SiteDemo('appbar', 'App bar',
      'A floating bar with a feed scrolling under it.',
      feature: false),
  SiteDemo('tabbar', 'Tab bar',
      'A glass tab capsule over a page that changes with it.',
      feature: false),
  SiteDemo('navbar', 'Bottom nav bar',
      'The bar and its two selection tiers, side by side.',
      feature: false),
  SiteDemo('jelly', 'Jelly',
      'The soft-body spring on its own, driven by a slider.',
      feature: false),
  SiteDemo('draggable', 'Draggable',
      'Drag wiring around a lens, reporting its offset.',
      feature: false),
];

SiteDemo? siteDemoById(String id) {
  for (final d in kSiteDemos) {
    if (d.id == id) return d;
  }
  return null;
}
