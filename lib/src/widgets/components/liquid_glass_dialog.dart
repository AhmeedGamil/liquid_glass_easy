import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// Displays a liquid glass dialog over the current route.
///
/// Uses [showGeneralDialog] with a tuned scale + fade modal animation
/// to present [LiquidGlassAlertDialog] or custom [LiquidGlassDialog] widgets.
///
/// ```dart
/// showLiquidGlassDialog(
///   context: context,
///   builder: (context) => LiquidGlassAlertDialog(
///     title: const Text('Delete Item?'),
///     content: const Text('This action cannot be undone.'),
///     actions: [
///       LiquidGlassButton(
///         label: 'Cancel',
///         onPressed: () => Navigator.of(context).pop(),
///       ),
///       LiquidGlassButton(
///         label: 'Delete',
///         style: LiquidGlassButton.defaultStyle.copyWith(
///           appearance: const LiquidGlassAppearance(color: Color(0x60FF3B30)),
///         ),
///         onPressed: () => Navigator.of(context).pop(true),
///       ),
///     ],
///   ),
/// );
/// ```
Future<T?> showLiquidGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x80000000),
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  Duration transitionDuration = const Duration(milliseconds: 350),
  Curve transitionCurve = const Cubic(0.16, 1.0, 0.3, 1.0),
  Curve reverseTransitionCurve = const Cubic(0.7, 0.0, 0.84, 0.0),
}) {
  assert(debugCheckHasMaterialLocalizations(context));

  final CapturedThemes themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(
      context,
      rootNavigator: useRootNavigator,
    ).context,
  );

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    transitionDuration: transitionDuration,
    pageBuilder: (buildContext, animation, secondaryAnimation) {
      final Widget page = builder(buildContext);
      Widget dialog = themes.wrap(page);
      if (useSafeArea) {
        dialog = SafeArea(child: dialog);
      }
      return dialog;
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final CurvedAnimation curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: transitionCurve,
        reverseCurve: reverseTransitionCurve,
      );

      // Scale only — deliberately no Fade/Opacity around the dialog. An
      // Opacity layer isolates the lenses' backdrop, so the glass loses
      // the page behind it mid-flight (no frost, dark buttons) and snaps
      // in when the layer drops. The barrier fades on its own; the glass
      // condenses over it by scale alone, live the whole way.
      return ScaleTransition(
        scale: Tween<double>(begin: 0.84, end: 1.0).animate(curvedAnimation),
        child: child,
      );
    },
  );
}

/// A generic dialog container rendered as a liquid glass surface.
class LiquidGlassDialog extends StatelessWidget {
  /// Custom inner content widget.
  final Widget child;

  /// Maximum width of the dialog card.
  final double width;

  /// Inner padding surrounding the child.
  final EdgeInsetsGeometry padding;

  /// Glass style (shape + appearance + refraction).
  final LiquidGlassStyle? style;

  /// Whether the dialog lens is visible.
  final bool visibility;

  /// Alignment of the dialog on screen.
  final AlignmentGeometry alignment;

  static const LiquidGlassAppearance _defaultAppearance = LiquidGlassAppearance(
    color: Color(0x28FFFFFF), // white frost, alpha 40
    blur: LiquidGlassBlur(sigmaX: 8, sigmaY: 8),
  );

  static const LiquidGlassRefraction _defaultRefraction = LiquidGlassRefraction(
    distortion: 0.08,
    distortionWidth: 36,
    chromaticAberration: 0.002,
  );

  /// Default glass look for dialogs.
  static const LiquidGlassStyle defaultStyle = LiquidGlassStyle(
    appearance: _defaultAppearance,
    refraction: _defaultRefraction,
  );

