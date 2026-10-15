# Liquid Glass Easy — fine-tuning to match iOS 26 / 27

This branch is where `liquid_glass_easy` is tuned to look and behave like Apple's
Liquid Glass. The values found here will become a **new kit of iOS 26–27
components**, so every suggestion, fix and measured value helps.

> **Full disclosure:** I don't have an iPhone or a Mac. Everything here is matched
> from videos, images and iOS simulator screenshots. If you have a real device,
> your eyes are worth more than mine.

## The tuner

`example/` is one page, **Apple Match**: each component sits under Apple's own,
over the same background, with a panel that changes every value live.

```bash
cd example
flutter pub get
flutter run
```

- On **iOS and macOS** the top band is Apple's **live** control (through
  `cupertino_native`). Everywhere else it is an iOS 26 simulator screenshot.
- Pick the iOS release, the component and the background from the top row.
- **Copy** gives the component's code with your values written in; **Copy all**
  does every component.

<p>
  <img src="showcases/fine_tune/tab_bar_photo_light.jpg" width="45%" alt="Tab bar over a photo, light mode: Apple's on top, the tuned one below"/>
  <img src="showcases/fine_tune/tab_bar_photo_dark.jpg" width="45%" alt="Tab bar over a photo, dark mode: Apple's on top, the tuned one below"/>
</p>

## How to contribute

- **Fine-tuning:** tune a component until it matches and tap **Copy**. Put the
  code in a folder named after your GitHub account, `contributions/<your-github-name>/`,
  with screenshots or short videos of your result next to Apple's (your device and
  the iOS version in a short note). Open a PR with that folder, or an issue if a
  PR is too much. Tuned starting values live in `example/lib/apple_match/presets/`.
- **iOS 27:** its preset is still a copy of iOS 26 and it has no screenshots yet.
  Screenshots go in `example/assets/apple_match/reference/ios27/` (names in the
  README there).
- **Enhancements:** fixes to the glass itself (`lib/`) are welcome as PRs; please
  say what you compared against.
- **Suggestions:** open an issue, even with a short video of the real thing.

## Open questions — help wanted

1. **Glass colour in dark mode:** I don't know whether Apple's dark glass has a
   saturation boost or only a tint. Over coloured stripes it looks more saturated
   than a plain grey layer would give, so for now I raised the dark saturation for
   the **tab bar only** (the other components keep 1).
2. **Tab bar background:** in dark mode I set the tab bar's colour to
   `rgba(69, 69, 69, 192)`. It matches over the photo, but over the plain dark
   screen it looks different from Apple's. What decides the glass colour, and how
   does it change with what is behind it?
3. **Tab bar tap-and-hold:** when you tap and hold the glass pill, does the whole
   **tab bar** scale, or only the pill?
4. **Tab bar on iOS 27:** does the selection pill still grow and lift when you tap
   an item, as on iOS 26?
5. **Tab bar dragging:** can you drag the pill straight away, or only after
   tap-and-hold?
6. **Dynamic adaptivity:** does the glass switch between light and dark on its own
   by what is behind it, as Apple's showcases suggest, and when?
7. **The public API of the new kit:** how would you like the components to be
   used? Should they be close to Apple's and less customisable (pick a component,
   it just looks right), or expose the glass values like the tuner does? What must
   every component let you change: colours, icons and labels, sizes, haptics,
   light and dark, or something else?

## New components

New components are coming soon. If you need one, or want to suggest one, open an
issue and say what it is and where you would use it.

---

The released package and its docs are on
[pub.dev](https://pub.dev/packages/liquid_glass_easy) and the
[documentation site](https://ahmeedgamil.github.io/liquid_glass_easy/).
