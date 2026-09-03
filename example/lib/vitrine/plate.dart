import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

// =============================================================
// What the glass looks at.
//
// Nothing here is downloaded. Every product in the shop is a PLATE: a
// studio wall in the product's hue, a disc hung on it, a floor, and an
// object standing on that floor casting a shadow onto it. All of it is
// canvas.
//
// The composition is not only taste. A lens needs edges — over a smooth
// gradient there is nothing to bend and refraction reads as a slightly
// blurry rectangle. So every plate lays three hard lines under the
// glass on purpose: the disc's rim, the wall/floor horizon, and the
// object's own silhouette. Watch any of the three bow as the tab bar
// slides over it.
// =============================================================

/// The ten things this shop sells. Each is a recipe rather than a
/// picture: a handful of paths drawn into whatever box it is given, so
/// the same object is a 64px thumbnail and a full-bleed hero.
enum ObjectKind { vase, lamp, chair, mug, bottle, clock, speaker, mirror, bowl, candle }

/// One product's picture.
///
/// Give it a [tone] (the hue family, from the product) and a [kind] (the
/// silhouette). [seed] only moves the dust, so two vases in the same
/// colour are not identically speckled.
class ProductPlate extends StatelessWidget {
  const ProductPlate({
    super.key,
    required this.tone,
    required this.kind,
    this.seed = 'plate',
    this.radius = 20,
    this.size,
    this.scale = 1.0,
    this.detail = true,
    this.child,
  });

  final PlateTone tone;
  final ObjectKind kind;
  final String seed;
  final double radius;

  /// Square side. Null takes the box it is given, which is how the hero
  /// and the grid cells use it.
  final double? size;

  /// How much of the plate the object fills. Under 1 it stands further
  /// back in the room — the hero uses that, so type has somewhere to go.
  final double scale;

  /// Dust, scan lines and the vignette. Off for thumbnails, where none
  /// of it survives the downscale and all of it costs.
  final bool detail;

  /// Painted over the plate: a price pill, a rim button, a tag.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PlatePainter(tone, kind, seed, scale, detail),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter(this.tone, this.kind, this.seed, this.scale, this.detail);

  final PlateTone tone;
  final ObjectKind kind;
  final String seed;
  final double scale;
  final bool detail;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double w = size.width;
    final double h = size.height;

