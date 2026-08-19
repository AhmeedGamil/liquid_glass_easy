import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'kitchen_backdrop_picker.dart';
import 'kitchen_glass_params.dart';
import 'kitchen_glass_surface.dart';
import 'kitchen_lab_backdrop.dart';
import 'kitchen_tuner_widgets.dart';

/// Playground for the experimental glass shader.
///
/// Four lobes can be dragged around a busy backdrop and fuse into one liquid
/// surface as they meet. Every shader uniform is on the panel behind the
/// bottom-right button, which stays hidden until it is asked for.
class KitchenGlassLabPage extends StatefulWidget {
  const KitchenGlassLabPage({super.key, this.onPickImage});

  /// Overrides how a backdrop picture is chosen. Left null the lab uses its
  /// own plugin-free chooser, which reads the app's external files directory
  /// (see [showBackdropPicker]).
  final Future<ui.Image?> Function(BuildContext context)? onPickImage;

  @override
  State<KitchenGlassLabPage> createState() => _KitchenGlassLabPageState();
}

class _KitchenGlassLabPageState extends State<KitchenGlassLabPage> {
  ui.FragmentShader? _shader;
  Object? _loadError;

  ui.Image? _photo;
  bool _picking = false;

  KitchenGlassParams _params = KitchenGlassParams.lens;
  String? _presetName = 'Lens';

  int _lobeCount = 3;
  int _selected = 0;
  bool _panelOpen = false;
  bool _showHandles = false;

  // Top-left of each lobe, and its size. Both are live: the panel resizes the
  // selected lobe, the drag gestures move it.
  final List<Offset> _origins = <Offset>[
    const Offset(60, 220),
    const Offset(170, 300),
    const Offset(90, 400),
    const Offset(210, 470),
  ];
  final List<Size> _sizes = <Size>[
    const Size(150, 110),
    const Size(120, 120),
    const Size(180, 90),
    const Size(110, 150),
  ];

