import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Social feed — a real-looking page for judging performance.
//
// A plain scrolling feed with all the glass floating over it: the
// glass tab bar, a header, filter chips, a "new posts" pill, an action
// rail, a now-playing bar, a settings panel and a round button that morphs
// into a menu. None of the glass scrolls.
//
// A batch puts the floating lenses on one shared backdrop read. The
// settings panel switches it off and on, and its Blur sets every glass
// surface on the page, 0 to 20. A batch's members must not overlap, so
// the pieces that would (the pill under the panel, the now-playing bar
// under the open menu) step aside while the other is showing.
//
//   flutter run -t lib/social_feed.dart
// =============================================================

final ValueNotifier<bool> _dark = ValueNotifier<bool>(true);
final ValueNotifier<bool> _overlay = ValueNotifier<bool>(false);
final ValueNotifier<double> _blur = ValueNotifier<double>(3);
final ValueNotifier<bool> _batch = ValueNotifier<bool>(true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Compile the glass programs before the first frame.
  await LiquidGlassShaders.ensureLoaded();
  runApp(const SocialFeedApp());
}

class SocialFeedApp extends StatelessWidget {
  const SocialFeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_dark, _overlay, _batch]),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Social Feed',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: _dark.value ? ThemeMode.dark : ThemeMode.light,
        home: const SocialFeedPage(),
      ),
    );
  }
}

ThemeData _theme(Brightness b) => ThemeData(
      brightness: b,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A84FF),
        brightness: b,
      ),
    );

const List<LiquidGlassTabBarItem> _tabs = [
  LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
  LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Explore'),
  LiquidGlassTabBarItem(icon: Icons.slideshow_rounded, label: 'Reels'),
  LiquidGlassTabBarItem(
      icon: Icons.account_circle_rounded, label: 'Profile'),
];

const List<String> _filters = ['For you', 'Following', 'Trending', 'Nearby'];

// ---------------------------------------------------------------------------
// The page's glass: one blur and one tint for every surface.
// ---------------------------------------------------------------------------

class _Knobs extends InheritedWidget {
  const _Knobs({
    required this.blur,
    required this.dark,
    required super.child,
  });

  final double blur;
  final bool dark;

  static _Knobs of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Knobs>()!;

  @override
  bool updateShouldNotify(_Knobs old) => blur != old.blur || dark != old.dark;
}

LiquidGlassStyle _style(BuildContext context, double radius, {Color? color}) {
  final _Knobs k = _Knobs.of(context);
  return LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: radius),
    blur: k.blur,
    color: color ??
        (k.dark ? const Color(0x33000000) : const Color(0x47FFFFFF)),
  );
}

class _Glass extends StatelessWidget {
  const _Glass({required this.radius, this.color, required this.child});

  final double radius;
  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLens(
      style: _style(context, radius, color: color),
      child: child,
    );
  }
}

Color _ink(BuildContext context) =>
    _Knobs.of(context).dark ? Colors.white : Colors.black;

Color _sub(BuildContext context) =>
    _Knobs.of(context).dark ? Colors.white70 : Colors.black54;

