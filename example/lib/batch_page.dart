import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Batch — many lenses, one backdrop read.
//
// A field of glass cards floating over a photo, all inside one
// LiquidGlassBatch. Each card bobs on its own slow sine, so every frame
// is a fresh read: on Impeller the batch is the whole story — flip it
// off and every card takes a readback of its own, flip it on and they
// all sample one shared copy. The raster ms in the HUD is the number to
// watch. On Skia / web the view already captures once for every lens
// inside it, so the batch is inert there rather than wrong: the same
// tree runs on both backends.
//
// The first card is deliberately OUT of the batch, wrapped in
// LiquidGlassBatch.exclude — it reads the backdrop on its own while
// every card around it shares the read.
//
//   flutter run -t lib/batch_page.dart   (standalone; use --profile
//   when you are reading the HUD — debug numbers lie)
//   …or open "Batch" from the gallery.
// =============================================================

void main() => runApp(const _BatchApp());

class _BatchApp extends StatelessWidget {
  const _BatchApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BatchPage(),
    );
  }
}

/// A field of floating, batched glass cards over a photo.
class BatchPage extends StatefulWidget {
  const BatchPage({super.key});

  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage>
    with SingleTickerProviderStateMixin {
  static const String _imageUrl =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  bool _batched = true;
  int _cardCount = 8;

  /// Drives the bob. One controller, every card reads it at its own phase.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Rolling window of raster-thread durations, refreshed into the HUD a
  // few times a second — a per-frame setState would be its own cost.
  static const int _window = 400;
  final List<int> _rasterUs = <int>[];
  String _hud = 'warming up…';
  int _framesSinceHud = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _float.dispose();
    super.dispose();
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    for (final ui.FrameTiming t in timings) {
      _rasterUs.add(t.rasterDuration.inMicroseconds);
    }
    while (_rasterUs.length > _window) {
      _rasterUs.removeAt(0);
    }
    _framesSinceHud += timings.length;
    if (_framesSinceHud >= 24 && mounted) {
      _framesSinceHud = 0;
      setState(() => _hud = _computeHud());
    }
  }

  String _computeHud() {
    if (_rasterUs.length < 10) return 'warming up… (${_rasterUs.length})';
    final List<int> sorted = List<int>.from(_rasterUs)..sort();
    double pct(double p) => sorted[((sorted.length - 1) * p).round()] / 1000.0;
    final double avg =
        _rasterUs.reduce((int a, int b) => a + b) / _rasterUs.length / 1000.0;
    String f(double v) => v.toStringAsFixed(2);
    return 'raster ms — avg ${f(avg)}   p50 ${f(pct(0.5))}   '
        'p90 ${f(pct(0.9))}';
  }

  void _reset() {
    _rasterUs.clear();
    _hud = 'reset — gathering…';
  }

  /// One material for every card. The batch does not ask members to match —
  /// each keeps its own style — but a field of cards should read as one
  /// family anyway.
  static const LiquidGlassStyle _cardStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 26,
      borderWidth: 1.2,
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x14FFFFFF),
      blur: LiquidGlassBlur(sigmaX: 9, sigmaY: 9),
    ),
    refraction: LiquidGlassRefraction(
      refractionType: OpticalRefraction(
        refraction: 1.5,
        refractionWidth: 20,
        depth: 0.5,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // The cards, floating in two columns. The bob is a few pixels, far
    // less than the gap, so no two of them ever overlap — the batch's
    // one rule.
    final Widget cards = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final EdgeInsets pad = MediaQuery.paddingOf(context);
        // Below the HUD panel.
        const double top = 215;
        final double bottom = pad.bottom + 30;
        const double gap = 14;
        final int rows = (_cardCount + 1) ~/ 2;
        final double pitch = (c.maxHeight - top - bottom) / rows;
        final double h = math.min(96.0, pitch - gap - 10);
        final double w = (c.maxWidth - 16 * 2 - gap) / 2;

        return AnimatedBuilder(
          animation: _float,
          builder: (BuildContext context, _) {
            final double phase = _float.value * 2 * math.pi;
            return Stack(
              children: <Widget>[
                for (int i = 0; i < _cardCount; i++)
                  Positioned(
                    left: 16 + (i % 2) * (w + gap),
                    top: top +
                        (i ~/ 2) * pitch +
                        // Each card on its own phase, ±5 px.
                        math.sin(phase + i * 1.3) * 5,
                    width: w,
                    height: h,
                    child: _card(i),
                  ),
              ],
            );
          },
        );
      },
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Batch'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LiquidGlassView(
        backgroundWidget: const _Background(url: _imageUrl),
        child: Stack(
          children: <Widget>[
            // The whole point: one wrapper, any number of lenses inside it.
            LiquidGlassBatch(enabled: _batched, child: cards),
            Positioned(left: 0, right: 0, top: 0, child: _panel()),
          ],
        ),
      ),
    );
  }

  Widget _card(int i) {
    final bool excluded = i == 0;
    final Widget card = LiquidGlassLens(
      style: _cardStyle,
      child: Center(
        child: Text(
          excluded ? 'card 1\nexcluded' : 'card ${i + 1}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return excluded ? LiquidGlassBatch.exclude(child: card) : card;
  }

  Widget _panel() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 56, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _hud,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.3,
                fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                _Chip(
                  label: _batched ? 'batch on' : 'batch off',
                  on: _batched,
                  onTap: () => setState(() {
                    _batched = !_batched;
                    _reset();
                  }),
                ),
                const SizedBox(width: 6),
                _Chip(
                  label: '−',
                  on: false,
                  onTap: () {
                    if (_cardCount > 2) {
                      setState(() {
                        _cardCount--;
                        _reset();
                      });
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$_cardCount cards',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                _Chip(
                  label: '+',
                  on: false,
                  onTap: () {
                    if (_cardCount < 12) {
                      setState(() {
                        _cardCount++;
                        _reset();
                      });
                    }
                  },
                ),
              ],
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

/// The photo behind the glass, with a gradient to fall back on.
class _Background extends StatelessWidget {
  const _Background({required this.url});

  final String url;

  static const DecoratedBox _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF1B2A6B),
          Color(0xFF7B1F6A),
          Color(0xFFB8501F),
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
            decoration: BoxDecoration(color: Color(0x2E000000)),
          ),
        ],
      );
}
