// -----------------------------------------------------------------------------
// PAINTED BORDER — the glass rim without a fragment shader.
//
// Two cards, the same LiquidGlassShape driving both. The left one is a real
// lens: its rim comes out of the glass shader, per pixel, off the refracted
// background. The right one is a LiquidGlassLite: the same lighting model,
// evaluated on the Dart side and drawn as one triangle mesh — no shader
// program, nothing to warm up. Turn the light and watch them turn together.
//
// Run it on its own:
//     cd example
//     flutter run -t lib/painted_border_page.dart
// -----------------------------------------------------------------------------

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(const _PaintedBorderApp());

class _PaintedBorderApp extends StatelessWidget {
  const _PaintedBorderApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PaintedBorderPage(),
      );
}

class PaintedBorderPage extends StatefulWidget {
  const PaintedBorderPage({super.key});

  @override
  State<PaintedBorderPage> createState() => _PaintedBorderPageState();
}

class _PaintedBorderPageState extends State<PaintedBorderPage> {
  double _borderWidth = 1.5;
  double _lightDirection = 40;
  double _lightIntensity = 1.0;
  double _lightSpread = 0.5;
  bool _optical = true;
  bool _radial = false;
  bool _tinted = false;

  static const Size _card = Size(150, 118);

  /// The one shape both cards are built from.
  LiquidGlassShape get _shape => LiquidGlassShape(
        cornerRadius: 30,
        clipQuality: LiquidGlassClipQuality.exact,
        borderWidth: _borderWidth,
        lightIntensity: _lightIntensity,
        lightDirection: _lightDirection,
        lightMode:
            _radial ? LiquidGlassLightMode.radial : LiquidGlassLightMode.edge,
        borderType: _optical
            ? OpticalBorder(lightSpread: _lightSpread)
            : const ClassicBorder(borderSoftness: 2),
      );

