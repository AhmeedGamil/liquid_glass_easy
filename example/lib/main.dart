import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'apple_match_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Compile the glass programs before the first frame.
  await LiquidGlassShaders.ensureLoaded();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Apple Match',
      theme: appleMatchTheme(Brightness.light),
      darkTheme: appleMatchTheme(Brightness.dark),
      home: const AppleMatchPage(),
    );
  }
}
