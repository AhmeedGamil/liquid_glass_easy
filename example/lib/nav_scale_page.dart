import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// EXPERIMENT — scaling the glass-pill bottom nav bar.
//
//   flutter run -t lib/nav_scale_page.dart   (standalone)
//   …or open it from the home menu.
//
// Press anywhere on the bar and the whole bar scales up on a spring, then
// springs back on release. Two ways of doing it, switchable live, because
// only one of them actually works on a live-backdrop lens.
//
// TRANSFORM (raster) — BROKEN, kept so the failure is visible
// -----------------------------------------------------------
// A parent `Transform` around the bar. The icons and the morph pill scale
// correctly, but the CAPSULE drifts out of position as it scales.
//
// The reason is in ImpellerLiquidGlassLens: under `ImageFilter.shader`,
// `FlutterFragCoord()` is in SCREEN pixels, so the lens hands the shader
// its own screen position, read with `localToGlobal`. An ancestor
// Transform is included in `localToGlobal` — and the painted output then
// goes through that same transform again. The position is applied twice
// while `config.geometry.width/height` are never scaled at all, so the
// glass no longer lands where its clip is. Worse, `localToGlobal` changes
// every spring frame, so the lens re-reads and chases a moving target.
//
// RESIZE (real) — the working one
// -------------------------------
// Animate the bar's `width` / `height` instead. The lens genuinely
// re-refracts at the new dimensions, so the glass stays sharp at any
// scale, and everything derived from the layout — cells, icon row, rest
// pill, morph pill — follows for free. `margin.bottom` is pulled in by
// half the height gain so the bar grows about its own centre instead of
// upward off its bottom margin.
//
// This is the same principle LiquidGlassElasticity is built on (resize,
// never transform) — but done entirely from OUTSIDE the component, with
// no package changes at all.
//
// HOW THE TOUCH IS PICKED UP
// --------------------------
// A `Listener` ANCESTOR of the bar. Hit testing builds a path from the
// root down to the deepest target and a RenderPointerListener adds itself
// to that path whenever it is hit; raw pointer events dispatch to every
// entry on it. The gesture arena only decides who wins a *gesture*, not
// who receives pointers — so this sees every down/up even though the
// bar's own opaque tab overlay is what handles the tap, and tab selection
// keeps working untouched. `deferToChild` keeps the empty page inert.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _NavScaleApp());
}

class _NavScaleApp extends StatelessWidget {
  const _NavScaleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const NavScalePage(),
    );
  }
}

/// How the scale is applied.
enum NavScaleMode {
  /// Animate width/height — the lens re-refracts, glass stays sharp.
  resize,

  /// Parent `Transform` — the capsule drifts. Kept to show why.
  transform,
}

/// Experiment: the glass-pill bottom nav bar scaled from outside.
class NavScalePage extends StatefulWidget {
  const NavScalePage({super.key});

  @override
  State<NavScalePage> createState() => _NavScalePageState();
}

