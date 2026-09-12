// A working use of [LiquidGlassMorph]: a search control that grows from a
// button straight into a results panel — anchored to a corner, so it opens
// the way a real toolbar control has to.
//
//   flutter run -t lib/morph_page.dart
//   …or open "Morph Component" from the gallery.

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const LiquidGlassMorphExamplePage(),
      );
}

/// The two shapes the one surface takes.
enum _Step { button, panel }

class LiquidGlassMorphExamplePage extends StatefulWidget {
  const LiquidGlassMorphExamplePage({super.key});

  @override
  State<LiquidGlassMorphExamplePage> createState() =>
      _LiquidGlassMorphExamplePageState();
}

class _LiquidGlassMorphExamplePageState
    extends State<LiquidGlassMorphExamplePage> {
  static const String _wallpaper =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  _Step _step = _Step.button;

  /// The corner the surface grows out of. Change it and the SAME code opens
  /// the other way — that is the whole point of the parameter.
  Alignment _anchor = Alignment.bottomRight;

  /// The motion presets, by name — the whole choice a caller makes.
  static const Map<String, LiquidGlassMorphMotion> _motions =
      <String, LiquidGlassMorphMotion>{
    'fluid': LiquidGlassMorphMotion.fluid,
    'anchored pop': LiquidGlassMorphMotion.anchoredPop,
    'droplet': LiquidGlassMorphMotion.droplet,
    'calm': LiquidGlassMorphMotion.calm,
    // One lens on one spring, no second blob and no blender: a plain
    // resize, with the content still cross-fading on the morph's clock.
    'plain': LiquidGlassMorphMotion.plain,
  };
  String _motion = 'fluid';

  /// Whether the options panel is showing its controls.
  bool _controlsOpen = true;

  /// Outline the blender's backdrop clip region. Off by default; turn it on
  /// while tuning the morph — it is the one control whose region moves every
  /// frame.
  bool _debugBounds = false;

  // ── The morph's tunables ──────────────────────────────────────────
  double _morphBlur = 7;

  /// Peak neck radius between the morph's two blobs. 0 is a hard union —
  /// no smin, so the merged field is a plain `min()` of the members and
  /// stays a true distance field.
  double _smoothness = 40;

  /// The glass, with the shape it should be resting in. `LiquidGlassMorph`
  /// animates the radius and swaps the corner curve mid-travel; the rest
  /// of the material is passed straight through.
  LiquidGlassShape get _shape => LiquidGlassShape(
        cornerStyle: _step == _Step.panel
            ? LiquidGlassCornerStyle.squircle
            : LiquidGlassCornerStyle.continuousRoundedRectangle,
        cornerRadius: _step == _Step.panel ? 30 : 28,
        borderWidth: 1.4,
      );

  LiquidGlassStyle get _style => LiquidGlassStyle(
        shape: _shape,
        appearance: LiquidGlassAppearance(
          color: const Color(0x1FFFFFFF),
          saturation: 1.06,
          blur: LiquidGlassBlur(sigmaX: _morphBlur, sigmaY: _morphBlur),
        ),
        // Fixed, not a knob: the refraction is what the morph is tuned
        // to wear, and the panel is about the shapes it takes.
        refraction: const LiquidGlassRefraction(
          refractionType: OpticalRefraction(
            refraction: 1.5,
            refractionWidth: 22,
            depth: 0.5,
          ),
        ),
      );

  /// The panel row last tapped, so a tap inside the panel visibly lands
  /// there instead of closing it.
  int? _selectedRow;

  Widget get _content => switch (_step) {
        _Step.button => _Button(
            key: const ValueKey<String>('button'),
            onTap: _open,
          ),
        _Step.panel => _Panel(
            key: const ValueKey<String>('panel'),
            selected: _selectedRow,
            onSelect: (int i) => setState(() => _selectedRow = i),
          ),
      };

  void _open() => setState(() => _step = _Step.panel);

  /// Only a tap that reached the field itself — outside the glass — closes
  /// the panel; the button and the panel's rows claim their own taps.
  void _closeIfOpen() {
    if (_step == _Step.panel) setState(() => _step = _Step.button);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('LiquidGlassMorph'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'Blender clip bounds',
            icon: Icon(
              _debugBounds ? Icons.crop_free : Icons.crop_free_outlined,
              color: _debugBounds ? const Color(0xFFFF00FF) : Colors.white70,
            ),
            onPressed: () => setState(() => _debugBounds = !_debugBounds),
          ),
        ],
      ),
      body: LiquidGlassView(
        backgroundWidget: const _Background(url: _wallpaper),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 44),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  // The component fills this padded box and anchors the
                  // glass inside it. That box IS the field the alignment
                  // resolves against, so anchoring is a matter of where
                  // you put it.
                  // The field catches taps the glass did not: with the
                  // panel open, one outside it closes the panel. Inside
                  // the glass the button opens and the rows select, and
                  // being the innermost recognisers they win the arena.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeIfOpen,
                    // No width. No height. The glass measures whatever is
                    // in it and flows to fit — so adding a row to _Panel
                    // below grows the glass, with nothing to keep in sync.
                    child: LiquidGlassMorph(
                      alignment: _anchor,
                      style: _style,
                      motion: _motions[_motion]!,
                      smoothness: _smoothness,
                      debugClipBounds: _debugBounds,
                      child: _content,
                    ),
                  ),
                ),
              ),
              _controls(),
            ],
          ),
        ),
      ),
    );
  }

  /// One compact slider row — label, live value, track.
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return SizedBox(
      height: 32,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 86,
            child: Text(
              '$label  ${value.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: (double v) => setState(() => onChanged(v)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One horizontally scrollable row of chips.
  ///
  /// The two option sets used to share a `Wrap`, so five anchors and four
  /// motions ran to three lines and the panel grew tall enough to crowd
  /// the glass it is here to show. A row each, scrolled sideways, keeps
  /// the panel one line per choice however many options a set gains.
  Widget _chipRow(String label, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0x8AFFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, int i) => Align(child: chips[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    const List<(String, Alignment)> anchors = <(String, Alignment)>[
      ('top-left', Alignment.topLeft),
      ('top-right', Alignment.topRight),
      ('centre', Alignment.center),
      ('bottom-left', Alignment.bottomLeft),
      ('bottom-right', Alignment.bottomRight),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The header folds the panel away: the morph anchors to the
          // corners of the field above, and the bottom two need the room.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _controlsOpen = !_controlsOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Tap the glass — ${_step.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _controlsOpen
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_controlsOpen) ...<Widget>[
            _chipRow('ANCHOR', <Widget>[
              for (final (String label, Alignment a) in anchors)
                _Chip(
                  label: label,
                  on: _anchor == a,
                  onTap: () => setState(() => _anchor = a),
                ),
            ]),
            _chipRow('MOTION', <Widget>[
              for (final String name in _motions.keys)
                _Chip(
                  label: name,
                  on: _motion == name,
                  onTap: () => setState(() => _motion = name),
                ),
            ]),
            _slider('blur', _morphBlur, 0, 40, (double v) => _morphBlur = v),
            _slider(
                'smooth', _smoothness, 0, 120, (double v) => _smoothness = v),
          ],
        ],
      ),
    );
  }
}

