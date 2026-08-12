import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/aurora_theme.dart';

/// A bar visualiser.
///
/// The bar heights are a fixed per-bar signature (so the shape reads as
/// *this* track, not as noise) modulated by three beating sine waves.
/// When [playing] goes false the bars settle to their resting height
/// instead of freezing mid-jump.
class Waveform extends StatefulWidget {
  final int bars;
  final double height;
  final Color color;

  /// Bars left of this fraction are drawn at full strength — the played
  /// portion of a track.
  final double progress;

  final Color? playedColor;
  final bool playing;
  final int seed;

  const Waveform({
    super.key,
    this.bars = 42,
    this.height = 64,
    required this.color,
    this.progress = 1,
    this.playedColor,
    this.playing = true,
    this.seed = 3,
  });

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  late List<double> _signature = _buildSignature();

  List<double> _buildSignature() {
    final rng = math.Random(widget.seed);
    return List.generate(widget.bars, (i) {
      // A gentle arch so the middle of the track is the loudest, plus
      // per-bar grain.
      final arch = math.sin(i / widget.bars * math.pi);
      return (0.22 + 0.62 * arch * (0.55 + rng.nextDouble() * 0.45))
          .clamp(0.08, 1.0);
    });
  }

  @override
  void didUpdateWidget(covariant Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed || oldWidget.bars != widget.bars) {
      _signature = _buildSignature();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final still = context.auroraController.reduceMotion;
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.playing && !still ? 1 : 0),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          builder: (context, energy, __) => CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _WavePainter(
              signature: _signature,
              t: _c.value,
              energy: energy,
              color: widget.color,
              playedColor: widget.playedColor ?? widget.color,
              restColor: p.textFaint,
              progress: widget.progress,
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> signature;
  final double t;
  final double energy;
  final Color color;
  final Color playedColor;
  final Color restColor;
  final double progress;

  _WavePainter({
    required this.signature,
    required this.t,
    required this.energy,
    required this.color,
    required this.playedColor,
    required this.restColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (signature.isEmpty) return;
    final slot = size.width / signature.length;
    final barWidth = math.max(2.0, slot - 3);
    final tau = t * 2 * math.pi;
    final mid = size.height / 2;

    for (var i = 0; i < signature.length; i++) {
      final phase = i * 0.38;
      final beat = 0.5 +
          0.28 * math.sin(tau * 2 + phase) +
          0.14 * math.sin(tau * 3.7 - phase * 0.6) +
          0.08 * math.sin(tau * 6.1 + phase * 1.9);
      final amp = signature[i] * (1 - energy + energy * beat.clamp(0.15, 1.2));
      final h = (amp * size.height).clamp(3.0, size.height);
      final x = slot * i + (slot - barWidth) / 2;
      final played = (i + 0.5) / signature.length <= progress;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, mid - h / 2, barWidth, h),
          Radius.circular(barWidth / 2),
        ),
        Paint()
          ..color = played ? playedColor : restColor.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.t != t ||
      old.energy != energy ||
      old.progress != progress ||
      old.color != color;
}

/// A pair of phase-shifted sine bands — the "audio is live" ribbon at
/// the top of the player, and the water level in the weather page.
class WaveRibbon extends StatefulWidget {
  final Color color;
  final double height;
  final double amplitude;
  final int layers;

  const WaveRibbon({
    super.key,
    required this.color,
    this.height = 90,
    this.amplitude = 12,
    this.layers = 3,
  });

  @override
  State<WaveRibbon> createState() => _WaveRibbonState();
}

class _WaveRibbonState extends State<WaveRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = context.auroraController.reduceMotion;
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _RibbonPainter(
            t: still ? 0 : _c.value,
            color: widget.color,
            amplitude: widget.amplitude,
            layers: widget.layers,
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final double t;
  final Color color;
  final double amplitude;
  final int layers;

  _RibbonPainter({
    required this.t,
    required this.color,
    required this.amplitude,
    required this.layers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var l = 0; l < layers; l++) {
      final depth = l / math.max(1, layers - 1);
      final path = Path()..moveTo(0, size.height);
      final phase = t * 2 * math.pi * (1 + l * 0.35) + l * 1.3;
      final base = size.height * (0.42 + depth * 0.18);
      for (var x = 0.0; x <= size.width; x += 6) {
        final y = base +
            math.sin(x / size.width * math.pi * 2 * (1.4 + l * 0.5) + phase) *
                amplitude *
                (1 - depth * 0.35);
        if (x == 0) {
          path.lineTo(0, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path
        ..lineTo(size.width, size.height)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.34 - depth * 0.09),
              color.withValues(alpha: 0.03),
            ],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.t != t || old.color != color;
}