    // ── The wall ─────────────────────────────────────────────
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[tone.wallTop, tone.wallBottom],
        ).createShader(rect),
    );

    // The disc hung behind the object. Lit from the upper left like
    // everything else, and the first of the three edges the glass bends.
    final Offset discCentre = Offset(w * 0.5, h * 0.415);
    final double discR = math.min(w, h) * 0.335;
    canvas.drawCircle(
      discCentre,
      discR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromCircle(center: discCentre, radius: discR)),
    );
    canvas.drawCircle(
      discCentre,
      discR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, w * 0.004)
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    // ── The floor ────────────────────────────────────────────
    final double horizon = h * 0.735;
    final Rect floor = Rect.fromLTRB(0, horizon, w, h);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            tone.floor,
            Color.lerp(tone.floor, Colors.black, 0.14)!,
          ],
        ).createShader(floor),
    );
    // The horizon itself, caught by the light.
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, math.max(0.8, h * 0.004)),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );

    // ── The object ───────────────────────────────────────────
    // Sized off the shorter side and stood ON the horizon, so a wide
    // plate puts room either side of it rather than stretching it.
    final double s = math.min(w, h);
    final double objH = s * 0.50 * scale;
    final double objW = objH * _aspect(kind);
    final Rect box = Rect.fromLTWH(
      (w - objW) / 2,
      horizon - objH,
      objW,
      objH,
    );

    _contactShadow(canvas, box, horizon, s);
    _drawObject(canvas, box, kind, tone, s);

    if (detail) {
      _paper(canvas, size);
      // Corners pulled down, which is what makes the middle read as lit
      // rather than the whole plate reading as flat colour.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.85,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.20),
            ],
            stops: const <double>[0.55, 1.0],
          ).createShader(rect),
      );
    }
  }

  /// The object's shadow, thrown to the lower right and squashed onto
  /// the floor plane. Two of them: a tight dark one at the contact
  /// point, and a wide soft one for the ambient.
  void _contactShadow(Canvas canvas, Rect box, double horizon, double s) {
    final Color ink = Color.lerp(tone.floor, Colors.black, 0.55)!;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(box.center.dx + box.width * 0.30, horizon + s * 0.018),
        width: box.width * 2.0,
        height: s * 0.075,
      ),
      Paint()
        ..color = ink.withValues(alpha: 0.26)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.045),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(box.center.dx + box.width * 0.08, horizon + s * 0.006),
        width: box.width * 0.92,
        height: s * 0.030,
      ),
      Paint()
        ..color = ink.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012),
    );
  }

  /// Paper: fine horizontal rules and a scatter of dust. Both are far
  /// too faint to see as themselves, and both are hard-edged, which is
  /// the point — they are what a lens has to distort.
  void _paper(Canvas canvas, Size size) {
    final Paint rule = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 0.7;
    for (double y = 0; y < size.height; y += 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    final math.Random rnd = math.Random(seed.hashCode);
    for (int i = 0; i < 34; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.4 + rnd.nextDouble() * 0.9,
        Paint()
          ..color = Colors.white
              .withValues(alpha: 0.10 + rnd.nextDouble() * 0.22),
      );
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.tone.hue != tone.hue ||
      old.kind != kind ||
      old.seed != seed ||
      old.scale != scale ||
      old.detail != detail;
}

// ── The silhouettes ──────────────────────────────────────────

/// Width over height, per kind. A chair is wide, a bottle is not.
double _aspect(ObjectKind kind) => switch (kind) {
      ObjectKind.vase => 0.62,
      ObjectKind.lamp => 0.80,
      ObjectKind.chair => 0.92,
      ObjectKind.mug => 0.95,
      ObjectKind.bottle => 0.42,
      ObjectKind.clock => 1.0,
      ObjectKind.speaker => 0.58,
      ObjectKind.mirror => 0.66,
      ObjectKind.bowl => 1.35,
      ObjectKind.candle => 0.50,
    };

/// The lit-to-shaded fill every object body uses. One light, upper
/// left, for the whole shop — it is most of what makes forty separately
/// drawn objects look photographed on the same day.
Paint _body(Rect r, PlateTone t) => Paint()
  ..isAntiAlias = true
  ..shader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[t.object, t.objectShade],
    stops: const <double>[0.14, 1.0],
  ).createShader(r);

/// The specular run down the lit side, clipped to whatever shape it is
/// given. Without it a filled path reads as a sticker.
void _sheen(Canvas canvas, Path shape, Rect r) {
  canvas.save();
  canvas.clipPath(shape);
  canvas.drawRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.42],
      ).createShader(r),
  );
  canvas.restore();
}

void _drawObject(
    Canvas canvas, Rect r, ObjectKind kind, PlateTone t, double s) {
  switch (kind) {
    case ObjectKind.vase:
      _vase(canvas, r, t);
    case ObjectKind.lamp:
      _lamp(canvas, r, t);
    case ObjectKind.chair:
      _chair(canvas, r, t);
    case ObjectKind.mug:
      _mug(canvas, r, t);
    case ObjectKind.bottle:
      _bottle(canvas, r, t);
    case ObjectKind.clock:
      _clock(canvas, r, t);
    case ObjectKind.speaker:
      _speaker(canvas, r, t);
    case ObjectKind.mirror:
      _mirror(canvas, r, t);
    case ObjectKind.bowl:
      _bowl(canvas, r, t);
    case ObjectKind.candle:
      _candle(canvas, r, t);
  }
}

