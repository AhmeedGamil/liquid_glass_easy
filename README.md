# Liquid Glass Easy

<p>
  🤝 <strong>Contributions are welcome!</strong>
</p>

**A Flutter package that adds real-time, interactive liquid glass lenses.**
These dynamic lenses can **magnify**, **distort**, **blur**, **tint**, and **refract** underlying content — creating stunning, glass-like effects that respond fluidly to **movement** and **touch**.

<p>
  <img src="showcases/liquid_glass_example_1.gif" width="60%" alt="LiquidGlass Example"/>
</p>

---

## Why LiquidGlassEffect?

Unlike traditional glassmorphism or static blur effects, **LiquidGlassEasy** simulates *real glass physics* — complete with **refraction, distortion, and fluid responsiveness**.
It captures and refracts live background content in real time, producing **immersive, motion-reactive visuals** that bring depth and realism to your UI.

---

## Features

- 💠 **True liquid glass visuals** — replicate the look and physics of real glass with fluid transparency, soft highlights, and refraction that bends light naturally through your UI.
- 🌀 **Real-time lens rendering** — see distortion, blur, tint, and refraction react instantly as elements move behind the glass.
- 🎨 **Custom shapes** — design lenses as rounded rectangles, circles, or smooth superellipses that perfectly match your interface style.
- 🌈 **Fully customizable effects** — control tint color, intensity, softness, refraction depth, and light direction for precise glass behavior.
- 🧠 **Controller-driven animations** — show, hide, or animate lenses in real time through the `LiquidGlassController`.
- ⚙️ **Shader-driven, GPU-accelerated pipeline** — ensures smooth, high-FPS performance even with multiple dynamic lenses.
- 📱 **Cross-platform compatibility** — works seamlessly on Android, iOS, Web, macOS, and Windows.

---

## Installation

Add the dependency:

```yaml
dependencies:
  liquid_glass_easy: ^1.0.0
```

Then run:
```bash
flutter pub get
```

---

## Getting Started

Use the `LiquidGlassExample` widget found in the `example/` directory for a quick preview.
You can also try:
- `LiquidGlassShowcase` — a comprehensive demo widget that lets you explore all Liquid Glass Easy capabilities interactively. Adjust parameters such as distortion, blur, magnification, lighting, and border style in real time using intuitive sliders and toggles.
- `LiquidGlassPlayground` — an experimental environment where you can test your own widgets beneath a live liquid glass lens. Fine-tune visual parameters with built-in controls to instantly see how the effect adapts to different content and layouts.

<p>
  <img src="showcases/liquid_glass_example_4.gif" width="40%" alt="LiquidGlass Example"/>
</p>

> ⚠️ **Important Note:**  
> The `LiquidGlassShowcase` and `LiquidGlassPlayground` widgets are designed only for **previewing and copying slider values**.
>
> They are **not intended for performance benchmarking**, because the `backgroundWidget` is rendered at **half the screen height**, while the other half is used for sliders.
>
> For **accurate performance testing**, use the `LiquidGlassView` directly without these preview widgets.

**Basic setup with one lens:**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

