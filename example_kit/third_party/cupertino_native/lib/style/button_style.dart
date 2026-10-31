/// Visual styles for [CNButton] and related controls.
enum CNButtonStyle {
  /// Minimal, text-only style.
  plain,

  /// Subtle gray background style.
  gray,

  /// Tinted/filled text style.
  tinted,

  /// Bordered button style.
  bordered,

  /// Prominent bordered (accent-colored) style.
  borderedProminent,

  /// Filled background style.
  filled,

  /// Glass effect (iOS 16+/macOS 13+ look-alike).
  glass, // iOS 26+
  /// More prominent glass effect.
  prominentGlass, // iOS 26+
}
