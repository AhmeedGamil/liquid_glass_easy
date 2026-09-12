import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Scaffold — LiquidGlassScaffold on a light page.
//
//   flutter run -t lib/scaffold_page.dart
//
// The scaffold IS the glass pipeline: it owns the view, and everything it
// places refracts its body. What it can place is a fixed set of slots —
// appBar, bottomNavigationBar, its action, a floating action button, the
// free-floating `lenses` list, and the dialog — and the chips at the top
// of the feed put exactly ONE of them on the page at a time.
//
// That is the whole page: the same scaffold, the same feed, one slot
// filled. Every slot is glass over the same captured body, so switching
// between them is a way to see what each one is for without a second
// surface in the frame arguing with it.
//
// The feed underneath is a light page with a red glow, so the frosted
// glass has colour to bend as it scrolls.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const ScaffoldPage(),
    ),
  );
}

const Color _kBrand = Color(0xFFFF3B30);
const Color _kInk = Color(0xFF121215);

/// The frosted-white capsule material over a soft optical rim.
LiquidGlassShape _frostShape(double cornerRadius) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 0.7,
      lightIntensity: 0.9,
      lightDirection: 62,
      borderType: const OpticalBorder(
        borderSaturation: 1.1,
        ambientIntensity: 0.85,
        borderSolidity: 0.95,
      ),
    );

LiquidGlassStyle _frost(double cornerRadius) => LiquidGlassStyle(
      shape: _frostShape(cornerRadius),
      appearance: const LiquidGlassAppearance(
        color: Color(0x8FFFFFFF),
        blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
        shadow: LiquidGlassShadow(blur: 9, opacity: 0.13),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.06,
        distortionWidth: 26,
      ),
    );

class ScaffoldPage extends StatefulWidget {
  const ScaffoldPage({super.key});

  @override
  State<ScaffoldPage> createState() => _ScaffoldPageState();
}

/// The scaffold's slots, one chip each. Picking one is what puts it — and
/// only it — on the page.
enum _Slot {
  none('body only', 'no slot at all — the captured page on its own'),
  appBar('app bar', 'appBar'),
  navBar('nav bar', 'bottomNavigationBar'),
  action('action', 'bottomNavigationBarAction'),
  fab('FAB', 'floatingActionButton'),
  lenses('lenses', 'lenses'),
  dialog('dialog', 'dialog + onDialogDismissed');

  const _Slot(this.label, this.param);

  /// What the chip says — short, because seven parameter names in a row
  /// would each be most of a phone's width.
  final String label;

  /// The real parameter, printed under the row so the short label is
  /// never the only name you are given.
  final String param;
}

class _ScaffoldPageState extends State<ScaffoldPage> {
  int _tab = 0;
  _Slot _slot = _Slot.navBar;

  static const double _barHeight = 60;

  static const List<(IconData, String, String)> _tabs =
      <(IconData, String, String)>[
    (Icons.home_rounded, 'Home', 'For you'),
    (Icons.grid_view_rounded, 'Browse', 'Browse'),
    (Icons.library_music_outlined, 'Library', 'Your library'),
  ];

  static final List<LiquidGlassTabBarItem> _items = <LiquidGlassTabBarItem>[
    for (final (IconData icon, String label, _) in _tabs)
      LiquidGlassTabBarItem(icon: icon, label: label),
  ];

