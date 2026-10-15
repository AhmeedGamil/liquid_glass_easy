import 'package:flutter/widgets.dart';

import 'presets/ios26.dart';
import 'presets/ios27.dart';

/// The iOS release a set of tuned values targets. Each one has its own
/// preset file in `presets/` and its own reference screenshots in
/// `assets/apple_match/reference/<folder>/`.
enum IosVersion {
  ios26('iOS 26', 'ios26', kIos26),
  ios27('iOS 27', 'ios27', kIos27);

  const IosVersion(this.label, this.folder, this.preset);

  final String label;

  /// The preset file's name and the reference screenshots' folder.
  final String folder;

  /// Every knob's tuned value for this release.
  final Map<String, num> preset;
}

enum KnobKind { number, color, toggle, choice }

/// One tunable value of an apple_match component. Its tuned value lives
/// in the active [IosVersion]'s preset, not here.
class Knob {
  const Knob(
    this.id,
    this.section,
    this.label, {
    this.min = 0,
    this.max = 1,
    this.step = 0.01,
  })  : kind = KnobKind.number,
        choices = const [];

  const Knob.color(this.id, this.section, this.label)
      : kind = KnobKind.color,
        min = 0,
        max = 0,
        step = 1,
        choices = const [];

  /// A checkbox: 1 is on, 0 is off.
  const Knob.toggle(this.id, this.section, this.label)
      : kind = KnobKind.toggle,
        min = 0,
        max = 1,
        step = 1,
        choices = const [];

  /// One of [choices], stored as its index.
  const Knob.choice(this.id, this.section, this.label, this.choices)
      : kind = KnobKind.choice,
        min = 0,
        max = 0,
        step = 1;

  final String id;
  final String section;
  final String label;
  final KnobKind kind;
  final double min;
  final double max;
  final double step;
  final List<String> choices;

  /// The component the knob belongs to: the id's prefix.
  String get component => id.substring(0, id.indexOf('.'));
}

// Sections every component's glass has, in tab order: a field of
// LiquidGlassStyle where it has one, a group of its flat fields otherwise.
const String kMaterial = 'Material';
const String kShape = 'shape';
const String kSpecular = 'specular';
const String kGlow = 'glow';
const String kRefraction = 'Refraction';
const String kShadow = 'shadow';

const List<String> kStyleSections = [
  kMaterial,
  kShape,
  kSpecular,
  kGlow,
  kRefraction,
  kShadow,
];

/// One LiquidGlassLight's fields as knobs, [l] being `spec` or `glow`.
List<Knob> _lightKnobs(String c, String l, String section) => [
      Knob('$c.${l}Thickness', section, 'thickness',
          max: l == 'glow' ? 30 : 12, step: l == 'glow' ? 0.5 : 0.1),
      if (l == 'spec') Knob('$c.${l}Sharpness', section, 'sharpness'),
      Knob('$c.${l}Angle', section, 'angle', max: 360, step: 1),
      Knob('$c.${l}Spread', section, 'spread'),
      Knob('$c.${l}Intensity', section, 'intensity', max: 3),
      Knob('$c.${l}Opposite', section, 'oppositeIntensity', max: 2),
      Knob.toggle(
          '$c.${l}ColorNull', section, 'color: null (picks up the backdrop)'),
      Knob.color('$c.${l}Color', section, 'color'),
      Knob('$c.${l}TintWeight', section, 'tintWeight'),
    ];

