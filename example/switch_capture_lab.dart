import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../lab/switch_picture_capture/recorded_switch.dart';
import '../lab/switch_picture_capture/switch_glass_source.dart';

// =============================================================
// Lab: the switch's first-tap stall, and whether a PICTURE RECORD
// removes it.
//
//   cd example && flutter run --profile --no-enable-impeller \
//       -t switch_capture_lab.dart
//
// --no-enable-impeller is not optional. The stall being chased is the
// Skia raster thread's; on Impeller the same activation measured ~21 ms
// and there is nothing to see.
//
// Three modes, one mounted at a time:
//
//   package        the shipping LiquidGlassSwitch, untouched. The
//                  reference number.
//   view capture   the lab's copy on the SAME path the package uses —
//                  OffsetLayer.toImageSync, a scene rasterized through
//                  the compositor. Proves the copy is faithful; if this
//                  does not match `package`, the comparison below is
//                  meaningless.
//   picture record the experiment. The track's layer already holds this
//                  frame's ui.Pictures; replay them into a
//                  PictureRecorder and rasterize that one display list
//                  with Picture.toImageSync. No scene, no compositor.
//
// READ THIS BEFORE TRUSTING A NUMBER
// The GPU program cache is per-PROCESS. Whichever switch you touch
// first pays for every program the others then reuse, so only the FIRST
// activation after a full app launch is a first-activation measurement.
// Hot restart does not clear it — the engine survives. Relaunch the app
// between modes.
// =============================================================

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SwitchCaptureLabPage(),
    ),
  );
}

enum LabMode {
  package('package', 'LiquidGlassSwitch, untouched'),
  viewCapture('view capture', 'OffsetLayer.toImageSync — scene rasterize'),
  pictureRecord('picture record', 'Picture.toImageSync — display list');

  const LabMode(this.label, this.blurb);
  final String label;
  final String blurb;
}

/// One activation's cost, as the frame timings saw it.
class _Activation {
  final int index;
  final Duration raster;
  final Duration build;
  final int frames;

  const _Activation({
    required this.index,
    required this.raster,
    required this.build,
    required this.frames,
  });
}

class SwitchCaptureLabPage extends StatefulWidget {
  const SwitchCaptureLabPage({super.key});

  @override
  State<SwitchCaptureLabPage> createState() => _SwitchCaptureLabPageState();
}

class _SwitchCaptureLabPageState extends State<SwitchCaptureLabPage> {
  LabMode _mode = LabMode.pictureRecord;
  bool _on = false;

  /// Activations recorded since this mode was mounted, newest last.
  final List<_Activation> _log = <_Activation>[];

  /// Whether a measurement window is open. Frame timings arriving while
  /// it is are folded into the pending activation.
  bool _armed = false;
  Duration _maxRaster = Duration.zero;
  Duration _maxBuild = Duration.zero;
  int _frames = 0;
  Timer? _closer;

  /// Rolling average of the composition's Dart-side cost. Not the stall
  /// — both sources hand back a lazily-rasterized handle — but it is
  /// what tells you whether the record is cheap to BUILD.
  Duration _composeTotal = Duration.zero;
  int _composeCount = 0;

