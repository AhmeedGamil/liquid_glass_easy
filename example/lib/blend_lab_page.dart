// -----------------------------------------------------------------------------
// BLEND LAB — a metaball blend of 2 to 8 lenses, every change of it MORPHED.
//
// A LiquidGlassBlender takes two to eight LiquidGlassLens descendants and stops
// drawing them as separate lenses. It evaluates each member's signed distance
// field, smooth-unions them, and paints ONE merged sheet of glass through a
// single shader pass over a single backdrop read. Members close enough to each
// other grow a liquid bridge; pull them apart and the bridge thins and snaps.
//
// THE TWO HALVES, AND WHY THEY BELONG ON ONE PAGE
//
// The blend is a function of geometry alone: where the members are, how big
// they are, what corners they carry. So if that geometry is not allowed to
// JUMP — if every member's position, size and corner radius rides a spring —
// then the merged outline is continuous too, and the bridges have to stretch,
// neck and snap their way to the new arrangement. That is the whole idea here:
//
//   • Nothing on this page snaps. Sliders, the resize grip, adding a member,
//     removing one, and the whole-cluster layout presets all set spring
//     TARGETS. The glass chases them.
//   • The springs are underdamped, so every member overshoots and comes back.
//     Two members overshooting out of phase is what makes a bridge wobble
//     after it forms.
//   • Squash and stretch is coupled to spring VELOCITY: a member opening fast
//     on one axis pinches in on the other, so it behaves like a volume of
//     liquid rather than a box being scaled.
//   • Corner CURVE is an enum and cannot be interpolated, so it is swapped at
//     the halfway point of a member's travel, where the motion hides it.
//   • Adding a member grows it in from a droplet; removing one shrinks it into
//     the cluster and lets the blend absorb it. Neither pops.
//
// WHAT THE CONTROLS EXPOSE
//   count 2…8 — `LiquidGlassBlender.maxLensCount` is eight. It is a shader
//     declaration limit, not a performance one: members ride four `mat4`
//     uniforms of two members each, and eight still cost one pass.
//   W / H / r — the selected member's own size and corner radius. Size is the
//     dominant term in the field: a big member swallows a small neighbour
//     instead of bridging to it.
//   k — smoothness, the radius over which two outlines flow together. The
//     "fuse" chip OFF passes `null`, which unions the members hard and makes
//     the shader skip the smin and the per-member weights entirely. That is a
//     different code path, not a very small k.
//   morph to — retargets every member's position AND size at once. This is the
//     one to watch: the cluster flows between arrangements as one surface.
//   scale — grow or shrink on X, on Y, or on both, either for the selected
//     member or for the whole cluster. The cluster case scales each member's
//     OFFSET FROM THE CENTROID as well as its size, so a one-axis scale
//     stretches the gaps too and the bridges have to stretch with them. Scaling
//     members in place would just make them fatter, which is not a scale.
//   seq — record the animation you actually want, as many steps as you like.
//     Arrange the members, "+ step"; rearrange, "+ step" again; press play and
//     it walks 1 → 2 → 3 → … A step captures every member's place, size,
//     corner radius and corner curve, and its member COUNT — so consecutive
//     steps may disagree about how many there are, and the extra member is
//     born or absorbed as part of the move. "loop" runs it round.
//
// Playback is not a separate animation path. Recalling a step only writes the
// same spring targets the sliders and the grip write, and the sequencer
// advances on the springs REACHING them rather than on a stopwatch — so it
// stays correct at 0.25× time, under retuned damping, and for a step whose
// members have much further to travel than the last one's.
//
// Per-member TINT is deliberately absent: the merged surface paints one
// material for the whole sheet, and a member only carries its own colour when
// it is adaptive and has judged its own patch of background. Here the group
// style owns the look and the per-member knobs are strictly geometry.
//
// Tap a lens to select it, drag it to move it, drag its corner grip to resize.
//
//   flutter run -t lib/blend_lab_page.dart   (standalone)
//   …or open it from the gallery.
// -----------------------------------------------------------------------------

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'spring.dart';

void main() {
  runApp(const _BlendLabApp());
}

class _BlendLabApp extends StatelessWidget {
  const _BlendLabApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const BlendLabPage(),
    );
  }
}

/// A whole-cluster morph: every member's position and size retargeted at once.
enum _Arrange { ring, row, stack, grid, drop }

/// Which axes a scale operation acts on.
enum _Axis { x, y, both }

/// One member inside a recorded pose.
///
/// The centre is stored NORMALISED to the stage (0…1 on each axis) rather than
/// in pixels: the panel's height changes as its chips reflow, which changes the
/// stage, and a pose recorded before that should still land where it looked
/// like it would. Sizes stay absolute — a member's size means px, not a
/// fraction of anything.
class _PoseMember {
  const _PoseMember({
    required this.center,
    required this.size,
    required this.radius,
    required this.corner,
  });

  final Offset center;
  final Size size;
  final double radius;
  final LiquidGlassCornerStyle corner;
}

/// A complete recorded state of the cluster: every member's place, size,
/// corner radius and corner curve — and, implicitly, how many members there
/// were. Recalling a pose with a different count adds or removes members to
/// match, so A and B may legitimately disagree about how many there are.
class _Pose {
  const _Pose(this.members);