/// Every [LiquidGlassStyle] field of component [c] as knobs, labelled by
/// field name.
List<Knob> _styleKnobs(String c) => [
      Knob.color('$c.fillLight', kMaterial, 'color (light)'),
      Knob.color('$c.fillDark', kMaterial, 'color (dark)'),
      Knob('$c.satLight', kMaterial, 'saturation (light)', max: 3),
      Knob('$c.satDark', kMaterial, 'saturation (dark)', max: 3),
      Knob('$c.blur', kMaterial, 'blur', max: 30, step: 0.5),
      Knob.toggle('$c.lite', kMaterial, 'liteGlass'),
      Knob.choice('$c.cornerStyle', kShape, 'cornerStyle', const [
        'roundedRectangle',
        'squircle',
        'continuousRoundedRectangle',
      ]),
      Knob('$c.cornerRadius', kShape, 'cornerRadius', max: 100, step: 0.5),
      ..._lightKnobs(c, 'spec', kSpecular),
      ..._lightKnobs(c, 'glow', kGlow),
      Knob('$c.refIndex', kRefraction, 'refractionIndex',
          min: 1, max: 1.5, step: 0.005),
      Knob('$c.refWidth', kRefraction, 'refractionWidth', max: 40, step: 0.5),
      Knob('$c.magnification', kRefraction, 'magnification',
          min: 0.5, max: 1.5),
      Knob('$c.dispersion', kRefraction, 'dispersion', max: 13, step: 0.1),
      Knob.toggle('$c.shadowOn', kShadow, 'shadow (off = null)'),
      Knob('$c.shadowBlur', kShadow, 'blur', max: 40, step: 0.5),
      Knob('$c.shadowOpacity', kShadow, 'opacity'),
      Knob.color('$c.shadowColor', kShadow, 'color'),
      Knob.toggle(
          '$c.shadowAutoOffset', kShadow, 'offset: null (blur + 2 down)'),
      Knob('$c.shadowOffsetX', kShadow, 'offset.dx',
          min: -10, max: 10, step: 0.5),
      Knob('$c.shadowOffsetY', kShadow, 'offset.dy',
          min: -10, max: 20, step: 0.5),
      Knob('$c.shadowInset', kShadow, 'inset', max: 12, step: 0.5),
      Knob.toggle('$c.shadowInsideGlass', kShadow, 'insideGlass'),
    ];

// The sections that only one component has: its own parameters.
const String kButton = 'LiquidGlassButton';
const String kTabBar = 'LiquidGlassTabBar';
const String kSlider = 'LiquidGlassSlider';
const String kSwitch = 'LiquidGlassSwitch';

/// Every knob: each component's full glass style, then its own values.
final List<Knob> kKnobs = [
  ..._styleKnobs('button'),
  const Knob.toggle('button.touch', kButton,
      'touch: LiquidGlassTouch.flexing (off = null)'),
  const Knob('button.fontSize', kButton, 'fontSize',
      min: 10, max: 24, step: 0.5),
  const Knob('button.fontWeight', kButton, 'fontWeight',
      min: 100, max: 900, step: 100),
  const Knob.color('button.prominentFill', kButton, 'style.color (prominent)'),
  ..._styleKnobs('tab'),
  const Knob('tab.width', kTabBar, 'width', min: 200, max: 400, step: 1),
  const Knob('tab.height', kTabBar, 'height', min: 44, max: 80, step: 1),
  const Knob('tab.itemPadding', kTabBar, 'itemPadding', max: 12, step: 0.5),
  const Knob('tab.itemCount', kTabBar, 'items.length', min: 1, max: 6, step: 1),
  const Knob.toggle(
      'tab.pillWidthNull', kTabBar, 'pillStyle.width: null (one equal share)'),
  const Knob('tab.pillWidthFactor', kTabBar,
      'pillStyle.width = equal share × factor',
      min: 0.5, max: 2, step: 0.005),
  const Knob('tab.growHeight', kTabBar, 'pillStyle.growHeight',
      max: 30, step: 0.5),
  const Knob('tab.pillRefIndex', kTabBar, 'pillStyle.refractionIndex',
      min: 1, max: 1.5, step: 0.005),
  const Knob('tab.pillRefWidth', kTabBar, 'pillStyle.refractionWidth',
      max: 40, step: 0.5),
  const Knob.toggle(
      'tab.pillLite', kTabBar, 'pillStyle.glassStyle.liteGlass'),
  const Knob('tab.pillRadius', kTabBar, 'pillStyle.rest.shape.cornerRadius',
      max: 40, step: 0.5),
  const Knob.color('tab.pillColor', kTabBar, 'pillStyle.rest.color'),
  const Knob('tab.iconSize', kTabBar, 'itemStyle.iconSize',
      min: 16, max: 36, step: 0.5),
  const Knob('tab.labelSize', kTabBar, 'itemStyle.labelFontSize',
      min: 8, max: 14, step: 0.5),
  const Knob('tab.labelWeight', kTabBar,
      'itemStyle.selectedFontWeight + unselectedFontWeight',
      min: 100, max: 900, step: 100),
  const Knob.color(
      'tab.selectedLight', kTabBar, 'itemStyle.selectedColor (light)'),
  const Knob.color(
      'tab.selectedDark', kTabBar, 'itemStyle.selectedColor (dark)'),
  ..._styleKnobs('slider'),
  const Knob.color('slider.active', kSlider, 'activeColor'),
  const Knob.color('slider.inactiveLight', kSlider, 'inactiveColor (light)'),
  const Knob.color('slider.inactiveDark', kSlider, 'inactiveColor (dark)'),
  const Knob('slider.trackHeight', kSlider, 'layout.trackHeight',
      min: 2, max: 12, step: 0.5),
  const Knob('slider.thumbWidth', kSlider, 'layout.thumbWidth',
      min: 20, max: 60, step: 0.5),
  const Knob('slider.thumbHeight', kSlider, 'layout.thumbHeight',
      min: 16, max: 40, step: 0.5),
  ..._styleKnobs('switch'),
  const Knob.color('switch.activeLight', kSwitch, 'activeColor (light)'),
  const Knob.color('switch.activeDark', kSwitch, 'activeColor (dark)'),
  const Knob.color('switch.inactiveLight', kSwitch, 'inactiveColor (light)'),
  const Knob.color('switch.inactiveDark', kSwitch, 'inactiveColor (dark)'),
  const Knob('switch.overshootRoom', kSwitch, 'layout.overshootRoom',
      max: 60, step: 1),
];

