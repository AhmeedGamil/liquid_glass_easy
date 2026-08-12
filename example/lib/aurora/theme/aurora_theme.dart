import 'package:flutter/material.dart';

import 'aurora_palette.dart';

/// App-wide preferences the user can change at runtime.
///
/// One notifier drives the whole app: flipping [mode] or [accent] here
/// rebuilds the `MaterialApp`, so every page — including the pages the
/// navigator is holding underneath — repaints in the new theme.
class AuroraController extends ChangeNotifier {
  ThemeMode _mode;
  Color _accent;
  bool _reduceMotion;

  AuroraController({
    ThemeMode mode = ThemeMode.dark,
    Color accent = const Color(0xFF6D5BFF),
    bool reduceMotion = false,
  })  : _mode = mode,
        _accent = accent,
        _reduceMotion = reduceMotion;

  ThemeMode get mode => _mode;
  set mode(ThemeMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  Color get accent => _accent;
  set accent(Color value) {
    if (_accent == value) return;
    _accent = value;
    notifyListeners();
  }

  /// When set, the ambient animations (aurora drift, particles, visualizers)
  /// hold still. Everything stays laid out exactly the same.
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
  }

  /// The accents offered by the settings page.
  static const List<Color> accents = [
    Color(0xFF6D5BFF),
    Color(0xFF00C2A8),
    Color(0xFFFF6B8B),
    Color(0xFFFF9F0A),
    Color(0xFF2E8BFF),
    Color(0xFFB05CFF),
  ];

  /// Cycles dark → light → system → dark.
  void cycleMode() {
    mode = switch (_mode) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
      ThemeMode.system => ThemeMode.dark,
    };
  }

  /// Flips straight between light and dark, resolving `system` first.
  void toggleBrightness(Brightness current) =>
      mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
}

/// Hands the resolved [AuroraPalette] and the [AuroraController] to the
/// whole subtree.
class AuroraTheme extends InheritedWidget {
  final AuroraPalette palette;
  final AuroraController controller;

  const AuroraTheme({
    super.key,
    required this.palette,
    required this.controller,
    required super.child,
  });

  static AuroraTheme _scope(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuroraTheme>();
    assert(scope != null, 'No AuroraTheme above this widget.');
    return scope!;
  }

  static AuroraPalette of(BuildContext context) => _scope(context).palette;

  static AuroraController controllerOf(BuildContext context) =>
      _scope(context).controller;

  @override
  bool updateShouldNotify(AuroraTheme oldWidget) =>
      oldWidget.palette != palette || oldWidget.controller != controller;
}

/// `context.palette` reads better than `AuroraTheme.of(context)` at the
/// three-hundredth call site.
extension AuroraThemeContext on BuildContext {
  AuroraPalette get palette => AuroraTheme.of(this);
  AuroraController get auroraController => AuroraTheme.controllerOf(this);
}

/// Builds the Material theme that matches [palette] — mostly so stock
/// widgets (dialogs, ripples, text fields) don't fight the palette.
ThemeData auroraThemeData(AuroraPalette palette) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: palette.brightness,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: palette.canvas.first,
    canvasColor: palette.canvas.first,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ),
    iconTheme: IconThemeData(color: palette.textPrimary),
    dividerColor: palette.stroke,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// The type ramp. Declared once so headings match across twelve pages.
class AuroraText {
  const AuroraText._();

  static TextStyle display(AuroraPalette p) => TextStyle(
        color: p.textPrimary,
        fontSize: 38,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
      );

  static TextStyle title(AuroraPalette p) => TextStyle(
        color: p.textPrimary,
        fontSize: 24,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  static TextStyle section(AuroraPalette p) => TextStyle(
        color: p.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle body(AuroraPalette p) => TextStyle(
        color: p.textSecondary,
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w500,
      );

  static TextStyle label(AuroraPalette p) => TextStyle(
        color: p.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  static TextStyle caps(AuroraPalette p) => TextStyle(
        color: p.textFaint,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      );

  /// Tabular figures for anything that counts up or ticks.
  static TextStyle numeric(AuroraPalette p, {double size = 30}) => TextStyle(
        color: p.textPrimary,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
