import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'data.dart';
import 'plate.dart';
import 'theme.dart';

// =============================================================
// The pieces every page is assembled from.
//
// The app has two surfaces and they are not interchangeable.
//
// On PAPER, things are separated by a hairline and nothing else —
// `PaperRow`, `SectionHead`, a rule. No cards, no shadows, no glass. A
// lens over paper has nothing to bend and reads as a smudge.
//
// On a PLATE, things are glass: `Rim` is a fill under a
// `LiquidGlassLite` in `blend` pickup, so the rim takes its colour
// from the plate it is lying on. None of it reads the backdrop, so a
// plate can carry four rims and the two bars still own the entire lens
// budget — which on this app is the real constraint.
// =============================================================

/// A press that answers, and the only feedback in the app. Scaling is
/// enough on a surface that is already glass; an ink splash under a
/// lens reads as a bug.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Arrives from just below, a beat after the thing above it.
///
/// Used down the first screen of every page. The stagger is small on
/// purpose — enough that the page assembles rather than appears, not so
/// much that scrolling back up feels like waiting for it.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.lift = 0.16});

  final Widget child;

  /// Position in the run. The delay is 55ms a step, capped, so a long
  /// list does not end up animating for two seconds.
  final int index;

  /// How far below its place it starts, as a fraction of its own height.
  final double lift;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool _in = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final int ms = (widget.index * 55).clamp(0, 440);
    _timer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _in ? Offset.zero : Offset(0, widget.lift),
      duration: const Duration(milliseconds: 620),
      curve: const Cubic(0.16, 1, 0.3, 1),
      child: AnimatedOpacity(
        opacity: _in ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        child: widget.child,
      ),
    );
  }
}

// ── Glass on a plate ─────────────────────────────────────────