final Map<String, Knob> _byId = {for (final k in kKnobs) k.id: k};

/// The active [IosVersion] and the values changed on top of its preset,
/// kept apart per version.
class _TuningState extends ChangeNotifier {
  IosVersion _version = IosVersion.ios26;
  final Map<IosVersion, Map<String, num>> _overrides = {
    for (final v in IosVersion.values) v: {},
  };

  void _notify() => notifyListeners();
}

/// Live values for [kKnobs]. The tuner panel changes them; the apple_match
/// components read them in build and rebuild through
/// [AppleMatchTuningScope].
class AppleMatchTuning {
  static final _TuningState _state = _TuningState();

  static IosVersion get version => _state._version;

  static set version(IosVersion v) {
    _state._version = v;
    _state._notify();
  }

  static Map<String, num> get _overrides => _state._overrides[version]!;

  /// The active version's preset value for [id].
  static num tuned(String id) {
    final num? v = version.preset[id];
    if (v == null) {
      throw StateError("presets/${version.folder}.dart has no '$id'");
    }
    return v;
  }

  static num value(String id) => _overrides[id] ?? tuned(id);

  static double d(String id) => value(id).toDouble();

  static Color c(String id) => Color(value(id).toInt());

  static bool b(String id) => value(id) != 0;

  static int i(String id) => value(id).toInt();

  static FontWeight w(String id) =>
      FontWeight.values[((d(id) / 100).round() - 1).clamp(0, 8)];

  /// Whether [id] differs from the active preset.
  static bool changed(String id) => value(id) != tuned(id);

  static int get changedCount => kKnobs.where((k) => changed(k.id)).length;

  /// Makes [context] rebuild when any knob or the version changes.
  static void watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppleMatchTuningScope>();

  static void set(String id, num v) {
    if (!_byId.containsKey(id)) return;
    _overrides[id] = v;
    _state._notify();
  }

  /// Puts [ids] back to the active preset.
  static void resetIds(Iterable<String> ids) {
    ids.forEach(_overrides.remove);
    _state._notify();
  }

  /// Puts every knob of the active version back to its preset.
  static void reset() {
    _overrides.clear();
    _state._notify();
  }

  /// [v] as Dart source for [k]: hex for a colour, an integer where the
  /// knob steps by whole numbers.
  static String formatValue(Knob k, num v) {
    if (k.kind == KnobKind.color) {
      return '0x${v.toInt().toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';
    }
    if (k.step >= 1 || v == v.roundToDouble()) return v.round().toString();
    String s = v.toStringAsFixed(4);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}

/// Rebuilds the apple_match components below it when a knob changes.
class AppleMatchTuningScope extends InheritedNotifier<_TuningState> {
  AppleMatchTuningScope({super.key, required super.child})
      : super(notifier: AppleMatchTuning._state);
}
