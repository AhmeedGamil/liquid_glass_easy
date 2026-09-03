// -----------------------------------------------------------------------------
// PHOTOS LENS LAB — the photo library page, turned into a test bench.
//
// A copy of the Photos showcase: the same edge-to-edge grid of photographs, the
// same glass header, tab capsule and search circle. What is added is a field of
// TEST LENSES over the grid, and a panel to shape them.
//
// Nothing on this page animates itself. The lenses sit exactly where you put
// them until you drag them. The motion under the glass is YOUR SCROLL — which
// is the realistic case: real photographs, real decode, real overscroll,
// travelling under real glass.
//
// BATCH here wraps THE WHOLE PAGE, not just the test lenses: the header
// buttons, the tab capsule and the search circle join it too, so one backdrop
// read serves every piece of glass on screen. That has a visible price, and
// seeing it is half the point — a component that stacks glass on glass is an
// overlap like any other, so the tab bar's travelling pill stops refracting
// the capsule beneath it and reads the page instead. Nesting a
// `LiquidGlassBatch(enabled: false)` around the tab bar is the escape hatch.
//
// WHAT YOU CAN CHANGE
//   • mode — SOLO / BATCH / GROUP, the three ways of drawing the same lenses
//   • each lens's own width, height and corner radius (select one, then W/H/R)
//   • add and remove lenses
//   • blur sigma
//   • adaptivity on and off, on a LiquidGlassSwitch
//   • drag any lens anywhere
//
// READING THE NUMBERS
//   Run in PROFILE mode — debug numbers lie:
//       cd example
//       flutter run --profile -t lib/photos_lens_lab.dart
//
//   By default the clock only records frames while you are SCROLLING or
//   DRAGGING ("rec: active"), so an idle page cannot quietly dilute the
//   average with frames that did no work. Flip it to "rec: always" if you
//   want the idle cost too.
//
//   Raster ms is the shader/GPU cost — the number to compare between modes.
//
// GROUP caps at 8 members. Past that the extras stay in the list and stay
// draggable, but only the first 8 are drawn as group members; the panel says
// so. SOLO and BATCH have no ceiling.
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Standalone entry point:
///   flutter run --profile -t lib/photos_lens_lab.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFD7D5D5),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101012),
      ),
      themeMode: ThemeMode.system,
      home: const PhotosLensLabPage(),
    ),
  );
}

/// The one saturated colour on the page.
const Color _kTint = Color(0xFF0A84FF);

/// Foreground on the glass.
const Color _kInk = Color(0xE61C1C1E);

/// How the test lenses are drawn.
enum LensMode { solo, batch, group }

/// The rim every piece of glass is cut with.
LiquidGlassShape _frostShape(double cornerRadius) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 0.7,
      lightIntensity: 1,
      lightDirection: 39,
      borderType: const OpticalBorder(
        borderSaturation: 1.0,
        ambientIntensity: 1.0,
        borderSolidity: 1,
      ),
    );

/// The page chrome's material — unchanged from the showcase, so the header,
/// tab capsule and search circle look and cost what they always did.
LiquidGlassStyle _frost(double cornerRadius, {LiquidGlassShadow? shadow}) =>
    LiquidGlassStyle(
      adaptivity: LiquidGlassAdaptivity(),
      shape: _frostShape(cornerRadius),
      appearance: LiquidGlassAppearance(
        color: const Color(0x6EFFFFFF),
        blur: const LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
        saturation: 1.2,
        shadow: shadow,
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.14,
        distortionWidth: 24,
        chromaticAberration: 0.002,
      ),
    );

const LiquidGlassAdaptivity _adapt = LiquidGlassAdaptivity(
  glassColorOnDark: Color(0x6EFFFFFF),
  contentColorOnDark: _kInk,
  glassColorOnLight: Color(0x99FFFFFF),
  contentColorOnLight: _kInk,
  duration: Duration(milliseconds: 300),
  continuousGlassColor: true,
);

const LiquidGlassAdaptivity _titleAdapt = LiquidGlassAdaptivity(
  contentColorOnDark: Color(0xFFFFFFFF),
  contentColorOnLight: _kInk,
  duration: Duration(milliseconds: 300),
);

const LiquidGlassTouch _press = LiquidGlassTouch.flexing(
  LiquidGlassFlex.subtle(),
);

