# Kitchen glass lab (experimental)

A scratch build of a liquid-glass fragment shader for Flutter, running on the
**Impeller live backdrop**. Nothing here is part of the published package, and
nothing under the project's `lib/` is touched by it.

```
kitchen/experimental/
  shaders/kitchen_liquid_glass.frag   the shader
  lib/src/kitchen_glass_params.dart   every knob, plus four presets
  lib/src/kitchen_glass_surface.dart  the BackdropFilter render object
  lib/src/kitchen_glass_lab_page.dart the draggable playground + tuning panel
  lib/src/kitchen_lab_backdrop.dart   the page to refract (generated or a photo)
  lib/src/kitchen_backdrop_picker.dart plugin-free picture chooser
  lib/src/kitchen_tuner_widgets.dart  sliders, chips, swatches
```

## Run it

```bash
cd example
flutter run -t lib/kitchen_lab.dart
```

Drag any lobe around. Bring two together and they fuse into one liquid surface;
pull them apart and the bridge snaps. The **Tune** button at the bottom right
opens the parameter panel, which starts hidden.

## The backdrop

Whatever it shows, the backdrop is **one `ui.Image` blitted once per frame**. A
live widget tree there would re-rasterise on every frame the glass samples it,
which is what made the first version expensive.

Two sources, switched from the panel's **Background** section:

- **Generated** (default) — colour blooms plus a tile grid, drawn once into an
  offscreen image at the current size and reused until the size changes.
- **A picture from the device** — the system gallery picker, decoded at most
  2048 px on the long edge.

### Two picking paths

`KitchenGlassLabPage.onPickImage` is an injection seam, so the lab package
itself never depends on a picker plugin:

- **Supplied** — `example/lib/kitchen_lab.dart` passes an `image_picker`-backed
  callback, which is the normal system gallery picker. This is why the example
  is on **Kotlin 2.1.0**: current picker plugins pull AndroidX artifacts whose
  Kotlin metadata a 1.8.x toolchain cannot read.
- **Omitted** — the lab falls back to `showBackdropPicker`, a plugin-free
  chooser over the app's **own** external files directory, which needs no
  permission at all:

  ```bash
  adb push photo.jpg /sdcard/Android/data/<applicationId>/files/
  ```

  It prints the exact path (the package id is recovered from Dart's temp
  directory, so nothing is hardcoded) and creates the folder if missing. It also
  tries `/sdcard/Download`, `/sdcard/Pictures` and `/sdcard/DCIM/Camera`,
  ignoring them when they refuse.

## What the shader does

One fragment pass over the live backdrop:

1. **Silhouette.** Up to four rounded rects, each with superellipse corners,
   combined by a polynomial smooth-union. The blend radius (`mergeSmoothness`)
   is the distance at which two lobes start flowing together.
2. **Refraction.** The signed distance inward is read as depth into a slab
   `thickness` points deep. Depth drives an incidence angle that sweeps from
   grazing at the outline to zero at the back of the slab, Snell's law bends it
   by `refractiveIndex`, and the difference between the two angles becomes the
   distance the sample is dragged back along the inward surface normal.
   Past the slab the glass looks straight through.
3. **Dispersion.** Red and blue walk slightly different distances than green,
   so the bend at the outline splits into a prism fringe.
4. **Fresnel rim** and **directional glare**, both ramped by distance from the
   outline, both applied in **LCH** so a highlight gains lightness and chroma
   instead of washing out to grey. The glare is additionally gated by the
   normal's angle, which is what puts it on two opposing arcs rather than all
   the way round.
5. **Coverage.** Outside the silhouette the pass emits zero premultiplied
   colour, so the untouched backdrop composites straight through.

## Four lobes, not sixteen

Flutter's runtime effects have no uniform arrays, so each lobe costs its own
`vec4` declaration and the shader carries exactly four (`uRect0..uRect3`).
`KitchenGlassSurface.maxLobes` is that cap; extra entries in `lobes` are
dropped. Raising it means adding uniforms and unrolled `smoothUnion` lines in
`sceneSDF` — the iOS Impeller backend caps runtime-effect uniforms at roughly
30 declarations, so there is headroom for a few more but not for sixteen.

## Coordinate space

Under `BackdropFilter(ImageFilter.shader(...))` the fragment coordinate is
**full-screen physical pixels** and the bound sampler is the whole frame, so
every geometry uniform is packed in that same space (`RenderKitchenGlass`
converts from local logical px with `getTransformTo(null)` and the device pixel
ratio). Distances stay in physical pixels inside the SDF and convert to logical
points only where the optics are defined in points, which keeps the look the
same across device pixel ratios.

## Notes and limits

- **Impeller only.** `kitchenGlassSupported` checks
  `ImageFilter.isShaderFilterSupported`; on Skia or the web the page shows a
  message instead. Feeding the Skia path would mean capturing the background
  into an image and binding it with `setImageSampler`.
- **Blur is in-shader** (a nine-tap golden-angle spiral over the sampled
  backdrop) so it stays inside the silhouette with no rectangular halo. It is
  the most expensive knob on the panel; `blur: 0` skips the loop entirely.
- **`edgeGain`** stands in for the surface-normal magnitude that scales the rim
  and glare. In a per-element renderer that magnitude falls out of the element's
  own pixel height; here one pass covers the whole screen, so it is a slider.
- The gradient uses four-tap central differences rather than hardware
  derivatives — it follows the smooth-union bridge, where a per-lobe analytic
  normal would show a seam.
