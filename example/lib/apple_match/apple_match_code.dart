import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'apple_match_tuning.dart';

// The apple_match components as plain package code, every value written in
// as the tuner has it, ready to paste into an app.

/// The ids of the components [componentCode] knows, in tuner order.
const List<String> kCodeComponents = ['button', 'tab', 'slider', 'switch'];

/// Component [c]'s code with the live values.
String componentCode(String c) => switch (c) {
      'button' => _buttonCode(),
      'tab' => _tabBarCode(),
      'slider' => _sliderCode(),
      'switch' => _switchCode(),
      _ => '',
    };

/// Every component's code, one after the other.
String allComponentsCode() => [
      for (final String c in kCodeComponents) componentCode(c),
    ].join('\n');

const String _darkLine =
    '// `dark` is Theme.of(context).brightness == Brightness.dark.\n';

String _header(String name) => '// ── $name '
    '(${AppleMatchTuning.version.label}) ──\n$_darkLine';

// ── Value formatting ─────────────────────────────────────────────

double _d(String id) => AppleMatchTuning.d(id);
bool _b(String id) => AppleMatchTuning.b(id);
int _i(String id) => AppleMatchTuning.i(id);

/// A number as Dart source: no trailing zeros, an integer when whole.
String _n(num v) {
  if (v == v.roundToDouble()) return v.round().toString();
  String s = v.toStringAsFixed(4);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

String _color(int argb) => 'Color(0x'
    '${argb.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()})';

String _c(String id) => _color(_i(id));

/// [light] and [dark] as one expression: plain when they agree.
String _lightDark(String light, String dark) =>
    light == dark ? light : 'dark ? $dark : $light';

String _weight(String id) =>
    'FontWeight.w${((_d(id) / 100).round().clamp(1, 9)) * 100}';

/// Indents every line after the first by [spaces].
String _indent(String s, int spaces) =>
    s.replaceAll('\n', '\n${' ' * spaces}');

// ── The shared glass style ───────────────────────────────────────

String _light(String c, String l, String ctor) {
  final String color = _b('$c.${l}ColorNull') ? 'null' : _c('$c.${l}Color');
  return '''LiquidGlassLight.$ctor(
  thickness: ${_n(_d('$c.${l}Thickness'))},
${l == 'spec' ? '  sharpness: ${_n(_d('$c.${l}Sharpness'))},\n' : ''}  angle: ${_n(_d('$c.${l}Angle'))},
  spread: ${_n(_d('$c.${l}Spread'))},
  intensity: ${_n(_d('$c.${l}Intensity'))},
  oppositeIntensity: ${_n(_d('$c.${l}Opposite'))},
  color: $color,
  tintWeight: ${_n(_d('$c.${l}TintWeight'))},
)''';
}

String _shadow(String c) {
  if (!_b('$c.shadowOn')) return 'null';
  final String offset = _b('$c.shadowAutoOffset')
      ? 'null'
      : 'Offset(${_n(_d('$c.shadowOffsetX'))}, ${_n(_d('$c.shadowOffsetY'))})';
  return '''LiquidGlassShadow(
  blur: ${_n(_d('$c.shadowBlur'))},
  opacity: ${_n(_d('$c.shadowOpacity'))},
  color: ${_c('$c.shadowColor')},
  offset: $offset,
  inset: ${_n(_d('$c.shadowInset'))},
  insideGlass: ${_b('$c.shadowInsideGlass')},
)''';
}

/// Component [c]'s [LiquidGlassStyle]. [cornerRadius] and [fill] replace
/// the knob values, as the components do for their variants.
String _style(String c, {String? cornerRadius, String? fill}) {
  final String cornerStyle = LiquidGlassCornerStyle
      .values[_i('$c.cornerStyle').clamp(0, 2)].name;
  return '''LiquidGlassStyle(
  shape: LiquidGlassShape(
    cornerStyle: LiquidGlassCornerStyle.$cornerStyle,
    cornerRadius: ${cornerRadius ?? _n(_d('$c.cornerRadius'))},
  ),
  specular: ${_indent(_light(c, 'spec', 'specular'), 2)},
  glow: ${_indent(_light(c, 'glow', 'glow'), 2)},
  refractionIndex: ${_n(_d('$c.refIndex'))},
  refractionWidth: ${_n(_d('$c.refWidth'))},
  magnification: ${_n(_d('$c.magnification'))},
  dispersion: ${_n(_d('$c.dispersion'))},
  saturation: ${_lightDark(_n(_d('$c.satLight')), _n(_d('$c.satDark')))},
  blur: ${_n(_d('$c.blur'))},
  color: ${fill ?? _lightDark(_c('$c.fillLight'), _c('$c.fillDark'))},
  shadow: ${_indent(_shadow(c), 2)},
  liteGlass: ${_b('$c.lite')},
)''';
}

// ── The components ───────────────────────────────────────────────

String _buttonCode() {
  const double height = 44;
  final String touch = _b('button.touch')
      ? 'const LiquidGlassTouch.flexing(LiquidGlassFlex())'
      : 'null';
  String button({
    required String label,
    required String foreground,
    String? fill,
  }) =>
      '''LiquidGlassButton(
  label: '$label',
  onPressed: () {},
  height: ${_n(height)},
  padding: const EdgeInsets.symmetric(horizontal: 18),
  fontSize: ${_n(_d('button.fontSize'))},
  fontWeight: ${_weight('button.fontWeight')},
  iconSize: 17,
  foregroundColor: $foreground,
  style: ${_indent(_style('button', fill: fill), 2)},
  touch: $touch,
)''';
  return '''${_header('LiquidGlassButton')}// Regular. An icon-only button: width = height, padding: EdgeInsets.zero,
// iconSize: height * 0.54 and cornerRadius: height / 2.
${button(label: 'Glass', foreground: 'dark ? Colors.white : Colors.black')}

// Prominent: the accent fill as the glass colour.
${button(label: 'Prominent', foreground: 'Colors.white', fill: _c('button.prominentFill'))}
''';
}

String _tabBarCode() {
  final double barWidth = _d('tab.width');
  final double padding = _d('tab.itemPadding');
  final int count = _i('tab.itemCount').clamp(1, 6);
  final String pillWidth = _b('tab.pillWidthNull')
      ? 'null'
      : _n(_d('tab.pillWidthFactor') * (barWidth - 2 * padding) / count);
  final String weight = _weight('tab.labelWeight');
  return '''${_header('LiquidGlassTabBar')}// Built for $count items; pillStyle.width follows the item count.
LiquidGlassTabBar(
  items: items,
  selectedIndex: selectedIndex,
  onChanged: onChanged,
  width: ${_n(barWidth)},
  height: ${_n(_d('tab.height'))},
  itemPadding: ${_n(padding)},
  style: ${_indent(_style('tab'), 2)},
  pillStyle: LiquidGlassTabPillStyle(
    mode: LiquidGlassPillMode.both,
    growHeight: ${_n(_d('tab.growHeight'))},
    refractionIndex: ${_n(_d('tab.pillRefIndex'))},
    refractionWidth: ${_n(_d('tab.pillRefWidth'))},
    width: $pillWidth,${_b('tab.pillLite') ? _pillLiteGlass() : ''}
    rest: LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: ${_n(_d('tab.pillRadius'))},
        clipQuality: LiquidGlassClipQuality.exact,
      ),
      color: ${_c('tab.pillColor')},
    ),
  ),
  itemStyle: LiquidGlassTabItemStyle(
    selectedColor: ${_lightDark(_c('tab.selectedLight'), _c('tab.selectedDark'))},
    unselectedColor: dark ? Colors.white : Colors.black,
    iconSize: ${_n(_d('tab.iconSize'))},
    labelFontSize: ${_n(_d('tab.labelSize'))},
    iconLabelGap: 1,
    selectedFontWeight: $weight,
    unselectedFontWeight: $weight,
  ),
)
''';
}

String _sliderCode() => '''${_header('LiquidGlassSlider')}LiquidGlassSlider(
  value: value,
  onChanged: onChanged,
  activeColor: ${_c('slider.active')},
  inactiveColor: ${_lightDark(_c('slider.inactiveLight'), _c('slider.inactiveDark'))},
  layout: LiquidGlassSliderLayout(
    trackHeight: ${_n(_d('slider.trackHeight'))},
    thumbWidth: ${_n(_d('slider.thumbWidth'))},
    thumbHeight: ${_n(_d('slider.thumbHeight'))},
  ),
  style: ${_indent(_style('slider'), 2)},
)
''';

String _switchCode() => '''${_header('LiquidGlassSwitch')}LiquidGlassSwitch(
  value: value,
  onChanged: onChanged,
  activeColor: ${_lightDark(_c('switch.activeLight'), _c('switch.activeDark'))},
  inactiveColor: ${_lightDark(_c('switch.inactiveLight'), _c('switch.inactiveDark'))},
  style: ${_indent(_style('switch'), 2)},
  layout: LiquidGlassSwitchLayout(
    overshootRoom: ${_n(_d('switch.overshootRoom'))},
  ),
)
''';

/// The moving pill's glassStyle with lite glass on: the pill's defaults
/// restated, since a glassStyle replaces its whole look.
String _pillLiteGlass() => '''

    glassStyle: LiquidGlassStyle(
      color: Colors.transparent,
      blur: 0,
      refractionIndex: ${_n(_d('tab.pillRefIndex'))},
      refractionWidth: ${_n(_d('tab.pillRefWidth'))},
      dispersion: 1.32,
      shadow: LiquidGlassShadow(blur: 9, opacity: 0.3, inset: 0),
      liteGlass: true,
    ),''';
