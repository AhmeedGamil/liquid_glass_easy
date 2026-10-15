import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens a colour picker over [initial] as a low bottom sheet that leaves
/// the screen above it undimmed, so the glass shows while it changes. Every
/// change is handed to [onChanged] as it happens; Cancel hands [initial]
/// back, Done or closing the sheet keeps the colour.
Future<void> showRgbaColorPicker({
  required BuildContext context,
  required String title,
  required Color initial,
  required ValueChanged<Color> onChanged,
}) async {
  final bool? cancelled = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // A vertical drag on the square must pick, not close the sheet.
    enableDrag: false,
    barrierColor: Colors.transparent,
    backgroundColor: _panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _PickerSheet(
      title: title,
      initial: initial,
      onChanged: onChanged,
    ),
  );
  if (cancelled == true) onChanged(initial);
}

const Color _panel = Color(0xFF1C1D24);
const Color _ink = Color(0xDDFFFFFF);
const Color _faint = Color(0x55FFFFFF);
const Color _accent = Color(0xFFB8B5FF);

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.initial,
    required this.onChanged,
  });

  final String title;
  final Color initial;
  final ValueChanged<Color> onChanged;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  /// The exact colour, channel by channel: what the fields show and what
  /// is handed out.
  late Color _color = widget.initial;

  /// The square and the hue strip work in HSV. Kept apart from [_color] so
  /// a grey or black keeps the hue it was picked at.
  late HSVColor _hsv = HSVColor.fromColor(widget.initial.withAlpha(255));

  late final Map<String, TextEditingController> _fields = {
    'R': TextEditingController(),
    'G': TextEditingController(),
    'B': TextEditingController(),
    'A': TextEditingController(),
    'hex': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _writeFields();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _channel(double v) => (v * 255).round().clamp(0, 255);

  int get _r => _channel(_color.r);
  int get _g => _channel(_color.g);
  int get _b => _channel(_color.b);
  int get _a => _channel(_color.a);

  String get _hex =>
      _color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();

  /// Puts the colour in the fields, leaving [except] as the user typed it.
  void _writeFields({String? except}) {
    void put(String key, String text) {
      if (key == except || _fields[key]!.text == text) return;
      _fields[key]!.text = text;
    }

    put('R', '$_r');
    put('G', '$_g');
    put('B', '$_b');
    put('A', '$_a');
    put('hex', _hex);
  }

  void _emit({String? except}) {
    _writeFields(except: except);
    widget.onChanged(_color);
  }

  /// A drag on the square, the hue or the opacity strip.
  void _pickHsv(HSVColor hsv, {int? alpha}) {
    setState(() {
      _hsv = hsv;
      _color = hsv.toColor().withAlpha(alpha ?? _a);
    });
    _emit();
  }

  void _pickAlpha(int alpha) {
    setState(() => _color = _color.withAlpha(alpha));
    _emit();
  }

  /// A typed channel, 0..255.
  void _typedChannel(String key, String text) {
    final int? v = int.tryParse(text);
    if (v == null || v < 0 || v > 255) return;
    setState(() {
      _color = Color.fromARGB(
        key == 'A' ? v : _a,
        key == 'R' ? v : _r,
        key == 'G' ? v : _g,
        key == 'B' ? v : _b,
      );
      if (key != 'A') _hsv = _hsvKeepingHue(_color);
    });
    _emit(except: key);
  }

  /// A typed hex: RRGGBB keeps the opacity, AARRGGBB sets it too.
  void _typedHex(String text) {
    final String t = text.replaceAll('#', '').trim();
    if (t.length != 6 && t.length != 8) return;
    final int? v = int.tryParse(t, radix: 16);
    if (v == null) return;
    setState(() {
      _color = t.length == 6 ? Color(v).withAlpha(_a) : Color(v);
      _hsv = _hsvKeepingHue(_color);
    });
    _emit(except: 'hex');
  }

  /// [c] in HSV, keeping the current hue when [c] has none (a grey).
  HSVColor _hsvKeepingHue(Color c) {
    final HSVColor next = HSVColor.fromColor(c.withAlpha(255));
    return next.saturation == 0 || next.value == 0
        ? next.withHue(_hsv.hue)
        : next;
  }

  @override
  Widget build(BuildContext context) {
    // Rides up over the keyboard while a value is typed.
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + keyboard),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Swatch(color: _color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Cancel', style: TextStyle(color: _ink)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF15161C),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SatValSquare(hsv: _hsv, onChanged: _pickHsv),
            const SizedBox(height: 8),
            _Strip(
              value: _hsv.hue / 360,
              background: const LinearGradient(colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ]),
              onChanged: (t) => _pickHsv(_hsv.withHue(t * 360)),
            ),
            const SizedBox(height: 8),
            _Strip(
              value: _a / 255,
              checkered: true,
              background: LinearGradient(colors: [
                _color.withAlpha(0),
                _color.withAlpha(255),
              ]),
              onChanged: (t) => _pickAlpha((t * 255).round()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final String key in const ['R', 'G', 'B', 'A']) ...[
                  Expanded(
                    flex: 2,
                    child: _Field(
                      label: key,
                      controller: _fields[key]!,
                      digitsOnly: true,
                      onChanged: (t) => _typedChannel(key, t),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  flex: 4,
                  child: _Field(
                    label: 'Hex',
                    controller: _fields['hex']!,
                    onChanged: _typedHex,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The colour over a white-black split, so its opacity shows.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _faint),
        gradient: const LinearGradient(
          colors: [Colors.white, Colors.white, Colors.black, Colors.black],
          stops: [0, 0.5, 0.5, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
        ),
      ),
    );
  }
}

/// Saturation across, brightness down, at the current hue.
class _SatValSquare extends StatelessWidget {
  const _SatValSquare({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4,
      child: LayoutBuilder(
        builder: (context, box) {
          void pick(Offset p) {
            final double s = (p.dx / box.maxWidth).clamp(0.0, 1.0);
            final double v = 1 - (p.dy / box.maxHeight).clamp(0.0, 1.0);
            onChanged(hsv.withSaturation(s).withValue(v));
          }

          return GestureDetector(
            onPanDown: (d) => pick(d.localPosition),
            onPanUpdate: (d) => pick(d.localPosition),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _SatValPainter(hsv),
                size: Size(box.maxWidth, box.maxHeight),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SatValPainter extends CustomPainter {
  const _SatValPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Color hue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            LinearGradient(colors: [Colors.white, hue]).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF000000)],
        ).createShader(rect),
    );
    final Offset at = Offset(
      hsv.saturation * size.width,
      (1 - hsv.value) * size.height,
    );
    canvas.drawCircle(
      at,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black54,
    );
    canvas.drawCircle(
      at,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SatValPainter old) => old.hsv != hsv;
}

/// A horizontal strip picked along its length, `0..1`.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.value,
    required this.background,
    required this.onChanged,
    this.checkered = false,
  });

  final double value;
  final Gradient background;
  final ValueChanged<double> onChanged;

  /// A checkerboard under the gradient, for the opacity strip.
  final bool checkered;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, box) {
          void pick(Offset p) =>
              onChanged((p.dx / box.maxWidth).clamp(0.0, 1.0));
          final double x = value.clamp(0.0, 1.0) * box.maxWidth;
          return GestureDetector(
            onPanDown: (d) => pick(d.localPosition),
            onPanUpdate: (d) => pick(d.localPosition),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CustomPaint(
                      painter: checkered ? const _Checker() : null,
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: background),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: x - 4,
                  top: -2,
                  bottom: -2,
                  width: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Checker extends CustomPainter {
  const _Checker();

  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 7;
    final Paint light = Paint()..color = const Color(0xFFCCCCCC);
    final Paint dark = Paint()..color = const Color(0xFF888888);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final bool even = ((x / cell).floor() + (y / cell).floor()).isEven;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), even ? light : dark);
      }
    }
  }

  @override
  bool shouldRepaint(_Checker old) => false;
}

/// A labelled text box for one value.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.digitsOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
        if (digitsOnly) LengthLimitingTextInputFormatter(3),
        if (!digitsOnly)
          FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
        if (!digitsOnly) LengthLimitingTextInputFormatter(9),
      ],
      style: const TextStyle(
        color: _ink,
        fontSize: 14,
        fontFamily: 'monospace',
      ),
      textAlign: digitsOnly ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _faint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }
}