  @override
  Widget build(BuildContext context) {
    final double screen = MediaQuery.sizeOf(context).width;
    // The bar is the only thing on the row here, so it takes the width a
    // lone capsule would: nothing is parked beside it to leave room for.
    final double barWidth = (screen - 32).clamp(220.0, 480.0);

    // One slot at a time: every one of these is null unless it is the one
    // the chips have picked, so the page never has two glass surfaces on
    // it to compare against each other.
    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,

      appBar: _slot == _Slot.appBar
          ? DemoHeader(
              title: _tabs[_tab].$3,
              foreground: _kInk,
              style: _frost(DemoHeader.height / 2),
            )
          : null,

      body: _Feed(
        title: _tabs[_tab].$3,
        seed: _tab,
        slot: _slot,
        onSlot: (_Slot v) => setState(() => _slot = v),
        // The feed starts under the header only when there is one.
        topInset: _slot == _Slot.appBar ? 96 : 34,
      ),

      bottomNavigationBar: _slot == _Slot.navBar
          ? LiquidGlassTabBar(
              items: _items,
              selectedIndex: _tab,
              onChanged: (int i) => setState(() => _tab = i),
              width: barWidth,
              height: _barHeight,
              itemPadding: 3,
              margin: const EdgeInsets.only(bottom: 22),
              style: _frost(_barHeight / 2),
              itemStyle: const LiquidGlassTabItemStyle(
                selectedColor: _kBrand,
                unselectedColor: _kInk,
                iconSize: 24,
                labelFontSize: 10,
                iconLabelGap: 2,
                selectedFontWeight: FontWeight.w700,
                unselectedFontWeight: FontWeight.w600,
              ),
              pillStyle: LiquidGlassTabPillStyle(
                rest: LiquidGlassStyle(
                  shape: _frostShape(28),
                  appearance:
                      const LiquidGlassAppearance(color: Color(0x2EAEAEB2)),
                ),
              ),
            )
          : null,

      // The round action the scaffold floats beside the bar. Its bottom
      // gap rides the BAR's `margin.bottom`, so with no bar in the tree
      // it sits on the safe-area edge — which is the slot telling you it
      // is meant to be one of a pair.
      bottomNavigationBarAction: _slot == _Slot.action
          ? LiquidGlassTabBarAction(
              icon: Icons.add_rounded,
              size: _barHeight,
              foregroundColor: _kInk,
              style: _frost(_barHeight / 2),
              onTap: () => setState(() => _slot = _Slot.dialog),
            )
          : null,

      // The FAB slot, with its own alignment rather than the bar's column.
      floatingActionButton: _slot == _Slot.fab
          ? LiquidGlassFab.extended(
              label: const Text('Play all'),
              icon: Icons.play_arrow_rounded,
              foregroundColor: _kInk,
              style: _frost(24),
              onPressed: () => setState(() => _slot = _Slot.dialog),
            )
          : null,
      floatingActionButtonAlignment: Alignment.bottomRight,

      // The escape hatch: glass the scaffold composites over the body but
      // does not place for you. Position each one yourself.
      lenses: _slot == _Slot.lenses
          ? <Widget>[
              Align(
                alignment: const Alignment(-0.72, 0.62),
                child: SizedBox(
                  width: 124,
                  height: 124,
                  child: LiquidGlassLens(
                    style: _frost(62),
                    child: const Center(
                      child: Icon(Icons.graphic_eq_rounded,
                          color: _kInk, size: 30),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0.78, 0.3),
                child: SizedBox(
                  width: 92,
                  height: 148,
                  child: LiquidGlassLens(
                    style: _frost(28),
                    child: const Center(
                      child: Icon(Icons.equalizer_rounded,
                          color: _kInk, size: 26),
                    ),
                  ),
                ),
              ),
            ]
          : const <Widget>[],

      // The dialog slot: a widget the scaffold animates in over its own
      // barrier, cleared through onDialogDismissed.
      dialog: _slot == _Slot.dialog
          ? LiquidGlassAlertDialog(
              icon: const Icon(Icons.playlist_add_rounded, color: _kBrand),
              title: const Text('New playlist'),
              content: const Text(
                "The scaffold's own dialog slot: glass over the same feed "
                'the bars refract, on a barrier it owns. Dismiss it and the '
                'page goes back to no slot at all.',
              ),
              actions: <Widget>[
                LiquidGlassButton(
                  label: 'Done',
                  onPressed: () => setState(() => _slot = _Slot.none),
                ),
              ],
            )
          : null,
      onDialogDismissed: () => setState(() => _slot = _Slot.none),
    );
  }
}

/// The light page behind the glass: a grey gradient, a red glow, a hero
/// card and a list of rows — enough colour and edges for frosted glass
/// to have something to do.
class _Feed extends StatelessWidget {
  final String title;
  final int seed;

