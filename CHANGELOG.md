## 1.1.0
- Added new refraction modes: **shape refraction** and **radial refraction**.
- Added new light modes: **edge** and **radial**.
- Added **chromatic aberration** support.
- Added **one side light intensity** support.
- Added **saturation** control.
- Updated magnification behavior to apply to the entire lens area rather than only the distortion region.
- Improved and optimized shader code.
- Removed `highDistortionOnCurves`; the same effect can now be achieved by increasing `distortion` and setting `distortionWidth` to half of the smallest lens dimension.