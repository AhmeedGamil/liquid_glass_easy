import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// **Scaffold + glass nav** — a real tabbed app, not a colour swatch.
///
/// [LiquidGlassScaffold] owns the glass pipeline: it captures its own `body`
/// and hands it to the bar, so the floating nav refracts your page on both
/// backends — including the web, which never runs Impeller.
///
/// ## Why `IndexedStack`
///
/// Swapping `body` for a different widget on every tap is the obvious way to
/// wire a bottom bar, and it is the one that bites: each tab is rebuilt from
/// scratch, so scroll position, form input and loaded data are all thrown
/// away. [IndexedStack] keeps every tab **mounted** and shows one, which is
/// the standard fix — scroll a feed, switch away, come back, and you are
/// where you left off.
///
/// The cost is that all four tabs build up front. That is the right trade for
/// four cheap pages; for a dozen expensive ones you would want
/// `AutomaticKeepAliveClientMixin` and lazily built tabs instead.
///
/// Worth knowing before you copy this: `IndexedStack` preserves tab *state*,
/// not a navigation *stack*. If a tab needs its own push/pop history, give
/// each one its own `Navigator` inside the stack.
///
/// ## Why not the glass pill
///
/// `pillStyle.mode` stays at its default `none`, so the selection is a soft
/// sliding highlight. The glass morph pill adds a SECOND full-page capture on
/// top of this one; on Skia — all a browser gives you — that is too much
/// beside a scrolling feed. On Impeller nothing is captured at all, so there
/// it is free.
class NavDemo extends StatefulWidget {
  const NavDemo({super.key});

  @override
  State<NavDemo> createState() => _NavDemoState();
}

class _NavDemoState extends State<NavDemo> {
  int _index = 0;

  /// Lives here, above the tabs, so Saved and Browse agree on what is saved.
  /// Tab-local state stays in the tabs; shared state does not.
  final Set<int> _saved = <int>{1, 4};

  void _toggleSaved(int id) => setState(() {
        _saved.contains(id) ? _saved.remove(id) : _saved.add(id);
      });

