import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'app_settings.dart';

// =============================================================
// Page 0 — Control Center
//
// iOS-style Control Center built entirely from the lens-anywhere API:
// every tile is a [LiquidGlassLens] placed (via `Positioned` + `SizedBox`)
// inside a single [LiquidGlassView]'s `child`. The view uses realtime
// capture so the glass refracts live as tiles update.
// =============================================================

/// Full-bleed background for the Control Center demo. Loads a hosted
/// wallpaper over the network, falling back to a gradient + dark scrim if
/// it can't be fetched or decoded.
class ControlCenterBackground extends StatelessWidget {
  static const String _imageUrl =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/main/control_center.jpg';

  const ControlCenterBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Zoomed in, anchored to the bottom edge (the crop eats into the
        // top while the bottom of the photo stays pinned).
        Transform.scale(
          scale: 1.2,
          alignment: Alignment.bottomCenter,
          child: Image.network(
            _imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            errorBuilder: (_, __, ___) => const _FallbackGradient(),
            // Hold a solid black backdrop until the first frame decodes, so
            // the glass capture never samples an empty/transparent screen
            // (which Skia would otherwise grab before the wallpaper loads).
            frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return const ColoredBox(color: Colors.black);
            },
          ),
        ),
        ColoredBox(color: Colors.black.withAlpha(60)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(40),
                Colors.black.withAlpha(110),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// In-code gradient shown if the hosted Control Center photo can't load,
/// so the demo runs even offline.
class _FallbackGradient extends StatelessWidget {
  const _FallbackGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001A33), Color(0xFF005CB8), Color(0xFF00C4D1)],
        ),
      ),
    );
  }
}

class CcConnectivityState {
  bool airplane;
  bool airdrop;
  bool wifi;
  bool bluetooth;
  bool cellular;
  bool data;

  CcConnectivityState({
    this.airplane = false,
    this.airdrop = true,
    this.wifi = true,
    this.bluetooth = true,
    this.cellular = true,
    this.data = false,
  });
}

// =============================================================
// Tiles — each a single LiquidGlassLens (lens-anywhere API). Size and
// placement are supplied by the surrounding `Positioned` + `SizedBox`
// in the page layout, so the tiles themselves are layout-driven.
// =============================================================

/// Shared look for the larger Control Center cards (connectivity + now
/// playing): a soft rounded-rectangle glass with a specular rim.
LiquidGlassStyle _cardStyle() => LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 32,
      ),
      magnification: 1,
      dispersion: 0,
      saturation: 1.25,
      color: Colors.white.withAlpha(50),
    );

class CcConnectivityCard extends StatelessWidget {
  final CcConnectivityState state;
  final VoidCallback onToggleAirplane;
  final VoidCallback onToggleAirdrop;
  final VoidCallback onToggleWifi;
  final VoidCallback onToggleBluetooth;
  final VoidCallback onToggleCellular;
  final VoidCallback onToggleData;

  const CcConnectivityCard({
    super.key,
    required this.state,
    required this.onToggleAirplane,
    required this.onToggleAirdrop,
    required this.onToggleWifi,
    required this.onToggleBluetooth,
    required this.onToggleCellular,
    required this.onToggleData,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLens(
      style: _cardStyle(),
      child: _ConnectivityGrid(
        state: state,
        onToggleAirplane: onToggleAirplane,
        onToggleAirdrop: onToggleAirdrop,
        onToggleWifi: onToggleWifi,
        onToggleBluetooth: onToggleBluetooth,
        onToggleCellular: onToggleCellular,
        onToggleData: onToggleData,
      ),
    );
  }
}

class _ConnectivityGrid extends StatelessWidget {
  final CcConnectivityState state;
  final VoidCallback onToggleAirplane;
  final VoidCallback onToggleAirdrop;
  final VoidCallback onToggleWifi;
  final VoidCallback onToggleBluetooth;
  final VoidCallback onToggleCellular;
  final VoidCallback onToggleData;

