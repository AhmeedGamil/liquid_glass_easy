import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy_example/tuner_widgets.dart';

import '../lab/nav_picture_capture/pill_glass_source.dart';
import '../lab/nav_picture_capture/recorded_pill_bar.dart';

// =============================================================
// Tuner: the tab bar's moving pill fed by a PICTURE RECORD of the bar
// instead of the second full-frame capture the shipping bar takes.
//
//   cd example && flutter run -t tab_record_tuner.dart
//
// Three resolutions are on sliders, and they are not the same knob:
//
//   page    the inner view's capture — screen-sized, every frame, shared
//           by all three sources. What the bar capsule refracts, and the
//           page half of the pill's image.
//   record  what the BAR is recorded at. Match it to `pill` and the bar
//           goes straight into the pill's image in one pass; move it and
//           the record becomes its own image first, at its own
//           resolution, which costs a second rasterization.
//   pill    the pill's image itself — a small region on the recorded
//           sources, the whole screen on `outer view`.
//
// The panel below is the page the bar refracts, so everything on it —
// sliders included — is inside the capture and still fully interactive.
// =============================================================

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const TabRecordTunerPage(),
    ),
  );
}

class TabRecordTunerPage extends StatefulWidget {
  const TabRecordTunerPage({super.key});

  @override
  State<TabRecordTunerPage> createState() => _TabRecordTunerPageState();
}

class _TabRecordTunerPageState extends State<TabRecordTunerPage> {
  // ── what is being tuned ──────────────────────────────────────
  PillGlassSource _source = PillGlassSource.recordedPicture;
  double _pageRatio = 1.0;
  double _recordRatio = 2.0;
  double _pillRatio = 2.0;
  bool _capsuleBlur = false;
  bool _peek = false;

  /// Whether the pill clears its interior on the landing. Off is the
  /// thing worth seeing at a low `pill` ratio — the icon pops from soft
  /// to crisp as the glass leaves.
  bool _innerClear = true;

  final PillImageSink _sink = PillImageSink();

