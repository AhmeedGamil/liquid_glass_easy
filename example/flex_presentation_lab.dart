import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../lab/flex_presentation/flex_driver.dart';
import '../lab/flex_presentation/flex_routes.dart';

// =============================================================
// Lab: should a dialog and a sheet arrive on the FLEX model?
//
//   cd example && flutter run -t flex_presentation_lab.dart
//
// Impeller (the default) — a lens presented in a route is above the
// scaffold that owns the capture, so on Skia there is no background for
// it to refract and the comparison is about a grey rectangle.
//
// WHAT IS BEING COMPARED
//
//   Dialog · shipping   showLiquidGlassDialog exactly as it ships:
//                       ScaleTransition 0.84 → 1.0 over 350ms on
//                       Cubic(0.16, 1, 0.3, 1). One anchor, one number,
//                       symmetric, no fade (an Opacity layer would
//                       isolate the lens's backdrop).
//   Dialog · flex       the same panel released from a flex entry: four
//                       edges on their own springs, area given back
//                       across the axes, content pinned at rest size,
//                       optics deepened while it moves.
//
//   Sheet · shipping    showLiquidGlassSheet, i.e. Flutter's own
//                       showModalBottomSheet — a curve-driven slide.
//   Sheet · flex        a spring-driven slide, plus the same soft-body
//                       arrival on top of it.
//
// WHAT IS THE SAME ON BOTH SIDES
// The content, the rest size, and the glass — the flex panels build
// their style from `LiquidGlassDialog.defaultStyle` and
// `LiquidGlassSheet.defaultStyle`, the very constants the components
// resolve. Only the motion differs.
//
// WHAT IS NOT
//  * The flex panels are a raw `LiquidGlassLens`, not `LiquidGlassDialog`
//    / `LiquidGlassSheet`. The deform has to reach the LENS's box —
//    growing it so the shader runs at the new size, rather than scaling
//    a rendered result — and there is no way in from outside.
//  * The flex sheet has no drag-to-dismiss. The shipping one gets that
//    from the framework route it wraps.
//  * The knobs apply to the NEXT open, not to a panel already up.
//
// THE ONE THING TO ACTUALLY LOOK AT
// Turn slow motion to 6× and watch the rim on the vertical edges. Under
// the shipping scale the whole rendered lens is magnified, so the rim
// thickens on the way in and thins as it lands. Under flex the lens is
// re-laid-out at each size, so the rim stays one pixel the whole way and
// only the shape moves. That is the difference the model exists for; the
// wobble is the part you notice first and the part that matters least.
// =============================================================

void main() => runApp(const FlexLabApp());

class FlexLabApp extends StatelessWidget {
  const FlexLabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flex presentation lab',
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        home: const FlexLabPage(),
      );
}

/// What the last button pressed was, so Replay can repeat it.
enum _Last { dialogShipping, dialogFlex, sheetShipping, sheetFlex }

class FlexLabPage extends StatefulWidget {
  const FlexLabPage({super.key});

  @override
  State<FlexLabPage> createState() => _FlexLabPageState();
}

class _FlexLabPageState extends State<FlexLabPage> {
  // ── The flex spec, live ────────────────────────────────────
  double _openScale = -0.16;
  double _pullY = -34;
  double _stiffness = 320;
  double _releaseDamping = 17;
  double _squeeze = 0.70;
  double _grip = 0.70;
  double _childFollow = 1.0;
  double _refractionBoost = 0.15;
  double _slowMo = 1;

  _Last? _last;

  LiquidGlassFlex get _spec => LiquidGlassFlex(
        stretch: 13,
        squeeze: _squeeze,
        lean: 0.5,
        grip: _grip,
        maxPull: 48,
        holdScale: 0.03,
        tapScale: 0.02,
        advanced: LiquidGlassFlexAdvanced(
          childFollow: _childFollow,
          refractionBoost: _refractionBoost,
          stiffness: _stiffness,
          damping: 24,
          releaseDamping: _releaseDamping,
        ),
      );