/// Each of these states its OWN size, and the glass reads it. That is the
/// whole contract: one source of truth per shape, owned by the content.
class _Button extends StatelessWidget {
  const _Button({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        // Opaque, so the whole 56×56 glass is the target — not just the
        // icon's glyph box, which is all a bare Icon hit-tests.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.search_rounded, color: Colors.white, size: 24),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.selected, required this.onSelect});

  final int? selected;
  final ValueChanged<int> onSelect;

  static const List<(IconData, String)> _rows = <(IconData, String)>[
    (Icons.history_rounded, 'Recent searches'),
    (Icons.photo_outlined, 'Photos'),
    (Icons.folder_outlined, 'Documents'),
    (Icons.person_outline_rounded, 'People'),
    (Icons.place_outlined, 'Places'),
  ];

  @override
  Widget build(BuildContext context) {
    // Opaque and swallowing: a tap anywhere on the panel — padding, header,
    // the gaps between rows — stays on the panel and never reaches the
    // field's close handler.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: SizedBox(
        width: 200,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.search_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final (int i, (IconData icon, String label))
                  in _rows.indexed)
                _row(i, icon, label),
            ],
          ),
        ),
      ),
    );
  }

  /// One tappable row: the full width of the panel, with a highlight on
  /// the one last picked.
  Widget _row(int i, IconData icon, String label) {
    final bool on = selected == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: on ? Colors.white.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: on
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? const Color(0xFF11131A) : Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

class _Background extends StatelessWidget {
  const _Background({required this.url});

  final String url;

  static const DecoratedBox _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF2E1065),
          Color(0xFF0EA5E9),
          Color(0xFFF59E0B),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x22000000), Color(0x55000000)],
              ),
            ),
          ),
        ],
      );
}