/// A shouldered vessel: narrow foot, belly at two thirds, drawn neck,
/// flared lip.
void _vase(Canvas canvas, Rect r, PlateTone t) {
  final double w = r.width, h = r.height;
  final double cx = r.center.dx;
  final double neck = w * 0.30, foot = w * 0.34, belly = w * 0.50;
  final double lipY = r.top + h * 0.10;

  final Path p = Path()
    ..moveTo(cx - neck, lipY)
    ..cubicTo(cx - neck * 1.05, r.top + h * 0.30, cx - belly,
        r.top + h * 0.42, cx - belly, r.top + h * 0.60)
    ..cubicTo(cx - belly, r.top + h * 0.85, cx - foot, r.bottom - h * 0.02,
        cx - foot, r.bottom)
    ..lineTo(cx + foot, r.bottom)
    ..cubicTo(cx + foot, r.bottom - h * 0.02, cx + belly, r.top + h * 0.85,
        cx + belly, r.top + h * 0.60)
    ..cubicTo(cx + belly, r.top + h * 0.42, cx + neck * 1.05,
        r.top + h * 0.30, cx + neck, lipY)
    ..close();

  canvas.drawPath(p, _body(r, t));
  _sheen(canvas, p, r);

  // The lip, and the shadow inside it. An open vessel has a dark mouth.
  final Rect lip = Rect.fromCenter(
      center: Offset(cx, lipY), width: neck * 2.28, height: h * 0.055);
  canvas.drawOval(lip, Paint()..color = t.object);
  canvas.drawOval(
    lip.deflate(math.max(1.0, w * 0.022)),
    Paint()..color = Color.lerp(t.objectShade, Colors.black, 0.42)!,
  );

  // A single band, in the one colour that is not in the family.
  canvas.save();
  canvas.clipPath(p);
  canvas.drawRect(
    Rect.fromLTWH(r.left, r.top + h * 0.66, w, h * 0.045),
    Paint()..color = t.accent.withValues(alpha: 0.85),
  );
  canvas.restore();
}

/// A dome shade on a stem, on a weighted disc.
void _lamp(Canvas canvas, Rect r, PlateTone t) {
  final double w = r.width, h = r.height;
  final double cx = r.center.dx;
  final double shadeH = h * 0.40;
  final Rect shade = Rect.fromLTWH(r.left, r.top, w, shadeH * 2);

  // The dome: a half-ellipse with a slight overhang at the rim.
  final Path dome = Path()
    ..moveTo(r.left, r.top + shadeH)
    ..arcTo(Rect.fromLTWH(r.left, r.top, w, shadeH * 2), math.pi, math.pi, false)
    ..close();
  canvas.drawPath(dome, _body(shade, t));
  _sheen(canvas, dome, shade);

  // Under the rim it is dark, and just below it the light spills out.
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(cx, r.top + shadeH), width: w, height: h * 0.075),
    Paint()..color = Color.lerp(t.objectShade, Colors.black, 0.35)!,
  );
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(cx, r.top + shadeH + h * 0.02),
        width: w * 0.92,
        height: h * 0.05),
    Paint()
      ..color = const Color(0xFFFFF3D0).withValues(alpha: 0.85)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.02),
  );

  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(cx, r.top + shadeH + (h * 0.94 - shadeH) / 2),
      width: w * 0.085,
      height: h * 0.94 - shadeH,
    ),
    Paint()..color = t.objectShade,
  );
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(cx, r.bottom - h * 0.03),
        width: w * 0.56,
        height: h * 0.075),
    _body(r, t),
  );
}

/// Seat, back, four legs — two of them behind, drawn darker so the
/// thing has a front.
void _chair(Canvas canvas, Rect r, PlateTone t) {
  final double w = r.width, h = r.height;
  final Color back = Color.lerp(t.objectShade, Colors.black, 0.22)!;
  final double legW = w * 0.062;
  final double seatY = r.top + h * 0.54;

  // Back legs first, inset, so they read as further away.
  for (final double x in <double>[r.left + w * 0.30, r.right - w * 0.30]) {
    canvas.drawRect(
      Rect.fromLTWH(x - legW * 0.4, seatY, legW * 0.8, h * 0.46),
      Paint()..color = back,
    );
  }

  // The back rest, leaning.
  canvas.save();
  canvas.translate(r.center.dx, seatY);
  canvas.rotate(-0.055);
  final RRect rest = RRect.fromRectAndRadius(
    Rect.fromLTWH(-w * 0.36, -h * 0.52, w * 0.72, h * 0.40),
    Radius.circular(w * 0.10),
  );
  canvas.drawRRect(rest, _body(rest.outerRect, t));
  canvas.restore();

  final RRect seat = RRect.fromRectAndRadius(
    Rect.fromLTWH(r.left, seatY, w, h * 0.11),
    Radius.circular(h * 0.045),
  );
  canvas.drawRRect(seat, Paint()..color = t.object);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(r.left, seatY + h * 0.075, w, h * 0.035),
      Radius.circular(h * 0.02),
    ),
    Paint()..color = t.objectShade,
  );

  // Front legs, splayed a little.
  for (int i = 0; i < 2; i++) {
    final double top = i == 0 ? r.left + w * 0.10 : r.right - w * 0.10 - legW;
    final double drift = i == 0 ? -w * 0.045 : w * 0.045;
    final Path leg = Path()
      ..moveTo(top, seatY + h * 0.10)
      ..lineTo(top + legW, seatY + h * 0.10)
      ..lineTo(top + legW + drift, r.bottom)
      ..lineTo(top + drift, r.bottom)
      ..close();
    canvas.drawPath(leg, Paint()..color = i == 0 ? t.object : t.objectShade);
  }
}