  /// The dialog's own shape, as `LiquidGlassDialog.build` derives it when
  /// the style names none. Copied rather than reached for: the component
  /// builds it inline.
  static final LiquidGlassStyle _dialogStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(
      cornerRadius: 28,
      borderWidth: 1.2,
      lightIntensity: 1.2,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.3,
        ambientIntensity: 1.0,
        borderSolidity: 0.4,
      ),
    ),
    appearance: LiquidGlassDialog.defaultStyle.appearance,
    refraction: LiquidGlassDialog.defaultStyle.refraction,
  );

  static final LiquidGlassStyle _sheetStyle = LiquidGlassStyle(
    shape: LiquidGlassSheet.defaultShape(),
    appearance: LiquidGlassSheet.defaultStyle.appearance,
    refraction: LiquidGlassSheet.defaultStyle.refraction,
  );

  static const Size _dialogRest = Size(320, 288);
  Size _sheetRest(BuildContext context) =>
      Size(MediaQuery.sizeOf(context).width - 20, 292);

  // ── The four presentations ─────────────────────────────────

  void _run(_Last which) {
    setState(() => _last = which);
    timeDilation = _slowMo;
    switch (which) {
      case _Last.dialogShipping:
        _dialogShipping();
      case _Last.dialogFlex:
        _dialogFlex();
      case _Last.sheetShipping:
        _sheetShipping();
      case _Last.sheetFlex:
        _sheetFlex();
    }
  }

  Future<void> _dialogShipping() async {
    await showLiquidGlassDialog<void>(
      context: context,
      builder: (BuildContext context) => LiquidGlassDialog(
        width: _dialogRest.width,
        padding: EdgeInsets.zero,
        child: SizedBox.fromSize(
          size: _dialogRest,
          child: _PanelBody(
            title: 'Dialog · shipping',
            note: 'ScaleTransition 0.84 → 1.0, 350ms, one anchor.',
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
    timeDilation = 1;
  }

  Future<void> _dialogFlex() async {
    await showFlexDialog<void>(
      context: context,
      restSize: _dialogRest,
      style: _dialogStyle,
      spec: _spec,
      entry: FlexEntry(
        grab: const Offset(0.5, 1.0),
        pull: Offset(0, _pullY),
        openScale: _openScale,
      ),
      builder: (BuildContext context, VoidCallback dismiss) => _PanelBody(
        title: 'Dialog · flex',
        note: 'Four edge springs released from a grab at the bottom.',
        onClose: dismiss,
      ),
    );
    timeDilation = 1;
  }

  Future<void> _sheetShipping() async {
    await showLiquidGlassSheet<void>(
      context: context,
      grabber: false,
      padding: EdgeInsets.zero,
      builder: (BuildContext context) => SizedBox(
        height: _sheetRest(context).height,
        child: _PanelBody(
          title: 'Sheet · shipping',
          note: "Flutter's modal slide, curve-driven.",
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
    timeDilation = 1;
  }

  Future<void> _sheetFlex() async {
    await showFlexSheet<void>(
      context: context,
      restSize: _sheetRest(context),
      style: _sheetStyle,
      spec: _spec,
      entry: FlexEntry(
        grab: const Offset(0.5, 1.0),
        pull: Offset(0, _pullY),
        openScale: _openScale,
      ),
      builder: (BuildContext context, VoidCallback dismiss) => _PanelBody(
        title: 'Sheet · flex',
        note: 'Spring slide, then a soft-body settle.',
        onClose: dismiss,
      ),
    );
    timeDilation = 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _TestBackdrop()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
              children: <Widget>[
                const Text(
                  'Flex as a presentation',
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Same panel, same glass, same size. Only the motion '
                  'differs. Run one, then the other, then raise slow '
                  'motion and watch the rim rather than the wobble.',
                  style: TextStyle(
                      fontSize: 13, height: 1.45, color: Color(0xB3FFFFFF)),
                ),
                const SizedBox(height: 20),

                // ── The four ─────────────────────────────────
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Run(
                        label: 'Dialog',
                        sub: 'shipping',
                        onTap: () => _run(_Last.dialogShipping),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Run(
                        label: 'Dialog',
                        sub: 'flex',
                        accent: true,
                        onTap: () => _run(_Last.dialogFlex),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Run(
                        label: 'Sheet',
                        sub: 'shipping',
                        onTap: () => _run(_Last.sheetShipping),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Run(
                        label: 'Sheet',
                        sub: 'flex',
                        accent: true,
                        onTap: () => _run(_Last.sheetFlex),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Replay(
                  enabled: _last != null,
                  onTap: () => _last == null ? null : _run(_last!),
                ),

                // ── Slow motion ──────────────────────────────
                const SizedBox(height: 26),
                const _Head('Slow motion'),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    for (final double x in <double>[1, 3, 6, 12])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Pill(
                          label: '${x.toInt()}×',
                          selected: _slowMo == x,
                          onTap: () => setState(() => _slowMo = x),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Applies to both sides — it is timeDilation, so the '
                  'route curve and the springs slow together.',
                  style: TextStyle(fontSize: 11.5, color: Color(0x8AFFFFFF)),
                ),

                // ── The spec ─────────────────────────────────
                const SizedBox(height: 24),
                const _Head('The entry it is released from'),
                _Knob(
                  label: 'Open scale',
                  value: _openScale,
                  min: -0.4,
                  max: 0.1,
                  note: 'Negative starts it small. −0.16 is the 0.84 the '
                      'shipping dialog scales from.',
                  onChanged: (double v) => setState(() => _openScale = v),
                ),
                _Knob(
                  label: 'Pull Y',
                  value: _pullY,
                  min: -80,
                  max: 80,
                  digits: 0,
                  note: 'The imaginary drag. Negative pulls up off the grab '
                      'point at the bottom edge, so it opens stretched.',
                  onChanged: (double v) => setState(() => _pullY = v),
                ),
                _Knob(
                  label: 'Grip',
                  value: _grip,
                  min: 0,
                  max: 1,
                  note: '0 deforms every edge equally; 1 gives it all to the '
                      'edges nearest the grab.',
                  onChanged: (double v) => setState(() => _grip = v),
                ),
                _Knob(
                  label: 'Squeeze',
                  value: _squeeze,
                  min: 0,
                  max: 1,
                  note: 'How much of the height it gains comes back out of '
                      'its width. 0 is a plain scale.',
                  onChanged: (double v) => setState(() => _squeeze = v),
                ),

                const SizedBox(height: 18),
                const _Head('The springs'),
                _Knob(
                  label: 'Stiffness',
                  value: _stiffness,
                  min: 80,
                  max: 700,
                  digits: 0,
                  onChanged: (double v) => setState(() => _stiffness = v),
                ),
                _Knob(
                  label: 'Release damping',
                  value: _releaseDamping,
                  min: 6,
                  max: 40,
                  digits: 0,
                  note: 'Lower is more recoil. This is the number that '
                      'decides whether the arrival reads as soft or as loose.',
                  onChanged: (double v) => setState(() => _releaseDamping = v),
                ),
                _Knob(
                  label: 'Child follow',
                  value: _childFollow,
                  min: 0,
                  max: 1,
                  note: '1 makes the content rubbery with the glass; 0 leaves '
                      'the text alone while the surface moves.',
                  onChanged: (double v) => setState(() => _childFollow = v),
                ),
                _Knob(
                  label: 'Refraction boost',
                  value: _refractionBoost,
                  min: 0,
                  max: 0.6,
                  note: 'How much harder the glass bends while it is still '
                      'moving. The shipping transition has no equivalent.',
                  onChanged: (double v) => setState(() => _refractionBoost = v),
                ),

                const SizedBox(height: 24),
                const _Note(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── The panel both sides show ────────────────────────────────

class _PanelBody extends StatelessWidget {
  const _PanelBody({
    required this.title,
    required this.note,
    required this.onClose,
  });

  final String title;
  final String note;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                note,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xB3FFFFFF),
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              // A hard rule and a row of blocks: the content has edges
              // too, and under `childFollow` they are what shows whether
              // the inside is riding the glass or sitting still on it.
              Container(height: 1, color: const Color(0x33FFFFFF)),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  for (int i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color.lerp(const Color(0xFF6C8CFF),
                              const Color(0xFFFF7AB6), i / 4)!,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── The thing being refracted ────────────────────────────────

/// Hard edges in every direction, because that is the only way to see
/// what a lens is doing. Rings for curvature, a rule grid for straight
/// lines, and colour bands so chromatic aberration has something to
/// split.
class _TestBackdrop extends StatelessWidget {
  const _TestBackdrop();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BackdropPainter(), child: const SizedBox.expand());
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF16213D),
            Color(0xFF3A1B45),
            Color(0xFF0E2C36),
          ],
        ).createShader(rect),
    );

    // Colour bands, at an angle so no edge is parallel to a panel's.
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.35);
    const List<Color> bands = <Color>[
      Color(0xFFFF6B6B),
      Color(0xFFFFD166),
      Color(0xFF06D6A0),
      Color(0xFF4CC9F0),
      Color(0xFFB388FF),
    ];
    for (int i = 0; i < 22; i++) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, (i - 11) * size.height * 0.075),
          width: size.width * 2.4,
          height: size.height * 0.020,
        ),
        Paint()..color = bands[i % bands.length].withValues(alpha: 0.5),
      );
    }
    canvas.restore();

    // Rings, off-centre.
    final Offset c = Offset(size.width * 0.30, size.height * 0.34);
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x59FFFFFF);
    for (int i = 1; i <= 14; i++) {
      canvas.drawCircle(c, i * size.shortestSide * 0.085, ring);
    }

    // A fine grid — the straight lines a bent edge is measured against.
    final Paint grid = Paint()..color = const Color(0x1FFFFFFF);
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), grid);
    }

    // Dots on a coarser pitch, for judging magnification.
    final Paint dot = Paint()..color = const Color(0x73FFFFFF);
    for (double x = 11; x < size.width; x += 44) {
      for (double y = 11; y < size.height; y += 44) {
        canvas.drawCircle(Offset(x, y), 1.6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => false;
}

// ── Controls ─────────────────────────────────────────────────

class _Run extends StatelessWidget {
  const _Run({
    required this.label,
    required this.sub,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent ? const Color(0xFF6C8CFF) : const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent ? const Color(0xFF6C8CFF) : const Color(0x33FFFFFF),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label,
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 3),
            Text(sub,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: accent ? Colors.white : const Color(0x99FFFFFF),
                )),
          ],
        ),
      ),
    );
  }
}