// ---------------------------------------------------------------------------
// Page.
// ---------------------------------------------------------------------------

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  int _tab = 0;
  int _filter = 0;
  bool _menuOpen = false;
  bool _panelOpen = false;
  bool _newPosts = true;

  @override
  Widget build(BuildContext context) {
    // The page carries its own theme and overlay, so the panel's switches
    // work the same from the gallery as standalone.
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_dark, _overlay, _batch]),
      builder: (context, _) => Theme(
        data: _theme(_dark.value ? Brightness.dark : Brightness.light),
        child: Builder(builder: _page),
      ),
    );
  }

  Widget _page(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Color page = dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: page,
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<double>(
              valueListenable: _blur,
              builder: (context, blur, _) => _Knobs(
                blur: blur,
                dark: dark,
                child: LayoutBuilder(
                  builder: (context, c) => _build(context, c, safe, page),
                ),
              ),
            ),
          ),
          if (_overlay.value)
            Positioned(
              left: 0,
              right: 0,
              top: safe.top + 120,
              child: IgnorePointer(child: PerformanceOverlay.allEnabled()),
            ),
        ],
      ),
    );
  }

  Widget _build(
      BuildContext context, BoxConstraints c, EdgeInsets safe, Color page) {
    const double barH = _FeedTabBar.height;
    final double barBottom = safe.bottom + 10;
    final double barTop = barBottom + barH;
    final double top = safe.top + 120;
    // Bottom row: the morph button on the left, the now-playing bar
    // beside it; the rail stands above that row on the right.
    final double rowBottom = barTop + 16;
    const double rowH = 56;

    // Plain content: no glass in here, it all floats in the chrome.
    final Widget content = ColoredBox(
      color: page,
      child: _tab == 1 || _tab == 3
          ? _Grid(
              key: ValueKey('grid$_tab'),
              top: top,
              bottom: barTop + rowH + 40,
              seed: _tab,
            )
          : _Feed(
              key: ValueKey('feed$_tab'),
              top: top,
              bottom: barTop + rowH + 40,
              seed: _tab,
            ),
    );

    return _FeedTabBar(
      selectedIndex: _tab,
      onChanged: (i) => setState(() {
        _tab = i;
        _newPosts = true;
      }),
      body: content,
      blur: _blur.value,
      bottom: barBottom,
      // A batch over every floating lens.
      chrome: LiquidGlassBatch(
        enabled: _batch.value,
        child: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              top: safe.top + 8,
              height: 56,
              child: _Header(
                panelOpen: _panelOpen,
                onPanel: () => setState(() => _panelOpen = !_panelOpen),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: safe.top + 72,
              height: 40,
              child: _FilterChips(
                selected: _filter,
                onSelect: (i) => setState(() => _filter = i),
              ),
            ),
            if (_panelOpen)
              Positioned(
                left: 16,
                right: 16,
                top: safe.top + 122,
                child: const _SettingsPanel(),
              )
            else if (_newPosts)
              Positioned(
                left: 0,
                right: 0,
                top: safe.top + 124,
                height: 36,
                child: Center(
                  child: _NewPostsPill(
                    onTap: () => setState(() => _newPosts = false),
                  ),
                ),
              ),
            Positioned(
              right: 14,
              bottom: rowBottom + rowH + 16,
              child: const _ActionRail(),
            ),
            Positioned(
              left: 16,
              bottom: rowBottom,
              width: 240,
              height: 330,
              child: _MorphMenu(
                open: _menuOpen,
                onToggle: () => setState(() => _menuOpen = !_menuOpen),
              ),
            ),
            if (!_menuOpen)
              Positioned(
                left: 16 + rowH + 12,
                right: 16,
                bottom: rowBottom,
                height: rowH,
                child: const _NowPlaying(),
              ),
          ],
        ),
      ),
    );
  }
}

/// The package's tab bar with its moving glass pill, floating over [body]
/// with [chrome] placed for the renderer.
class _FeedTabBar extends StatelessWidget {
  const _FeedTabBar({
    required this.selectedIndex,
    required this.onChanged,
    required this.body,
    required this.chrome,
    required this.blur,
    required this.bottom,
  });

  static const double height = 62;

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Widget body;
  final Widget chrome;
  final double blur;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return LiquidGlassTabBar(
      items: _tabs,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      width: 328,
      height: height,
      margin: EdgeInsets.only(bottom: bottom),
      itemPadding: 4,
      style: LiquidGlassTabBar.defaultStyle.copyWith(blur: blur),
      pillStyle: const LiquidGlassTabPillStyle(mode: LiquidGlassPillMode.both),
      itemStyle: LiquidGlassTabItemStyle(
        selectedColor: const Color(0xFF0A84FF),
        unselectedColor: dark ? Colors.white : Colors.black,
      ),
    ).buildGlassPillBar(
      body: body,
      chromeChild: chrome,
      batch: _batch.value,
    );
  }
}

