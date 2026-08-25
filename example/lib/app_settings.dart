import 'package:flutter/material.dart';

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
