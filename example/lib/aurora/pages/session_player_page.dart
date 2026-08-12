import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../data/aurora_data.dart';
import '../theme/aurora_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/aurora_gooey.dart';
import '../widgets/aurora_surface.dart';
import '../widgets/aurora_waveform.dart';

/// A session, playing.
///
/// The whole page is built around one instruction — breathe with the
/// blob — so the blob gets the middle of the screen and everything else
/// gets out of its way. The transport is the app's one piece of hero
/// glass: a single lens over the drifting field, holding the scrubber.
class SessionPlayerPage extends StatefulWidget {
  final AuroraSession session;

  const SessionPlayerPage({super.key, required this.session});

  @override
  State<SessionPlayerPage> createState() => _SessionPlayerPageState();
}

class _SessionPlayerPageState extends State<SessionPlayerPage>
    with TickerProviderStateMixin {
  /// The breath cycle: one loop of inhale → hold → exhale → rest.
  late final AnimationController _breath;

  /// Playback position, 0..1 across the session's length.
  late final AnimationController _progress;

  bool _playing = true;
  double _volume = 0.7;

  @override
  void initState() {
    super.initState();
    final cycle = widget.session.pattern.fold<int>(0, (a, b) => a + b);
    _breath = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: cycle * 1000),
    )..repeat();
    _progress = AnimationController(
      vsync: this,
      duration: Duration(minutes: widget.session.minutes),
    )..forward();
  }

  @override
  void dispose() {
    _breath.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _progress.forward();
      _breath.repeat();
    } else {
      _progress.stop();
      _breath.stop();
    }
  }

  /// Where we are in the cycle: the phase label, and 0..1 through it.
  ({String label, double scale}) _phase(double t) {
    final steps = widget.session.pattern;
    final total = steps.fold<int>(0, (a, b) => a + b).toDouble();
    const names = ['Inhale', 'Hold', 'Exhale', 'Rest'];
    var elapsed = t * total;
    for (var i = 0; i < steps.length; i++) {
      if (steps[i] == 0) continue;
      if (elapsed <= steps[i]) {
        final u = elapsed / steps[i];
        // The blob is at its smallest before an inhale and its largest
        // after one; hold and rest sit still at the end they arrived on.
        final scale = switch (i) {
          0 => 0.72 + 0.28 * Curves.easeInOutSine.transform(u),
          1 => 1.0,
          2 => 1.0 - 0.28 * Curves.easeInOutSine.transform(u),
          _ => 0.72,
        };
        return (label: names[i], scale: scale);
      }
      elapsed -= steps[i];
    }
    return (label: names.first, scale: 0.72);
  }

  String _clock(double fraction) {
    final seconds = (widget.session.minutes * 60 * fraction).round();
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final still = context.auroraController.reduceMotion;
    final c = p.series[widget.session.slot % p.series.length];

    if (still && _breath.isAnimating) _breath.stop();

    return LiquidGlassScaffold(
      pixelRatio: 1,
      body: AuroraBackground(
        // The session repaints the sky in its own color, so the room
        // changes when the track does.
        blobs: [c, p.accent, c.withValues(alpha: 0.8), p.blobs.last],
        intensity: 1.15,
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Column(
              children: [
                _Header(session: widget.session),
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _breath,
                      builder: (context, _) {
                        final phase = _phase(still ? 0.5 : _breath.value);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: phase.scale,
                              child: BlobMorph(
                                size: 232,
                                wobble: 0.1,
                                colors: [c, p.accent],
                              ),
                            ),
                            const SizedBox(height: 34),
                            // The instruction, swapped on the phase change
                            // rather than counted down — a number here
                            // makes people watch the clock instead of
                            // their breath.
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 420),
                              child: Text(
                                phase.label,
                                key: ValueKey(phase.label),
                                style: AuroraText.title(p),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                  // Listening to `_progress` here too: the played portion
                  // has to creep forward between setStates, or the bars
                  // only ever advance when something else rebuilds.
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) => Waveform(
                      bars: 44,
                      height: 46,
                      color: p.textFaint,
                      playedColor: c,
                      playing: _playing && !still,
                      progress: _progress.value,
                      seed: widget.session.slot + 2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
                  child: _Transport(
                    color: c,
                    playing: _playing,
                    onPlay: _togglePlay,
                    progress: _progress,
                    onSeek: (v) => setState(() => _progress.value = v),
                    clock: _clock,
                    total: widget.session.minutes,
                    volume: _volume,
                    onVolume: (v) => setState(() => _volume = v),
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

class _Header extends StatelessWidget {
  final AuroraSession session;

  const _Header({required this.session});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 18, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: p.textPrimary, size: 30),
          ),
          Expanded(
            child: Column(
              children: [
                Text(session.kind.label.toUpperCase(),
                    style: AuroraText.caps(p)),
                const SizedBox(height: 4),
                Text(
                  session.title,
                  style: AuroraText.section(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

/// The one lens on this page: scrubber, transport, volume.
class _Transport extends StatelessWidget {
  final Color color;
  final bool playing;
  final VoidCallback onPlay;
  final AnimationController progress;
  final ValueChanged<double> onSeek;
  final String Function(double) clock;
  final int total;
  final double volume;
  final ValueChanged<double> onVolume;

  const _Transport({
    required this.color,
    required this.playing,
    required this.onPlay,
    required this.progress,
    required this.onSeek,
    required this.clock,
    required this.total,
    required this.volume,
    required this.onVolume,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SizedBox(
      height: 220,
      child: LiquidGlassLens(
        style: p.glass(radius: 34, blur: 4, distortion: 0.12),
        // The lens measures its child before it has a height to give it,
        // so nothing in here may be a Spacer — the spacing is explicit.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: progress,
                builder: (context, _) => Column(
                  children: [
                    // The slider takes a concrete width, so it is measured
                    // from the lens rather than guessed at.
                    LayoutBuilder(
                      builder: (context, box) => LiquidGlassSlider(
                        value: progress.value,
                        onChanged: onSeek,
                        activeColor: color,
                        inactiveColor: p.isDark
                            ? const Color(0x33FFFFFF)
                            : const Color(0x2A101430),
                        layout: LiquidGlassSliderLayout(width: box.maxWidth),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(clock(progress.value), style: AuroraText.label(p)),
                        Text('-${clock(1 - progress.value)}',
                            style: AuroraText.label(p)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundIcon(
                    icon: Icons.replay_10_rounded,
                    onTap: () => onSeek(
                      math.max(0, progress.value - 10 / (total * 60)),
                    ),
                  ),
                  PressableScale(
                    onTap: onPlay,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey(playing),
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  _RoundIcon(
                    icon: Icons.forward_30_rounded,
                    onTap: () => onSeek(
                      math.min(1, progress.value + 30 / (total * 60)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.volume_down_rounded,
                      size: 16, color: p.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _VolumeBar(value: volume, onChanged: onVolume),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.volume_up_rounded,
                      size: 16, color: p.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Volume, drawn rather than borrowed.
///
/// A Material `Slider` here would bring its own thumb, its own ripple and
/// its own idea of spacing into a panel that already has a glass slider
/// six pixels above it — two sliders, two vocabularies.
class _VolumeBar extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _VolumeBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, box) {
        void set(Offset local) =>
            onChanged((local.dx / box.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => set(d.localPosition),
          onHorizontalDragUpdate: (d) => set(d.localPosition),
          child: SizedBox(
            height: 22,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 5,
                  child: Row(
                    // A childless ColoredBox takes the loose height a
                    // centered Row hands it, which is none — stretch is
                    // what gives the track its 5px back.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: (value * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: p.textSecondary),
                      ),
                      Expanded(
                        flex: ((1 - value) * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: p.stroke),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressableScale(
      onTap: onTap,
      child: Icon(icon, size: 27, color: p.textPrimary),
    );
  }
}
