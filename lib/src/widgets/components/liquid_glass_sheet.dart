import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../lens/liquid_glass_batch.dart';
import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';
import '../utils/liquid_glass_touch.dart';
import 'liquid_glass_scaffold.dart';

/// How a [LiquidGlassSheet] meets the bottom of the screen.
enum LiquidGlassSheetAnchor {
  /// An inset card: the sheet keeps a margin on all sides and rounds all
  /// four corners, so the page stays visible around it. The default.
  floating,

  /// A full-width panel sitting on the bottom edge. Only the top corners
  /// are visible — the glass is built taller than the sheet and the extra
  /// hangs off the screen, so the bottom corners are never seen and no
  /// sliver of page shows under the sheet.
  attached,
}

/// Presents [builder]'s content on a [LiquidGlassSheet].
///
/// This is Flutter's own `showModalBottomSheet` with the glass put where
/// its filled `Material` used to be: the route, the slide-up, the drag,
/// the barrier and the dismissal are all Flutter's, unchanged, and every
/// parameter of theirs is forwarded here. What the sheet *looks* like is
/// this package's — [style] is the same [LiquidGlassStyle] vocabulary
/// every other component takes.
///
/// ```dart
/// showLiquidGlassSheet<String>(
///   context: context,
///   header: const Padding(
///     padding: EdgeInsets.fromLTRB(20, 2, 20, 12),
///     child: Text('Share', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
///   ),
///   builder: (context) => Column(
///     mainAxisSize: MainAxisSize.min,
///     children: [ ... ],
///   ),
/// );
/// ```
///
/// Because it is the Material route underneath, everything you already
/// know about it holds: [isScrollControlled] for a sheet taller than
/// nine sixteenths of the screen, [constraints] to bound it,
/// [transitionAnimationController] to drive it yourself. For a sheet that
/// resizes as you drag it, put a `DraggableScrollableSheet` in a
/// `showModalBottomSheet` and place a bare [LiquidGlassSheet] inside
/// **its** builder — the glass has to be within what resizes, and this
/// presenter wraps your content from outside it.
///
/// **On the Skia / Web capture path**, a sheet builds in the navigator's
/// overlay rather than inside the `LiquidGlassView` that captured the
/// page. `showModalBottomSheet` carries the ambient themes across for
/// its own reasons, and the view's lens scope rides along with them, so
/// a sheet opened from a context **inside** a view refracts the page
/// behind it. Impeller never needed it.
///
/// **On Impeller** the sheet takes a backdrop read of its own, even inside
/// a `LiquidGlassScaffold`: the route sits outside the scaffold's tree,
/// where no batch reaches it. Pass [batch] to have it join the scaffold's
/// chrome batch instead — the read its tab bar's capsule already takes —
/// so the sheet costs no read beyond that one. The batch then covers the
/// whole sheet, its own glass and every lens in [builder]'s subtree alike,
/// and the copy they all sample was taken before the tab bar and the route
/// painted: the sheet refracts the page as it lay under the bar, with no
/// tab bar glass in it and no barrier scrim, and glass **inside** the sheet
/// reads that page rather than the sheet's surface; wrap it in
/// `LiquidGlassBatch.exclude` to get that back. Outside a scaffold, or
/// with the scaffold's `batch` off, the flag does nothing. On the Skia /
/// Web capture path there is no shared key and it does nothing either.
Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  LiquidGlassStyle? style,
  LiquidGlassSheetAnchor anchor = LiquidGlassSheetAnchor.floating,
  Widget? header,
  bool grabber = true,
  Color? grabberColor,
  EdgeInsets? margin,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 4, 20, 20),
  Color? foregroundColor,
  bool avoidKeyboard = true,
  LiquidGlassTouch? touch,
  bool batch = false,
  Color? barrierColor,
  String? barrierLabel,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  BoxConstraints? constraints,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
}) {
  // Asked to, and presented from inside a LiquidGlassScaffold, the sheet
  // joins the scaffold's chrome batch — the read its tab bar takes — so it
  // costs no read of its own. See `LiquidGlassScaffold.batch`.
  final int? batchId =
      batch ? LiquidGlassScaffold.chromeBatchIdOf(context) : null;
  return showModalBottomSheet<T>(
    context: context,
    // The glass is the surface, so Material's is given nothing to draw:
    // no fill, no tint, no elevation shadow, and no clip of its own —
    // the lens clips to its own outline, and an attached sheet needs to
    // paint past its box.
    backgroundColor: Colors.transparent,
    elevation: 0,
    clipBehavior: Clip.none,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    isScrollControlled: isScrollControlled,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    constraints: constraints,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    builder: (BuildContext context) {
      Widget sheet = LiquidGlassSheet(
        header: header,
        anchor: anchor,
        grabber: grabber,
        grabberColor: grabberColor,
        margin: margin,
        padding: padding,
        style: style,
        foregroundColor: foregroundColor,
        touch: touch,
        child: builder(context),
      );
      if (batchId != null) {
        sheet = LiquidGlassBatchScope(backdropId: batchId, child: sheet);
      }
      if (!avoidKeyboard) return sheet;
      // The route does not lift for the keyboard on its own. This is the
      // padding you would otherwise write in every builder, and it only
      // has room to work with `isScrollControlled: true`.
      return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: sheet,
      );
    },
  );
}

