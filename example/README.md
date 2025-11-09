
# liquid_glass_easy_example

This example demonstrates how to use `LiquidGlassView` and a single `LiquidGlass` lens.

## Features
- Realtime capture ON by default
- Two buttons at the bottom:
  - **Refresh Snapshot** (captures one frame cleanly)
  - **Next Background** (cycles between gradient backgrounds)
- Clean light theme

## Run
```bash
cd example
flutter run
```

## Using Images Later (Optional)
If you prefer images:
1. Add your files under `example/assets/` (e.g., `forest.jpg`, `mountain.jpg`, `waterfall.jpg`)
2. Uncomment the `assets:` section in `example/pubspec.yaml`
3. Replace `_buildBackground()` in `main.dart` with `Image.asset(..., fit: BoxFit.cover)`
