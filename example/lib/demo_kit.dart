import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Shared pieces for the one-component demo pages.
//
// A procedural backdrop with enough detail to read refraction against,
// a bottom control panel, and the chip / slider rows the panels use.
// Nothing here is glass: the point of each page is the one component
// it is named after, and these keep the rest out of the way.
// =============================================================

/// A painted backdrop: a two-tone gradient, soft colour blobs, and a fine
/// dot grid so magnification and distortion are visible through any lens.
class DemoBackdrop extends StatelessWidget {
  /// Picks the palette. Same seed, same picture, every build.
  final int seed;

  const DemoBackdrop({super.key, this.seed = 0});

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF1B1035), Color(0xFF0E7490), Color(0xFFF59E0B)],
    <Color>[Color(0xFF14532D), Color(0xFF0369A1), Color(0xFFE11D48)],
    <Color>[Color(0xFF3B0764), Color(0xFFBE185D), Color(0xFFFBBF24)],
    <Color>[Color(0xFF0F172A), Color(0xFF2563EB), Color(0xFF22D3EE)],
  ];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackdropPainter(_palettes[seed % _palettes.length], seed),
      child: const SizedBox.expand(),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final List<Color> colors;
  final int seed;
  const _BackdropPainter(this.colors, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors[0], colors[1]],
        ).createShader(rect),
    );

    // Soft blobs: big, low-alpha discs so a lens passing over one bends a
    // visible colour edge.
    final math.Random rng = math.Random(seed * 7919 + 17);
    for (int i = 0; i < 9; i++) {
      final double r = size.shortestSide * (0.18 + rng.nextDouble() * 0.28);
      final Offset c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final Color tint = colors[1 + (i % 2)];
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              tint.withValues(alpha: 0.55),
              tint.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // The dot grid. Fine, even, high contrast: the thing refraction and
    // magnification are easiest to see against.
    final Paint dot = Paint()..color = Colors.white.withValues(alpha: 0.28);
    const double step = 22;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.4, dot);
      }
    }

    // A few diagonal bands so straight edges cross the glass too.
    final Paint band = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 26;
    for (double x = -size.height; x < size.width; x += 140) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), band);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.seed != seed || old.colors != colors;
}

/// A photo from the project's asset repo, with [DemoBackdrop] standing in
/// while it loads or if it cannot.
class DemoPhoto extends StatelessWidget {
  /// File name in the asset repo — `mountain.jpg`, `rain.jpg`, `neon.png` —
  /// or a full `http` URL, for a photo that lives somewhere else.
  final String name;

  /// Seed for the stand-in backdrop.
  final int seed;

  /// How dark a scrim to lay over the photo so white text reads on it.
  final double scrim;

  const DemoPhoto(this.name, {super.key, this.seed = 0, this.scrim = 0.18});

  static String urlFor(String name) => name.startsWith('http')
      ? name
      : 'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
          '/main/$name';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.network(
          urlFor(name),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => DemoBackdrop(seed: seed),
          loadingBuilder: (BuildContext context, Widget child,
              ImageChunkEvent? progress) {
            if (progress == null) return child;
            return DemoBackdrop(seed: seed);
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: scrim),
          ),
        ),
      ],
    );
  }
}

/// A page header for the scaffold's `appBar` slot: a round glass back
/// button on the left and the title dead-centre, on a Stack so the title
/// centres on the screen rather than on what is left beside the button.
class DemoHeader extends StatelessWidget {
  final String title;

  /// Ink for the title and the back glyph — white over a photo, near-black
  /// on a light page.
  final Color foreground;

  /// The back button's glass. Defaults to a clear capsule with a soft rim.
  final LiquidGlassStyle? style;

  static const double height = 52;

  const DemoHeader({
    super.key,
    required this.title,
    this.foreground = Colors.white,
    this.style,
  });

  static const LiquidGlassStyle _clear = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(
      cornerRadius: height / 2,
      borderWidth: 0.8,
    ),
    appearance: LiquidGlassAppearance(
      blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
      color: Color(0x1AFFFFFF),
    ),
    refraction: LiquidGlassRefraction(distortion: 0.08, distortionWidth: 22),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Center(
              child: Text(
                title,
                style: TextStyle(
                  color: foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: LiquidGlassTabBarAction(
                icon: Icons.arrow_back_ios_new_rounded,
                size: height,
                foregroundColor: foreground,
                onTap: () => Navigator.of(context).maybePop(),
                style: style ?? _clear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dark card the controls sit on, pinned to the bottom of the page.
///
/// The header is a toggle: tap it and the controls fold away, leaving a
/// single title strip. A panel of chips and sliders covers the bottom
/// third of a phone, and the thing every one of these pages is actually
/// about is the glass behind it — so getting the panel out of the way has
/// to be one tap, from the panel itself.
class DemoPanel extends StatefulWidget {
  final String title;
  final List<Widget> children;

  /// Whether the controls start showing. The pages open with them out.
  final bool initiallyOpen;

  const DemoPanel({
    super.key,
    required this.title,
    required this.children,
    this.initiallyOpen = true,
  });

  @override
  State<DemoPanel> createState() => _DemoPanelState();
}

class _DemoPanelState extends State<DemoPanel> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xCC15161C),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  // The whole strip is the target, not just the glyph.
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      Icon(
                        _open
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              if (_open) ...<Widget>[
                const SizedBox(height: 2),
                ...widget.children,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of mutually exclusive chips.
class DemoChips<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const DemoChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final T v in values)
          _Chip(
            text: label(v),
            selected: v == selected,
            onTap: () => onChanged(v),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? const Color(0xFF15161C) : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A labelled slider row with the live value beside the label.
class DemoSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final ValueChanged<double> onChanged;

  const DemoSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 150,
          child: Text(
            '$label  ${value.toStringAsFixed(decimals)}',
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: const Color(0xFFB8B5FF),
              thumbColor: const Color(0xFFB8B5FF),
              inactiveTrackColor: const Color(0x33FFFFFF),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