/// One test lens: its own box, its own corner, its own place on the page.
class _TestLens {
  _TestLens({
    required this.id,
    required this.offset,
    required this.width,
    required this.height,
    required this.radius,
  });

  final int id;

  /// Top-left, in the body's coordinate space.
  Offset offset;
  double width;
  double height;
  double radius;

  /// Kept at or under half the short side, which is where a rounded
  /// rectangle becomes a capsule — past it the shape stops changing.
  double get clampedRadius => math.min(radius, math.min(width, height) / 2);
}

class PhotosLensLabPage extends StatefulWidget {
  const PhotosLensLabPage({super.key});

  @override
  State<PhotosLensLabPage> createState() => _PhotosLensLabPageState();
}

class _PhotosLensLabPageState extends State<PhotosLensLabPage> {
  static const double _barHeight = 58;
  static const double _edge = 20;

  static const int _groupMax = LiquidGlassGroup.maxLensCount;

  // ── page state (from the showcase) ────────────────────────────────
  int _tab = 0;
  int _filter = 0;

  static const List<(String, String, int)> _filters = [
    ('Items', '4,627', 1),
    ('Favorites', '318', 3),
    ('Videos', '96', 4),
    ('Screenshots', '211', 5),
  ];

  static final List<LiquidGlassTabBarItem> _tabs = [
    const LiquidGlassTabBarItem(
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library_rounded,
      label: 'Library',
    ),
    const LiquidGlassTabBarItem(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Collections',
    ),
  ];

  List<int> get _photos {
    final int step = _filters[_filter].$3;
    return [for (int i = 0; i < 96; i += step) i];
  }

  // ── lab state ─────────────────────────────────────────────────────
  final List<_TestLens> _lenses = <_TestLens>[];
  int _nextId = 1;
  int? _selectedId;

  LensMode _mode = LensMode.solo;
  double _blur = 4;
  bool _adaptive = true;
  bool _panelOpen = true;

  /// The shape the next "+" creates, and what the W/H/R steppers edit when
  /// no lens is selected.
  double _newW = 150;
  double _newH = 110;
  double _newR = 34;

  // ── the clock ─────────────────────────────────────────────────────
  static const int _window = 600;
  final List<int> _rasterUs = <int>[];
  final List<int> _totalUs = <int>[];

  /// The readout lives in a notifier, not in `setState`: this page is a
  /// measuring instrument, and rebuilding the whole tree twice a second just
  /// to redraw a line of text would show up in the very numbers it prints.
  final ValueNotifier<String> _hud = ValueNotifier<String>('scroll to gather…');
  Timer? _hudTimer;

  /// Record only frames that did real work — a scroll or a drag. Idle frames
  /// are cheap and would pull every average down toward nothing.
  bool _recordAlways = false;
  final Stopwatch _clock = Stopwatch()..start();
  int _activeUntilMs = 0;

  bool get _active =>
      _recordAlways || _clock.elapsedMilliseconds < _activeUntilMs;