  // ── what it costs ────────────────────────────────────────────
  double _rasterMs = 0;
  double _uiMs = 0;
  double _composeMs = 0;
  Size _composed = Size.zero;
  String? _dropped;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    double raster = 0;
    double build = 0;
    for (final FrameTiming t in timings) {
      raster += t.rasterDuration.inMicroseconds / 1000;
      build += t.buildDuration.inMicroseconds / 1000;
    }
    // Smoothed: these have to be readable while the pill is moving, not
    // exact for one frame.
    _rasterMs = _rasterMs * 0.8 + (raster / timings.length) * 0.2;
    _uiMs = _uiMs * 0.8 + (build / timings.length) * 0.2;
    _push();
  }

  void _push() {
    final DateTime now = DateTime.now();
    if (now.difference(_lastPush).inMilliseconds < 400) return;
    _lastPush = now;
    if (mounted) setState(() {});
  }

  void _reset() => setState(() {
        _source = PillGlassSource.recordedPicture;
        _pageRatio = 1.0;
        _recordRatio = 2.0;
        _pillRatio = 2.0;
        _capsuleBlur = false;
        _innerClear = true;
        _dropped = null;
      });

  bool get _recorded => _source != PillGlassSource.outerView;
  bool get _replays => _source == PillGlassSource.recordedPicture;
  bool get _twoPass => _replays && (_recordRatio - _pillRatio).abs() > 0.01;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);

    return Scaffold(
      body: RecordedPillBar(
        source: _source,
        pageRatio: _pageRatio,
        recordRatio: _recordRatio,
        pillRatio: _pillRatio,
        capsuleBlur: _capsuleBlur,
        clearInteriorOnLanding: _innerClear,
        sink: _sink,
        onComposed: (d) {
          _composeMs = _composeMs * 0.85 + (d.inMicroseconds / 1000) * 0.15;
          final ui.Image? image = _sink.image;
          if (image != null) {
            _composed =
                Size(image.width.toDouble(), image.height.toDouble());
          }
        },
        onUnsupportedLayer: (kind) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _dropped = kind);
          });
        },
        body: Stack(
          fit: StackFit.expand,
          children: [
            TunerGradientBackground(
              child: Material(
                type: MaterialType.transparency,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      16, MediaQuery.paddingOf(context).top + 16, 16, 190),
                  children: [
                    _pipelineCard(),
                    const SizedBox(height: 14),
                    _resolutionCard(dpr),
                    const SizedBox(height: 14),
                    _costCard(screen),
                    const SizedBox(height: 14),
                    _looksCard(),
                    const SizedBox(height: 14),
                    const _ContrastStrip(),
                    const SizedBox(height: 14),
                    TunerCodeCard(snippet: _snippet(), onReset: _reset),
                  ],
                ),
              ),
            ),
            // The record itself, drawn straight, so it can be judged
            // without the glass that samples it in the way.
            if (_peek && _recorded)
              Positioned(
                right: 12,
                bottom: 190,
                child: _RecordPeek(sink: _sink),
              ),
          ],
        ),
      ),
    );
  }

  // ── cards ────────────────────────────────────────────────────

  Widget _pipelineCard() {
    const Map<PillGlassSource, (String, String)> copy = {
      PillGlassSource.outerView: (
        'outer view',
        'The shipping design. A second LiquidGlassView captures the whole '
            'inner stack — page, capsule, icons — full frame, every frame.',
      ),
      PillGlassSource.recordedPicture: (
        'picture record',
        'The experiment. The page crop comes out of the inner capture that '
            'already exists; the bar is replayed from the ui.Pictures its '
            'layers recorded this frame.',
      ),
      PillGlassSource.regionRaster: (
        'region raster',
        'The control. Same small region, but rasterized off the inner '
            'stack layer instead of replayed — which keeps the capsule '
            'blur, because the page is inside the same scene.',
      ),
    };

    return TunerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TunerPanelTitle('Pill image source'),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final PillGlassSource s in PillGlassSource.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _source = s;
                        _dropped = null;
                        _composed = Size.zero;
                      }),
                      child: Container(
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s == _source
                              ? kTunerAccent.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: s == _source
                                ? kTunerAccent
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          copy[s]!.$1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color:
                                s == _source ? kTunerAccent : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            copy[_source]!.$2,
            style: const TextStyle(
                fontSize: 12, color: Colors.white54, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _resolutionCard(double dpr) {
    final String device = dpr.toStringAsFixed(2);
    return TunerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TunerPanelTitle('Capture resolution'),
              const Spacer(),
              if (_replays)
                TunerBadge(
                    text: _twoPass ? 'TWO PASS' : 'ONE PASS', good: !_twoPass),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'This screen is $device×. Above it nothing sharpens — the '
            'capture is already denser than the display.',
            style: const TextStyle(
                fontSize: 12, color: Colors.white54, height: 1.3),
          ),
          const SizedBox(height: 8),
          TunerParamSlider('page', _pageRatio, 0.5, 3.0,
              '${_pageRatio.toStringAsFixed(2)}×',
              (v) => setState(() => _pageRatio = v)),
          TunerParamSlider('record', _recordRatio, 0.5, 3.0,
              '${_recordRatio.toStringAsFixed(2)}×',
              (v) => setState(() => _recordRatio = v)),
          TunerParamSlider('pill', _pillRatio, 0.5, 3.0,
              '${_pillRatio.toStringAsFixed(2)}×',
              (v) => setState(() => _pillRatio = v)),
          const SizedBox(height: 6),
          Text(
            _resolutionHint(),
            style: const TextStyle(
                fontSize: 12, color: Colors.white54, height: 1.35),
          ),
        ],
      ),
    );
  }

  String _resolutionHint() {
    if (!_recorded) {
      return 'On outer view the pill’s image IS a full-frame capture, so '
          '“pill” buys resolution across the whole screen. '
          '“record” does nothing here.';
    }
    if (!_replays) {
      return 'Region raster rasterizes the region in one go, so '
          '“record” does nothing here — “pill” is the '
          'only resolution the record has.';
    }
    if (_twoPass) {
      return _recordRatio < _pillRatio
          ? 'The bar is recorded below the pill’s image and stretched '
              'into it: the rim softens while the page half stays sharp. '
              'Costs an extra rasterization.'
          : 'The bar is recorded above the pill’s image and shrunk into '
              'it — detail paid for and then thrown away. Costs an extra '
              'rasterization.';
    }
    return 'Matched, so the bar goes straight into the pill’s image in '
        'one rasterization. Raising “pill” past “page” '
        'sharpens the rim and the border sweep; the page half cannot pass '
        'what “page” captured.';
  }

  Widget _costCard(Size screen) {
    final double fullW = screen.width * _pillRatio;
    final double fullH = screen.height * _pillRatio;
    final double fullPx = fullW * fullH;
    final double recordPx = _composed.width * _composed.height;
    return TunerCard(
      child: DefaultTextStyle(
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: Colors.white70,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TunerPanelTitle('Cost'),
            const SizedBox(height: 8),
            Text('raster  ${_rasterMs.toStringAsFixed(1)} ms'
                '     ui  ${_uiMs.toStringAsFixed(1)} ms'),
            if (_recorded)
              Text('compose ${_composeMs.toStringAsFixed(2)} ms cpu'),
            Text(_recorded && recordPx > 0
                ? 'record  ${_composed.width.toStringAsFixed(0)}×'
                    '${_composed.height.toStringAsFixed(0)} px'
                    '   ${(recordPx / fullPx * 100).toStringAsFixed(1)}% of a '
                    'full frame'
                : 'capture ${fullW.toStringAsFixed(0)}×'
                    '${fullH.toStringAsFixed(0)} px   full frame, every '
                    'frame'),
            if (_dropped != null)
              Text('dropped from the record: $_dropped',
                  style: const TextStyle(color: Color(0xFFFF8FB0))),
            if (_capsuleBlur && _replays)
              const Text(
                'the capsule blur is on screen but not in the record',
                style: TextStyle(color: Color(0xFFFF8FB0)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _looksCard() {
    return TunerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TunerPanelTitle('Bar look'),
          const SizedBox(height: 4),
          const Text(
            'A backdrop filter reads the scene beneath it, which a canvas '
            'replay has no way to reproduce — turn it on to see exactly '
            'what the picture record loses.',
            style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.3),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: kTunerAccent,
            title: const Text('capsule blur',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
            value: _capsuleBlur,
            onChanged: (v) => setState(() => _capsuleBlur = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: kTunerAccent,
            title: const Text('clear interior on landing',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
            subtitle: const Text(
                'the pill stops resampling its middle on the frame the '
                'under-glass icon size lands — drop the pill ratio and '
                'turn this off to see the pop it removes',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
            value: _innerClear,
            onChanged: (v) => setState(() => _innerClear = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: kTunerAccent,
            title: const Text('peek at the record',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
            subtitle: const Text('draws the composed image over the bar',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
            value: _peek,
            onChanged: _recorded ? (v) => setState(() => _peek = v) : null,
          ),
        ],
      ),
    );
  }

  String _snippet() {
    final String source = switch (_source) {
      PillGlassSource.outerView => 'PillGlassSource.outerView',
      PillGlassSource.recordedPicture => 'PillGlassSource.recordedPicture',
      PillGlassSource.regionRaster => 'PillGlassSource.regionRaster',
    };
    return 'RecordedPillBar(\n'
        '  source: $source,\n'
        '  pageRatio: ${_pageRatio.toStringAsFixed(2)},\n'
        '  recordRatio: ${_recordRatio.toStringAsFixed(2)},\n'
        '  pillRatio: ${_pillRatio.toStringAsFixed(2)},\n'
        '  capsuleBlur: $_capsuleBlur,\n'
        '  clearInteriorOnLanding: $_innerClear,\n'
        ')';
  }
}

/// Saturated blocks that pass under the bar as the panel scrolls — a
/// record that is stale, mis-mapped or the wrong resolution shows up
/// against these long before it does against a gradient.
class _ContrastStrip extends StatelessWidget {
  const _ContrastStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int row = 0; row < 6; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (int i = 0; i < 6; i++)
                  Expanded(
                    child: Container(
                      height: 46,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: HSLColor.fromAHSL(
                                1, ((row * 6 + i) * 37) % 360, 0.75, 0.55)
                            .toColor(),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Draws the last composed record at a readable size. Repaints off a
/// ticker-driven notifier rather than `setState`, so watching it costs
/// one draw a frame and not a rebuild — the `ui ms` readout has to stay
/// honest while it is open.
class _RecordPeek extends StatefulWidget {
  final PillImageSink sink;

  const _RecordPeek({required this.sink});

  @override
  State<_RecordPeek> createState() => _RecordPeekState();
}

class _RecordPeekState extends State<_RecordPeek>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker((_) => _frame.value++);

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kTunerAccent.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.black.withValues(alpha: 0.35),
      ),
      padding: const EdgeInsets.all(3),
      child: CustomPaint(
        size: const Size(104, 104),
        painter: _SinkPainter(widget.sink, repaint: _frame),
      ),
    );
  }
}

class _SinkPainter extends CustomPainter {
  final PillImageSink sink;

  const _SinkPainter(this.sink, {required Listenable repaint})
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? image = sink.image;
    if (image == null) return;
    final double scale =
        (size.width / image.width).clamp(0.0, size.height / image.height);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: image.width * scale,
        height: image.height * scale,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_SinkPainter oldDelegate) => true;
}
