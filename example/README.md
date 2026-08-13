# liquid_glass_easy — example

This folder has two entry points:

- **`lib/main.dart`** — a minimal, self-contained example: one `LiquidGlassLens`
  over a background. Its only import is the package, so you can copy it straight
  into a fresh Flutter project and run it.
- **`lib/gallery.dart`** — the full on-device gallery whose home menu opens each
  demo (control center, scaffold + glass nav, slider & toggle, corner styles,
  plus motion tuners) on its own page. This is what the README screenshots/GIFs
  come from.

## Run

```bash
cd example
flutter pub get

flutter run                       # minimal example (lib/main.dart)
flutter run -t lib/gallery.dart   # full demo gallery
```

## Minimal example

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Anything you want refracted behind the glass.
            Image.network('https://picsum.photos/800/1600', fit: BoxFit.cover),
            Center(
              child: SizedBox(
                width: 260,
                height: 150,
                child: LiquidGlassLens(
                  style: const LiquidGlassStyle(
                    shape: LiquidGlassShape.squircle(cornerRadius: 44),
                    refraction: LiquidGlassRefraction(
                      distortion: 0.13,
                      distortionWidth: 34,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Liquid Glass',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

> On the Skia engine, wrap your UI in a `LiquidGlassView` (with a
> `backgroundWidget`) so the lens has a background to refract — on Impeller no
> view is needed. See the package
> [README](https://pub.dev/packages/liquid_glass_easy) for the full API.
