import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shell.dart';

// =============================================================
// Aurora — a small music app built entirely on liquid_glass_easy.
//
// Eight pages: five tabs (Home, Browse, Search, Library, You) and three
// pushed on top of them (an album, the player, settings). Nothing is
// downloaded — every backdrop and every cover is painted from a seed
// string, so it runs offline and every record has its own colour.
//
//   flutter run -t lib/aurora/main.dart
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  runApp(const AuroraApp());
}