/// A tapered cup with a strap handle.
void _mug(Canvas canvas, Rect r, PlateTone t) {
  final double w = r.width, h = r.height;
  final Rect cup = Rect.fromLTRB(
      r.left + w * 0.10, r.top + h * 0.16, r.right - w * 0.28, r.bottom);

  // The handle sits behind the cup, so it is drawn first and clipped by
  // nothing — the body covers its inner half on its own.
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(cup.right + w * 0.06, cup.center.dy + h * 0.02),
      width: w * 0.34,
      height: h * 0.44,
    ),
    -math.pi / 2,
    math.pi,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..color = t.objectShade,
  );

  final Path body = Path()
    ..moveTo(cup.left, cup.top)
    ..lineTo(cup.left + cup.width * 0.09, cup.bottom - h * 0.03)
    ..quadraticBezierTo(cup.center.dx, cup.bottom + h * 0.035,
        cup.right - cup.width * 0.09, cup.bottom - h * 0.03)
    ..lineTo(cup.right, cup.top)
    ..close();
  canvas.drawPath(body, _body(cup, t));
  _sheen(canvas, body, cup);

  final Rect rim = Rect.fromCenter(
      center: Offset(cup.center.dx, cup.top), width: cup.width, height: h * 0.10);
  canvas.drawOval(rim, Paint()..color = t.object);
  canvas.drawOval(
    rim.deflate(math.max(1.0, w * 0.028)),
    Paint()..color = Color.lerp(t.objectShade, Colors.black, 0.40)!,
  );
}

/// A shouldered bottle with a stopper.
void _bottle(Canvas canvas, Rect r, PlateTone t) {
  final double w = r.width, h = r.height;
  final double cx = r.center.dx;
  final double neck = w * 0.19;
  final double shoulder = r.top + h * 0.30;

  final Path p = Path()
    ..moveTo(cx - neck, r.top + h * 0.09)
    ..lineTo(cx - neck, shoulder - h * 0.04)
    ..quadraticBezierTo(cx - w * 0.5, shoulder, cx - w * 0.5, shoulder + h * 0.07)
    ..lineTo(cx - w * 0.5, r.bottom - h * 0.03)
    ..quadraticBezierTo(cx - w * 0.5, r.bottom, cx - w * 0.44, r.bottom)
    ..lineTo(cx + w * 0.44, r.bottom)
    ..quadraticBezierTo(cx + w * 0.5, r.bottom, cx + w * 0.5, r.bottom - h * 0.03)
    ..lineTo(cx + w * 0.5, shoulder + h * 0.07)
    ..quadraticBezierTo(cx + w * 0.5, shoulder, cx + neck, shoulder - h * 0.04)
    ..lineTo(cx + neck, r.top + h * 0.09)
    ..close();

  canvas.drawPath(p, _body(r, t));
  _sheen(canvas, p, r);

  // A paper label across the belly, and the stopper on top.
  canvas.save();
  canvas.clipPath(p);
  canvas.drawRect(
    Rect.fromLTRB(r.left, r.top + h * 0.52, r.right, r.top + h * 0.78),
    Paint()..color = Colors.white.withValues(alpha: 0.62),
  );
  canvas.drawRect(
    Rect.fromLTRB(r.left, r.top + h * 0.52, r.right, r.top + h * 0.535),
    Paint()..color = t.accent.withValues(alpha: 0.9),
  );
  canvas.restore();

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, r.top + h * 0.055),
          width: neck * 2.5,
          height: h * 0.085),
      Radius.circular(w * 0.05),
    ),
    Paint()..color = t.accent,
  );
}