  const LiquidGlassDialog({
    super.key,
    required this.child,
    this.width = 340.0,
    this.padding = const EdgeInsets.all(24.0),
    this.style,
    this.visibility = true,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle resolved = defaultStyle.merge(style);
    final LiquidGlassShape effectiveShape = resolved.shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: 28,
          borderWidth: 1.2,
          lightIntensity: 1.2,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.3,
            ambientIntensity: 1.0,
            borderSolidity: 0.4,
          ),
        );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: LiquidGlassLens(
          style: LiquidGlassStyle(
            shape: effectiveShape,
            appearance: resolved.appearance,
            refraction: resolved.refraction,
          ),
          visibility: visibility,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: padding,
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An alert dialog rendered with a liquid glass surface.
///
/// Features standard Material 3 dialog slots (`icon`, `title`, `content`, `actions`)
/// elevated on top of a frosted refractive liquid glass lens.
class LiquidGlassAlertDialog extends StatelessWidget {
  /// Optional leading icon above the title.
  final Widget? icon;

  /// Icon color if a plain Icon is provided.
  final Color? iconColor;

  /// Padding around the icon.
  final EdgeInsetsGeometry iconPadding;

  /// Title widget (or Text).
  final Widget? title;

  /// Padding around the title.
  final EdgeInsetsGeometry titlePadding;

  /// Default text style for title.
  final TextStyle? titleTextStyle;

  /// Content widget (body).
  final Widget? content;

  /// Padding around content widget.
  final EdgeInsetsGeometry contentPadding;

  /// Default text style for content.
  final TextStyle? contentTextStyle;

  /// List of action widgets (e.g. [LiquidGlassButton] or standard buttons).
  final List<Widget>? actions;

  /// Padding around action buttons row/column.
  final EdgeInsetsGeometry actionsPadding;

  /// Horizontal alignment of actions.
  final MainAxisAlignment actionsAlignment;

  /// Overflow alignment when actions do not fit horizontally.
  final OverflowBarAlignment actionsOverflowAlignment;

  /// Direction of actions when overflowing.
  final VerticalDirection actionsOverflowDirection;

  /// Spacing between action buttons when overflowing.
  final double? actionsOverflowButtonSpacing;

  /// Glass style descriptor.
  final LiquidGlassStyle? style;

  /// Dialog max width.
  final double width;

  /// Whether title and content should be scrollable.
  final bool scrollable;

  /// Whether the dialog lens is visible.
  final bool visibility;

  const LiquidGlassAlertDialog({
    super.key,
    this.icon,
    this.iconColor,
    this.iconPadding = const EdgeInsets.only(bottom: 16.0),
    this.title,
    this.titlePadding = const EdgeInsets.only(bottom: 12.0),
    this.titleTextStyle,
    this.content,
    this.contentPadding = const EdgeInsets.only(bottom: 24.0),
    this.contentTextStyle,
    this.actions,
    this.actionsPadding = EdgeInsets.zero,
    this.actionsAlignment = MainAxisAlignment.end,
    this.actionsOverflowAlignment = OverflowBarAlignment.end,
    this.actionsOverflowDirection = VerticalDirection.down,
    this.actionsOverflowButtonSpacing,
    this.style,
    this.width = 340.0,
    this.scrollable = false,
    this.visibility = true,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final TextStyle effectiveTitleStyle = titleTextStyle ??
        theme.textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );

    final TextStyle effectiveContentStyle = contentTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withAlpha(220),
          fontSize: 14.5,
          height: 1.4,
        ) ??
        TextStyle(
          color: Colors.white.withAlpha(220),
          fontSize: 14.5,
          height: 1.4,
        );

    Widget dialogContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (icon != null)
          Padding(
            padding: iconPadding,
            child: IconTheme.merge(
              data: IconThemeData(
                color: iconColor ?? Colors.white,
                size: 28.0,
              ),
              child: Center(child: icon),
            ),
          ),
        if (title != null)
          Padding(
            padding: titlePadding,
            child: DefaultTextStyle(
              style: effectiveTitleStyle,
              textAlign: icon == null ? TextAlign.start : TextAlign.center,
              child: title!,
            ),
          ),
        if (content != null)
          Padding(
            padding: contentPadding,
            child: DefaultTextStyle(
              style: effectiveContentStyle,
              textAlign: icon == null ? TextAlign.start : TextAlign.center,
              child: content!,
            ),
          ),
        if (actions != null && actions!.isNotEmpty)
          Padding(
            padding: actionsPadding,
            child: OverflowBar(
              alignment: actionsAlignment,
              overflowAlignment: actionsOverflowAlignment,
              overflowDirection: actionsOverflowDirection,
              overflowSpacing: actionsOverflowButtonSpacing ?? 8.0,
              spacing: 12.0,
              children: actions!,
            ),
          ),
      ],
    );

    if (scrollable) {
      dialogContent = SingleChildScrollView(child: dialogContent);
    }

    return LiquidGlassDialog(
      width: width,
      style: style,
      visibility: visibility,
      child: dialogContent,
    );
  }
}