  static const List<Offset> _defaultOrigins = <Offset>[
    Offset(60, 220),
    Offset(170, 300),
    Offset(90, 400),
    Offset(210, 470),
  ];
  static const List<Size> _defaultSizes = <Size>[
    Size(150, 110),
    Size(120, 120),
    Size(180, 90),
    Size(110, 150),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ui.FragmentShader shader = await loadKitchenGlassShader();
      if (!mounted) {
        shader.dispose();
        return;
      }
      setState(() => _shader = shader);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    _photo?.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    final Future<ui.Image?> Function(BuildContext) picker =
        widget.onPickImage ?? showBackdropPicker;
    setState(() => _picking = true);
    try {
      final ui.Image? image = await picker(context);
      if (!mounted) {
        image?.dispose();
        return;
      }
      if (image != null) {
        setState(() {
          _photo?.dispose();
          _photo = image;
        });
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _clearPhoto() {
    setState(() {
      _photo?.dispose();
      _photo = null;
    });
  }

  void _edit(KitchenGlassParams next) {
    setState(() {
      _params = next;
      _presetName = null;
    });
  }

  void _applyPreset(String name) {
    setState(() {
      _params = KitchenGlassParams.presets[name]!;
      _presetName = name;
    });
  }

  void _resetLayout() {
    setState(() {
      for (int i = 0; i < _origins.length; i++) {
        _origins[i] = _defaultOrigins[i];
        _sizes[i] = _defaultSizes[i];
      }
    });
  }

  List<KitchenGlassLobe> _lobes() {
    return <KitchenGlassLobe>[
      for (int i = 0; i < _lobeCount; i++)
        KitchenGlassLobe(_origins[i] & _sizes[i]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return _Message('Shader failed to load:\n$_loadError');
    }
    if (!kitchenGlassSupported) {
      return const _Message(
        'This surface needs the Impeller shader image filter.\n'
        'Run on a device or simulator with Impeller enabled.',
      );
    }
    final ui.FragmentShader? shader = _shader;
    if (shader == null) {
      return const _Message('Compiling shader…');
    }

    final Size screen = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: KitchenLabBackdrop(photo: _photo)),

          // The glass pass itself: one BackdropFilter over the whole page.
          Positioned.fill(
            child: KitchenGlassSurface(
              shader: shader,
              lobes: _lobes(),
              params: _params,
              child: const SizedBox.expand(),
            ),
          ),

          // Drag targets, one per active lobe, sitting above the glass.
          for (int i = 0; i < _lobeCount; i++)
            Positioned(
              left: _origins[i].dx,
              top: _origins[i].dy,
              width: _sizes[i].width,
              height: _sizes[i].height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _selected = i),
                onPanStart: (_) => setState(() => _selected = i),
                onPanUpdate: (DragUpdateDetails d) {
                  setState(() {
                    final Size s = _sizes[i];
                    final Offset next = _origins[i] + d.delta;
                    _origins[i] = Offset(
                      next.dx.clamp(-s.width * 0.5, screen.width - s.width * 0.5),
                      next.dy.clamp(-s.height * 0.5, screen.height - s.height * 0.5),
                    );
                  });
                },
                child: _showHandles
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: i == _selected
                                ? const Color(0xFF6BE3FF)
                                : const Color(0x66FFFFFF),
                            width: i == _selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

          // Hidden tuning panel.
          _TuningPanel(
            open: _panelOpen,
            params: _params,
            presetName: _presetName,
            lobeCount: _lobeCount,
            selected: _selected,
            selectedSize: _sizes[_selected],
            showHandles: _showHandles,
            hasPhoto: _photo != null,
            picking: _picking,
            onPickPhoto: _pickPhoto,
            onClearPhoto: _clearPhoto,
            onClose: () => setState(() => _panelOpen = false),
            onParams: _edit,
            onPreset: _applyPreset,
            onLobeCount: (int n) => setState(() {
              _lobeCount = n;
              if (_selected >= n) _selected = n - 1;
            }),
            onSelect: (int i) => setState(() => _selected = i),
            onSelectedSize: (Size s) => setState(() => _sizes[_selected] = s),
            onShowHandles: (bool v) => setState(() => _showHandles = v),
            onResetLayout: _resetLayout,
          ),

          if (!_panelOpen)
            Positioned(
              right: 16,
              bottom: 28,
              child: SafeArea(
                child: _RoundButton(
                  icon: Icons.tune,
                  label: 'Tune',
                  onTap: () => setState(() => _panelOpen = true),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Slide-up sheet holding every uniform the shader takes.
class _TuningPanel extends StatelessWidget {
  const _TuningPanel({
    required this.open,
    required this.params,
    required this.presetName,
    required this.lobeCount,
    required this.selected,
    required this.selectedSize,
    required this.showHandles,
    required this.hasPhoto,
    required this.picking,
    required this.onPickPhoto,
    required this.onClearPhoto,
    required this.onClose,
    required this.onParams,
    required this.onPreset,
    required this.onLobeCount,
    required this.onSelect,
    required this.onSelectedSize,
    required this.onShowHandles,
    required this.onResetLayout,
  });

  final bool open;
  final KitchenGlassParams params;
  final String? presetName;
  final int lobeCount;
  final int selected;
  final Size selectedSize;
  final bool showHandles;
  final bool hasPhoto;
  final bool picking;
  final VoidCallback onPickPhoto;
  final VoidCallback onClearPhoto;
  final VoidCallback onClose;
  final ValueChanged<KitchenGlassParams> onParams;
  final ValueChanged<String> onPreset;
  final ValueChanged<int> onLobeCount;
  final ValueChanged<int> onSelect;
  final ValueChanged<Size> onSelectedSize;
  final ValueChanged<bool> onShowHandles;
  final VoidCallback onResetLayout;

  static const List<Color> _tints = <Color>[
    Color(0x00FFFFFF),
    Color(0xFFFFFFFF),
    Color(0xFFE6F2FF),
    Color(0xFF9FE8FF),
    Color(0xFFFFD9A8),
    Color(0xFF12203A),
  ];

  @override
  Widget build(BuildContext context) {
    final double height = math.min(MediaQuery.sizeOf(context).height * 0.62, 560);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: open ? 0 : -height - 40,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xF00E1116),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: <BoxShadow>[
            BoxShadow(color: Color(0x88000000), blurRadius: 24, offset: Offset(0, -6)),
          ],
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 4),
              child: Row(
                children: <Widget>[
                  const Text(
                    'Glass parameters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                children: <Widget>[
                  TunerSection(
                    title: 'Background',
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: picking ? null : onPickPhoto,
                              icon: picking
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.image_outlined, size: 18),
                              label: Text(hasPhoto ? 'Change photo' : 'Pick a photo'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: hasPhoto ? onClearPhoto : null,
                            child: const Text('Generated'),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Reads the app folder on the device — no permission, '
                          'no plugin. The chooser shows where to copy files.',
                          style: TextStyle(color: Colors.white38, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                  TunerSection(
                    title: 'Presets',
                    children: <Widget>[
                      ChipRow<String>(
                        values: KitchenGlassParams.presets.keys.toList(),
                        selected: presetName,
                        label: (String v) => v,
                        onSelect: onPreset,
                      ),
                    ],
                  ),
                  TunerSection(
                    title: 'Blending',
                    children: <Widget>[
                      ChipRow<int>(
                        values: const <int>[1, 2, 3, 4],
                        selected: lobeCount,
                        label: (int v) => '$v lobe${v == 1 ? '' : 's'}',
                        onSelect: onLobeCount,
                      ),
                      TunerSlider(
                        label: 'Merge smoothness',
                        value: params.mergeSmoothness,
                        min: 0.5,
                        max: 120,
                        onChanged: (double v) =>
                            onParams(params.copyWith(mergeSmoothness: v)),
                      ),
                      TunerSlider(
                        label: 'Corner radius',
                        value: params.cornerRadius,
                        min: 0,
                        max: 120,
                        onChanged: (double v) =>
                            onParams(params.copyWith(cornerRadius: v)),
                      ),
                      TunerSlider(
                        label: 'Corner exponent',
                        value: params.cornerExponent,
                        min: 1,
                        max: 8,
                        onChanged: (double v) =>
                            onParams(params.copyWith(cornerExponent: v)),
                      ),
                    ],
                  ),
                  TunerSection(
                    title: 'Glass',
                    children: <Widget>[
                      TunerSlider(
                        label: 'Thickness',
                        value: params.thickness,
                        min: 1,
                        max: 80,
                        onChanged: (double v) =>
                            onParams(params.copyWith(thickness: v)),
                      ),
                      TunerSlider(
                        label: 'Refractive index',
                        value: params.refractiveIndex,
                        min: 1.001,
                        max: 2.2,
                        onChanged: (double v) =>
                            onParams(params.copyWith(refractiveIndex: v)),
                      ),
                      TunerSlider(
                        label: 'Dispersion',
                        value: params.dispersion,
                        min: 0,
                        max: 30,
                        onChanged: (double v) =>
                            onParams(params.copyWith(dispersion: v)),
                      ),
                      TunerSlider(
                        label: 'Magnification',
                        value: params.magnification,
                        min: 0.4,
                        max: 2.5,
                        onChanged: (double v) =>
                            onParams(params.copyWith(magnification: v)),
                      ),
                      TunerSlider(
                        label: 'Backdrop blur',
                        value: params.blur,
                        min: 0,
                        max: 30,
                        onChanged: (double v) => onParams(params.copyWith(blur: v)),
                      ),
                    ],
                  ),
                  TunerSection(
                    title: 'Tint',
                    children: <Widget>[
                      SwatchRow(
                        colors: _tints,
                        selected: params.tint,
                        onSelect: (Color c) => onParams(
                          params.copyWith(
                            tint: c.withValues(alpha: params.tint.a == 0 ? 0.2 : params.tint.a),
                          ),
                        ),
                      ),
                      TunerSlider(
                        label: 'Tint amount',
                        value: params.tint.a,
                        min: 0,
                        max: 1,
                        onChanged: (double v) => onParams(
                          params.copyWith(tint: params.tint.withValues(alpha: v)),
                        ),
                      ),
                    ],
                  ),
                  TunerSection(
                    title: 'Fresnel rim',
                    children: <Widget>[
                      TunerSlider(
                        label: 'Range',
                        value: params.fresnelRange,
                        min: 5,
                        max: 400,
                        onChanged: (double v) =>
                            onParams(params.copyWith(fresnelRange: v)),
                      ),
                      TunerSlider(
                        label: 'Intensity',
                        value: params.fresnelIntensity,
                        min: 0,
                        max: 2,
                        onChanged: (double v) =>
                            onParams(params.copyWith(fresnelIntensity: v)),
                      ),
                      TunerSlider(
                        label: 'Sharpness',
                        value: params.fresnelSharpness,
                        min: -0.6,
                        max: 0.4,
                        onChanged: (double v) =>
                            onParams(params.copyWith(fresnelSharpness: v)),
                      ),
                    ],
                  ),
                  TunerSection(
                    title: 'Glare',
                    children: <Widget>[
                      TunerSlider(
                        label: 'Range',
                        value: params.glareRange,
                        min: 5,
                        max: 400,
                        onChanged: (double v) =>
                            onParams(params.copyWith(glareRange: v)),
                      ),
                      TunerSlider(
                        label: 'Intensity',
                        value: params.glareIntensity,
                        min: 0,
                        max: 2,
                        onChanged: (double v) =>
                            onParams(params.copyWith(glareIntensity: v)),
                      ),
                      TunerSlider(
                        label: 'Convergence',
                        value: params.glareConvergence,
                        min: 0,
                        max: 1,
                        onChanged: (double v) =>
                            onParams(params.copyWith(glareConvergence: v)),
                      ),
                      TunerSlider(
                        label: 'Opposite bias',
                        value: params.glareOppositeBias,
                        min: 0,
                        max: 3,
                        onChanged: (double v) =>
                            onParams(params.copyWith(glareOppositeBias: v)),
                      ),
                      TunerSlider(
                        label: 'Sharpness',
                        value: params.glareSharpness,
                        min: -0.6,
                        max: 0.4,
                        onChanged: (double v) =>
                            onParams(params.copyWith(glareSharpness: v)),
                      ),
                      TunerSlider(
                        label: 'Angle offset',
                        value: params.glareAngleOffset,
                        min: -math.pi,
                        max: math.pi,
                        onChanged: (double v) =>
                            onParams(params.copyWith(glareAngleOffset: v)),
                      ),
                      TunerSlider(
                        label: 'Edge gain',
                        value: params.edgeGain,
                        min: 0,
                        max: 20,
                        onChanged: (double v) =>
                            onParams(params.copyWith(edgeGain: v)),
                      ),
                    ],
                  ),
                  TunerSection(
                    title: 'Layout',
                    children: <Widget>[
                      ChipRow<int>(
                        values: <int>[for (int i = 0; i < lobeCount; i++) i],
                        selected: selected,
                        label: (int v) => 'Lobe ${v + 1}',
                        onSelect: onSelect,
                      ),
                      TunerSlider(
                        label: 'Width',
                        value: selectedSize.width,
                        min: 40,
                        max: 340,
                        onChanged: (double v) =>
                            onSelectedSize(Size(v, selectedSize.height)),
                      ),
                      TunerSlider(
                        label: 'Height',
                        value: selectedSize.height,
                        min: 40,
                        max: 340,
                        onChanged: (double v) =>
                            onSelectedSize(Size(selectedSize.width, v)),
                      ),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TunerSwitch(
                              label: 'Outlines',
                              value: showHandles,
                              onChanged: onShowHandles,
                            ),
                          ),
                          TextButton(
                            onPressed: onResetLayout,
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TunerSection(
                    title: 'Debug',
                    children: <Widget>[
                      ChipRow<int>(
                        values: const <int>[0, 1, 2],
                        selected: params.debugMode.round(),
                        label: (int v) =>
                            <String>['Glass', 'Field', 'Normals'][v],
                        onSelect: (int v) =>
                            onParams(params.copyWith(debugMode: v.toDouble())),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xEE151A22),
      shape: const StadiumBorder(),
      elevation: 8,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E13),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
      ),
    );
  }
}