/// A wall clock: case, dial, ticks, two hands.
void _clock(Canvas canvas, Rect r, PlateTone t) {
  final Offset c = r.center;
  final double rad = math.min(r.width, r.height) / 2;

  canvas.drawCircle(c, rad, _body(r, t));
  _sheen(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: rad)), r);
  canvas.drawCircle(
      c, rad * 0.86, Paint()..color = const Color(0xFFFCFAF6));

  final Paint tick = Paint()
    ..color = kInk.withValues(alpha: 0.75)
    ..strokeCap = StrokeCap.round;
  for (int i = 0; i < 12; i++) {
    final double a = i * math.pi / 6;
    final bool major = i % 3 == 0;
    tick.strokeWidth = major ? rad * 0.055 : rad * 0.028;
    final double inner = major ? 0.60 : 0.68;
    canvas.drawLine(
      c + Offset(math.cos(a), math.sin(a)) * rad * inner,
      c + Offset(math.cos(a), math.sin(a)) * rad * 0.76,
      tick,
    );
  }

  // Ten past ten, the way every clock is photographed.
  final Paint hand = Paint()
    ..color = kInk
    ..strokeCap = StrokeCap.round;
  hand.strokeWidth = rad * 0.075;
  canvas.drawLine(c, c + const Offset(-0.42, -0.30) * 1.0 * rad, hand);
  hand.strokeWidth = rad * 0.055;
  canvas.drawLine(c, c + const Offset(0.36, -0.52) * 1.0 * rad, hand);
  canvas.drawCircle(c, rad * 0.055, Paint()..color = t.accent);
}

/// A standing speaker: fabric front, a knob, a foot.
void _speaker(Canvas canvas, Rect r, PlateTone t) {
  final double w = r.width, h = r.height;
  final RRect shell = RRect.fromRectAndRadius(
    Rect.fromLTRB(r.left, r.top, r.right, r.bottom - h * 0.05),
    Radius.circular(w * 0.28),
  );
  canvas.drawRRect(shell, _body(r, t));
  _sheen(canvas, Path()..addRRect(shell), r);

  // The grille: a dot field, dimmed toward the bottom so the cabinet
  // still reads as curved.
  canvas.save();
  canvas.clipRRect(shell);
  final double step = w * 0.115;
  for (double y = r.top + step; y < r.bottom - h * 0.16; y += step) {
    for (double x = r.left + step * 0.7; x < r.right - step * 0.2; x += step) {
      final double d = (y - r.top) / h;
      canvas.drawCircle(
        Offset(x, y),
        w * 0.022,
        Paint()..color = kInk.withValues(alpha: 0.20 - d * 0.08),
      );
    }
  }
  canvas.restore();

  canvas.drawCircle(
    Offset(r.center.dx, r.bottom - h * 0.14),
    w * 0.115,
    Paint()..color = t.accent,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(r.center.dx, r.bottom - h * 0.02),
          width: w * 0.62,
          height: h * 0.045),
      Radius.circular(h * 0.02),
    ),
    Paint()..color = Color.lerp(t.objectShade, Colors.black, 0.25)!,
  );
}

/// An arched mirror. The only object that shows the room back.
void _mirror(Canvas canvas, Rect r, PlateTone t) {
  final double w = r.width;
  final double arch = w / 2;

  final Path frame = Path()
    ..moveTo(r.left, r.bottom)
    ..lineTo(r.left, r.top + arch)
    ..arcToPoint(Offset(r.right, r.top + arch),
        radius: Radius.circular(arch), clockwise: true)
    ..lineTo(r.right, r.bottom)
    ..close();
  canvas.drawPath(frame, _body(r, t));

  final Rect inner = r.deflate(w * 0.07);
  final double innerArch = inner.width / 2;
  final Path glass = Path()
    ..moveTo(inner.left, inner.bottom)
    ..lineTo(inner.left, inner.top + innerArch)
    ..arcToPoint(Offset(inner.right, inner.top + innerArch),
        radius: Radius.circular(innerArch), clockwise: true)
    ..lineTo(inner.right, inner.bottom)
    ..close();
  canvas.drawPath(
    glass,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.lerp(t.wallTop, Colors.white, 0.45)!,
          Color.lerp(t.floor, Colors.white, 0.10)!,
        ],
      ).createShader(inner),
  );

  // The diagonal every mirror in every catalogue has.
  canvas.save();
  canvas.clipPath(glass);
  canvas.drawRect(
    inner,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.30, 0.42, 0.56],
      ).createShader(inner),
  );
  canvas.restore();
}