// ---------------------------------------------------------------------------
// Floating glass.
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.panelOpen, required this.onPanel});

  final bool panelOpen;
  final VoidCallback onPanel;

  @override
  Widget build(BuildContext context) {
    final Color ink = _ink(context);
    return _Glass(
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.only(left: 18, right: 4),
        child: Row(
          children: [
            Text(
              'Glassgram',
              style: TextStyle(
                color: ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onPanel,
              icon: Icon(
                panelOpen ? Icons.close_rounded : Icons.tune_rounded,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final Color ink = _ink(context);
    return Row(
      children: [
        for (int i = 0; i < _filters.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: _Glass(
                radius: 20,
                color: i == selected ? const Color(0x880A84FF) : null,
                child: Center(
                  child: Text(
                    _filters[i],
                    maxLines: 1,
                    style: TextStyle(
                      color: i == selected ? Colors.white : ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NewPostsPill extends StatelessWidget {
  const _NewPostsPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Glass(
        radius: 18,
        color: const Color(0x990A84FF),
        child: const SizedBox(
          height: 36,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  '12 new posts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating like / comment / share / save buttons.
class _ActionRail extends StatefulWidget {
  const _ActionRail();

  @override
  State<_ActionRail> createState() => _ActionRailState();
}

class _ActionRailState extends State<_ActionRail> {
  bool _liked = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final Color ink = _ink(context);
    Widget button(IconData icon, Color color, String? count, VoidCallback tap) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GestureDetector(
          onTap: tap,
          child: _Glass(
            radius: 26,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: color),
                  if (count != null)
                    Text(count,
                        style: TextStyle(
                            color: ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          _liked ? const Color(0xFFFF375F) : ink,
          _liked ? '4.9k' : '4.8k',
          () => setState(() => _liked = !_liked),
        ),
        button(Icons.chat_bubble_outline_rounded, ink, '312', () {}),
        button(Icons.send_rounded, ink, null, () {}),
        button(
          _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          _saved ? const Color(0xFFFFD60A) : ink,
          null,
          () => setState(() => _saved = !_saved),
        ),
      ],
    );
  }
}

class _NowPlaying extends StatefulWidget {
  const _NowPlaying();

  @override
  State<_NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<_NowPlaying> {
  bool _playing = true;

  @override
  Widget build(BuildContext context) {
    final Color ink = _ink(context);
    final Color sub = _sub(context);
    return _Glass(
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF375F), Color(0xFF5E5CE6)],
                ),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Golden Hour',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('Lina Haddad · Original audio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sub, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _playing = !_playing),
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    final Color ink = _ink(context);
    final Color sub = _sub(context);
    final TextStyle label =
        TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w600);
    final bool impeller = ui.ImageFilter.isShaderFilterSupported;
    return _Glass(
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _blur,
              builder: (context, blur, _) => Row(
                children: [
                  Icon(Icons.blur_on_rounded, size: 20, color: ink),
                  const SizedBox(width: 10),
                  Text('Blur', style: label),
                  Expanded(
                    child: Slider(
                      value: blur,
                      min: 0,
                      max: 20,
                      divisions: 40,
                      onChanged: (v) => _blur.value = v,
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      blur.toStringAsFixed(1),
                      textAlign: TextAlign.end,
                      style: label,
                    ),
                  ),
                ],
              ),
            ),
            _switchRow(Icons.join_full_rounded, 'Batch', _batch, ink, label),
            _switchRow(Icons.speed_rounded, 'Performance overlay', _overlay,
                ink, label),
            _switchRow(Icons.dark_mode_rounded, 'Dark mode', _dark, ink, label),
            const SizedBox(height: 4),
            Text(
              impeller
                  ? 'Impeller: a batch shares one backdrop read.'
                  : 'Skia: batching has no effect on this renderer.',
              style: TextStyle(color: sub, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(IconData icon, String text, ValueNotifier<bool> value,
      Color ink, TextStyle label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: ink),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: label)),
        ValueListenableBuilder<bool>(
          valueListenable: value,
          builder: (context, on, _) => Transform.scale(
            scale: 0.8,
            child: Switch(value: on, onChanged: (v) => value.value = v),
          ),
        ),
      ],
    );
  }
}

class _MorphMenu extends StatelessWidget {
  const _MorphMenu({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  static const List<(IconData, String)> _entries = [
    (Icons.photo_camera_rounded, 'New post'),
    (Icons.auto_awesome_rounded, 'Story'),
    (Icons.movie_creation_rounded, 'Reel'),
    (Icons.sensors_rounded, 'Go live'),
    (Icons.close_rounded, 'Close'),
  ];

  @override
  Widget build(BuildContext context) {
    final Color ink = _ink(context);
    return LiquidGlassMorph(
      alignment: Alignment.bottomLeft,
      motion: LiquidGlassMorphMotion.plain,
      style: _style(context, 28),
      child: open
          ? SizedBox(
              key: const ValueKey('menu'),
              width: 220,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (IconData icon, String label) in _entries)
                      InkWell(
                        onTap: onToggle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 13),
                          child: Row(
                            children: [
                              Icon(icon, size: 22, color: ink),
                              const SizedBox(width: 14),
                              Text(
                                label,
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : GestureDetector(
              key: const ValueKey('button'),
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.add_rounded, size: 30, color: ink),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feed content: plain widgets, no glass.
// ---------------------------------------------------------------------------

const List<String> _names = [
  'Lina Haddad', 'Omar Farouk', 'Maya Chen', 'Yusuf Ali', 'Sara Lind',
  'Karim Nasser', 'Nour Saleh', 'Diego Ruiz', 'Aya Mostafa', 'Leo Martin',
  'Hana Kim', 'Adam Fawzi', 'Zoe Park', 'Tariq Aziz', 'Mira Costa',
];

const List<String> _captions = [
  'Golden hour never misses. Took this on the way back from work.',
  'Trying a new coffee place downtown, the cardamom latte is unreal.',
  'Weekend hike done. Legs are gone, view was worth it.',
  'Finally finished the side project I have been talking about for months.',
  'Rainy days are for reading and slow music.',
  'New desk setup, minimal but cozy. Thoughts?',
  'Grandma\'s recipe, my kitchen. Still not as good as hers.',
  'Sunsets from the rooftop hit different in October.',
];

const List<String> _photos = [
  'assets/feed/flower.jpg',
  'assets/feed/mountain.jpg',
];

Color _hue(int i, {double s = 0.65, double l = 0.55}) =>
    HSLColor.fromAHSL(1, (i * 47.0) % 360, s, l).toColor();

class _Feed extends StatelessWidget {
  const _Feed({
    super.key,
    required this.top,
    required this.bottom,
    required this.seed,
  });

  final double top;
  final double bottom;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: top)),
        const SliverToBoxAdapter(child: _Stories()),
        SliverList.builder(
          itemCount: 300,
          itemBuilder: (context, i) => _Post(index: i + seed * 300),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: bottom)),
      ],
    );
  }
}

class _Stories extends StatelessWidget {
  const _Stories();

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: 20,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [
                    _hue(i * 3),
                    _hue(i * 3 + 2),
                    _hue(i * 3 + 4),
                    _hue(i * 3),
                  ]),
                ),
                child: _Avatar(
                    index: i,
                    size: 62,
                    ring: dark ? Colors.black : Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                _names[i % _names.length].split(' ').first,
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.index, required this.size, this.ring});

  final int index;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final String name = _names[index % _names.length];
    final String initials = name.split(' ').map((w) => w[0]).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ring!, width: 2.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_hue(index * 5), _hue(index * 5 + 3, l: 0.4)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

class _Post extends StatelessWidget {
  const _Post({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = dark ? Colors.white : Colors.black;
    final Color sub = dark ? Colors.white60 : Colors.black54;
    final String name = _names[index % _names.length];
    final int kind = index % 4;
    final int likes = 37 + (index * 7919) % 4800;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 10),
            child: Row(
              children: [
                _Avatar(index: index, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text(
                          '@${name.split(' ').first.toLowerCase()} · ${1 + index % 23}h',
                          style: TextStyle(color: sub, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz_rounded, color: sub),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (kind == 0 || kind == 2)
            AspectRatio(
              aspectRatio: kind == 0 ? 1 : 4 / 5,
              child: Image.asset(
                _photos[(index ~/ 2) % _photos.length],
                fit: BoxFit.cover,
                cacheWidth: 1080,
                alignment: Alignment((index % 5) / 2 - 1, 0),
              ),
            )
          else if (kind == 1)
            _ArtCard(index: index)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                _captions[(index * 3) % _captions.length] * 2,
                style: TextStyle(color: ink, fontSize: 17, height: 1.35),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                IconButton(
                    onPressed: () {},
                    icon: Icon(
                        index % 3 == 0
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: index % 3 == 0 ? const Color(0xFFFF375F) : ink)),
                Text('$likes', style: TextStyle(color: ink, fontSize: 13)),
                IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.chat_bubble_outline_rounded, color: ink)),
                Text('${likes ~/ 12}', style: TextStyle(color: ink, fontSize: 13)),
                IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.repeat_rounded, color: ink)),
                const Spacer(),
                IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.bookmark_border_rounded, color: ink)),
              ],
            ),
          ),
          if (kind != 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${name.split(' ').first.toLowerCase()} ',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: _captions[index % _captions.length]),
                ]),
                style: TextStyle(color: ink, fontSize: 14, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bright generated artwork, so the glass has colour to bend.
class _ArtCard extends StatelessWidget {
  const _ArtCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final math.Random r = math.Random(index);
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _hue(index * 7, s: 0.8, l: 0.55),
              _hue(index * 7 + 3, s: 0.8, l: 0.45),
              _hue(index * 7 + 6, s: 0.7, l: 0.3),
            ],
          ),
        ),
        child: Stack(
          children: [
            for (int k = 0; k < 6; k++)
              Positioned(
                left: r.nextDouble() * 300,
                top: r.nextDouble() * 300,
                child: Container(
                  width: 40 + r.nextDouble() * 120,
                  height: 40 + r.nextDouble() * 120,
                  decoration: BoxDecoration(
                    shape: k.isEven ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius:
                        k.isEven ? null : BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.12 + r.nextDouble() * 0.2),
                  ),
                ),
              ),
            Center(
              child: Text(
                ['Design', 'Travel', 'Music', 'Food', 'Code', 'Art'][index % 6],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    super.key,
    required this.top,
    required this.bottom,
    required this.seed,
  });

  final double top;
  final double bottom;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(2, top, 2, bottom),
          sliver: SliverGrid.builder(
            itemCount: 600,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemBuilder: (context, i) {
              final int n = i + seed * 600;
              return n % 3 == 0
                  ? Image.asset(
                      _photos[n % _photos.length],
                      fit: BoxFit.cover,
                      cacheWidth: 360,
                      alignment: Alignment((n % 7) / 3 - 1, (n % 5) / 2 - 1),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _hue(n * 11, s: 0.75),
                            _hue(n * 11 + 4, s: 0.75, l: 0.35),
                          ],
                        ),
                      ),
                    );
            },
          ),
        ),
      ],
    );
  }
}
