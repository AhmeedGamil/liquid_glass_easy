import 'package:flutter/widgets.dart';

/// Screen size class, resolved from the width the widget is actually given.
///
/// Deliberately read from a `LayoutBuilder`'s constraints rather than from
/// `MediaQuery.sizeOf` wherever a demo is framed: inside the desktop device
/// frame the window is wide but the demo is not, and the demo must lay out
/// for the box it is in.
enum ScreenClass {
  /// Phones and narrow browser windows: one column, full-bleed demos.
  compact,

  /// Tablets and small laptops: still one column, but with room to breathe.
  medium,

  /// Desktop: demos sit in a device frame with prose beside them.
  expanded;

  static ScreenClass of(double width) => width < 720
      ? ScreenClass.compact
      : (width < 1180 ? ScreenClass.medium : ScreenClass.expanded);

  bool get isCompact => this == ScreenClass.compact;
  bool get isExpanded => this == ScreenClass.expanded;

  /// Whether a demo is shown inside a phone-shaped frame. These are mobile
  /// UIs; stretching a bottom nav bar across 1900px reads as broken, not as
  /// responsive.
  bool get framesDemos => !isCompact;

  /// Picks one of three values for this size class.
  T pick<T>({required T compact, required T medium, required T expanded}) =>
      switch (this) {
        ScreenClass.compact => compact,
        ScreenClass.medium => medium,
        ScreenClass.expanded => expanded,
      };
}

/// [ScreenClass] for the nearest enclosing `MediaQuery` — the window, or the
/// device frame's own size once [DemoFrame] has overridden it.
ScreenClass screenClassOf(BuildContext context) =>
    ScreenClass.of(MediaQuery.sizeOf(context).width);

/// Horizontal page padding that keeps text readable at any width.
double pagePadding(ScreenClass s) =>
    s.pick(compact: 20, medium: 32, expanded: 40);
