# liquid_glass_easy — example

**Apple Match**: glass buttons, a tab bar, a slider and a switch tuned to
read like Apple's Liquid Glass controls, per iOS release. Each scene shows
two bands over the same backdrop: Apple's control on top (live through
cupertino_native on iOS and macOS, an iOS simulator screenshot
elsewhere), the live package component below.

## Tuning

The panel at the bottom picks the iOS release, the component and the
backdrop. Its tabs hold every value of the component: its own sizes and
colours, then every `LiquidGlassStyle` field — Material, Shape, Specular,
Glow, Refraction, Shadow. A dot on a tab marks changed values.

Where things live:

| What | Where |
|---|---|
| Tuned values, one file per release | `lib/apple_match/presets/ios26.dart`, `ios27.dart` |
| Apple's controls, per release | `assets/apple_match/reference/ios26/`, `ios27/` |
| The knobs (ranges, tabs) | `lib/apple_match/apple_match_tuning.dart` |
| Knobs → `LiquidGlassStyle` | `lib/apple_match/apple_match_style.dart` |

**Copy** puts the component's package code, with every tuned value written
in, on the clipboard; **Copy all** does it for every component. Values are
not saved: to keep them as the starting point, write them into
`lib/apple_match/presets/<release>.dart`. Every knob needs a value in every
preset file.

To add a release: add its preset file and screenshot folder, an entry in
`IosVersion`, and the folder under `assets:` in `pubspec.yaml`.

## Run

```bash
cd example
flutter pub get
flutter run
```