  @override
  Widget build(BuildContext context) {
    final LiquidGlassShape shape = _shape;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _Backdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Text(
                    'Same shape, same light. One rim is a shader, the other is '
                    'a mesh.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _Labelled(
                      label: 'shader',
                      child: SizedBox.fromSize(
                        size: _card,
                        child: LiquidGlassLens(
                          style: LiquidGlassStyle(
                            shape: shape,
                            appearance: const LiquidGlassAppearance(
                              color: Color(0x14FFFFFF),
                              blur: LiquidGlassBlur(sigmaX: 6, sigmaY: 6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 26),
                    _Labelled(
                      label: 'painted',
                      child: SizedBox.fromSize(
                        size: _card,
                        child: LiquidGlassLite(
                          shape: shape,
                          ambientColor: _tinted ? const Color(0xFF3E82F7) : null,
                          child: liquidGlassClip(
                            shape: shape,
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 6,
                                sigmaY: 6,
                              ),
                              child: Container(color: const Color(0x14FFFFFF)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _ChipRow(shape: shape),
                const Spacer(),
                _Controls(
                  borderWidth: _borderWidth,
                  lightDirection: _lightDirection,
                  lightIntensity: _lightIntensity,
                  lightSpread: _lightSpread,
                  optical: _optical,
                  radial: _radial,
                  tinted: _tinted,
                  onChanged: (_ControlValues v) => setState(() {
                    _borderWidth = v.borderWidth;
                    _lightDirection = v.lightDirection;
                    _lightIntensity = v.lightIntensity;
                    _lightSpread = v.lightSpread;
                    _optical = v.optical;
                    _radial = v.radial;
                    _tinted = v.tinted;
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eighteen rims at once — the case a real lens would not be spent on.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.shape});

  final LiquidGlassShape shape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (int i = 0; i < 18; i++)
            SizedBox(
              width: 62,
              height: 34,
              child: LiquidGlassLite(
                shape: LiquidGlassShape(
                  cornerRadius: 17,
                  borderWidth: shape.borderWidth,
                  lightIntensity: shape.lightIntensity,
                  lightDirection: shape.lightDirection,
                  lightMode: shape.lightMode,
                  borderType: shape.borderType,
                ),
                child: const ColoredBox(color: Color(0x10FFFFFF)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          child,
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
        ],
      );
}

class _ControlValues {
  const _ControlValues({
    required this.borderWidth,
    required this.lightDirection,
    required this.lightIntensity,
    required this.lightSpread,
    required this.optical,
    required this.radial,
    required this.tinted,
  });

  final double borderWidth;
  final double lightDirection;
  final double lightIntensity;
  final double lightSpread;
  final bool optical;
  final bool radial;
  final bool tinted;

  _ControlValues copyWith({
    double? borderWidth,
    double? lightDirection,
    double? lightIntensity,
    double? lightSpread,
    bool? optical,
    bool? radial,
    bool? tinted,
  }) =>
      _ControlValues(
        borderWidth: borderWidth ?? this.borderWidth,
        lightDirection: lightDirection ?? this.lightDirection,
        lightIntensity: lightIntensity ?? this.lightIntensity,
        lightSpread: lightSpread ?? this.lightSpread,
        optical: optical ?? this.optical,
        radial: radial ?? this.radial,
        tinted: tinted ?? this.tinted,
      );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.borderWidth,
    required this.lightDirection,
    required this.lightIntensity,
    required this.lightSpread,
    required this.optical,
    required this.radial,
    required this.tinted,
    required this.onChanged,
  });

  final double borderWidth;
  final double lightDirection;
  final double lightIntensity;
  final double lightSpread;
  final bool optical;
  final bool radial;
  final bool tinted;
  final ValueChanged<_ControlValues> onChanged;

  _ControlValues get _values => _ControlValues(
        borderWidth: borderWidth,
        lightDirection: lightDirection,
        lightIntensity: lightIntensity,
        lightSpread: lightSpread,
        optical: optical,
        radial: radial,
        tinted: tinted,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      color: Colors.black38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _slider('width', borderWidth, 0, 6,
              (double v) => onChanged(_values.copyWith(borderWidth: v))),
          _slider('light', lightDirection, 0, 360,
              (double v) => onChanged(_values.copyWith(lightDirection: v))),
          _slider('intensity', lightIntensity, 0, 3,
              (double v) => onChanged(_values.copyWith(lightIntensity: v))),
          if (optical)
            _slider('spread', lightSpread, 0, 1,
                (double v) => onChanged(_values.copyWith(lightSpread: v))),
          Row(
            children: <Widget>[
              _toggle('optical', optical,
                  (bool v) => onChanged(_values.copyWith(optical: v))),
              _toggle('radial', radial,
                  (bool v) => onChanged(_values.copyWith(radial: v))),
              _toggle('ambient tint', tinted,
                  (bool v) => onChanged(_values.copyWith(tinted: v))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onSlide,
  ) =>
      Row(
        children: <Widget>[
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onSlide,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(value >= 100 ? 0 : 2),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      );

  Widget _toggle(String label, bool value, ValueChanged<bool> onTap) => Expanded(
        child: GestureDetector(
          onTap: () => onTap(!value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: value ? Colors.white24 : Colors.white10,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: value ? Colors.white : Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
        ),
      );
}

/// A procedural background with enough colour and contrast that a rim has
/// something to sit against.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF11131C),
              Color(0xFF1E2A5A),
              Color(0xFF7B2D6B),
              Color(0xFFB4552B),
            ],
            stops: <double>[0, 0.38, 0.72, 1],
          ),
        ),
        child: CustomPaint(painter: _BlobPainter()),
      );
}

class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final List<(Offset, double, Color)> blobs = <(Offset, double, Color)>[
      (Offset(size.width * 0.18, size.height * 0.22), 120, const Color(0x5533E1C4)),
      (Offset(size.width * 0.82, size.height * 0.30), 150, const Color(0x55FFC24B)),
      (Offset(size.width * 0.55, size.height * 0.62), 180, const Color(0x4400C2FF)),
    ];
    for (final (Offset centre, double radius, Color color) in blobs) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