class DemoGlass extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: Image.asset('assets/bg.jpg', fit: BoxFit.cover),
        children: [
          LiquidGlass(
            width: 200,
            height: 100,
            magnification: 1,
            distortion: 0.2,
            distortionWidth: 50,
            position: LiquidGlassAlignPosition(alignment: Alignment.center),
          ),
        ],
      ),
    );
  }
}
```

---

## Common Use Cases

### Multiple Lenses
```dart
LiquidGlassView(
  backgroundWidget: YourBackground(),
  children: [
    LiquidGlass(
      width: 160,
      height: 160,
      distortion: 0.3,
      distortionWidth: 50,
      position: LiquidGlassOffsetPosition(left: 40, top: 100),
    ),
    LiquidGlass(
      width: 220,
      height: 120,
      distortion: 0.15,
      magnification: 1,
      distortionWidth: 40,
      position: LiquidGlassAlignPosition(alignment: Alignment.bottomRight),
      blur: LiquidGlassBlur(sigmaX: 1, sigmaY: 1),
      color: Colors.white30,
    ),
  ],
);
```

### Draggable Lens

<p>
  <img src="showcases/liquid_glass_example_2.gif" width="60%" alt="LiquidGlass Example"/>
</p>

```dart
LiquidGlass(
  draggable: true,
  width: 200,
  height: 120,
  position: LiquidGlassAlignPosition(alignment: Alignment.center),
)
```

### Lens with Overlay Content
```dart
LiquidGlass(
  width: 200,
  height: 120,
  position: LiquidGlassAlignPosition(alignment: Alignment.center),
  child: Center(child: Icon(Icons.search, color: Colors.white)),
)
```

### ⚠️ Important Note

The child widget inside `LiquidGlass` always takes the **full size of the lens**.

If you want to reduce the child’s visible area, wrap it with your own `Padding`:

```dart
LiquidGlass(
  child: Padding(
           padding: EdgeInsets.all(12),
           child: YourWidget(),
  ),
)
```

---

## Positions & Shapes

<p>
  <img src="showcases/liquid_glass_example_3.gif" width="60%" alt="LiquidGlass Example"/>
</p>

### Position Types
| Class | Description |
|--------|-------------|
| `LiquidGlassOffsetPosition` | Uses pixel offsets: `left`, `top`, `right`, `bottom`. |
| `LiquidGlassAlignPosition` | Uses `alignment` with optional `margin`. |

### Shape Types
| Class | Description |
|--------|-------------|
| `RoundedRectangleShape` | Use `cornerRadius`. |
| `SuperellipseShape` | Use `curveExponent`. |

> **Tip:**  
> The `RoundedRectangleShape` includes a property called `highDistortionOnCurves`, which enhances distortion along curved edges.  
> Use this when you want refracted highlights or edge refraction even with a small `distortionWidth`, especially for circular or highly curved shapes.
>`distortionWidth` defines the area that is gonna be refracted, started from the edge.

---

## Show/Hide Lens with Controller (Animated)

```dart
final lensController = LiquidGlassController();

LiquidGlass(
  controller: lensController,
  position: LiquidGlassAlignPosition(alignment: Alignment.center),
);

// Later
lensController.hideLiquidGlass(animationTimeMillisecond: 300);
lensController.showLiquidGlass(animationTimeMillisecond: 300);
```

Toggle real-time capturing:
```dart
if (isVisible = (!isVisible)) {
  viewController.startRealtimeCapture();
  lensController.showLiquidGlass!();
} 
else {
  lensController.hideLiquidGlass!(
  onComplete: viewController.stopRealtimeCapture,
  );
}
```

---

## Snapshot vs Realtime

| Mode | When to Use | Config |
|-------|--------------|--------|
| **Realtime** | For moving backgrounds (scrolling, videos) | `realTimeCapture: true` |
| **Snapshot** | For static backgrounds | `realTimeCapture: false` + `captureOnce()` |

**Example:**
```dart
final viewController = LiquidGlassViewController();

LiquidGlassView(
  controller: viewController,
  backgroundWidget: ...,
  realTimeCapture: false,
  children: [...],
);

// Refresh manually
await viewController.captureOnce();
```

---

## Recommended Settings

- **General use:**
  `useSync: true`, `pixelRatio: 0.8–1.0`
- **Performance-focused:**
  `useSync: false`, `pixelRatio: 0.5–0.7`

> If your background is full-screen, a pixel ratio of 0.5–1.0 gives the best trade-off between performance and detail.
> For smaller regions, higher pixel ratios yield sharper glass.
> This is a general guideline — the final choice depends on your device’s performance.

---

## Key API (Quick Reference)

### `LiquidGlassView`
```dart
LiquidGlassView({
  required Widget backgroundWidget,
  required List<LiquidGlass> children,
  double pixelRatio = 1.0,
  bool realTimeCapture = true,
  bool useSync = true,
  LiquidGlassRefreshRate refreshRate = LiquidGlassRefreshRate.deviceRefreshRate,
})
```

### `LiquidGlass`
```dart
LiquidGlass({
  double width = 200,
  double height = 100,
  double magnification = 1.0,
  double distortion = 0.25,
  bool draggable = false,
  required LiquidGlassPosition position,
  Widget? child,
  Color color = Colors.transparent,
})
```

---

## License
**MIT License**

---

## Author

**Ahmed Gamil**

- GitHub: https://github.com/AhmeedGamil
- LinkedIn: https://www.linkedin.com/in/ahmed-gamil-630980218
- Email: ahmed.gamil.codes@gmail.com

Feel free to open issues or contribute to the project!