  static const _items = [
    LiquidGlassTabBarItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      label: 'Browse',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.bookmark_outline_rounded,
      selectedIcon: Icons.bookmark_rounded,
      label: 'Saved',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'You',
    ),
  ];

  /// The rim shared by the bar capsule and its highlight.
  static LiquidGlassShape _navGlass(double cornerRadius) =>
      LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: cornerRadius,
        clipQuality: LiquidGlassClipQuality.exact,
        borderWidth: 0.8,
        lightIntensity: 1.1,
        lightDirection: 39,
        borderType: const OpticalBorder(
          borderSaturation: 1.2,
          ambientIntensity: 1.0,
          borderSolidity: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LiquidGlassScaffold(
      // A capture runs per frame on Skia; 1.0 keeps it honest on the web
      // without visibly softening the refraction.
      pixelRatio: 1,
      useSync: true,

      // Every tab stays mounted. Only the visible one is painted, so the
      // scroll offsets and the little bits of state inside each survive.
      body: IndexedStack(
        index: _index,
        children: [
          HomeTab(saved: _saved, onToggleSaved: _toggleSaved),
          BrowseTab(saved: _saved, onToggleSaved: _toggleSaved),
          SavedTab(saved: _saved, onToggleSaved: _toggleSaved),
          const ProfileTab(),
        ],
      ),

      bottomNavigationBar: LiquidGlassBottomNavBar(
        items: _items,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        width: 300,
        margin: const EdgeInsets.only(bottom: 22),
        style: LiquidGlassStyle(
          shape: _navGlass(50),
          appearance: const LiquidGlassAppearance(
            color: Color(0x40000000),
            blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
          ),
        ),
        pillStyle: const LiquidGlassNavPillStyle(
          animated: true,
          color: Color(0x2EFFFFFF),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Tabs
// ══════════════════════════════════════════════════════════════════

const List<(String, String, Color)> _catalog = [
  ('Midnight Drive', 'Nocturne', Color(0xFF7C5CFF)),
  ('Paper Lanterns', 'Hazel Fox', Color(0xFFFF5C8A)),
  ('Low Tide', 'Ana Reyes', Color(0xFF2DD4BF)),
  ('Copper Sun', 'The Vale', Color(0xFFFFB020)),
  ('Glass House', 'Sonder', Color(0xFF4FB3FF)),
  ('Slow Static', 'Marden', Color(0xFFA78BFA)),
  ('Northbound', 'Ivy Lake', Color(0xFF34D399)),
  ('Afterimage', 'Kestrel', Color(0xFFF97316)),
];

/// Scrollable feed. Scroll it, switch tabs, come back — the offset is still
/// here, and that is the whole point of the `IndexedStack`.
class HomeTab extends StatelessWidget {
  final Set<int> saved;
  final ValueChanged<int> onToggleSaved;

  const HomeTab({super.key, required this.saved, required this.onToggleSaved});

  @override
  Widget build(BuildContext context) {
    return _TabSurface(
      accent: const Color(0xFF7C5CFF),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 130),
        children: [
          const _TabHeader(overline: 'TUESDAY', title: 'Good evening'),
          const _NowPlaying(),
          const SizedBox(height: 20),
          const _SectionLabel('Recently played'),
          const SizedBox(height: 8),
          for (int i = 0; i < _catalog.length; i++)
            _TrackRow(
              id: i,
              saved: saved.contains(i),
              onToggleSaved: () => onToggleSaved(i),
            ),
        ],
      ),
    );
  }
}

/// A grid, and a tab-local filter. The chip you pick is state that lives
/// *inside* this tab — leave, come back, and it is unchanged.
class BrowseTab extends StatefulWidget {
  final Set<int> saved;
  final ValueChanged<int> onToggleSaved;

  const BrowseTab(
      {super.key, required this.saved, required this.onToggleSaved});

  @override
  State<BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<BrowseTab> {
  static const _filters = ['All', 'Ambient', 'Focus', 'Late night'];
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    return _TabSurface(
      accent: const Color(0xFFFF5C8A),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int columns = constraints.maxWidth < 560 ? 2 : 3;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 130),
            children: [
              const _TabHeader(overline: 'CATALOGUE', title: 'Browse'),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _FilterChip(
                    label: _filters[i],
                    selected: _filter == i,
                    onTap: () => setState(() => _filter = i),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
                children: [
                  for (int i = 0; i < _catalog.length; i++)
                    _AlbumTile(
                      id: i,
                      saved: widget.saved.contains(i),
                      onToggleSaved: () => widget.onToggleSaved(i),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reads the shared set. Save something in Home or Browse and it is already
/// here — state that belongs to the app, not to a tab, lives above them.
class SavedTab extends StatelessWidget {
  final Set<int> saved;
  final ValueChanged<int> onToggleSaved;

  const SavedTab({super.key, required this.saved, required this.onToggleSaved});

  @override
  Widget build(BuildContext context) {
    final ids = saved.toList()..sort();
    return _TabSurface(
      accent: const Color(0xFF2DD4BF),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 130),
        children: [
          _TabHeader(
            overline: '${ids.length} ITEM${ids.length == 1 ? '' : 'S'}',
            title: 'Saved',
          ),
          if (ids.isEmpty)
            const _Empty(
              icon: Icons.bookmark_border_rounded,
              text: 'Tap the bookmark on any track to keep it here.',
            )
          else
            for (final id in ids)
              _TrackRow(
                id: id,
                saved: true,
                onToggleSaved: () => onToggleSaved(id),
              ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _TabSurface(
      accent: const Color(0xFFFFB020),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 130),
        children: [
          const _TabHeader(overline: 'ACCOUNT', title: 'You'),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFB020), Color(0xFFFF5C8A)],
                  ),
                ),
                child: const Center(
                  child: Text('AG',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ahmed',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Premium · since 2024',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (final (icon, label) in const [
            (Icons.download_rounded, 'Downloads'),
            (Icons.history_rounded, 'Listening history'),
            (Icons.equalizer_rounded, 'Audio quality'),
            (Icons.notifications_none_rounded, 'Notifications'),
            (Icons.help_outline_rounded, 'Help'),
          ])
            _SettingRow(icon: icon, label: label),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Shared tab furniture
// ══════════════════════════════════════════════════════════════════

/// The coloured wash behind a tab. This is what the bar refracts, so every
/// tab is a different hue — switching tabs visibly changes the glass.
class _TabSurface extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _TabSurface({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent,
            Color.lerp(accent, const Color(0xFF0B0B12), 0.62)!,
            const Color(0xFF0B0B12),
          ],
          stops: const [0, 0.42, 1],
        ),
      ),
      child: child,
    );
  }
}

class _TabHeader extends StatelessWidget {
  final String overline;
  final String title;

  const _TabHeader({required this.overline, required this.title});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              overline,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.06),
        ]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFF7C5CFF)],
              ),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Color(0xFF0B0B12), size: 34),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Midnight Drive',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('Nocturne',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                SizedBox(height: 10),
                _Progress(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: 0.42,
        minHeight: 3,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        valueColor: const AlwaysStoppedAnimation(Colors.white),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final int id;
  final bool saved;
  final VoidCallback onToggleSaved;

  const _TrackRow({
    required this.id,
    required this.saved,
    required this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    final (title, artist, color) = _catalog[id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: LinearGradient(colors: [
                Color.lerp(color, Colors.white, 0.28)!,
                Color.lerp(color, const Color(0xFF0B0B12), 0.42)!,
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(artist,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggleSaved,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: saved
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.45),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final int id;
  final bool saved;
  final VoidCallback onToggleSaved;

  const _AlbumTile({
    required this.id,
    required this.saved,
    required this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    final (title, artist, color) = _catalog[id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(color, Colors.white, 0.25)!,
                        Color.lerp(color, const Color(0xFF0B0B12), 0.5)!,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: IconButton(
                  onPressed: onToggleSaved,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
        Text(artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0B0B12) : Colors.white,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SettingRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 19),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.4), size: 20),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.35), size: 40),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
