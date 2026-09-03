import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shell.dart';

// =============================================================
// Vitrine — a shop built entirely on liquid_glass_easy.
//
// Nine pages: five tabs (Shop, Browse, Search, Saved, Bag) and four
// pushed over them (a product, a collection, a shelf, checkout, and the
// account). Nothing is downloaded — every object in the catalogue is
// drawn from a hue and a silhouette, so it runs offline and every
// product arrives in its own colour.
//
// It is a LIGHT app, which is the point of it: Aurora is the same
// package over a near-black page, and almost every decision here had to
// go the other way. See the README next to this file.
//
//   flutter run -t lib/vitrine/main.dart
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // Dark glyphs: the status bar spends its life over a mid-tone plate
    // or over paper, and both take dark type better than light.
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const VitrineApp());
}