class _Replay extends StatelessWidget {
  const _Replay({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: const Text(
            'Replay the last one',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          color: Color(0x8AFFFFFF),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? Colors.white : const Color(0x33FFFFFF)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF0B0D12) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _Knob extends StatelessWidget {
  const _Knob({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.note,
    this.digits = 2,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String? note;
  final int digits;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const Spacer(),
              Text(
                value.toStringAsFixed(digits),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  color: Color(0xB3FFFFFF),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: const Color(0xFF6C8CFF),
              inactiveTrackColor: const Color(0x2EFFFFFF),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                note!,
                style: const TextStyle(
                    fontSize: 11.5, height: 1.35, color: Color(0x8AFFFFFF)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Head('What is honest about this'),
          const SizedBox(height: 10),
          for (final String line in const <String>[
            'Flex is pointer-driven. LiquidGlassFlexDriver takes down / '
                'move / up and is not exported, so nothing in the package '
                'can present with it today. The lab re-derives the model '
                'against the public spring and LiquidGlassFlexDeform.',
            'The flex panels are a raw lens, not LiquidGlassDialog / '
                'LiquidGlassSheet: the deform has to grow the lens\'s BOX '
                'so the shader re-runs at each size. Scaling a rendered '
                'lens instead is the thing being compared against.',
            'Glass, size and content are identical on both sides. The '
                'flex styles are built from the components\' own '
                'defaultStyle constants.',
            'The flex sheet has no drag-to-dismiss — that comes from the '
                'framework route the shipping one wraps.',
            'Knobs apply to the next open, not to a panel already up.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('· ',
                      style: TextStyle(color: Color(0x8AFFFFFF), fontSize: 12)),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: Color(0x99FFFFFF)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Text(
            'Springs settle when every edge is within 0.05px and 0.5px/s '
            'of its target — which is why the exit pops on a callback '
            'rather than a duration.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