/// A filled shape with a glass rim, for the things that lie ON a plate:
/// the price capsule, the favourite button, the bar at the foot of a
/// product page.
///
/// The rim is a [LiquidGlassLite] in [LiquidGlassPickup.blend],
/// which is the mode this app is built around — the rim's light is
/// mixed into the plate under it rather than covering it, so the same
/// widget comes out warm on a clay plate and cold on a blue one without
/// being told which it is on, and without reading the backdrop.
class Rim extends StatelessWidget {
  const Rim({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    this.tint = const Color(0x59FFFFFF),
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: CustomPaint(
        painter: PlateFill(radius: radius, color: tint),
        child: LiquidGlassLite(
          shape: vitrineRim(radius: radius),
          pickup: LiquidGlassPickup.blend,
          blendFloor: kRimFloor,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// How much plain white rim survives the blend.
///
/// `overlay` multiplies, so it has nothing to work with over black and
/// blows out over white. The plates here are deliberately mid-tone,
/// which is the band the blend is best in, so this sits only a little
/// over the widget's own 0.25 default — enough to hold the rim together
/// where a plate goes dark at the floor.
const double kRimFloor = 0.3;

/// The fill under a rim, on the rim's own outline.
///
/// `LiquidGlassLite` paints the rim and leaves the fill to the caller,
/// and it lights that rim along the package's continuous corner — so a
/// `BorderRadius` fill would leave a circular arc showing inside it at
/// every corner. This comes from the same path. One `drawPath`, no layer.
class PlateFill extends CustomPainter {
  const PlateFill({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a <= 0 || size.isEmpty) return;
    canvas.drawPath(
      liquidGlassContinuousRoundedRectPath(size, radius),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(PlateFill oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}

/// A round rim button, for the corner of a plate.
class RimIcon extends StatelessWidget {
  const RimIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.active = false,
    this.activeColor = kSignal,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Rim(
      radius: size / 2,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: size * 0.45,
          color: active ? activeColor : kInk.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

// ── Paper ────────────────────────────────────────────────────

/// A row on paper: a hairline underneath, and nothing else. Everything
/// that repeats down a page is one of these.
class PaperRow extends StatelessWidget {
  const PaperRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    this.rule = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool rule;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: padding,
        decoration: rule
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: kLine)),
              )
            : null,
        child: child,
      ),
    );
  }
}

/// The line above a section: an eyebrow, a heading, and an optional
/// link on the right.
class SectionHead extends StatelessWidget {
  const SectionHead(
    this.title, {
    super.key,
    this.eyebrow,
    this.action,
    this.onAction,
  });

  final String title;
  final String? eyebrow;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (eyebrow != null) ...<Widget>[
                  Text(eyebrow!.toUpperCase(), style: kEyebrow),
                  const SizedBox(height: 7),
                ],
                Text(title, style: kDisplay.copyWith(fontSize: 25)),
              ],
            ),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 3),
                child: Text(
                  action!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                    decoration: TextDecoration.underline,
                    decorationColor: kLine,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A selectable pill. There are five or six of these in a row wherever
/// they appear, which is exactly the case a lens is wrong for.
class VitrineChip extends StatelessWidget {
  const VitrineChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kInk : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? kInk : const Color(0x261A1714)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: selected ? kPaper : kInkSoft),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? kPaper : kInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shop's button: filled ink, or outlined. Not glass — it lives on
/// paper, where glass has nothing to refract.
class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.filled = true,
    this.height = 52,
    this.color = kInk,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final double height;
  final Color color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final Color fg = foreground ?? (filled ? kPaper : kInk);
    return Pressable(
      onTap: onPressed,
      scale: 0.975,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(height / 2),
          border: filled ? null : Border.all(color: const Color(0x331A1714)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 9),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Products ─────────────────────────────────────────────────

/// A price, struck through when it has moved.
class Price extends StatelessWidget {
  const Price(this.product, {super.key, this.size = 14.5, this.onDark = false});

  final Product product;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color ink = onDark ? const Color(0xFFFBF9F6) : kInk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          money(product.price),
          style: kPrice.copyWith(
            fontSize: size,
            color: product.reduced ? kSignal : ink,
          ),
        ),
        if (product.reduced) ...<Widget>[
          const SizedBox(width: 7),
          Text(
            money(product.was!),
            style: kPrice.copyWith(
              fontSize: size - 1.5,
              color: ink.withValues(alpha: 0.42),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}

/// A product in a grid: its plate, its name, its price, and the one
/// rim button that saves it.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.aspect = 1.0,
  });

  final Product product;
  final VoidCallback? onTap;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    final Bag bag = BagScope.of(context);
    final bool saved = bag.isSaved(product.id);

    return Pressable(
      onTap: onTap,
      scale: 0.975,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: aspect,
            child: ProductPlate(
              tone: product.tone(),
              kind: product.kind,
              seed: product.id,
              radius: 18,
              child: Stack(
                children: <Widget>[
                  if (product.reduced)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Rim(
                        radius: 13,
                        tint: kSignal.withValues(alpha: 0.86),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        child: Text(
                          'REDUCED',
                          style: kEyebrow.copyWith(
                              fontSize: 8.5, color: const Color(0xFFFFF3EF)),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: RimIcon(
                      icon: saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 34,
                      active: saved,
                      onTap: () => bag.toggleSaved(product.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(product.maker.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kEyebrow.copyWith(fontSize: 8.5)),
          const SizedBox(height: 5),
          Text(product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kTitle.copyWith(fontSize: 14)),
          const SizedBox(height: 5),
          Price(product, size: 13),
        ],
      ),
    );
  }
}

/// A product in a list: a small plate, the name, the price on the right.
class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
    this.plate = 66,
  });

  final Product product;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double plate;

  @override
  Widget build(BuildContext context) {
    return PaperRow(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          ProductPlate(
            tone: product.tone(),
            kind: product.kind,
            seed: product.id,
            size: plate,
            radius: 14,
            detail: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(product.maker.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kEyebrow.copyWith(fontSize: 8.5)),
                const SizedBox(height: 5),
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(product.line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kBody.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ?? Price(product, size: 13.5),
        ],
      ),
    );
  }
}

// ── The tab contract ─────────────────────────────────────────

/// One destination in the shell.
///
/// A tab hands the shell two things and does not build a page: the
/// light it is lit by ([tone], which becomes the captured room) and the
/// [content] that floats over it. That split is what lets one
/// `LiquidGlassScaffold` serve five tabs, and it is why the tab bar's
/// pill keeps travelling across a tab change instead of being rebuilt.
abstract class VitrineTab {
  const VitrineTab();

  String get title;
  String get label;
  IconData get icon;

  /// The hue of the room this tab is shown in.
  PlateTone get tone;

  Widget content(BuildContext context);

  List<Widget> actions(BuildContext context) => const <Widget>[];
}

// ── Layout ───────────────────────────────────────────────────

/// Room the floating bar needs above a page's first line.
const double kTopInset = 84;

/// Room the tab bar needs below its last one.
const double kBottomInset = 126;

/// The scroll view every page is, with the chrome's clearances already
/// in it. Pages pass children, not padding.
class VitrineList extends StatelessWidget {
  const VitrineList({
    super.key,
    required this.children,
    this.top = kTopInset,
    this.bottom = kBottomInset,
    this.horizontal = 22,
    this.controller,
  });

  final List<Widget> children;
  final double top;
  final double bottom;
  final double horizontal;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    return ListView(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        horizontal,
        pad.top + top,
        horizontal,
        pad.bottom + bottom,
      ),
      children: children,
    );
  }
}

// ── A word back ──────────────────────────────────────────────

/// A glass capsule that says one thing and leaves.
///
/// It goes into the root `Overlay` rather than through
/// `ScaffoldMessenger`, because there is no `Scaffold` anywhere in this
/// app — the pages are `LiquidGlassScaffold`s, which own a capture
/// pipeline rather than a Material layout.
void showVitrineToast(BuildContext context, String message, {IconData? icon}) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(message: message, icon: icon),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2200), () {
    if (entry.mounted) entry.remove();
  });
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.paddingOf(context).bottom + 116,
      child: IgnorePointer(
        child: AnimatedSlide(
          offset: _in ? Offset.zero : const Offset(0, 0.5),
          duration: const Duration(milliseconds: 340),
          curve: const Cubic(0.16, 1, 0.3, 1),
          child: AnimatedOpacity(
            opacity: _in ? 1 : 0,
            duration: const Duration(milliseconds: 240),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kInk,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: kInk.withValues(alpha: 0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.icon != null) ...<Widget>[
                        Icon(widget.icon, size: 17, color: kPaper),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.message,
                        style: kTitle.copyWith(fontSize: 13.5, color: kPaper),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pages arrive by growing very slightly into place under a fade —
/// short enough to feel immediate, long enough that the glass on the
/// new page is seen settling rather than appearing.
Route<T> vitrineRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 440),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, Animation<double> a, __, Widget child) {
      final Animation<double> eased =
          CurvedAnimation(parent: a, curve: const Cubic(0.16, 1, 0.3, 1));
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.05, end: 1).animate(eased),
          child: child,
        ),
      );
    },
  );
}