/// A sheet of liquid glass — the panel [showLiquidGlassSheet] presents,
/// and an ordinary widget you can place yourself.
///
/// It draws the surface and nothing else: the glass, an optional
/// [grabber], an optional [header] and the padded [child]. Where it sits
/// and how it is dragged belong to whatever presents it.
///
/// The sheet takes the height it is given and hugs its content when it is
/// given none, so all of these work:
///
/// ```dart
/// // A panel pinned to the bottom of a page.
/// Align(
///   alignment: Alignment.bottomCenter,
///   child: LiquidGlassSheet(child: myControls),
/// )
///
/// // The same surface, presented as a modal.
/// showLiquidGlassSheet(context: context, builder: (context) => myControls);
///
/// // Or inside anything else that owns the motion.
/// showModalBottomSheet(
///   context: context,
///   backgroundColor: Colors.transparent,
///   isScrollControlled: true,
///   builder: (context) => DraggableScrollableSheet(
///     expand: false,
///     initialChildSize: 0.5,
///     builder: (context, scrollController) => LiquidGlassSheet(
///       child: ListView(controller: scrollController, children: [...]),
///     ),
///   ),
/// );
/// ```
///
/// On Impeller it works standalone; on Skia / Web it needs an ancestor
/// `LiquidGlassView` with a background to refract.
class LiquidGlassSheet extends StatelessWidget {
  const LiquidGlassSheet({
    super.key,
    required this.child,
    this.header,
    this.anchor = LiquidGlassSheetAnchor.floating,
    this.grabber = true,
    this.grabberColor,
    this.grabberSize = const Size(38, 5),
    this.margin,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 20),
    this.style,
    this.visibility = true,
    this.foregroundColor,
    this.safeArea = true,
    this.touch,
  });

  /// The sheet's content. Give it a scrollable and the sheet fills the
  /// height it was handed; give it a `Column` and it hugs it.
  final Widget child;

  /// Optional widget between the grabber and [child], laid out full
  /// width with no padding of its own — a title row, a segmented
  /// control, a search field. It is outside [padding], so pad it
  /// yourself if it should line up with the content.
  final Widget? header;

  /// Whether the sheet is inset on all sides or sits on the bottom edge.
  final LiquidGlassSheetAnchor anchor;

  /// Whether the small drag handle is drawn at the top of the sheet.
  final bool grabber;

  /// Color of the grabber. When null it is the resolved foreground at
  /// 35% alpha, so it follows an adaptive flip with the rest.
  final Color? grabberColor;

  /// Size of the grabber bar. Its height also sets its corner radius.
  final Size grabberSize;

  /// Space around the glass. When null it is derived from [anchor]:
  /// `10` on the sides and below for a [LiquidGlassSheetAnchor.floating]
  /// sheet (the bottom growing to clear the home indicator when
  /// [safeArea] is set), and nothing at all for an attached one.
  final EdgeInsets? margin;

  /// Padding around [child] inside the glass.
  final EdgeInsetsGeometry padding;

  /// The sheet's glass look as one [LiquidGlassStyle] (shape +
  /// appearance + refraction). When null the tuned [defaultStyle] is
  /// used; anything you pass is merged over it, so one facet changes
  /// without retyping the rest. A null `shape` derives a continuous
  /// rounded rectangle with an optical rim.
  final LiquidGlassStyle? style;

  /// Whether the glass is shown; toggling animates it in/out.
  final bool visibility;

  /// Color of bare `Icon`s and `Text` inside the sheet.
  ///
  /// **Adaptivity outranks this.** On an adaptive surface the color comes
  /// from the verdict, whatever is named here. Opt the surface out with
  /// `adaptivity: LiquidGlassAdaptivity.none` to pin a color on it.
  ///
  /// `null` (the default) is white on a non-adaptive surface.
  final Color? foregroundColor;

  /// Whether the sheet keeps clear of the system insets — the bottom
  /// margin of a floating sheet grows to clear the home indicator, and an
  /// attached sheet pads its content by the same amount.
  final bool safeArea;

  /// How the surface answers a finger — see [LiquidGlassTouch]. A sheet
  /// is a large body, so it ships rigid; prefer a restrained spec such as
  /// `LiquidGlassFlex.subtle` if you enable it.
  final LiquidGlassTouch? touch;

  static const LiquidGlassAppearance _defaultAppearance = LiquidGlassAppearance(
    color: Color(0x24FFFFFF), // white, alpha 36
    blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
  );

  static const LiquidGlassRefraction _defaultRefraction = LiquidGlassRefraction(
    distortion: 0.12,
    distortionWidth: 40,
    chromaticAberration: 0.002,
  );

  /// The tuned default look — a frost heavier than the button's, because
  /// a sheet has to carry content over whatever it covers, over a wide,
  /// soft refraction. Its `shape` is `null`: the sheet derives a
  /// continuous rounded rectangle (radius `28`) with an optical rim when
  /// [style] supplies no shape. Compose with `copyWith` to tweak one
  /// facet, e.g. `style: LiquidGlassSheet.defaultStyle.copyWith(...)`.
  static const LiquidGlassStyle defaultStyle = LiquidGlassStyle(
    appearance: _defaultAppearance,
    refraction: _defaultRefraction,
  );

  /// The shape a sheet uses when its style names none.
  static LiquidGlassShape defaultShape() =>
      LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 28,
        borderWidth: 0.6,
        lightIntensity: 1.2,
        lightDirection: 39,
        borderType: const OpticalBorder(
          borderSaturation: 1.3,
          ambientIntensity: 1.0,
          borderSolidity: 0.4,
        ),
      );

  /// The margin [anchor] implies when none is given.
  static EdgeInsets defaultMargin(
    LiquidGlassSheetAnchor anchor, {
    double bottomInset = 0,
  }) {
    if (anchor == LiquidGlassSheetAnchor.attached) return EdgeInsets.zero;
    return EdgeInsets.fromLTRB(10, 0, 10, bottomInset > 10 ? bottomInset : 10);
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle resolved = defaultStyle.merge(style);
    final LiquidGlassShape shape = resolved.shape ?? defaultShape();
    final double bottomInset =
        safeArea ? MediaQuery.viewPaddingOf(context).bottom : 0;
    final EdgeInsets effectiveMargin =
        margin ?? defaultMargin(anchor, bottomInset: bottomInset);
    // An attached sheet is built taller than it is and lets the extra
    // hang off the screen, so its bottom corners are never in frame.
    final double overhang =
        anchor == LiquidGlassSheetAnchor.attached ? shape.cornerRadius : 0;
    final EdgeInsets contentSafeArea =
        anchor == LiquidGlassSheetAnchor.attached && safeArea
            ? EdgeInsets.only(bottom: bottomInset)
            : EdgeInsets.zero;

    return Padding(
      padding: effectiveMargin,
      child: _BottomOverhang(
        overhang: overhang,
        child: LiquidGlassLens(
          touch: touch,
          visibility: visibility,
          style: LiquidGlassStyle(
            shape: shape,
            appearance: resolved.appearance,
            refraction: resolved.refraction,
            adaptivity: resolved.adaptivity,
            liteGlass: resolved.liteGlass,
          ),
          // Below the lens, so the adaptive content color it installs is
          // in scope, and read here rather than inherited because the
          // Material underneath overwrites the ambient DefaultTextStyle.
          child: Builder(builder: (context) {
            final Color foreground =
                foregroundColor ?? IconTheme.of(context).color ?? Colors.white;
            return Material(
              color: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.only(bottom: overhang) + contentSafeArea,
                child: _body(foreground),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _body(Color foreground) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Widget content = Padding(padding: padding, child: child);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (grabber)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Center(
                  child: Container(
                    width: grabberSize.width,
                    height: grabberSize.height,
                    decoration: BoxDecoration(
                      color: grabberColor ?? foreground.withValues(alpha: 0.35),
                      borderRadius:
                          BorderRadius.circular(grabberSize.height / 2),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 10),
            if (header != null) header!,
            // A sheet given a height hands the rest of it to the content
            // (so a list fills it); one that was given none hugs it, and
            // a flexible child there would have nothing to resolve
            // against.
            if (constraints.hasBoundedHeight)
              Flexible(child: content)
            else
              content,
          ],
        );
      },
    );
  }
}

/// Lays its child out [overhang] taller than the box it reports, so the
/// extra hangs below unclipped. Used by an attached sheet to push its
/// bottom corners off the screen.
class _BottomOverhang extends SingleChildRenderObjectWidget {
  const _BottomOverhang({required this.overhang, required super.child});

  final double overhang;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBottomOverhang(overhang);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderBottomOverhang).overhang = overhang;
  }
}

class _RenderBottomOverhang extends RenderShiftedBox {
  _RenderBottomOverhang(this._overhang) : super(null);

  double _overhang;
  double get overhang => _overhang;
  set overhang(double value) {
    if (value == _overhang) return;
    _overhang = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
      minHeight: constraints.minHeight + _overhang,
      maxHeight: constraints.maxHeight.isFinite
          ? constraints.maxHeight + _overhang
          : double.infinity,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.smallest;
    final Size size = child.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(Size(size.width, size.height - _overhang));
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints
        .constrain(Size(child.size.width, child.size.height - _overhang));
    (child.parentData! as BoxParentData).offset = Offset.zero;
  }
}
