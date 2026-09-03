import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'backdrop.dart';
import 'data.dart';
import 'theme.dart';

// =============================================================
// The pieces every page is assembled from.
//
// One rule runs through all of it: SURFACES wear a rim, and a real lens
// is kept for chrome and for the controls whose behaviour is the glass.
// Every card, tile and button in a page is a `LiquidGlassLite` — the
// same optical rim the shader lights, from a triangle mesh, with no
// fragment shader and no read of the backdrop under it.
//
// So the surfaces have three weights and no budget. Cards you can lift
// off the page are `GlassPanel`, a fill under a rim; buttons are
// `GlassButton`, the same material at button size; rows and anything
// that repeats down a page are `FrostPanel`, a fill and a hairline.
// Only the first two carry a rim, which is what keeps a card reading as
// an object rather than a rectangle.
// =============================================================

/// A press that answers. Scales down under the finger on a spring-ish
/// curve, which is all the feedback a glass surface needs — an ink
/// splash under a lens reads as a bug.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.965,
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
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// How much plain white rim survives under the blend.
///
/// The blend is `overlay`, and overlay multiplies — over black there is
/// nothing to multiply, so a rim on the unlit half of an Aurora page
/// would fade out exactly where it is most needed. This is the plain
/// rim screened in underneath, and every page here is near-black
/// between its lamps, so it sits above the widget's own 0.25 default:
/// a little less colour picked up from the lit corners, in exchange for
/// a card that still has an edge in the dark ones.
const double kRimFloor = 0.35;

/// A card: a translucent fill with a glass rim around it.
///
/// The rim is a [LiquidGlassLite] in [LiquidGlassPickup.blend],
/// which is the mode that matters on a page like this one. A plain rim
/// carries its own white light; a blended one is mixed INTO the light
/// behind it, so a card over the violet corner of a backdrop takes the
/// violet up and a card over the teal one takes the teal — for a blend
/// mode, and no read of the backdrop at all.
///
/// [AuroraFill] paints the fill on the same continuous-corner outline
/// the rim is lit along, so the two agree at the corner instead of the
/// fill's circular arc cutting inside the rim's.
///
/// [kRimFloor] is the one number tuned for this app rather than taken
/// from the widget's defaults — see it for why.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(18),
    this.tint = const Color(0x1FFFFFFF),
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
        painter: AuroraFill(radius: radius, color: tint),
        child: LiquidGlassLite(
          shape: auroraRim(radius: radius),
          pickup: LiquidGlassPickup.blend,
          blendFloor: kRimFloor,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A button of the same material as [GlassPanel], at button size: a
/// filled shape with a rim around it, and a press that answers.
///
/// Give it a [label], an [icon], both, or a [child] of your own when the
/// content has to animate — the play/pause glyph on the player does.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    this.label,
    this.icon,
    this.child,
    this.onPressed,
    this.height = 44,
    this.width,
    this.radius = 22,
    this.tint = const Color(0x1FFFFFFF),
    this.foregroundColor = Colors.white,
    this.scale = 0.94,
  });

  final String? label;
  final IconData? icon;

  /// Replaces [label] and [icon] entirely.
  final Widget? child;

  final VoidCallback? onPressed;
  final double height;

  /// Null lets the button take the width it is given.
  final double? width;

  final double radius;
  final Color tint;
  final Color foregroundColor;

  /// How far the press shrinks it. A round button can take more than a
  /// wide one before the scale reads as a wobble.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final Widget content = child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) Icon(icon, size: 19, color: foregroundColor),
            if (icon != null && label != null) const SizedBox(width: 8),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: foregroundColor,
                ),
              ),
          ],
        );

    return Pressable(
      onTap: onPressed,
      scale: scale,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: AuroraFill(radius: radius, color: tint),
          child: LiquidGlassLite(
            shape: auroraRim(radius: radius, borderWidth: 0.8),
            pickup: LiquidGlassPickup.blend,
            blendFloor: kRimFloor,
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

/// The fill under a rim, on the rim's own outline.
///
/// `LiquidGlassLite` paints the rim and nothing else — the fill is the
/// caller's — and it lights that rim along the package's continuous
/// corner. A `BorderRadius` fill would leave a circular arc sitting
/// inside it at every corner, so the fill comes from the same path.
/// Painted rather than clipped: one `drawPath` under the child, no layer.
class AuroraFill extends CustomPainter {
  const AuroraFill({required this.radius, required this.color});

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
  bool shouldRepaint(AuroraFill oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}

/// Quieter still: a translucent fill with a hairline, and no rim. Rows,
/// list tiles and anything that repeats down a page use this — the rim
/// is what makes a `GlassPanel` read as a surface you could pick up, so
/// spending one on every row of a list is how a page stops having a
/// foreground.
class FrostPanel extends StatelessWidget {
  const FrostPanel({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.opacity = 1,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055 * opacity),
          borderRadius: BorderRadius.circular(radius),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.07 * opacity)),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// The quiet line above a section, and the optional link on its right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.eyebrow,
    this.action,
    this.onAction,
    this.accent = const Color(0xFF9E8CFF),
  });

  final String title;
  final String? eyebrow;
  final String? action;
  final VoidCallback? onAction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (eyebrow != null) ...<Widget>[
                  Text(eyebrow!.toUpperCase(), style: kEyebrow),
                  const SizedBox(height: 6),
                ],
                Text(
                  title,
                  style: kTitle.copyWith(fontSize: 20, letterSpacing: -0.4),
                ),
              ],
            ),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  action!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row of a track list: the number, the title, the run time.