/// A wide, shallow bowl, seen slightly from above.
void _bowl(Canvas canvas, Rect r, PlateTone t) {
  final double w = r.width, h = r.height;
  final Rect rim = Rect.fromLTWH(r.left, r.top, w, h * 0.55);

  final Path body = Path()
    ..moveTo(r.left, r.top + h * 0.27)
    ..quadraticBezierTo(r.center.dx, r.bottom + h * 0.16, r.right,
        r.top + h * 0.27)
    ..close();
  canvas.drawPath(body, _body(r, t));
  _sheen(canvas, body, r);

  canvas.drawOval(rim, Paint()..color = t.object);
  canvas.drawOval(
    rim.deflate(math.max(1.5, w * 0.030)),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.lerp(t.objectShade, Colors.black, 0.34)!,
          t.objectShade,
        ],
      ).createShader(rim),
  );
  // A ring of the accent just inside the rim, the way a glazed bowl
  // pools colour where the brush stopped.
  canvas.drawOval(
    rim.deflate(math.max(1.5, w * 0.030)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..color = t.accent.withValues(alpha: 0.75),
  );
}

/// A pillar candle in a dish, lit.
void _candle(Canvas canvas, Rect r, PlateTone t) {
  final double w = r.width, h = r.height;
  final double cx = r.center.dx;
  final Rect pillar = Rect.fromLTRB(
      r.left + w * 0.14, r.top + h * 0.20, r.right - w * 0.14, r.bottom - h * 0.08);

  canvas.drawRect(pillar, _body(pillar, t));
  _sheen(canvas, Path()..addRect(pillar), pillar);
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(cx, pillar.top), width: pillar.width, height: h * 0.055),
    Paint()..color = t.object,
  );
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(cx, pillar.top + h * 0.008),
        width: pillar.width * 0.72,
        height: h * 0.032),
    Paint()..color = t.objectShade,
  );

  // The wick, the flame, and the light it throws back onto the wax.
  canvas.drawRect(
    Rect.fromCenter(
        center: Offset(cx, r.top + h * 0.165), width: w * 0.022, height: h * 0.05),
    Paint()..color = kInk.withValues(alpha: 0.7),
  );
  final Path flame = Path()
    ..moveTo(cx, r.top)
    ..quadraticBezierTo(cx + w * 0.13, r.top + h * 0.075, cx, r.top + h * 0.145)
    ..quadraticBezierTo(cx - w * 0.13, r.top + h * 0.075, cx, r.top);
  canvas.drawPath(
    flame,
    Paint()
      ..color = const Color(0xFFFFC24D)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.012),
  );
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(cx, pillar.top), width: w * 1.5, height: h * 0.22),
    Paint()
      ..color = const Color(0xFFFFD98A).withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.05),
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, r.bottom - h * 0.035),
          width: w * 1.05,
          height: h * 0.06),
      Radius.circular(h * 0.03),
    ),
    Paint()..color = Color.lerp(t.objectShade, Colors.black, 0.2)!,
  );
}

// ── The room itself ──────────────────────────────────────────

/// The page's own light: paper, two soft washes, and a ruled grid.
///
/// This is what a page hands its scaffold as the `body` — the layer the
/// bars capture. It is deliberately quiet, because in this app the
/// interesting thing under the glass is a plate scrolling past, not the
/// background behind it.
class VitrineRoom extends StatelessWidget {
  const VitrineRoom({super.key, required this.tone, this.seed = 'room'});

  final PlateTone tone;
  final String seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(painter: _RoomPainter(tone, seed)),
    );
  }
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter(this.tone, this.seed);

  final PlateTone tone;
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = kPaper);

    // Two washes of the page's hue, kept under 10% — on paper anything
    // stronger stops being light and starts being a colour.
    for (final (Alignment at, double reach, double alpha) in <
        (Alignment, double, double)>[
      (const Alignment(-0.9, -0.85), 1.15, 0.085),
      (const Alignment(1.0, 0.35), 0.95, 0.065),
    ]) {
      final Offset c = at.alongSize(size);
      final double r = reach * size.shortestSide;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              tone.wallBottom.withValues(alpha: alpha),
              tone.wallBottom.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // The grid. It is the only hard structure on the paper, and it is
    // here so the bars have something to bend where no plate is passing.
    final Paint line = Paint()..color = const Color(0x0C1A1714);
    const double step = 44;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.tone.hue != tone.hue || old.seed != seed;
}