  /// The slot that is on, and the way back out. The picker rides IN the
  /// feed rather than over it: it is part of the body the scaffold
  /// captures, so whichever slot is showing refracts its own chips.
  final _Slot slot;
  final ValueChanged<_Slot> onSlot;

  /// How far down the list starts — clear of the header when there is
  /// one, tight to the top when there is not.
  final double topInset;

  const _Feed({
    required this.title,
    required this.seed,
    required this.slot,
    required this.onSlot,
    required this.topInset,
  });

  static const List<(String, String, String)> _rows =
      <(String, String, String)>[
    ('Signal Lost', 'Kova · 4:12', 'r1'),
    ('Analog Heart', 'June Wilder · 3:38', 'r2'),
    ('Neon Rain', 'The Hours · 5:02', 'r3'),
    ('Slow Burn', 'Marisa Oak · 4:47', 'r4'),
    ('Paper Moon', 'Ilse Varga · 3:21', 'r5'),
    ('Low Tide', 'Cassiel · 4:03', 'r6'),
    ('Half Light', 'The Hours · 3:56', 'r7'),
    ('Ember', 'Kova · 4:30', 'r8'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFFE7E5EB),
                    Color(0xFFDBD9E2),
                    Color(0xFFCFCDD8),
                  ],
                  stops: <double>[0, 0.45, 1],
                ),
              ),
            ),
          ),
          const Positioned(top: -110, right: -80, child: _Glow(size: 340)),
          const Positioned(bottom: 40, left: -130, child: _Glow(size: 320)),
          ListView(
            padding: EdgeInsets.fromLTRB(20, topInset, 20, 150),
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 16),
              _SlotPicker(slot: slot, onChanged: onSlot),
              const SizedBox(height: 20),
              _hero(),
              const SizedBox(height: 26),
              const Text(
                'Recently played',
                style: TextStyle(
                  color: _kInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              for (int i = 0; i < _rows.length; i++) ...<Widget>[
                _row(_rows[i]),
                if (i != _rows.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: <Widget>[
          Image.network(
            'https://picsum.photos/seed/onair$seed/900/620',
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const SizedBox(height: 220, child: DemoBackdrop(seed: 2)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: <Color>[
                    _kBrand.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const <double>[0, 0.5, 1],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'The Midnight Signal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'with Nadia Rey · 2 hrs left',
                  style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row((String, String, String) r) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kInk.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://picsum.photos/seed/${r.$3}/120/120',
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 54,
                height: 54,
                child: DemoBackdrop(seed: 3),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  r.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  r.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kInk.withValues(alpha: 0.55),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill_rounded, color: _kBrand, size: 32),
        ],
      ),
    );
  }
}

/// The slot chips.
///
/// A scrollable row rather than a wrap: the slot names are the real
/// parameter names, some of them long, and a wrap of them would run to
/// three lines and push the feed down every time one was picked.
class _SlotPicker extends StatelessWidget {
  const _SlotPicker({required this.slot, required this.onChanged});

  final _Slot slot;
  final ValueChanged<_Slot> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'SLOT',
          style: TextStyle(
            color: _kInk.withValues(alpha: 0.45),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _Slot.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) {
              final _Slot s = _Slot.values[i];
              return Align(
                child: _SlotChip(
                  label: s.label,
                  selected: s == slot,
                  onTap: () => onChanged(s),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slot.param,
          style: TextStyle(
            color: _kInk.withValues(alpha: 0.5),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kBrand : Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color:
                  selected ? Colors.transparent : _kInk.withValues(alpha: 0.10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _kInk.withValues(alpha: 0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft red bloom behind the feed.
class _Glow extends StatelessWidget {
  final double size;
  const _Glow({required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              _kBrand.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