  const _ConnectivityGrid({
    required this.state,
    required this.onToggleAirplane,
    required this.onToggleAirdrop,
    required this.onToggleWifi,
    required this.onToggleBluetooth,
    required this.onToggleCellular,
    required this.onToggleData,
  });

  @override
  Widget build(BuildContext context) {
    // iOS connectivity module: three large toggles (Airplane, AirDrop,
    // Wi-Fi) plus a 2x2 cluster of smaller controls, laid out as a centered
    // 2x2 grid with equal horizontal and vertical spacing ([gap]).
    const double gap = 12;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CcRoundIcon(
                icon: Icons.airplanemode_active_rounded,
                active: state.airplane,
                activeColor: const Color(0xFFFF9500),
                onTap: onToggleAirplane,
                size: 54,
              ),
              const SizedBox(width: gap),
              _CcRoundIcon(
                icon: Icons.podcasts_rounded,
                active: state.airdrop,
                activeColor: const Color(0xFF007AFF),
                onTap: onToggleAirdrop,
                size: 54,
              ),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CcRoundIcon(
                icon: Icons.wifi_rounded,
                active: state.wifi,
                activeColor: const Color(0xFF007AFF),
                onTap: onToggleWifi,
                size: 54,
              ),
              const SizedBox(width: gap),
              _ConnectivityMiniGrid(
                state: state,
                onToggleCellular: onToggleCellular,
                onToggleBluetooth: onToggleBluetooth,
                onToggleData: onToggleData,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 2x2 cluster of smaller connectivity controls that fills the
/// bottom-right quadrant of the [_ConnectivityGrid] (Cellular, Bluetooth,
/// Personal Hotspot, Mobile Data) — the iOS connectivity-module look.
class _ConnectivityMiniGrid extends StatelessWidget {
  final CcConnectivityState state;
  final VoidCallback onToggleCellular;
  final VoidCallback onToggleBluetooth;
  final VoidCallback onToggleData;

  const _ConnectivityMiniGrid({
    required this.state,
    required this.onToggleCellular,
    required this.onToggleBluetooth,
    required this.onToggleData,
  });

  // Sized so the 2x2 cluster fills the same 54px square as a large toggle
  // (the Wi-Fi button to its left): 24 * 2 + 6 = 54.
  static const double _s = 24;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CcRoundIcon(
              icon: Icons.signal_cellular_alt_rounded,
              active: state.cellular,
              activeColor: const Color(0xFF34C759),
              onTap: onToggleCellular,
              size: _s,
            ),
            const SizedBox(width: _gap),
            _CcRoundIcon(
              icon: Icons.bluetooth_rounded,
              active: state.bluetooth,
              activeColor: const Color(0xFF007AFF),
              onTap: onToggleBluetooth,
              size: _s,
            ),
          ],
        ),
        const SizedBox(height: _gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _CcRoundIcon(
              icon: Icons.wifi_tethering_rounded,
              active: false,
              activeColor: Color(0xFF34C759),
              onTap: null,
              size: _s,
            ),
            const SizedBox(width: _gap),
            _CcRoundIcon(
              icon: Icons.public_rounded,
              active: state.data,
              activeColor: const Color(0xFF007AFF),
              onTap: onToggleData,
              size: _s,
            ),
          ],
        ),
      ],
    );
  }
}