  void _markActive() => _activeUntilMs = _clock.elapsedMilliseconds + 180;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // The page has no animation of its own, so nothing would otherwise
    // rebuild the readout. Two refreshes a second, and the frames they
    // cost are not recorded unless you are actually scrolling.
    _hudTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) _hud.value = _computeHud();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _hud.dispose();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  /// Three lenses to start with, so the page is never empty on open.
  void _seed() {
    if (!mounted || _lenses.isNotEmpty) return;
    final Size size = MediaQuery.sizeOf(context);
    setState(() {
      _add(Offset(size.width * 0.10, size.height * 0.30));
      _add(Offset(size.width * 0.42, size.height * 0.48));
      _add(Offset(size.width * 0.16, size.height * 0.64));
    });
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    if (!_active) return;
    for (final ui.FrameTiming t in timings) {
      _rasterUs.add(t.rasterDuration.inMicroseconds);
      _totalUs.add(t.totalSpan.inMicroseconds);
    }
    while (_rasterUs.length > _window) {
      _rasterUs.removeAt(0);
      _totalUs.removeAt(0);
    }
  }

  /// The lenses actually drawn. The group's shader compares every member per
  /// fragment, so it is capped — the extras stay in the list (and stay
  /// draggable in the other modes) rather than being deleted behind your back.
  List<_TestLens> get _drawn =>
      _mode == LensMode.group && _lenses.length > _groupMax
          ? _lenses.sublist(0, _groupMax)
          : _lenses;

  String get _expectedReads {
    final int n = _drawn.length;
    if (n == 0) return '0';
    switch (_mode) {
      case LensMode.solo:
        // Blur is a second BackdropFilter stacked under the shader — and the
        // page chrome (two header buttons, the tab capsule, search) reads on
        // its own account too, which is why this is a floor, not a total.
        final int per = _blur > 0 ? 2 : 1;
        return '${n * per} + chrome  ($n × $per)';
      case LensMode.batch:
        return '1  (whole page — test lenses AND chrome)';
      case LensMode.group:
        // The group's surface has no backdrop-key wiring, so it cannot join a
        // batch: its one read stands apart from the chrome's.
        return '1 merged + chrome';
    }
  }

  String _computeHud() {
    if (_rasterUs.length < 10) {
      return _recordAlways
          ? 'gathering… (${_rasterUs.length})'
          : 'scroll or drag to gather… (${_rasterUs.length})';
    }
    final List<int> sorted = List<int>.from(_rasterUs)..sort();
    double pct(double p) => sorted[((sorted.length - 1) * p).round()] / 1000.0;
    final double avg =
        _rasterUs.reduce((int a, int b) => a + b) / _rasterUs.length / 1000.0;
    final double totAvg =
        _totalUs.reduce((int a, int b) => a + b) / _totalUs.length / 1000.0;
    final double fps = totAvg > 0 ? 1000.0 / totAvg : 0;
    String f(double v) => v.toStringAsFixed(2);

    return 'RASTER ms  avg ${f(avg)}   p50 ${f(pct(0.5))}   '
        'p90 ${f(pct(0.9))}   max ${f(pct(1.0))}\n'
        'frame ${f(totAvg)} ms (~${fps.toStringAsFixed(0)} fps)   '
        'samples ${_rasterUs.length}\n'
        'reads (expected): $_expectedReads';
  }

  void _reset() {
    _rasterUs.clear();
    _totalUs.clear();
    _hud.value = 'reset — scroll to gather…';
  }

  // ── lens editing ──────────────────────────────────────────────────

  _TestLens? get _selected {
    for (final _TestLens l in _lenses) {
      if (l.id == _selectedId) return l;
    }
    return null;
  }

  void _add([Offset? at]) {
    final Size size = MediaQuery.sizeOf(context);
    final Offset where = at ??
        Offset(
          size.width * 0.5 - _newW / 2 + (_lenses.length % 4) * 14,
          size.height * 0.45 + (_lenses.length % 5) * 16,
        );
    final _TestLens lens = _TestLens(
      id: _nextId++,
      offset: where,
      width: _newW,
      height: _newH,
      radius: _newR,
    );
    _lenses.add(lens);
    _selectedId = lens.id;
  }

  void _removeSelected() {
    final _TestLens? sel = _selected;
    if (sel == null) {
      if (_lenses.isNotEmpty) _lenses.removeLast();
    } else {
      _lenses.remove(sel);
    }
    _selectedId = _lenses.isEmpty ? null : _lenses.last.id;
  }

  /// W / H / R apply to the selected lens; with nothing selected they set the
  /// shape the next "+" will create.
  void _bumpSize({double dw = 0, double dh = 0, double dr = 0}) {
    setState(() {
      final _TestLens? sel = _selected;
      if (sel == null) {
        _newW = (_newW + dw).clamp(40.0, 340.0);
        _newH = (_newH + dh).clamp(40.0, 340.0);
        _newR = (_newR + dr).clamp(0.0, 170.0);
      } else {
        sel.width = (sel.width + dw).clamp(40.0, 340.0);
        sel.height = (sel.height + dh).clamp(40.0, 340.0);
        sel.radius = (sel.radius + dr).clamp(0.0, 170.0);
        // Carry the edit forward, so the next lens starts where this one is.
        _newW = sel.width;
        _newH = sel.height;
        _newR = sel.radius;
      }
      _reset();
    });
  }

  // ── build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      // THE WHOLE PAGE in one batch — not just the test lenses. Every lens
      // below shares a single backdrop read: the header's two buttons, the tab
      // capsule, the search circle and every test lens, however deep in a
      // component's tree it sits. A lens finds the batch from its own context,
      // so nothing here has to be told about it.
      body: LiquidGlassBatch(
        enabled: _mode == LensMode.batch,
        child: LiquidGlassScaffold(
          pixelRatio: 1,
          useSync: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          actionMargin: _edge,
          adaptivity: const LiquidGlassScaffoldAdaptivity(
            _adapt,
            systemChrome: LiquidGlassSystemChrome.both,
          ),

          // The photographs, the test lenses over them, and the panel on top.
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final Size area = c.biggest;
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // A scroll is the only thing that moves on this page, so it
                  // is also what says "these frames did work".
                  NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification n) {
                      if (n is ScrollUpdateNotification ||
                          n is OverscrollNotification) {
                        _markActive();
                      }
                      return false;
                    },
                    child: _PhotoGrid(
                      photos: _photos,
                      bottomInset: pad.bottom,
                    ),
                  ),
                  _testGlass(area),
                  Positioned(
                    left: 8,
                    right: 8,
                    top: pad.top + 92,
                    child: _panel(),
                  ),
                ],
              );
            },
          ),

          appBar: _LibraryHeader(
            subtitle: '${_lenses.length} test '
                '${_lenses.length == 1 ? 'lens' : 'lenses'} · '
                '${_mode.name}',
            panelOpen: _panelOpen,
            onFilter: () => setState(() {
              _filter = (_filter + 1) % _filters.length;
              _reset();
            }),
            onPanel: () => setState(() => _panelOpen = !_panelOpen),
          ),

          bottomNavigationBar: LiquidGlassTabBar(
            items: _tabs,
            selectedIndex: _tab,
            onChanged: (int i) => setState(() => _tab = i),
            width: 189,
            height: _barHeight,
            itemPadding: 4,
            alignment: Alignment.bottomLeft,
            margin: const EdgeInsets.only(left: _edge, bottom: 12),
            style: _frost(
              _barHeight / 2,
              shadow: const LiquidGlassShadow(blur: 9, opacity: 0.16),
            ),
            itemStyle: const LiquidGlassTabItemStyle(
              selectedColor: Color.fromARGB(255, 0, 123, 255),
              unselectedColor: _kInk,
              iconSize: 24,
              underGlassIconSize: 28,
              labelFontSize: 11,
              iconLabelGap: 2,
              selectedFontWeight: FontWeight.w600,
              unselectedFontWeight: FontWeight.w500,
            ),
            pillStyle: LiquidGlassTabPillStyle(
              mode: LiquidGlassPillMode.both,
              animated: true,
              growHeight: 7,
              distortionWidth: 10,
              rest: LiquidGlassStyle(
                shape: _frostShape(50),
                appearance: const LiquidGlassAppearance(
                  color: Color.fromARGB(40, 0, 0, 0),
                ),
              ),
            ),
          ),

          bottomNavigationBarAction: LiquidGlassTabBarAction(
            icon: Icons.search_rounded,
            size: _barHeight,
            onTap: () {},
            touch: _press,
            style: _frost(_barHeight / 2),
          ),
        ),
      ),
    );
  }

  /// The material every test lens is cut from. Adaptivity is the switch:
  /// [LiquidGlassAdaptivity.none] is the explicit opt-out, so flipping it off
  /// really does stop the lens judging its backdrop rather than quietly
  /// inheriting the scaffold's palette.
  LiquidGlassStyle _lensStyle(double radius) => LiquidGlassStyle(
        adaptivity: _adaptive ? _adapt : LiquidGlassAdaptivity.none,
        shape: _frostShape(radius),
        appearance: LiquidGlassAppearance(
          color: const Color(0x6EFFFFFF),
          blur: LiquidGlassBlur(sigmaX: _blur, sigmaY: _blur),
          saturation: 1.2,
        ),
        refraction: const LiquidGlassRefraction(
          distortion: 0.14,
          distortionWidth: 24,
          chromaticAberration: 0.002,
        ),
      );

  /// The test lenses, wrapped in whichever mode is selected.
  ///
  /// SOLO and BATCH build the identical tree and differ by one boolean, so a
  /// difference between them is the shared backdrop read and nothing else.
  /// GROUP replaces the wrapper: the members hand their glass to one surface.
  Widget _testGlass(Size area) {
    final List<_TestLens> drawn = _drawn;
    if (drawn.isEmpty) return const SizedBox.shrink();

    final Widget field = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        for (final _TestLens lens in drawn) _draggable(lens, area),
      ],
    );

    // A group with one member paints nothing: the member has already handed
    // its glass over, and the merged surface needs two to draw. Rather than
    // let the lens silently vanish, stay on the plain path until there are
    // two — the panel says why.
    if (_mode == LensMode.group &&
        drawn.length >= LiquidGlassGroup.minLensCount) {
      return Positioned.fill(
        child: LiquidGlassGroup(
          style: _lensStyle(drawn.first.clampedRadius),
          child: field,
        ),
      );
    }
    // SOLO and BATCH build the IDENTICAL tree here — the only difference
    // between them is the page-level LiquidGlassBatch in [build], which is
    // what makes the two directly comparable.
    return Positioned.fill(child: field);
  }

  /// One lens: draggable, tappable to select, and nothing else. It moves only
  /// while a finger is on it — there is no animation anywhere on this page.
  Widget _draggable(_TestLens lens, Size area) {
    final bool selected = lens.id == _selectedId;
    return Positioned(
      left: lens.offset.dx,
      top: lens.offset.dy,
      width: lens.width,
      height: lens.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedId = lens.id),
        onPanStart: (_) => setState(() => _selectedId = lens.id),
        onPanUpdate: (DragUpdateDetails d) {
          _markActive();
          setState(() {
            lens.offset = Offset(
              (lens.offset.dx + d.delta.dx)
                  .clamp(-lens.width / 2, area.width - lens.width / 2),
              (lens.offset.dy + d.delta.dy)
                  .clamp(-lens.height / 2, area.height - lens.height / 2),
            );
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: LiquidGlassLens(
                style: _lensStyle(lens.clampedRadius),
                child: Center(
                  child: Text(
                    '${lens.id}',
                    style: TextStyle(
                      color: _kInk,
                      fontSize: math.min(lens.width, lens.height) * 0.24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            // The selection ring sits OUTSIDE the glass, so it marks the lens
            // without becoming part of what the lens looks like.
            if (selected)
              Positioned(
                left: -4,
                top: -4,
                right: -4,
                bottom: -4,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: _kTint, width: 2),
                      borderRadius:
                          BorderRadius.circular(lens.clampedRadius + 4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── panel ─────────────────────────────────────────────────────────

  Widget _panel() {
    if (!_panelOpen) return const SizedBox.shrink();

    final _TestLens? sel = _selected;
    final double w = sel?.width ?? _newW;
    final double h = sel?.height ?? _newH;
    final double r = sel?.radius ?? _newR;
    final bool capped = _mode == LensMode.group && _lenses.length > _groupMax;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ValueListenableBuilder<String>(
            valueListenable: _hud,
            builder: (BuildContext context, String text, Widget? _) => Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                height: 1.4,
                fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _chip('SOLO', _mode == LensMode.solo,
                  () => _setMode(LensMode.solo)),
              _chip('BATCH', _mode == LensMode.batch,
                  () => _setMode(LensMode.batch)),
              _chip('GROUP', _mode == LensMode.group,
                  () => _setMode(LensMode.group)),
              const Spacer(),
              _chip('reset', false, () => setState(_reset)),
            ],
          ),
          if (capped)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'group draws the first 8 — the rest are still in the list',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 10.5),
              ),
            ),
          if (_mode == LensMode.batch)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'whole page batched — the tab pill reads the page, not the '
                'capsule under it',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 10.5),
              ),
            ),
          if (_mode == LensMode.group &&
              _drawn.length < LiquidGlassGroup.minLensCount)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'group needs 2 lenses — drawing them plain until then',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 10.5),
              ),
            ),
          const Divider(color: Colors.white24, height: 16),

          // The adaptivity switch the page is really about.
          Row(
            children: <Widget>[
              const Text(
                'adaptivity',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 10),
              LiquidGlassSwitch(
                value: _adaptive,
                width: 52,
                height: 30,
                onChanged: (bool v) => setState(() {
                  _adaptive = v;
                  _reset();
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _adaptive
                      ? 'lenses judge the photo under them'
                      : 'opted out — one fixed tint',
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Per-lens geometry.
          Text(
            sel == null
                ? 'no lens selected — W/H/R set the NEXT one'
                : 'lens ${sel.id} selected',
            style: TextStyle(
              color: sel == null ? Colors.white54 : _kTint,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          _stepper('W', w, (double d) => _bumpSize(dw: d)),
          _stepper('H', h, (double d) => _bumpSize(dh: d)),
          _stepper('R', r, (double d) => _bumpSize(dr: d)),
          const SizedBox(height: 6),
          _stepper('blur', _blur, (double d) {
            setState(() {
              _blur = (_blur + d).clamp(0.0, 40.0);
              _reset();
            });
          }, step: 2),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _chip('+ lens', false, () {
                setState(() {
                  _add();
                  _reset();
                });
              }),
              _chip('− lens', false, () {
                setState(() {
                  _removeSelected();
                  _reset();
                });
              }),
              _chip(
                  'deselect', false, () => setState(() => _selectedId = null)),
              const Spacer(),
              _chip(
                _recordAlways ? 'rec: always' : 'rec: active',
                _recordAlways,
                () => setState(() {
                  _recordAlways = !_recordAlways;
                  _reset();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setMode(LensMode mode) => setState(() {
        _mode = mode;
        _reset();
      });

  Widget _stepper(
    String label,
    double value,
    ValueChanged<double> onDelta, {
    double step = 5,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          _chip('−', false, () => onDelta(-step)),
          Container(
            width: 42,
            alignment: Alignment.center,
            child: Text(
              value.toStringAsFixed(0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
          _chip('+', false, () => onDelta(step)),
          _chip('−−', false, () => onDelta(-step * 5)),
          _chip('++', false, () => onDelta(step * 5)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color:
                on ? Colors.tealAccent.withValues(alpha: 0.85) : Colors.white24,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? Colors.black : Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Header — the showcase's title, with the panel toggle in place of
//  the Select button.
// ════════════════════════════════════════════════════════════════

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.subtitle,
    required this.panelOpen,
    required this.onFilter,
    required this.onPanel,
  });

  final String subtitle;
  final bool panelOpen;
  final VoidCallback onFilter;
  final VoidCallback onPanel;

  static const double _controlHeight = 44;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: IgnorePointer(
              child: LiquidGlassAdaptiveContent(
                adaptivity: _titleAdapt,
                builder:
                    (BuildContext context, Color color, Brightness brightness) {
                  final Color halo = brightness == Brightness.dark
                      ? const Color(0x73000000)
                      : const Color(0x8CFFFFFF);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Lens Lab',
                        style: TextStyle(
                          color: color,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.15,
                          shadows: <Shadow>[
                            Shadow(color: halo, blurRadius: 12)
                          ],
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: color.withValues(alpha: color.a * 0.82),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                          shadows: <Shadow>[
                            Shadow(color: halo, blurRadius: 10)
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          LiquidGlassButton(
            width: _controlHeight,
            height: _controlHeight,
            padding: EdgeInsets.zero,
            onPressed: onFilter,
            touch: _press,
            foregroundColor: _kInk,
            iconSize: 24,
            style: _frost(_controlHeight / 2),
            child: const Icon(Icons.filter_list_rounded),
          ),
          const SizedBox(width: 10),
          LiquidGlassButton(
            width: _controlHeight,
            height: _controlHeight,
            padding: EdgeInsets.zero,
            onPressed: onPanel,
            touch: _press,
            foregroundColor: _kInk,
            iconSize: 24,
            style: _frost(_controlHeight / 2),
            child: Icon(
              panelOpen ? Icons.close_rounded : Icons.tune_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The photographs — unchanged from the showcase, minus the picking.
// ════════════════════════════════════════════════════════════════

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.bottomInset});

  final List<int> photos;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GridView.builder(
          padding: EdgeInsets.only(bottom: bottomInset + 108),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: photos.length,
          itemBuilder: (BuildContext context, int i) =>
              _PhotoCell(id: photos[i]),
        ),
        const IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 230,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x8C000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.id});

  final int id;

  static const List<Color> _placeholders = <Color>[
    Color(0xFF23262B),
    Color(0xFF2B2A33),
    Color(0xFF1F2A2E),
    Color(0xFF2E2724),
    Color(0xFF262B24),
  ];

  @override
  Widget build(BuildContext context) {
    final Color fill = _placeholders[id % _placeholders.length];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: fill),
        Image.network(
          'https://picsum.photos/seed/glass$id/320/320',
          fit: BoxFit.cover,
          cacheWidth: 320,
          errorBuilder: (_, __, ___) => ColoredBox(color: fill),
          frameBuilder: (BuildContext context, Widget child, int? frame,
              bool wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: child,
            );
          },
        ),
      ],
    );
  }
}
