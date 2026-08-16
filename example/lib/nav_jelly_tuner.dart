import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'nav_bar_tuning.dart';
import 'tuner_widgets.dart';
import 'tuning_store.dart';

// =============================================================
// Nav-bar Motion Tuner — a live playground for the bottom-nav glass pill.
//
//   flutter run -t lib/nav_jelly_tuner.dart   (standalone)
//   …or open it from the home menu.
//
// Every control writes straight into the shared [TuningStore.nav], so the
// glass nav bar below reacts live and any page reading the store picks up
// the same values (in memory, this session).
//
//   Travel spring — the positional slide (bounce vs glide).
//   Motion        — the acceleration squash/stretch of the pill.
//   Background    — the bar's frosted tint.
//   Light dir     — the angle of the rim highlight.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _TunerApp());
}

class _TunerApp extends StatelessWidget {
  const _TunerApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const NavJellyTunerPage(),
    );
  }
}

/// Live tuner for the bottom-nav glass pill + bar look. Writes to
/// [TuningStore.nav]; pushable as its own route from the home menu.
class NavJellyTunerPage extends StatefulWidget {
  const NavJellyTunerPage({super.key});

  @override
  State<NavJellyTunerPage> createState() => _NavJellyTunerPageState();
}

class _NavJellyTunerPageState extends State<NavJellyTunerPage> {
  int _index = 0;

  // Travel (positional) spring.
  late double _travelStiffness;
  late double _travelDamping;
  late double _growHeight;
  late double _lightDirection;

  // Motion (acceleration squash/stretch) knobs.
  late double _sampleWindow;
  late double _sensitivity;
  late double _maxDeformation;
  late double _responseTime;

  // Background (frosted tint): an opaque base hue + an opacity.
  late Color _bgBase;
  late double _bgOpacity;

  static const List<Color> _bgSwatches = [
    Colors.black,
    Colors.white,
    Color(0xFF7C5CFF),
    Color(0xFF2DD4BF),
    Color(0xFFFF5C8A),
    Color(0xFF4FB3FF),
  ];

  @override
  void initState() {
    super.initState();
    _seedFrom(TuningStore.instance.nav.value);
  }

  void _seedFrom(NavTuning n) {
    _travelStiffness = n.travelStiffness;
    _travelDamping = n.travelDamping;
    _growHeight = n.growHeight;
    _lightDirection = n.lightDirection;
    final m = n.motion;
    _sampleWindow = m.sampleWindow;
    _sensitivity = m.sensitivity;
    _maxDeformation = m.maxDeformation;
    _responseTime = m.responseTime;
    _bgOpacity = n.background.a;
    _bgBase = n.background.withValues(alpha: 1);
  }

  LiquidGlassLensMotionSpec get _motion => LiquidGlassLensMotionSpec(
        sampleWindow: _sampleWindow,
        sensitivity: _sensitivity,
        maxDeformation: _maxDeformation,
        responseTime: _responseTime,
      );

  Color get _bg => _bgBase.withValues(alpha: _bgOpacity);

  NavTuning get _tuning => NavTuning(
        motion: _motion,
        travelStiffness: _travelStiffness,
        travelDamping: _travelDamping,
        growHeight: _growHeight,
        lightDirection: _lightDirection,
        background: _bg,
      );

  double get _travelCritical => 2 * math.sqrt(_travelStiffness);

  /// Applies a local edit, then commits it to the shared in-memory store
  /// so the scaffold demo sees it.
  void _update(VoidCallback change) {
    setState(change);
    TuningStore.instance.nav.value = _tuning;
  }

  void _reset() {
    setState(() => _seedFrom(NavTuning.defaults));
    TuningStore.instance.nav.value = NavTuning.defaults;
  }

  String get _snippet => '''
LiquidGlassTabPillStyle(
  mode: LiquidGlassPillMode.both,
  animated: true,
  travelStiffness: ${_travelStiffness.round()},
  travelDamping: ${_travelDamping.toStringAsFixed(1)},
  growHeight: ${_growHeight.round()},
  motion: const LiquidGlassLensMotionSpec(
    sampleWindow: ${_sampleWindow.toStringAsFixed(2)},
    sensitivity: ${_sensitivity.toStringAsFixed(5)},
    maxDeformation: ${_maxDeformation.toStringAsFixed(2)},
    responseTime: ${_responseTime.toStringAsFixed(2)},
  ),
)
// bar: lightDirection ${_lightDirection.round()}, '''
      'background 0x${_bg.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bounces = _travelDamping < _travelCritical;

