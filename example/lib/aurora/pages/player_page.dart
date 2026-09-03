import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../common.dart';
import '../data.dart';
import '../theme.dart';

// =============================================================
// Now playing — the page the whole package is for.
//
// Two moving lenses, and the page is built to show them off: the
// scrubber's thumb and the volume thumb travel over a backdrop with
// rings and stars painted into it, which is where refraction stops
// being a screenshot effect and starts being visible — watch a contour
// line bend as the thumb crosses it.
//
// `LiquidGlassSlider` owns its own capture pipeline, so this page
// deliberately holds exactly two of them, and the play button between
// them is a painted rim rather than a third.
// =============================================================

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static const Album _album = kNowPlaying;
  static const Duration _length = Duration(minutes: 4, seconds: 12);

  Timer? _tick;
  double _position = 0.28;
  double _volume = 0.62;
  bool _playing = true;
  bool _loved = false;

  @override
  void initState() {
    super.initState();
    _restartClock();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// The transport actually runs: one tick a second while playing, so
  /// the thumb crosses the backdrop on its own instead of only when
  /// dragged.
  void _restartClock() {
    _tick?.cancel();
    if (!_playing) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _position += 1 / _length.inSeconds;
        if (_position >= 1) _position = 0;
      });
    });
  }

  String _stamp(double t) {
    final int s = (t * _length.inSeconds).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _showLyrics(Color accent) {
    return showLiquidGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      style: auroraGlass(radius: 34, tint: const Color(0x24FFFFFF), blur: 10),
      foregroundColor: const Color(0xFFF4F3F8),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('LYRICS', style: kEyebrow.copyWith(color: accent)),
          const SizedBox(height: 14),
          Text(
            'Low tide radio,\n'
            'nothing on the dial but the sea.\n\n'
            'Keep the lamp on,\n'
            'I am coming back the long way round.\n\n'
            'Salt on every window,\n'
            'and the signal going out.',
            style: kTitle.copyWith(
              fontSize: 20,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 22),
          Text('${_album.tracks.first.title} — ${_album.artist}', style: kBody),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuroraPalette palette = AuroraPalette.fromSeed(_album.seed);
    final Color accent = palette.accent;
    final Size screen = MediaQuery.sizeOf(context);
    final double art = (screen.width - 96).clamp(150.0, screen.height * 0.34);
    final double controlWidth = (screen.width - 48).clamp(240.0, 460.0);

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: AuroraBackdrop(palette: palette, seed: 'player-${_album.seed}'),
      lenses: <Widget>[
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
            child: Column(
              children: <Widget>[
                // ── Header ───────────────────────────────────
                Row(
                  children: <Widget>[
                    Pressable(
                      onTap: () => Navigator.of(context).maybePop(),
                      scale: 0.85,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 28, color: Color(0xCCEDECF5)),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          Text('PLAYING FROM ALBUM',
                              style: kEyebrow.copyWith(fontSize: 9)),
                          const SizedBox(height: 3),
                          Text(_album.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: kTitle.copyWith(fontSize: 13.5)),
                        ],
                      ),
                    ),
                    Pressable(
                      onTap: () => showAuroraToast(context, 'Queue is empty'),
                      scale: 0.85,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.more_horiz_rounded,
                            size: 22, color: Color(0xCCEDECF5)),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // ── The record ───────────────────────────────
                // Paused, it settles back a little; playing, it stands
                // at full size. The size change is the only thing on
                // the page that says which state it is in besides the
                // glyph itself.
                AnimatedScale(
                  scale: _playing ? 1 : 0.9,
                  duration: const Duration(milliseconds: 520),
                  curve: const Cubic(0.2, 0.9, 0.2, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 70,
                          spreadRadius: -26,
                          offset: const Offset(0, 30),
                        ),
                      ],
                    ),
                    child: CoverArt(seed: _album.seed, size: art, radius: 30),
                  ),
                ),

                const Spacer(),

                // ── What it is ───────────────────────────────
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(_album.tracks.first.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: kDisplay.copyWith(fontSize: 25)),
                          const SizedBox(height: 5),
                          Text(_album.artist,
                              style: kTitle.copyWith(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: accent)),
                        ],
                      ),
                    ),
                    Pressable(
                      onTap: () => setState(() => _loved = !_loved),
                      scale: 0.85,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          _loved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 24,
                          color: _loved ? accent : const Color(0x99EDECF5),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Scrubber ─────────────────────────────────
                LiquidGlassSlider(
                  value: _position,
                  width: controlWidth,
                  activeColor: accent,
                  inactiveColor: Colors.white.withValues(alpha: 0.16),
                  onChangeStart: (_) => _tick?.cancel(),
                  onChanged: (double v) => setState(() => _position = v),
                  onChangeEnd: (_) => _restartClock(),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(_stamp(_position),
                        style: kBody.copyWith(fontSize: 11.5)),
                    Text('-${_stamp(1 - _position)}',
                        style: kBody.copyWith(fontSize: 11.5)),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Transport ────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _TransportIcon(
                      icon: Icons.shuffle_rounded,
                      size: 20,
                      onTap: () => showAuroraToast(context, 'Shuffle on'),
                    ),
                    _TransportIcon(
                      icon: Icons.skip_previous_rounded,
                      size: 34,
                      onTap: () => setState(() => _position = 0),
                    ),

                    // The one round button on the page. A circle is
                    // where the rim earns its keep: the light sweeps
                    // the whole way round it, so the shape is read from
                    // the edge alone with nothing drawn inside it.
                    GlassButton(
                      width: 72,
                      height: 72,
                      radius: 36,
                      scale: 0.92,
                      tint: accent.withValues(alpha: 0.30),
                      onPressed: () {
                        setState(() => _playing = !_playing);
                        _restartClock();
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey<bool>(_playing),
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    _TransportIcon(
                      icon: Icons.skip_next_rounded,
                      size: 34,
                      onTap: () => setState(() => _position = 0),
                    ),
                    _TransportIcon(
                      icon: Icons.repeat_rounded,
                      size: 20,
                      onTap: () => showAuroraToast(context, 'Repeat album'),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ── Volume ───────────────────────────────────
                Row(
                  children: <Widget>[
                    const Icon(Icons.volume_down_rounded,
                        size: 18, color: Color(0x8AEDECF5)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LiquidGlassSlider(
                        value: _volume,
                        height: 26,
                        activeColor: Colors.white.withValues(alpha: 0.85),
                        inactiveColor: Colors.white.withValues(alpha: 0.14),
                        onChanged: (double v) => setState(() => _volume = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.volume_up_rounded,
                        size: 18, color: Color(0x8AEDECF5)),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _FooterAction(
                      icon: Icons.lyrics_outlined,
                      label: 'Lyrics',
                      onTap: () => _showLyrics(accent),
                    ),
                    _FooterAction(
                      icon: Icons.speaker_group_outlined,
                      label: 'Devices',
                      onTap: () => showAuroraToast(context, 'No devices found'),
                    ),
                    _FooterAction(
                      icon: Icons.queue_music_rounded,
                      label: 'Queue',
                      onTap: () => showAuroraToast(context, 'Queue is empty'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TransportIcon extends StatelessWidget {
  const _TransportIcon({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.85,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: size, color: const Color(0xE6EDECF5)),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: const Color(0x99EDECF5)),
            const SizedBox(height: 5),
            Text(label, style: kEyebrow.copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
