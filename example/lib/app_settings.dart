import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Whether the gallery paints itself dark.
///
/// The Settings page flips it with a glass switch; the gallery's
/// [MaterialApp] rebuilds from it, so every demo opened from the menu
/// inherits the brightness through `Theme.of(context)` without knowing
/// this notifier exists.
///
/// Lives in its own file so a page can read or flip it without importing
/// the gallery that imports the page.
final ValueNotifier<bool> darkMode = ValueNotifier<bool>(true);

/// Whether every lens in the gallery draws lite glass — frost, tint and rim,
/// no shader and no capture — on whichever engine the app is on.
///
/// Flipping it sets both `LiquidGlassEngine` switches; the gallery's
/// [MaterialApp] rebuilds from it too, so a page already on screen redraws
/// its lenses instead of waiting to be reopened.
final ValueNotifier<bool> liteGlass = ValueNotifier<bool>(false)
  ..addListener(() {
    LiquidGlassEngine.liteGlassOnSkia = liteGlass.value;
    LiquidGlassEngine.liteGlassOnImpeller = liteGlass.value;
  });

/// The gallery's page backdrop for [brightness]: a deep violet wash in the
/// dark, the same hue bleached to near-paper in the light.
///
/// Shared by the home menu and the Settings page so the two read as one
/// surface when you push between them.
LinearGradient galleryBackground(Brightness brightness) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brightness == Brightness.dark
        ? const [Color(0xFF0B0A12), Color(0xFF17112E), Color(0xFF241543)]
        : const [Color(0xFFF7F6FB), Color(0xFFEFE9FB), Color(0xFFE6DDF7)],
  );
}

/// The theme every demo page is opened under.
///
/// Lives here rather than in the gallery because the pages are opened
/// from more than one place — the gallery, a standalone `-t` entry
/// point, the docs-site build — and a page that looks different
/// depending on who pushed it is a page nobody can check.
ThemeData galleryTheme(Brightness brightness) => ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C5CFF),
        brightness: brightness,
      ),
      useMaterial3: true,
    );