  final List<_PoseMember> members;
}

/// One member of the blend, and its spring bank.
///
/// Mutable on purpose: a drag edits the blob in place and the ticker
/// integrates it, rather than rebuilding a list of immutable records at 120 Hz.
class _Blob {
  _Blob({
    required Offset center,
    required Size size,
    required double radius,
    required this.corner,
  })  : x = Spring(center.dx),
        y = Spring(center.dy),
        w = Spring(size.width),
        h = Spring(size.height),
        r = Spring(radius),
        shownCorner = corner;

  final Spring x, y, w, h, r;

  /// The corner curve this member is headed for.
  LiquidGlassCornerStyle corner;

  /// The one it is currently drawn with. Lags [corner] to the halfway point of
  /// the travel; see the file header.
  LiquidGlassCornerStyle shownCorner;

  /// Distance left at the moment the target was last set — the denominator for
  /// "how far along am I", which is what times the corner swap.
  double travelStart = 0;

  /// Shrinking out after being removed. Still a member of the blend, so the
  /// cluster absorbs it instead of it vanishing.
  bool dying = false;

  /// What the shader will actually use: the radius clamps to the shorter half
  /// side, so a member shrunk past twice its radius becomes a capsule rather
  /// than keeping a radius its box can no longer hold.
  double get effectiveRadius =>
      math.min(r.value, math.min(w.value, h.value) / 2);

  /// The radius counts double: a corner change is a small number of pixels but
  /// a large amount of what the eye reads as "shape".
  double get distance =>
      x.remaining + y.remaining + w.remaining + h.remaining + r.remaining * 2;

  bool get moving => x.moving || y.moving || w.moving || h.moving || r.moving;

  void aim({Offset? center, Size? size, double? radius}) {
    if (center != null) {
      x.target = center.dx;
      y.target = center.dy;
    }
    if (size != null) {
      w.target = size.width;
      h.target = size.height;
    }
    if (radius != null) r.target = radius;
    travelStart = distance;
    if (travelStart < 1) shownCorner = corner;
  }

  void snap() {
    x.snap();
    y.snap();
    w.snap();
    h.snap();
    r.snap();
  }
}

class BlendLabPage extends StatefulWidget {
  const BlendLabPage({super.key});

  @override
  State<BlendLabPage> createState() => _BlendLabPageState();
}