class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.accent,
    this.playing = false,
    this.onTap,
  });

  final int index;
  final Track track;
  final Color accent;
  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 26,
              child: playing
                  ? Icon(Icons.graphic_eq_rounded, size: 16, color: accent)
                  : Text(
                      '${index + 1}',
                      style: kBody.copyWith(
                        color: const Color(0x66EDECF5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kTitle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: playing ? accent : kTitle.color,
                    ),
                  ),
                  if (track.plays.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text('${track.plays} plays',
                        style: kBody.copyWith(fontSize: 11.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(track.length,
                style: kBody.copyWith(
                    fontSize: 12.5, color: const Color(0x73EDECF5))),
          ],
        ),
      ),
    );
  }
}

/// A record in a list: art, title, artist.
class AlbumRow extends StatelessWidget {
  const AlbumRow({
    super.key,
    required this.album,
    this.trailing,
    this.onTap,
    this.artSize = 54,
  });

  final Album album;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double artSize;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: <Widget>[
          CoverArt(seed: album.seed, size: artSize, radius: 14),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 3),
                Text('${album.artist} · ${album.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kBody.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A small selectable chip. Not glass — there are usually six of them
/// in a row, and six lenses side by side is six reads of the backdrop.
class AuroraChip extends StatelessWidget {
  const AuroraChip({
    super.key,
    required this.label,
    required this.accent,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Color accent;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon,
                  size: 15, color: selected ? accent : const Color(0xB3EDECF5)),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? accent : const Color(0xCCEDECF5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A statistic: the number large and light, its name small and quiet.
class StatColumn extends StatelessWidget {
  const StatColumn(this.value, this.label, {super.key, this.accent});

  final String value;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(value,
            style: kDisplay.copyWith(
                fontSize: 26, color: accent ?? kDisplay.color)),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Tracking is what makes an eyebrow read as one; four of them
          // shoulder to shoulder is where it has to give a little.
          style: kEyebrow.copyWith(fontSize: 9, letterSpacing: 0.9),
        ),
      ],
    );
  }
}

// ── The tab contract ─────────────────────────────────────────

/// One destination in the shell.
///
/// A tab does not build a page — it hands the shell the two halves of
/// one: the light it is lit by ([palette], which becomes the captured
/// backdrop) and the [content] that floats over it. That split is the
/// whole reason the shell can own a single `LiquidGlassScaffold` while
/// five different screens pass through it, and it is what lets the tab
/// bar's pill keep travelling across a tab change instead of being
/// rebuilt with the page.
abstract class AuroraTab {
  const AuroraTab();

  /// Shown in the app bar.
  String get title;

  /// Shown in the tab bar.
  String get label;

  IconData get icon;

  AuroraPalette get palette;

  /// The floating layer: laid out full-screen, usually an [AuroraList].
  Widget content(BuildContext context);

  /// Trailing app-bar buttons, if the tab wants any.
  List<Widget> actions(BuildContext context) => const <Widget>[];
}

// ── Layout ───────────────────────────────────────────────────

/// Room the floating app bar needs above a page's first line.
const double kAuroraTopInset = 78;

/// Room the mini player and the tab bar need below its last one.
const double kAuroraBottomInset = 172;

/// The scroll view every tab's content is, with the chrome's clearances
/// already in it. A page passes children, not padding.
class AuroraList extends StatelessWidget {
  const AuroraList({
    super.key,
    required this.children,
    this.top = kAuroraTopInset,
    this.bottom = kAuroraBottomInset,
    this.horizontal = 20,
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
/// It goes into the `Overlay` rather than through `ScaffoldMessenger`,
/// because there is no `Scaffold` anywhere in this app — the pages are
/// `LiquidGlassScaffold`s, which own a capture pipeline rather than a
/// Material layout.
void showAuroraToast(BuildContext context, String message) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Toast(message: message));
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2100), () {
    if (entry.mounted) entry.remove();
  });
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message});

  final String message;

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
      bottom: MediaQuery.paddingOf(context).bottom + 130,
      child: IgnorePointer(
        child: AnimatedSlide(
          offset: _in ? Offset.zero : const Offset(0, 0.4),
          duration: const Duration(milliseconds: 320),
          curve: const Cubic(0.16, 1, 0.3, 1),
          child: AnimatedOpacity(
            opacity: _in ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            child: Center(
              child: LiquidGlassLens(
                style: auroraChrome(radius: 22),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  child: Text(widget.message,
                      style: kTitle.copyWith(fontSize: 14)),
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
Route<T> auroraRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, Animation<double> a, __, Widget child) {
      final Animation<double> eased =
          CurvedAnimation(parent: a, curve: const Cubic(0.16, 1, 0.3, 1));
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.06, end: 1).animate(eased),
          child: child,
        ),
      );
    },
  );
}