  /// Layer kinds the picture replay could not reproduce. Should stay
  /// empty for the switch; anything here means the record is not
  /// equivalent to the capture and the comparison is off.
  final Set<String> _dropped = <String>{};

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _closer?.cancel();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_armed) return;
    for (final FrameTiming t in timings) {
      if (t.rasterDuration > _maxRaster) _maxRaster = t.rasterDuration;
      if (t.buildDuration > _maxBuild) _maxBuild = t.buildDuration;
      _frames++;
    }
  }

  /// Opens a measurement window on pointer-down — the moment the morph
  /// starts, which is the moment the glass, the shadow and the capture
  /// all arrive at once.
  void _arm() {
    if (_armed) return;
    _armed = true;
    _maxRaster = Duration.zero;
    _maxBuild = Duration.zero;
    _frames = 0;
    // Long enough to cover the expand, the glide and the contraction,
    // plus the lag before timings are reported back.
    _closer?.cancel();
    _closer = Timer(const Duration(milliseconds: 1200), _close);
  }

  void _close() {
    if (!_armed) return;
    _armed = false;
    final _Activation a = _Activation(
      index: _log.length + 1,
      raster: _maxRaster,
      build: _maxBuild,
      frames: _frames,
    );
    setState(() => _log.add(a));
    debugPrint('[LAB] ${_mode.label} activation ${a.index}: '
        'raster ${_ms(a.raster)} ms, build ${_ms(a.build)} ms, '
        '${a.frames} frames');
  }

  static String _ms(Duration d) =>
      (d.inMicroseconds / 1000).toStringAsFixed(1).padLeft(6);

  void _selectMode(LabMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _log.clear();
      _composeTotal = Duration.zero;
      _composeCount = 0;
      _dropped.clear();
    });
  }

  void _onComposed(Duration d) {
    _composeTotal += d;
    _composeCount++;
  }

  void _onDropped(String kind) {
    if (_dropped.add(kind)) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101318),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'switch capture lab',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Where the glass thumb gets the image it refracts.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _modeSelector(),
              const SizedBox(height: 8),
              Text(
                _mode.blurb,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 28),
              _stage(),
              const SizedBox(height: 28),
              _readout(),
              const SizedBox(height: 20),
              _caveat(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final LabMode mode in LabMode.values)
          GestureDetector(
            onTap: () => _selectMode(mode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: mode == _mode
                    ? const Color(0xFF2E6BE6)
                    : const Color(0xFF1C212B),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                mode.label,
                style: TextStyle(
                  color: mode == _mode ? Colors.white : Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The switch, over something worth refracting.
  Widget _stage() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B3550), Color(0xFF5B3A57), Color(0xFF2E4A44)],
        ),
      ),
      child: Center(
        child: Listener(
          onPointerDown: (_) => _arm(),
          // The switch is the only thing under test; keying it on the
          // mode means changing modes mounts a fresh one rather than
          // reconfiguring a warm one.
          child: KeyedSubtree(
            key: ValueKey<LabMode>(_mode),
            child: _switchForMode(),
          ),
        ),
      ),
    );
  }

  Widget _switchForMode() {
    if (_mode == LabMode.package) {
      return LiquidGlassSwitch(
        value: _on,
        onChanged: (v) => setState(() => _on = v),
      );
    }
    return RecordedGlassSwitch(
      value: _on,
      onChanged: (v) => setState(() => _on = v),
      source: _mode == LabMode.viewCapture
          ? SwitchGlassSource.viewCapture
          : SwitchGlassSource.pictureRecord,
      onComposed: _onComposed,
      onUnsupportedLayer: _onDropped,
    );
  }

  Widget _readout() {
    final Duration? avgCompose = _composeCount == 0
        ? null
        : Duration(microseconds: _composeTotal.inMicroseconds ~/ _composeCount);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'peak frame cost per activation',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'window opens on pointer-down, closes 1.2 s later',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
          const SizedBox(height: 14),
          if (_log.isEmpty)
            const Text(
              'tap the switch',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            )
          else ...[
            const Row(
              children: [
                SizedBox(width: 34, child: Text('#', style: _headStyle)),
                SizedBox(width: 92, child: Text('raster', style: _headStyle)),
                SizedBox(width: 92, child: Text('build', style: _headStyle)),
                Text('frames', style: _headStyle),
              ],
            ),
            const SizedBox(height: 6),
            for (final _Activation a in _log) _activationRow(a),
          ],
          if (avgCompose != null) ...[
            const SizedBox(height: 14),
            Text(
              'compose ${_ms(avgCompose)} ms avg over $_composeCount frames '
              '(Dart side only)',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
          if (_dropped.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'replay dropped: ${_dropped.join(", ")} — the record is NOT '
              'equivalent to the capture, so the numbers below are not '
              'comparable',
              style: const TextStyle(color: Color(0xFFE0605A), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activationRow(_Activation a) {
    // The first activation is the one the whole lab exists for.
    final bool first = a.index == 1;
    final TextStyle style = TextStyle(
      color: first ? const Color(0xFFF0B849) : Colors.white70,
      fontSize: 13,
      fontFamily: 'monospace',
      fontWeight: first ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text('${a.index}', style: style)),
          SizedBox(width: 92, child: Text('${_ms(a.raster)} ms', style: style)),
          SizedBox(width: 92, child: Text('${_ms(a.build)} ms', style: style)),
          Text('${a.frames}', style: style),
        ],
      ),
    );
  }

  Widget _caveat() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x22F0B849),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55F0B849)),
      ),
      child: const Text(
        'The GPU program cache is per-process. Whichever switch you touch '
        'first pays for every program the others then reuse — so row 1 is a '
        'first-activation reading only if this is the first switch touched '
        'since the app launched. Hot restart does not clear it. Relaunch '
        'between modes.',
        style: TextStyle(color: Color(0xFFF0B849), fontSize: 11.5, height: 1.5),
      ),
    );
  }
}

const TextStyle _headStyle = TextStyle(color: Colors.white38, fontSize: 11);