class _BlendLabPageState extends State<BlendLabPage>
    with SingleTickerProviderStateMixin {
  static const String _wallpaper =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  /// Mirrored from the blender so the stepper can never trip its assert — it
  /// THROWS on the ninth member rather than silently dropping it.
  static const int _minCount = LiquidGlassBlender.minLensCount;
  static const int _maxCount = LiquidGlassBlender.maxLensCount;

  static const double _minSide = 44;
  static const double _newSide = 104;

  /// The size a removed member shrinks to before it is dropped from the tree.
  static const double _deathSide = 8;

  // ── The spring bank ──────────────────────────────────────────────
  // ζ = c / (2·√k) ≈ 0.60 — underdamped, so members overshoot and settle back.
  // "eased" swaps in [_dampingCalm] (ζ ≈ 1.08), the same integrator with the
  // wobble removed, so the A/B compares the overshoot and nothing else.
  static const double _stiffness = 250;
  static const double _dampingLiquid = 19;
  static const double _dampingCalm = 34;

  /// Speed, in px/s, that counts as "full" squash.
  static const double _squashReference = 1400;

  /// Peak pinch as a fraction of the axis. Past ~0.14 a member stops reading
  /// as a surface and starts reading as a rubber sheet.
  static const double _squashGain = 0.10;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Every member, INCLUDING the ones shrinking out. The blender's cap counts
  /// those too, so this is the list that must never exceed [_maxCount].
  final List<_Blob> _blobs = <_Blob>[];
  _Blob? _sel;

  _Arrange _arrange = _Arrange.ring;

  /// The recorded sequence, in order. Empty until the first "+ step".
  final List<_Pose> _steps = <_Pose>[];

  /// The step being travelled to, or `-1` when not playing.
  int _step = -1;

  bool _loop = false;

  /// Seconds spent parked on the current step.
  double _hold = 0;

  /// How long the cluster sits on a step before moving off it.
  static const double _holdFor = 0.4;

  bool get _playing => _step >= 0;

  /// Axis (or axes) the scale buttons act on.
  _Axis _axis = _Axis.both;

  /// Whether a scale acts on the whole cluster or only the selected member.
  bool _scaleAll = false;

  /// One press of the scale buttons. Small enough to dial in, big enough to
  /// see the blend respond to a single tap.
  static const double _scaleStep = 1.15;

  double _smoothness = 48;
  bool _fuse = true;
  bool _link = true;
  bool _liquid = true;
  bool _squash = true;
  bool _slow = false;
  bool _panelOpen = true;

  Size _stage = Size.zero;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    // Seeded here, NOT on the first layout: the control panel is built before
    // the stage is laid out, and it dereferences the selected member.
    for (int i = 0; i < 3; i++) {
      _blobs.add(_Blob(
        center: Offset.zero,
        size: const Size(_newSide, _newSide),
        radius: _newSide / 2,
        corner: LiquidGlassCornerStyle.continuousRoundedRectangle,
      ));
    }
    _sel = _blobs.first;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── Members ──────────────────────────────────────────────────────

  List<_Blob> get _live => <_Blob>[
        for (final _Blob b in _blobs)
          if (!b.dying) b
      ];

  /// Every mutation goes through here: rebuild, then make sure the integrator
  /// is running. The ticker stops itself once the springs settle, so at rest
  /// the page requests no frames at all.
  void _edit(VoidCallback fn) {
    setState(fn);
    _wake();
  }

  void _wake() {
    if (!_ticker.isActive) {
      // Ticker.elapsed restarts at zero, so the baseline has to as well —
      // otherwise the first step after a pause integrates the whole gap.
      _last = Duration.zero;
      _ticker.start();
    }
  }

  _Blob get _current {
    final _Blob? s = _sel;
    if (s != null && !s.dying) return s;
    final List<_Blob> live = _live;
    return _sel = (live.isNotEmpty ? live.first : _blobs.first);
  }

  /// Retarget the live members into [_arrange].
  ///
  /// [resize] is false for add/remove, which only need the cluster
  /// re-positioned — re-aiming sizes there would silently undo every manual
  /// W/H edit the moment a member was added.
  void _layout(Size stage, {required bool resize}) {
    final List<_Blob> live = _live;
    final int n = live.length;
    if (n == 0 || stage.isEmpty) return;
    final Offset c = stage.center(Offset.zero);

    Offset onRing(int i, double radius) => n == 1
        ? c
        : c +
            Offset(
                  math.cos(-math.pi / 2 + i * 2 * math.pi / n),
                  math.sin(-math.pi / 2 + i * 2 * math.pi / n),
                ) *
                radius;

    switch (_arrange) {
      case _Arrange.ring:
        final double ring = math.min(stage.width, stage.height) * 0.26;
        for (int i = 0; i < n; i++) {
          live[i].aim(
            center: onRing(i, ring),
            size: resize ? const Size(_newSide, _newSide) : null,
            radius: resize ? _newSide / 2 : null,
          );
        }

      case _Arrange.row:
        // Cells sized to the stage, members 18% wider than their cell so
        // neighbours always overlap enough to bridge into one bar.
        final double cell = (stage.width - 20) / n;
        final double w = cell * 1.18;
        final double h = math.min(96, stage.height * 0.3);
        for (int i = 0; i < n; i++) {
          live[i].aim(
            center: Offset(10 + cell * (i + 0.5), c.dy),
            size: resize ? Size(w, h) : null,
            radius: resize ? math.min(w, h) / 2 : null,
          );
        }

      case _Arrange.stack:
        final double cell = (stage.height - 20) / n;
        final double h = math.min(cell * 1.18, 130);
        final double w = math.min(stage.width * 0.74, 260);
        for (int i = 0; i < n; i++) {
          live[i].aim(
            center: Offset(c.dx, 10 + cell * (i + 0.5)),
            size: resize ? Size(w, h) : null,
            radius: resize ? math.min(w, h) * 0.34 : null,
          );
        }

      case _Arrange.grid:
        final int cols = n <= 2 ? n : 2;
        final int rows = (n / cols).ceil();
        final double cw = (stage.width - 20) / cols;
        final double ch = math.min((stage.height - 20) / rows, 150);
        for (int i = 0; i < n; i++) {
          live[i].aim(
            center: Offset(
              10 + cw * (i % cols + 0.5),
              c.dy - ch * rows / 2 + ch * (i ~/ cols + 0.5),
            ),
            size: resize ? Size(cw * 1.02, ch * 1.02) : null,
            radius: resize ? math.min(cw, ch) * 0.3 : null,
          );
        }

      case _Arrange.drop:
        // Everyone piled on the centre: the union collapses to one fat droplet.
        final double ring = math.min(stage.width, stage.height) * 0.07;
        for (int i = 0; i < n; i++) {
          live[i].aim(
            center: onRing(i, ring),
            size: resize ? const Size(96, 96) : null,
            radius: resize ? 48 : null,
          );
        }
    }
  }

  void _setArrange(_Arrange a) => _edit(() {
        _arrange = a;
        _layout(_stage, resize: true);
      });

  /// Bring one member into the world. Not wrapped in [_edit]: pose recall adds
  /// several at once and positions them itself, so the rebuild and the
  /// arrangement are the caller's business.
  _Blob? _addBlob() {
    if (_live.length >= _maxCount) return null;
    // The blender counts EVERY member, including ones still shrinking out.
    // Drop the oldest of those rather than let the ninth member throw.
    while (_blobs.length >= _maxCount) {
      final int i = _blobs.indexWhere((_Blob b) => b.dying);
      if (i < 0) return null;
      _blobs.removeAt(i);
    }
    // Cycle the corner curve as members are added, so a fresh blend shows
    // straight away that members keep their OWN corners through the union.
    final LiquidGlassCornerStyle corner = LiquidGlassCornerStyle
        .values[_blobs.length % LiquidGlassCornerStyle.values.length];
    final _Blob b = _Blob(
      // Born as a droplet at the centre of the cluster and grown out, so it
      // arrives through the blend rather than appearing on top of it.
      center: _stage.center(Offset.zero),
      size: const Size(_deathSide, _deathSide),
      radius: _deathSide / 2,
      corner: corner,
    )..aim(size: const Size(_newSide, _newSide), radius: _newSide / 2);
    _blobs.add(b);
    return b;
  }

  /// Send one member away. It stays in the tree, shrinking, so the cluster
  /// absorbs it instead of it vanishing.
  void _killBlob(_Blob b) {
    b.dying = true;
    b.aim(size: const Size(_deathSide, _deathSide), radius: _deathSide / 2);
  }

  void _add() {
    if (_live.length >= _maxCount) return;
    _edit(() {
      final _Blob? b = _addBlob();
      if (b != null) _sel = b;
      _layout(_stage, resize: false);
    });
  }

  void _removeSelected() {
    final List<_Blob> live = _live;
    if (live.length <= _minCount) return;
    _edit(() {
      final _Blob b = _current;
      final int i = live.indexOf(b);
      _killBlob(b);
      final List<_Blob> rest = _live;
      _sel = rest.isEmpty ? null : rest[i.clamp(0, rest.length - 1)];
      _layout(_stage, resize: false);
    });
  }

  /// Grow or shrink the cluster to exactly [n] live members, within the
  /// blender's own floor and cap. Used by pose recall, where A and B may
  /// legitimately have been recorded with different counts.
  void _setCount(int n) {
    final int want = n.clamp(_minCount, _maxCount);
    while (_live.length < want) {
      if (_addBlob() == null) break;
    }
    while (_live.length > want) {
      _killBlob(_live.last);
    }
  }

  // ── Poses ────────────────────────────────────────────────────────

  /// Snapshot the live members.
  ///
  /// Records TARGETS, not current values: what the user dialled in is the
  /// pose, even if the springs are still on their way there.
  _Pose _capture() {
    final double sw = math.max(1, _stage.width);
    final double sh = math.max(1, _stage.height);
    return _Pose(<_PoseMember>[
      for (final _Blob b in _live)
        _PoseMember(
          center: Offset(b.x.target / sw, b.y.target / sh),
          size: Size(b.w.target, b.h.target),
          radius: b.r.target,
          corner: b.corner,
        ),
    ]);
  }

  /// Retarget everything to [p]. The springs do the rest, so recalling a pose
  /// IS the morph — there is no separate animation path.
  void _applyPose(_Pose p, {bool snap = false}) {
    _setCount(p.members.length);
    final List<_Blob> live = _live;
    for (int i = 0; i < live.length && i < p.members.length; i++) {
      final _PoseMember m = p.members[i];
      final _Blob b = live[i];
      // Set the curve BEFORE aiming: aim() measures the travel the corner
      // swap will hide inside, and adopts it outright when there is none.
      b.corner = m.corner;
      b.aim(
        center: Offset(m.center.dx * _stage.width, m.center.dy * _stage.height),
        size: m.size,
        radius: m.radius,
      );
      if (snap) b.snap();
    }
  }

  /// Append the current arrangement to the sequence.
  void _addStep() => _edit(() => _steps.add(_capture()));

  void _dropStep() => _edit(() {
        if (_steps.isNotEmpty) _steps.removeLast();
        if (_step >= _steps.length) _stopPlaying();
      });

  void _clearSteps() => _edit(() {
        _steps.clear();
        _stopPlaying();
      });

  /// Jump to one recorded step. Not a special path — it writes the same spring
  /// targets everything else here writes, so it IS a morph.
  void _recall(int i) {
    if (i < 0 || i >= _steps.length) return;
    _edit(() {
      _stopPlaying();
      _applyPose(_steps[i]);
    });
  }

  /// Run the sequence from the top.
  ///
  /// Step 0 is travelled to like any other, from wherever the cluster happens
  /// to be — so pressing play never snaps, and the first recorded move is
  /// always seen in full rather than started from halfway.
  void _playSeq() {
    if (_steps.length < 2) return;
    _edit(() {
      _hold = 0;
      _step = 0;
      _applyPose(_steps[0]);
    });
  }

  void _stopPlaying() {
    _step = -1;
    _hold = 0;
  }

  void _stop() => _edit(_stopPlaying);

  // ── Scaling ──────────────────────────────────────────────────────

  /// Scale by [factor] along [_axis].
  ///
  /// On a single member this is just its size. On the whole cluster it is the
  /// size AND each member's offset from the cluster's centroid, so the group
  /// stretches as one thing and the bridges between members stretch with it —
  /// which is the only way a one-axis scale reads as a scale rather than as
  /// members growing in place.
  void _scale(double factor) {
    final double sx = _axis == _Axis.y ? 1.0 : factor;
    final double sy = _axis == _Axis.x ? 1.0 : factor;
    final double maxSide = math.max(_minSide, _stage.shortestSide);

    _edit(() {
      final List<_Blob> live = _live;
      if (live.isEmpty) return;

      if (!_scaleAll) {
        final _Blob b = _current;
        b.aim(
          size: Size(
            (b.w.target * sx).clamp(_minSide, maxSide),
            (b.h.target * sy).clamp(_minSide, maxSide),
          ),
          // A one-axis scale must not move the corner: the radius already
          // clamps to the shorter half side, which is the whole story there.
          radius: _axis == _Axis.both ? b.r.target * factor : null,
        );
        return;
      }

      double cx = 0;
      double cy = 0;
      for (final _Blob b in live) {
        cx += b.x.target;
        cy += b.y.target;
      }
      cx /= live.length;
      cy /= live.length;

      for (final _Blob b in live) {
        b.aim(
          center: Offset(
            (cx + (b.x.target - cx) * sx).clamp(0.0, _stage.width),
            (cy + (b.y.target - cy) * sy).clamp(0.0, _stage.height),
          ),
          size: Size(
            (b.w.target * sx).clamp(_minSide, maxSide),
            (b.h.target * sy).clamp(_minSide, maxSide),
          ),
          radius: _axis == _Axis.both ? b.r.target * factor : null,
        );
      }
    });
  }

  /// Dragging sets the TARGET, not the position — so a member still lags and
  /// springs behind the finger, and its bridges have to keep up.
  void _move(Offset delta) {
    _edit(() {
      final _Blob b = _current;
      // Clamp the CENTRE, not the box: a member may hang half off the edge —
      // that sliced look is part of the blend — but can never be lost.
      b.aim(
        center: Offset(
          (b.x.target + delta.dx).clamp(0.0, _stage.width),
          (b.y.target + delta.dy).clamp(0.0, _stage.height),
        ),
      );
    });
  }

  /// Resize from the corner grip. A centred box grows at twice the drag, and
  /// [_link] mirrors the dominant axis onto the other.
  void _resize(Offset delta) {
    _edit(() {
      final _Blob b = _current;
      final double maxSide = math.max(_minSide, _stage.shortestSide);
      if (_link) {
        final double d =
            (delta.dx.abs() > delta.dy.abs() ? delta.dx : delta.dy) * 2;
        final double side = (b.w.target + d).clamp(_minSide, maxSide);
        b.aim(size: Size(side, side));
      } else {
        b.aim(
          size: Size(
            (b.w.target + delta.dx * 2).clamp(_minSide, maxSide),
            (b.h.target + delta.dy * 2).clamp(_minSide, maxSide),
          ),
        );
      }
    });
  }

  void _setWidth(double v) => _edit(
      () => _current.aim(size: Size(v, _link ? v : _current.h.target)));

  void _setHeight(double v) => _edit(
      () => _current.aim(size: Size(_link ? v : _current.w.target, v)));

  // ── Integration ──────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    // Clamp the step: a dropped frame or a resumed app must not launch every
    // member across the stage in a single integration.
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 1 / 30) dt = 1 / 30;
    if (_slow) dt *= 0.25;

    final double damping = _liquid ? _dampingLiquid : _dampingCalm;
    bool moving = false;

    for (final _Blob b in _blobs) {
      b.x.step(dt, _stiffness, damping);
      b.y.step(dt, _stiffness, damping);
      b.w.step(dt, _stiffness, damping);
      b.h.step(dt, _stiffness, damping);
      // The radius rides a stiffer, calmer spring than the box: a corner that
      // overshoots as hard as the width visibly pumps on arrival, and unlike
      // the box there is no volume to justify it.
      b.r.step(dt, _stiffness * 1.4, damping * 1.3);

      // Halfway: adopt the destination's corner curve. The enum cannot be
      // interpolated, so it is swapped where the member is moving fastest and
      // the eye is least able to catch the discontinuity.
      if (b.shownCorner != b.corner &&
          (b.travelStart <= 1 || b.distance < b.travelStart * 0.5)) {
        b.shownCorner = b.corner;
        b.travelStart = 0;
      }

      if (b.moving) moving = true;
    }

    // A member that has finished shrinking leaves the tree, freeing its slot
    // under the blender's cap.
    final int before = _blobs.length;
    _blobs.removeWhere((_Blob b) => b.dying && !b.moving);
    if (_blobs.length != before) moving = true;

    if (_playing) _advancePlayback(dt, moving);

    if (moving || _dirty || _playing) {
      _dirty = false;
      setState(() {});
    } else {
      // Settled and idle. Stop asking for frames entirely rather than waking
      // the engine every vsync to discover there is nothing to do; any control
      // that moves a target calls _wake() and starts it again.
      _ticker.stop();
    }
  }

  /// The A→B sequencer.
  ///
  /// It advances on the SPRINGS being done rather than on a duration, so it
  /// stays correct whatever the springs are doing — retuned damping, 0.25×
  /// time, or a pose whose members have much further to travel than the last
  /// one's. There is no timeline to keep in sync with the motion.
  void _advancePlayback(double dt, bool moving) {
    if (moving) {
      _hold = 0;
      return;
    }
    _hold += dt;
    if (_hold < _holdFor) return;
    _hold = 0;

    // Every path below changes the phase, and the caller re-reads `_playing`
    // AFTER this returns to decide whether to repaint. Without this, the final
    // transition to idle is invisible: nothing is moving any more, so the
    // caller would stop the ticker instead of painting the chip's way back
    // from "stop" to "play", and nothing would ever repaint it.
    _dirty = true;

    final int next = _step + 1;
    if (next < _steps.length) {
      _step = next;
      _applyPose(_steps[next]);
      return;
    }
    // Off the end of the sequence.
    if (!_loop) {
      _stopPlaying();
      return;
    }
    _step = 0;
    _applyPose(_steps[0]);
  }

  /// Squash and stretch for [b], straight off spring velocity: the axis
  /// opening fast pushes the other in, and the pair sums to ~0 so the member
  /// keeps roughly its area. Both terms decay on their own as it settles.
  Rect _drawnRect(_Blob b) {
    final Offset c = Offset(b.x.value, b.y.value);
    if (!_squash) {
      return Rect.fromCenter(center: c, width: b.w.value, height: b.h.value);
    }
    double norm(double v) => (v / _squashReference).clamp(-1.0, 1.0);
    final double bias = (norm(b.w.vel) - norm(b.h.vel)) * 0.5 * _squashGain;
    return Rect.fromCenter(
      center: c,
      width: math.max(1, b.w.value * (1 + bias)),
      height: math.max(1, b.h.value * (1 - bias)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Blend lab'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: _panelOpen ? 'Hide controls' : 'Show controls',
            onPressed: () => setState(() => _panelOpen = !_panelOpen),
            icon: Icon(
              _panelOpen
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
            ),
          ),
        ],
      ),
      body: LiquidGlassView(
        backgroundWidget: const _Background(url: _wallpaper),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints outer) {
              return Column(
                children: <Widget>[
                  const SizedBox(height: 46),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints c) {
                        final Size stage = Size(c.maxWidth, c.maxHeight);
                        _syncStage(stage);
                        return _buildStage(stage);
                      },
                    ),
                  ),
                  // The panel is capped and scrolls inside the cap. Left to
                  // size itself it can eat most of a short screen — and the
                  // stage's height is what bounds how big a member may be, so
                  // a tall panel silently shrinks the maximum member size.
                  if (_panelOpen)
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: outer.maxHeight * 0.46),
                      child: _panel(),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Re-lay-out whenever the stage changes, so neither the first layout nor a
  /// rotation can strand members off-stage.
  ///
  /// Called from inside `build`, so it must not `setState`. It marks the frame
  /// dirty instead and lets the ticker repaint: layout runs AFTER the panel is
  /// built, so the panel's stage-derived slider bounds would otherwise be a
  /// frame stale — and on the first frame, derived from a zero-sized stage.
  void _syncStage(Size stage) {
    if (stage == _stage) return;
    final Size old = _stage;
    final bool first = old == Size.zero;
    _stage = stage;

    if (first) {
      // No opening animation: the cluster starts arranged rather than
      // springing in from a corner.
      _layout(stage, resize: true);
      for (final _Blob b in _blobs) {
        b.snap();
      }
    } else {
      // NOT a re-layout. A stage change is usually not a rotation — a chip
      // label reflowing the panel's Wrap changes the panel's height and
      // therefore the stage's — and re-running the arrangement here would
      // overwrite whatever the user (or a pose) had just put on screen. Worse,
      // it feeds back: the arrangement moves members, that repaints the panel,
      // which can resize it again.
      //
      // So the cluster is REMAPPED into the new stage instead. Both the value
      // and the target scale together, which is the one place outside the
      // integrator that writes a live value — deliberately, because this is a
      // change of coordinates and must not read as motion.
      final double kx = stage.width / old.width;
      final double ky = stage.height / old.height;
      for (final _Blob b in _blobs) {
        b.x.value *= kx;
        b.x.target *= kx;
        b.y.value *= ky;
        b.y.target *= ky;
      }
    }
    _dirty = true;
    _wake();
  }

  Widget _buildStage(Size stage) {
    // The GROUP's material: one sheet, one tint, one rim, one refraction. The
    // members contribute geometry only — see the header.
    const LiquidGlassStyle groupStyle = LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 36,
        borderWidth: 1.5,
      ),
      appearance: LiquidGlassAppearance(
        color: Color(0x16FFFFFF),
        saturation: 1.06,
        blur: LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
      ),
      refraction: LiquidGlassRefraction(
        refractionType: OpticalRefraction(
          refraction: 1.5,
          refractionWidth: 24,
          depth: 0.6,
        ),
      ),
    );

    final List<_Blob> live = _live;

    return SizedBox(
      width: stage.width,
      height: stage.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Layer 1 — the glass. Every lens here is a member; nothing in this
          // subtree handles pointers, so members stay pure geometry.
          Positioned.fill(
            child: LiquidGlassBlender(
              smoothness: _fuse ? _smoothness : null,
              style: groupStyle,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  for (final _Blob b in _blobs)
                    _member(b, b.dying ? -1 : live.indexOf(b) + 1),
                ],
              ),
            ),
          ),

          // Layer 2 — the handles. Gestures live ABOVE the merged surface, so
          // hit testing never has to reason about a shape the shader invented.
          // Nothing here paints except the grip.
          Positioned.fill(
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (final _Blob b in live) _handle(b),
                _grip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One member: a bare [LiquidGlassLens] carrying its own size and its own
  /// corner profile, and nothing else. [label] is `-1` while shrinking out.
  Widget _member(_Blob b, int label) {
    final Rect r = _drawnRect(b);
    return Positioned.fromRect(
      rect: r,
      child: IgnorePointer(
        child: LiquidGlassLens(
          style: LiquidGlassStyle(
            shape: LiquidGlassShape(
              cornerStyle: b.shownCorner,
              cornerRadius: b.effectiveRadius,
            ),
          ),
          child: label < 0
              ? null
              : Center(
                  child: Text(
                    '$label',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: math.min(r.width, r.height) * 0.26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// The pointer target for [b] — invisible. Which member is selected is shown
  /// by the grip on its corner and by the panel's readout, not by an outline:
  /// a rectangle drawn over the glass competes with the very outline the
  /// metaball is there to produce.
  Widget _handle(_Blob b) {
    return Positioned.fromRect(
      rect: _drawnRect(b),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _sel = b),
        onPanDown: (_) => setState(() => _sel = b),
        onPanUpdate: (DragUpdateDetails d) => _move(d.delta),
        child: const SizedBox.expand(),
      ),
    );
  }

  /// Resize grip on the selected member's bottom-right corner, clamped into
  /// the stage so a member dragged to the edge keeps a reachable handle.
  Widget _grip() {
    final Rect r = _drawnRect(_current);
    return Positioned(
      left: (r.right - _ResizeGrip.size / 2)
          .clamp(0.0, math.max(0.0, _stage.width - _ResizeGrip.size)),
      top: (r.bottom - _ResizeGrip.size / 2)
          .clamp(0.0, math.max(0.0, _stage.height - _ResizeGrip.size)),
      child: GestureDetector(
        onPanUpdate: (DragUpdateDetails d) => _resize(d.delta),
        child: const _ResizeGrip(),
      ),
    );
  }

  // ── Panel ────────────────────────────────────────────────────────

  Widget _panel() {
    final _Blob b = _current;
    final int n = _live.length;
    final double maxSide = math.max(_minSide + 1, _stage.shortestSide);
    final double maxRadius = math.max(1, math.min(b.w.target, b.h.target) / 2);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Live geometry, not the targets — it animates while the blend does.
            Text(
              'lens ${_live.indexOf(b) + 1}/$n   '
              '${b.w.value.round()} × ${b.h.value.round()}   '
              'r ${b.effectiveRadius.round()}   ${_cornerName(b.shownCorner)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: <Widget>[
                const _Label('lenses'),
                _Chip(
                  label: '−',
                  on: false,
                  enabled: n > _minCount,
                  onTap: _removeSelected,
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '$n',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFeatures: <ui.FontFeature>[
                        ui.FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
                _Chip(
                    label: '+', on: false, enabled: n < _maxCount, onTap: _add),
                // Expanded, not Spacer + Text: the badge is the only thing here
                // that may be squeezed, so it is the only thing allowed to be.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      n >= _maxCount ? 'cap $_maxCount' : '1 read',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: n >= _maxCount
                            ? Colors.orangeAccent
                            : Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Per-member geometry. These drive the TARGETS; the glass springs to
            // them, so even a slider drag is a morph.
            _LabSlider(
              label: 'W',
              value: b.w.target.clamp(_minSide, maxSide),
              min: _minSide,
              max: maxSide,
              onChanged: _setWidth,
            ),
            _LabSlider(
              label: 'H',
              value: b.h.target.clamp(_minSide, maxSide),
              min: _minSide,
              max: maxSide,
              onChanged: _setHeight,
            ),
            _LabSlider(
              label: 'r',
              value: b.r.target.clamp(0.0, maxRadius),
              min: 0,
              max: maxRadius,
              onChanged: (double v) => _edit(() => _current.aim(radius: v)),
            ),
            _LabSlider(
              label: 'k',
              value: _smoothness,
              min: 4,
              max: 96,
              enabled: _fuse,
              onChanged: (double v) => setState(() => _smoothness = v),
            ),

            const SizedBox(height: 2),
            // Wrap, not Row: chip labels change width as they cycle, and a
            // narrow phone should get a second line rather than a stripe of
            // overflow.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                _Chip(
                  label: _fuse ? 'fuse' : 'hard union',
                  on: _fuse,
                  onTap: () => setState(() => _fuse = !_fuse),
                ),
                _Chip(
                  label: 'link W/H',
                  on: _link,
                  onTap: () => setState(() => _link = !_link),
                ),
                _Chip(
                  label: _cornerName(b.corner),
                  on: false,
                  onTap: () => _edit(() {
                    const List<LiquidGlassCornerStyle> all =
                        LiquidGlassCornerStyle.values;
                    final _Blob c = _current;
                    c.corner = all[(all.indexOf(c.corner) + 1) % all.length];
                    // Give the swap a travel to hide inside, even when the
                    // member is otherwise already where it wants to be.
                    c.travelStart = math.max(c.distance, 2);
                  }),
                ),
                _Chip(
                  label: _liquid ? 'spring' : 'eased',
                  on: _liquid,
                  onTap: () => setState(() => _liquid = !_liquid),
                ),
                _Chip(
                  label: 'squash',
                  on: _squash,
                  onTap: () => setState(() => _squash = !_squash),
                ),
                _Chip(
                  label: '0.25×',
                  on: _slow,
                  onTap: () => setState(() => _slow = !_slow),
                ),
              ],
            ),

            const SizedBox(height: 8),
            // Scale on either axis, or both. A one-axis scale of the whole
            // cluster is the interesting one: it stretches the gaps as well as
            // the members, so the bridges have to stretch with them.
            Row(
              children: <Widget>[
                const _Label('scale'),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final _Axis a in _Axis.values)
                        _Chip(
                          label: switch (a) {
                            _Axis.x => 'X',
                            _Axis.y => 'Y',
                            _Axis.both => 'XY',
                          },
                          on: _axis == a,
                          onTap: () => _edit(() => _axis = a),
                        ),
                      _Chip(
                        label: _scaleAll ? 'cluster' : 'one lens',
                        on: _scaleAll,
                        onTap: () => _edit(() => _scaleAll = !_scaleAll),
                      ),
                      // Not "+" / "−": the lens stepper already owns those
                      // glyphs, and two controls with the same label on one
                      // panel is a coin toss for the user and for a test.
                      _Chip(
                        label: '÷',
                        on: false,
                        onTap: () => _scale(1 / _scaleStep),
                      ),
                      _Chip(
                        label: '×',
                        on: false,
                        onTap: () => _scale(_scaleStep),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            // The sequence. Recording a step is a snapshot of everything;
            // playing it back is not a special animation path — it moves the
            // same spring targets every other control on this page moves.
            Row(
              children: <Widget>[
                const _Label('seq'),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _Chip(label: '+ step', on: false, onTap: _addStep),
                      // "s1", not "1": every lens draws its own number on the
                      // glass, so a bare digit here would be ambiguous.
                      for (int i = 0; i < _steps.length; i++)
                        _Chip(
                          label: 's${i + 1}',
                          on: _step == i,
                          onTap: () => _recall(i),
                        ),
                      if (_steps.isNotEmpty)
                        _Chip(label: '− step', on: false, onTap: _dropStep),
                      _Chip(
                        label: _playing ? 'stop' : 'play',
                        on: _playing,
                        // Two steps is the minimum that is a sequence at all.
                        enabled: _steps.length >= 2,
                        onTap: _playing ? _stop : _playSeq,
                      ),
                      _Chip(
                        label: 'loop',
                        on: _loop,
                        onTap: () => _edit(() => _loop = !_loop),
                      ),
                      if (_steps.isNotEmpty)
                        _Chip(label: 'clear', on: false, onTap: _clearSteps),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const _Label('morph to'),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final _Arrange a in _Arrange.values)
                        _Chip(
                          label: a.name,
                          on: _arrange == a,
                          onTap: () => _setArrange(a),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _cornerName(LiquidGlassCornerStyle s) => switch (s) {
        LiquidGlassCornerStyle.roundedRectangle => 'circular',
        LiquidGlassCornerStyle.squircle => 'squircle',
        LiquidGlassCornerStyle.continuousRoundedRectangle => 'continuous',
      };
}

// ── Chrome ─────────────────────────────────────────────────────────

class _ResizeGrip extends StatelessWidget {
  const _ResizeGrip();

  static const double size = 34;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Transform.rotate(
        angle: math.pi / 2,
        child: const Icon(
          Icons.open_in_full_rounded,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
        ),
      );
}

/// Compact labelled slider — label, track, value, on one 32 px row.
class _LabSlider extends StatelessWidget {
  const _LabSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final double a = enabled ? 1.0 : 0.35;
    final double v = value.clamp(min, max);
    return SizedBox(
      height: 32,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 18,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7 * a),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white.withValues(alpha: a),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.22 * a),
                thumbColor: Colors.white.withValues(alpha: a),
                overlayColor: Colors.white.withValues(alpha: 0.14),
              ),
              child: Slider(
                value: v,
                min: min,
                max: max,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              v.round().toString(),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withValues(alpha: a),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const <ui.FontFeature>[
                  ui.FontFeature.tabularFigures()
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final double a = enabled ? 1.0 : 0.3;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: on
              ? Colors.white.withValues(alpha: 0.92 * a)
              : Colors.white.withValues(alpha: 0.16 * a),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on
                ? const Color(0xFF11131A)
                : Colors.white.withValues(alpha: a),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The refractable photo captured by [LiquidGlassView].
class _Background extends StatelessWidget {
  const _Background({required this.url});

  final String url;

  static const DecoratedBox _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF2E1065),
          Color(0xFF0EA5E9),
          Color(0xFFF59E0B),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback,
          loadingBuilder: (
            BuildContext context,
            Widget child,
            ImageChunkEvent? progress,
          ) {
            if (progress == null) return child;
            return const Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _fallback,
                Center(child: CircularProgressIndicator(color: Colors.white)),
              ],
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x22000000), Color(0x55000000)],
            ),
          ),
        ),
      ],
    );
  }
}