class _CcRoundIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;

  /// `null` makes the icon a non-interactive (faded) decoration — used for
  /// the placeholder controls (e.g. Personal Hotspot) in the mini cluster.
  final VoidCallback? onTap;

  /// Diameter of the circle in logical pixels.
  final double size;

  const _CcRoundIcon({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.white.withAlpha(36),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(active ? 60 : 80),
              width: 0.6,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

class CcNowPlayingCard extends StatelessWidget {
  final String track;
  final String artist;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onAirplay;
  final Widget? artwork;

  const CcNowPlayingCard({
    super.key,
    required this.track,
    required this.artist,
    required this.isPlaying,
    required this.onPlayPause,
    this.onPrev,
    this.onNext,
    this.onAirplay,
    this.artwork,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLens(
      style: _cardStyle(),
      child: _NowPlayingBody(
        track: track,
        artist: artist,
        isPlaying: isPlaying,
        onPlayPause: onPlayPause,
        onPrev: onPrev,
        onNext: onNext,
        onAirplay: onAirplay,
        artwork: artwork,
      ),
    );
  }
}

class _NowPlayingBody extends StatelessWidget {
  final String track;
  final String artist;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onAirplay;
  final Widget? artwork;

  const _NowPlayingBody({
    required this.track,
    required this.artist,
    required this.isPlaying,
    required this.onPlayPause,
    this.onPrev,
    this.onNext,
    this.onAirplay,
    this.artwork,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: artwork ??
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF6B7280),
                              Color(0xFF374151),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAirplay,
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            track,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CcTransportButton(
                icon: Icons.fast_rewind_rounded,
                onTap: onPrev,
                size: 28,
              ),
              _CcTransportButton(
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: onPlayPause,
                size: 34,
              ),
              _CcTransportButton(
                icon: Icons.fast_forward_rounded,
                onTap: onNext,
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CcTransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  /// Glyph size — the play/pause button is rendered larger than the skips.
  final double size;

  const _CcTransportButton({
    required this.icon,
    required this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

class CcRoundTile extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final Color iconColor;
  final VoidCallback? onTap;

  /// Diameter of the tile — drives the circular corner radius. Must match
  /// the `SizedBox` the tile is placed in.
  final double size;

  const CcRoundTile({
    super.key,
    required this.icon,
    required this.size,
    this.active = false,
    this.activeColor = const Color(0xFFFF9500),
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLens(
      style: LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: size / 2,
        ),
        magnification: 1,
        dispersion: 0,
        saturation: 1.25,
        color: active
              ? activeColor.withAlpha(180)
              : Colors.white.withAlpha(50),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(icon, color: iconColor, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}

/// Visual fill drawn under the slider lens (white fill + bottom icon).
class VerticalSliderFill extends StatelessWidget {
  final double value;
  final IconData icon;
  final Color iconColor;
  final double width;
  final double height;

  const VerticalSliderFill({
    super.key,
    required this.value,
    required this.icon,
    this.iconColor = const Color(0xFF007AFF),
    this.width = 84,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final radius = width / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            FractionallySizedBox(
              heightFactor: value.clamp(0.0, 1.0),
              widthFactor: 1,
              child: Container(color: Colors.white),
            ),
            Positioned(
              bottom: 14,
              child: Icon(icon, color: iconColor, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass pill lens that overlays a [VerticalSliderFill]. Carries the
/// gesture detector mapping vertical drag to a 0..1 value.
class CcVerticalSliderLens extends StatelessWidget {
  /// Pill width — drives the circular corner radius. Must match the
  /// `SizedBox` this lens is placed in.
  final double width;
  final double height;
  final ValueChanged<double> onChanged;

  const CcVerticalSliderLens({
    super.key,
    required this.width,
    required this.height,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLens(
      style: LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: width / 2,
        ),
        magnification: 1,
        dispersion: 0,
        saturation: 1.25,
        color: Colors.white.withAlpha(50),
      ),
      child: _VerticalSliderGestureChild(
        width: width,
        height: height,
        onChanged: onChanged,
      ),
    );
  }
}

class _VerticalSliderGestureChild extends StatelessWidget {
  final double width;
  final double height;
  final ValueChanged<double> onChanged;

  const _VerticalSliderGestureChild({
    required this.width,
    required this.height,
    required this.onChanged,
  });

  void _handle(double localY) {
    final clamped = (1.0 - (localY / height)).clamp(0.0, 1.0);
    onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => _handle(d.localPosition.dy),
        onTapDown: (d) => _handle(d.localPosition.dy),
      ),
    );
  }
}

class CcFocusPill extends StatelessWidget {
  final VoidCallback onTap;

  /// Pill height — drives the circular corner radius. Must match the
  /// `SizedBox` this lens is placed in.
  final double height;

  const CcFocusPill({
    super.key,
    required this.onTap,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLens(
      style: LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: height / 2,
        ),
        dispersion: 0,
        saturation: 1.25,
        color: Colors.white.withAlpha(50),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Icon(
                  Icons.nightlight_round,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Focus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.unfold_more_rounded,
                  color: Colors.white.withAlpha(200),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS-style Control Center built entirely from liquid-glass lenses.
/// All tiles are [LiquidGlassLens] widgets placed inside a single
/// [LiquidGlassView]'s `child`; the view uses realtime capture so the
/// glass refracts live as tiles update.
class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> {
  final _viewController = LiquidGlassViewController();

  final CcConnectivityState _cc = CcConnectivityState();
  bool _playing = true;
  bool _lockRotation = false;
  bool _bell = true;
  double _brightness = 0.55;
  double _volume = 0.65;
  bool _torch = false;
  bool _timer = false;
  bool _calc = false;
  bool _camera = false;
  bool _darkMode = false;
  bool _screenMirror = false;
  bool _notes = false;
  bool _magnifier = false;

  static const double _pagePadding = 18;
  static const double _gutter = 14;
  static const double _topOffset = 185;
  static const double _bottomTileSize = 70;
  // The middle-row round tiles (rotation lock + silent) match the bottom row.
  static const double _roundTileSize = _bottomTileSize;
  static const double _vSliderWidth = 72;
  // Horizontal gap between the two vertical sliders.
  static const double _vSliderGap = 12;
  static const double _focusPillHeight = 72;
  // The sliders span the two left-column rows beside them — the round-tile
  // row, the gutter, and the focus pill — so their bottom lines up with the
  // focus pill's bottom.
  static const double _vSliderHeight =
      _roundTileSize + _gutter + _focusPillHeight;

  double _screenWidth = 0;

  double get _cardWidth => (_screenWidth - _pagePadding * 2 - _gutter) / 2;
  // The two top cards are square: their height tracks their width.
  double get _topCardHeight => _cardWidth;
  double get _leftColLeft => _pagePadding;
  double get _rightColLeft => _pagePadding + _cardWidth + _gutter;

  double get _topRowTop => _topOffset;
  double get _middleRowTop => _topRowTop + _topCardHeight + _gutter;
  double get _leftRoundTileLeft =>
      _leftColLeft + (_cardWidth - _roundTileSize * 2 - _gutter) / 2;
  double get _rightRoundTileLeft =>
      _leftRoundTileLeft + _roundTileSize + _gutter;

  double get _vSliderTop => _middleRowTop;
  // The two sliders sit as a centered group in the right column, separated
  // by [_vSliderGap].
  double get _vSliderGroupLeft =>
      _rightColLeft + (_cardWidth - (_vSliderWidth * 2 + _vSliderGap)) / 2;
  double get _brightnessLeft => _vSliderGroupLeft;
  double get _volumeLeft => _vSliderGroupLeft + _vSliderWidth + _vSliderGap;

  double get _focusPillTop => _middleRowTop + _roundTileSize + _gutter;

  double get _bottomRowTop =>
      _topRowTop + _topCardHeight + _gutter + _vSliderHeight + _gutter;
  // Second bottom row of round tiles, directly beneath the first.
  double get _bottomRow2Top => _bottomRowTop + _bottomTileSize + _gutter;
  double _bottomTileLeft(int index) {
    final spacing =
        (_screenWidth - _pagePadding * 2 - _bottomTileSize * 4) / 3;
    return _pagePadding + index * (_bottomTileSize + spacing);
  }

  /// Wraps a lens tile in the absolute placement + tight size the lens
  /// needs (the lens-anywhere API is layout-driven, so size comes from
  /// the `SizedBox`).
  Widget _placed({
    required double left,
    required double top,
    required double width,
    required double height,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(width: width, height: height, child: child),
    );
  }

  @override
  void dispose() {
    _viewController.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        _screenWidth = constraints.maxWidth;
        return Stack(
          children: [
            LiquidGlassView(
              batch: galleryBatch,
              controller: _viewController,
              backgroundWidget: const ControlCenterBackground(),
              pixelRatio: 1,
              useSync: true,
              realTimeCapture: true,
              refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _placed(
                    left: _leftColLeft,
                    top: _topRowTop,
                    width: _cardWidth,
                    height: _topCardHeight,
                    child: CcConnectivityCard(
                      state: _cc,
                      onToggleAirplane: () =>
                          setState(() => _cc.airplane = !_cc.airplane),
                      onToggleAirdrop: () =>
                          setState(() => _cc.airdrop = !_cc.airdrop),
                      onToggleWifi: () => setState(() => _cc.wifi = !_cc.wifi),
                      onToggleBluetooth: () =>
                          setState(() => _cc.bluetooth = !_cc.bluetooth),
                      onToggleCellular: () =>
                          setState(() => _cc.cellular = !_cc.cellular),
                      onToggleData: () => setState(() => _cc.data = !_cc.data),
                    ),
                  ),
                  _placed(
                    left: _rightColLeft,
                    top: _topRowTop,
                    width: _cardWidth,
                    height: _topCardHeight,
                    child: CcNowPlayingCard(
                      track: 'Backseat Driver',
                      artist: 'Kane Brown',
                      isPlaying: _playing,
                      onPlayPause: () => setState(() => _playing = !_playing),
                    ),
                  ),
                  _placed(
                    left: _leftRoundTileLeft,
                    top: _middleRowTop,
                    width: _roundTileSize,
                    height: _roundTileSize,
                    child: CcRoundTile(
                      size: _roundTileSize,
                      icon: Icons.screen_lock_rotation_rounded,
                      active: _lockRotation,
                      activeColor: const Color(0xFFFF3B30),
                      onTap: () =>
                          setState(() => _lockRotation = !_lockRotation),
                    ),
                  ),
                  _placed(
                    left: _rightRoundTileLeft,
                    top: _middleRowTop,
                    width: _roundTileSize,
                    height: _roundTileSize,
                    child: CcRoundTile(
                      size: _roundTileSize,
                      icon: _bell
                          ? Icons.notifications_rounded
                          : Icons.notifications_off_rounded,
                      active: !_bell,
                      activeColor: const Color(0xFFFF9500),
                      onTap: () => setState(() => _bell = !_bell),
                    ),
                  ),
                  _placed(
                    left: _brightnessLeft,
                    top: _vSliderTop,
                    width: _vSliderWidth,
                    height: _vSliderHeight,
                    child: CcVerticalSliderLens(
                      width: _vSliderWidth,
                      height: _vSliderHeight,
                      onChanged: (v) => setState(() => _brightness = v),
                    ),
                  ),
                  _placed(
                    left: _volumeLeft,
                    top: _vSliderTop,
                    width: _vSliderWidth,
                    height: _vSliderHeight,
                    child: CcVerticalSliderLens(
                      width: _vSliderWidth,
                      height: _vSliderHeight,
                      onChanged: (v) => setState(() => _volume = v),
                    ),
                  ),
                  _placed(
                    left: _leftColLeft,
                    top: _focusPillTop,
                    width: _cardWidth,
                    height: _focusPillHeight,
                    child: CcFocusPill(
                      height: _focusPillHeight,
                      onTap: () {},
                    ),
                  ),
                  _placed(
                    left: _bottomTileLeft(0),
                    top: _bottomRowTop,
                    width: _bottomTileSize,
                    height: _bottomTileSize,
                    child: CcRoundTile(
                      size: _bottomTileSize,
                      icon: Icons.flashlight_on_rounded,
                      active: _torch,
                      activeColor: const Color(0xFFFFCC00),
                      onTap: () => setState(() => _torch = !_torch),
                    ),
                  ),
                  _placed(
                    left: _bottomTileLeft(1),
                    top: _bottomRowTop,
                    width: _bottomTileSize,
                    height: _bottomTileSize,
                    child: CcRoundTile(
                      size: _bottomTileSize,
                      icon: Icons.timer_rounded,
                      active: _timer,
                      activeColor: const Color(0xFFFFCC00),
                      onTap: () => setState(() => _timer = !_timer),
                    ),
                  ),
                  _placed(
                    left: _bottomTileLeft(2),
                    top: _bottomRowTop,
                    width: _bottomTileSize,
                    height: _bottomTileSize,
                    child: CcRoundTile(
                      size: _bottomTileSize,
                      icon: Icons.calculate_rounded,
                      active: _calc,
                      activeColor: const Color(0xFFFF9500),
                      onTap: () => setState(() => _calc = !_calc),
                    ),
                  ),
                  _placed(
                    left: _bottomTileLeft(3),
                    top: _bottomRowTop,
                    width: _bottomTileSize,
                    height: _bottomTileSize,
                    child: CcRoundTile(
                      size: _bottomTileSize,
                      icon: Icons.photo_camera_rounded,
                      active: _camera,
                      activeColor: const Color(0xFFFFCC00),
                      onTap: () => setState(() => _camera = !_camera),
                    ),
                  ),
                  // ── second bottom row ──────────────────────────────
                  _placed(
                    left: _bottomTileLeft(0),
                    top: _bottomRow2Top,
                    width: _bottomTileSize,
                    height: _bottomTileSize,
                    child: CcRoundTile(
                      size: _bottomTileSize,
                      icon: Icons.dark_mode_rounded,
                      active: _darkMode,
                      activeColor: const Color(0xFF5E5CE6),
                      onTap: () => setState(() => _darkMode = !_darkMode),
                    ),
                  ),
                  _placed(
                    left: _bottomTileLeft(1),
                    top: _bottomRow2Top,
                    width: _bottomTileSize,
                    height: _bottomTileSize,
                    child: CcRoundTile(
                      size: _bottomTileSize,
                      icon: Icons.screen_share_rounded,
                      active: _screenMirror,
                      activeColor: const Color(0xFF007AFF),
                      onTap: () =>
                          setState(() => _screenMirror = !_screenMirror),
                    ),
                  ),
                  _placed(
                    left: _bottomTileLeft(2),
                    top: _bottomRow2Top,
                    width: _bottomTileSize,
                    height: _bottomTileSize,
                    child: CcRoundTile(
                      size: _bottomTileSize,
                      icon: Icons.sticky_note_2_rounded,
                      active: _notes,
                      activeColor: const Color(0xFFFFCC00),
                      onTap: () => setState(() => _notes = !_notes),
                    ),
                  ),
                  _placed(
                    left: _bottomTileLeft(3),
                    top: _bottomRow2Top,
                    width: _bottomTileSize,
                    height: _bottomTileSize,
                    child: CcRoundTile(
                      size: _bottomTileSize,
                      icon: Icons.zoom_in_rounded,
                      active: _magnifier,
                      activeColor: const Color(0xFFFF9500),
                      onTap: () => setState(() => _magnifier = !_magnifier),
                    ),
                  ),
                ],
              ),
            ),
            // Crisp slider fills drawn ON TOP so they aren't refracted
            // by the glass lens underneath (the lens refracts only the
            // wallpaper). IgnorePointer lets drags reach the lens below.
            Positioned(
              left: _brightnessLeft,
              top: _vSliderTop,
              child: IgnorePointer(
                child: VerticalSliderFill(
                  value: _brightness,
                  icon: Icons.brightness_high_rounded,
                  iconColor: const Color(0xFFFFB800),
                  width: _vSliderWidth,
                  height: _vSliderHeight,
                ),
              ),
            ),
            Positioned(
              left: _volumeLeft,
              top: _vSliderTop,
              child: IgnorePointer(
                child: VerticalSliderFill(
                  value: _volume,
                  icon: Icons.volume_up_rounded,
                  iconColor: const Color(0xFF007AFF),
                  width: _vSliderWidth,
                  height: _vSliderHeight,
                ),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(top: 36),
                  child: Text(
                    ' ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
