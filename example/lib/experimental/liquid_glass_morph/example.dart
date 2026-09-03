// A working use of [LiquidGlassMorph]: a search control that grows from a
// button straight into a results panel — anchored to a corner, so it opens
// the way a real toolbar control has to.
//
//   flutter run -t lib/experimental/liquid_glass_morph/example.dart
//   …or open "Morph Component" from the gallery.

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'liquid_glass_morph.dart';
import 'liquid_glass_morph_motion.dart';

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
  };
  String _motion = 'fluid';

  /// Outline the blender's backdrop clip region. On while tuning the morph:
  /// it is the one control whose region moves every frame.
  bool _debugBounds = true;

  // ── The probe lens ────────────────────────────────────────────────
  // A plain [LiquidGlassLens] you can drag over the same backdrop, so the
  // single-lens path and the merged one can be compared side by side under
  // the same wallpaper and the same numbers.

  /// Whether the probe lens is in the tree at all. Off removes it entirely
  /// — no widget, no backdrop pass — so the morph can be read on its own.
  bool _showLens = true;

  /// Top-left of the probe lens, in the padded field's coordinates.
  Offset _lensPos = const Offset(16, 40);
  double _lensW = 150;
  double _lensH = 110;
  double _lensBlur = 7;
  double _lensRefraction = 22;

  // ── The morph's tunables ──────────────────────────────────────────
  double _morphBlur = 7;
  double _morphRefraction = 22;

  /// Peak neck radius between the morph's two blobs. 0 is a hard union — no
  /// smin, so the merged field is a plain `min()` of the members and stays a
  /// true distance field. That is the setting that should make the blender's
  /// refraction band read the same as the probe lens's.
  double _smoothness = 40;

  /// Which surface the sliders drive — the probe lens, or the morph.
  bool _tuningLens = false;

  /// The glass, with the shape it should be resting in. `LiquidGlassMorph`
  /// animates the radius and swaps the corner curve mid-travel; the rest of
  /// the material is passed straight through.
  /// The shape BOTH surfaces wear. Shared so the probe lens and the morph
  /// differ only in the thing under test — corner style, corner radius and
  /// rim are the same on each, whichever step the morph is resting in.
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
        refraction: LiquidGlassRefraction(
          refractionType: OpticalRefraction(
            refraction: 1.5,
            refractionWidth: _morphRefraction,
            depth: 0.5,
          ),
        ),
      );

  /// The probe lens's material — the same numbers, driven by its own pair of
  /// sliders so the two surfaces can be set apart and compared.
  LiquidGlassStyle get _lensStyle => LiquidGlassStyle(
        shape: _shape,
        appearance: LiquidGlassAppearance(
          color: const Color(0x1FFFFFFF),
          saturation: 1.06,
          blur: LiquidGlassBlur(sigmaX: _lensBlur, sigmaY: _lensBlur),
        ),
        refraction: LiquidGlassRefraction(
          refractionType: OpticalRefraction(
            refraction: 1.5,
            refractionWidth: _lensRefraction,
            depth: 0.5,
          ),
        ),
      );

  Widget get _content => switch (_step) {
        _Step.button => const _Button(key: ValueKey<String>('button')),
        _Step.panel => const _Panel(key: ValueKey<String>('panel')),
      };

  void _next() => setState(() {
        _step = _Step.values[(_step.index + 1) % _Step.values.length];
      });

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
              _debugBounds
                  ? Icons.crop_free
                  : Icons.crop_free_outlined,
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
                  // The component fills this padded box and anchors the glass
                  // inside it. That box IS the field the alignment resolves
                  // against, so anchoring is a matter of where you put it.
                  // The probe lens rides on top of the SAME field, so both
                  // surfaces read the one backdrop.
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints field) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _next,
                              // No width. No height. The glass measures
                              // whatever is in it and flows to fit — so
                              // adding a row to _Panel below grows the
                              // glass, with nothing to keep in sync.
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
                          if (_showLens) _probeLens(field),
                        ],
                      );
                    },
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

  /// The draggable single lens. Positioned in the same field the morph
  /// anchors against, and clamped to it so a drag cannot lose it off-screen.
  Widget _probeLens(BoxConstraints field) {
    void drag(DragUpdateDetails d) => setState(() {
          _lensPos = Offset(
            (_lensPos.dx + d.delta.dx).clamp(0.0, field.maxWidth - _lensW),
            (_lensPos.dy + d.delta.dy).clamp(0.0, field.maxHeight - _lensH),
          );
        });

    return Positioned(
      left: _lensPos.dx.clamp(0.0, (field.maxWidth - _lensW).clamp(0.0, 1e5)),
      top: _lensPos.dy.clamp(0.0, (field.maxHeight - _lensH).clamp(0.0, 1e5)),
      child: GestureDetector(
        // Absorb the tap: the field below morphs on tap, and dragging the
        // lens should not also swap the panel.
        onTap: () {},
        onPanUpdate: drag,
        child: SizedBox(
          width: _lensW,
          height: _lensH,
          child: LiquidGlassLens(
            style: _lensStyle,
            child: const Center(
              child: Text(
                'drag me',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
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

  /// The sliders for whichever surface is selected. The lens adds width and
  /// height; the morph has none to give — its size is its content's.
  List<Widget> _tuningSliders() {
    if (_tuningLens) {
      return <Widget>[
        _slider('blur', _lensBlur, 0, 40, (double v) => _lensBlur = v),
        _slider('refract', _lensRefraction, 0, 60,
            (double v) => _lensRefraction = v),
        _slider('width', _lensW, 60, 300, (double v) => _lensW = v),
        _slider('height', _lensH, 60, 300, (double v) => _lensH = v),
      ];
    }
    return <Widget>[
      _slider('blur', _morphBlur, 0, 40, (double v) => _morphBlur = v),
      _slider('refract', _morphRefraction, 0, 60,
          (double v) => _morphRefraction = v),
      _slider('smooth', _smoothness, 0, 120, (double v) => _smoothness = v),
    ];
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      // Capped and scrollable: the slider set changes with the target, and
      // the lens's is twice the morph's.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 268),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Tap the glass — ${_step.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final (String label, Alignment a) in anchors)
                    _Chip(
                      label: label,
                      on: _anchor == a,
                      onTap: () => setState(() => _anchor = a),
                    ),
                  for (final String name in _motions.keys)
                    _Chip(
                      label: name,
                      on: _motion == name,
                      onTap: () => setState(() => _motion = name),
                    ),
                ],
              ),
              const Divider(color: Colors.white24, height: 18),
              Row(
                children: <Widget>[
                  _Chip(
                    label: 'morph',
                    on: !_tuningLens,
                    onTap: () => setState(() => _tuningLens = false),
                  ),
                  const SizedBox(width: 6),
                  _Chip(
                    label: 'lens',
                    on: _tuningLens,
                    onTap: () => setState(() => _tuningLens = true),
                  ),
                  const Spacer(),
                  _Chip(
                    label: _showLens ? 'hide lens' : 'show lens',
                    on: _showLens,
                    onTap: () => setState(() => _showLens = !_showLens),
                  ),
                ],
              ),
              ..._tuningSliders(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Each of these states its OWN size, and the glass reads it. That is the
/// whole contract: one source of truth per shape, owned by the content.
class _Button extends StatelessWidget {
  const _Button({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 56,
        height: 56,
        child: Icon(Icons.search_rounded, color: Colors.white, size: 24),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({super.key});

  static const List<(IconData, String)> _rows = <(IconData, String)>[
    (Icons.history_rounded, 'Recent searches'),
    (Icons.photo_outlined, 'Photos'),
    (Icons.folder_outlined, 'Documents'),
    (Icons.person_outline_rounded, 'People'),
    (Icons.place_outlined, 'Places'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
            for (final (IconData icon, String label) in _rows) ...<Widget>[
              Row(
                children: <Widget>[
                  Icon(icon,
                      size: 18, color: Colors.white.withValues(alpha: 0.85)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
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