class _NavScalePageState extends State<NavScalePage>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _showControls = true;
  bool _enabled = true;
  NavScaleMode _mode = NavScaleMode.resize;

  // ── Bar geometry at rest ─────────────────────────────────────────
  static const double _barW = 260;
  static const double _barH = 64;
  static const double _barBottomMargin = 24;

  // ── Tuning ───────────────────────────────────────────────────────
  double _amount = 0.06;
  double _stiffness = 320;
  double _damping = 24;

  // ── Spring ───────────────────────────────────────────────────────
  double _scale = 1;
  double _vel = 0;
  bool _down = false;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  static const List<LiquidGlassTabBarItem> _items = [
    LiquidGlassTabBarItem(icon: Icons.play_circle_fill_rounded),
    LiquidGlassTabBarItem(icon: Icons.grid_view_rounded),
    LiquidGlassTabBarItem(icon: Icons.favorite_rounded),
    LiquidGlassTabBarItem(icon: Icons.person_rounded),
  ];

  @override
  void dispose() {
    _ticker?.stop(canceled: true);
    _ticker?.dispose();
    super.dispose();
  }

  void _setDown(bool down) {
    if (_down == down) return;
    _down = down;
    final Ticker ticker = _ticker ??= createTicker(_onTick);
    // Pressing again while the release is still settling is normal, and
    // starting an already-active Ticker throws.
    if (ticker.isActive) return;
    _lastTick = Duration.zero;
    ticker.start();
  }

  void _onTick(Duration elapsed) {
    final double dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final (double x, double vel) = liquidGlassSpringStep(
      x: _scale,
      vel: _vel,
      target: _down ? 1 + _amount : 1.0,
      // Clamp so a dropped frame cannot launch the spring.
      dt: dt.clamp(0.0, 1 / 30),
      stiffness: _stiffness,
      damping: _damping,
    );

    setState(() {
      _scale = x;
      _vel = vel;
    });

    if (!_down && (x - 1).abs() < 0.0005 && vel.abs() < 0.005) {
      setState(() {
        _scale = 1;
        _vel = 0;
      });
      _ticker?.stop();
      _lastTick = Duration.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07040F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Feed(index: _index),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
          Listener(
            // Only fires when something inside is actually hit, so the
            // empty page around the bar stays inert.
            behavior: HitTestBehavior.deferToChild,
            onPointerDown: _enabled ? (_) => _setDown(true) : null,
            onPointerUp: _enabled ? (_) => _setDown(false) : null,
            onPointerCancel: _enabled ? (_) => _setDown(false) : null,
            child: _mode == NavScaleMode.resize
                ? _resized()
                : _transformed(),
          ),
          Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              child: IconButton(
                icon: Icon(
                    _showControls ? Icons.close_rounded : Icons.tune_rounded),
                color: Colors.white,
                onPressed: () =>
                    setState(() => _showControls = !_showControls),
              ),
            ),
          ),
          if (_showControls)
            Align(alignment: Alignment.topCenter, child: _controls()),
        ],
      ),
    );
  }

  /// The working one: the bar is genuinely bigger, so the shader
  /// re-refracts at the new size.
  Widget _resized() {
    final double w = _barW * _scale;
    final double h = _barH * _scale;
    return _bar(
      width: w,
      height: h,
      // Pull the bottom margin in by half the height gain so the bar grows
      // about its own centre rather than upward off its margin.
      margin: EdgeInsets.only(bottom: _barBottomMargin - (h - _barH) / 2),
    );
  }

  /// The broken one, kept switchable so the failure is visible.
  Widget _transformed() {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(builder: (context, constraints) {
      final Offset barCentre = Offset(
        constraints.maxWidth / 2,
        constraints.maxHeight - (safeBottom + _barBottomMargin + _barH / 2),
      );
      return Transform(
        transform: Matrix4.identity()..scaleByDouble(_scale, _scale, 1, 1),
        origin: barCentre,
        child: _bar(
          width: _barW,
          height: _barH,
          margin: const EdgeInsets.only(bottom: _barBottomMargin),
        ),
      );
    });
  }

  /// The bar itself — identical in both modes, and untouched by either.
  Widget _bar({
    required double width,
    required double height,
    required EdgeInsets margin,
  }) {
    return LiquidGlassBottomNavBar.withImpeller(
      items: _items,
      selectedIndex: _index,
      onChanged: (i) => setState(() => _index = i),
      width: width,
      height: height,
      margin: margin,
      pillStyle: const LiquidGlassNavPillStyle(
        // The real refracting jelly pill, at its tuned default.
        mode: LiquidGlassPillMode.impellerOnly,
      ),
    );
  }

  Widget _controls() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 56, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: const Color(0xCC15102B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<NavScaleMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
              ),
              segments: const [
                ButtonSegment(
                    value: NavScaleMode.resize, label: Text('resize')),
                ButtonSegment(
                    value: NavScaleMode.transform,
                    label: Text('transform (broken)')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 6),
            _slider('scale', _amount, 0, 0.4, 3,
                (v) => setState(() => _amount = v)),
            _slider('stiffness', _stiffness, 80, 700, 0,
                (v) => setState(() => _stiffness = v)),
            _slider('damping', _damping, 6, 50, 0,
                (v) => setState(() => _damping = v)),
            SwitchListTile.adaptive(
              value: _enabled,
              onChanged: (v) => setState(() {
                _enabled = v;
                if (!v) _setDown(false);
              }),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title:
                  const Text('scale on press', style: TextStyle(fontSize: 13)),
              subtitle: Text(
                _enabled
                    ? 'live scale ${_scale.toStringAsFixed(3)}'
                    : 'off — the bar is untouched',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
            Text(
              _mode == NavScaleMode.resize
                  ? 'The bar is really bigger, so the glass re-refracts and '
                      'stays sharp.'
                  : 'Watch the capsule: its shader position is applied twice, '
                      'so it drifts out from under its own clip.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      int decimals, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ),
        SizedBox(
          width: 46,
          child: Text(
            value.toStringAsFixed(decimals),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
        Expanded(
          child: Slider(
              value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

/// A busy, high-contrast feed so the bar has something worth refracting.
class _Feed extends StatelessWidget {
  final int index;
  const _Feed({required this.index});

  static const List<List<Color>> _palettes = [
    [Color(0xFFFF6B9D), Color(0xFFFFC46B)],
    [Color(0xFF6EE7F9), Color(0xFF7C5CFF)],
    [Color(0xFF34D399), Color(0xFF0E7C8C)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
  ];

  @override
  Widget build(BuildContext context) {
    final List<Color> palette = _palettes[index % _palettes.length];
    return ScrollConfiguration(
      // Android's stretch overscroll lifts content into its own layer, and
      // a BackdropFilter lens above it then reads a black backdrop.
      behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 190),
        itemCount: 30,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, i) {
          final double t = (i % 7) / 6;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(palette[0], palette[1], t)!,
                  Color.lerp(palette[1], palette[0], t)!,
                ],
              ),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
