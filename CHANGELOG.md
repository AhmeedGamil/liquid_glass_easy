## 1.1.1
- Formatted the dart files and changed the size of the thumbnail of screenshot.

## 1.1.0
- Added new refraction modes: **shape refraction** and **radial refraction**.
- Added new light modes: **edge** and **radial**.
- Added **chromatic aberration** support.
- Added **one side light intensity** support.
- Added **saturation** control.
- Updated magnification behavior to apply to the entire lens area rather than only the distortion region.
- Improved and optimized shader code.
- Removed `highDistortionOnCurves`; the same effect can now be achieved by increasing `distortion` and setting `distortionWidth` to half of the smallest lens dimension.

## 1.0.0
**Initial Stable Release – Liquid Glass Easy**

- First official release of the **`liquid_glass_easy`** Flutter package.
- Provides real-time **liquid glass lens effects** with smooth distortion, magnification, and refraction.
- Built with **shader-based rendering** for high performance and flexibility.
- Includes `LiquidGlassView` and `LiquidGlass` widgets for quick and easy integration into any UI.
- Example app included to demonstrate usage, configuration, and visual styles.
- Ready for production and pub.dev distribution.