    return LiquidGlassScaffold(
      appBar: LiquidGlassAppBar(
        width: width - 32,
        title: const Text('Nav Motion Tuner'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: Navigator.of(context).canPop()
              ? () => Navigator.of(context).pop()
              : null,
        ),
      ),
      body: TunerGradientBackground(
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.paddingOf(context).top + 84, 16, 170),
            children: [
              // ── Travel spring ─────────────────────────────────────
              TunerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const TunerPanelTitle('Travel spring'),
                        const Spacer(),
                        TunerBadge(
                            text: bounces ? 'BOUNCES' : 'SETTLES',
                            good: !bounces),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Critical ≈ ${_travelCritical.toStringAsFixed(1)} '
                      '— below it the pill overshoots.',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white54, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    TunerParamSlider(
                        'stiffness',
                        _travelStiffness,
                        80,
                        600,
                        _travelStiffness.round().toString(),
                        (v) => _update(() => _travelStiffness = v)),
                    TunerParamSlider(
                        'damping',
                        _travelDamping,
                        8,
                        48,
                        _travelDamping.toStringAsFixed(1),
                        (v) => _update(() => _travelDamping = v)),
                    TunerParamSlider(
                        'growHeight',
                        _growHeight,
                        0,
                        40,
                        _growHeight.round().toString(),
                        (v) => _update(() => _growHeight = v)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Bar look ──────────────────────────────────────────
              TunerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TunerPanelTitle('Bar look'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const SizedBox(
                          width: 104,
                          child: Text('background',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white70)),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 10,
                            children: [
                              for (final c in _bgSwatches)
                                _Swatch(
                                  color: c,
                                  selected: c.toARGB32() == _bgBase.toARGB32(),
                                  onTap: () => _update(() => _bgBase = c),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TunerParamSlider(
                        'opacity',
                        _bgOpacity,
                        0,
                        1,
                        '${(_bgOpacity * 100).round()}%',
                        (v) => _update(() => _bgOpacity = v)),
                    TunerParamSlider(
                        'lightDir',
                        _lightDirection,
                        0,
                        360,
                        _lightDirection.round().toString(),
                        (v) => _update(() => _lightDirection = v)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Motion ────────────────────────────────────────────
              TunerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TunerPanelTitle('Motion'),
                    const SizedBox(height: 4),
                    const Text(
                        'Acceleration squash & stretch: the pill stretches as '
                        'it launches and squashes as it brakes.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.white54, height: 1.3)),
                    const SizedBox(height: 8),
                    TunerParamSlider(
                        'maxDeformation',
                        _maxDeformation,
                        0,
                        0.5,
                        _maxDeformation.toStringAsFixed(2),
                        (v) => _update(() => _maxDeformation = v)),
                    TunerParamSlider(
                        'sensitivity',
                        _sensitivity,
                        0,
                        0.0003,
                        _sensitivity.toStringAsFixed(5),
                        (v) => _update(() => _sensitivity = v)),
                    const Divider(color: Colors.white12, height: 24),
                    TunerParamSlider(
                        'sampleWindow',
                        _sampleWindow,
                        0.05,
                        0.8,
                        _sampleWindow.toStringAsFixed(2),
                        (v) => _update(() => _sampleWindow = v)),
                    TunerParamSlider(
                        'responseTime',
                        _responseTime,
                        0,
                        0.6,
                        _responseTime.toStringAsFixed(2),
                        (v) => _update(() => _responseTime = v)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TunerCodeCard(snippet: _snippet, onReset: _reset),
              const SizedBox(height: 8),
              const Center(
                child: Text('Tap or drag the pill below to feel it',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: LiquidGlassTabBar(
        width: width - 32,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        style: navBarStyle(_tuning),
        pillStyle: navPillStyle(_tuning),
        items: const [
          LiquidGlassTabBarItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home'),
          LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Search'),
          LiquidGlassTabBarItem(
              icon: Icons.favorite_border_rounded,
              selectedIcon: Icons.favorite_rounded,
              label: 'Likes'),
          LiquidGlassTabBarItem(
              icon: Icons.notifications_none_rounded,
              selectedIcon: Icons.notifications_rounded,
              label: 'Alerts'),
          LiquidGlassTabBarItem(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Profile'),
        ],
      ),
    );
  }
}

/// A tappable background-color swatch.
class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch(
      {required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? kTunerAccent : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}
