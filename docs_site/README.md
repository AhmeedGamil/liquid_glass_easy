# docs_site

The `liquid_glass_easy` documentation site: **real HTML for the prose, Flutter
Web for the demos.**

Every heading, paragraph, table and code sample is ordinary markup — selectable,
copyable, indexable, and painted before anything downloads. The live demos are
the same Flutter app embedded per page with `<iframe>`, chosen by URL, and
`loading="lazy"` so a page nobody scrolls never downloads CanvasKit at all.

## Layout

```
content/          the docs themselves, as plain-Dart data
  doc_model.dart    block types (Prose, Code, DocTable, Note, TryIt, …)
  doc_content.dart  every page, in reading order
  demos.dart        the demo ids the site links to and embeds
assets/           styles.css + site.js, copied verbatim
tool/
  build_site.dart the whole toolchain
build/            generated — git-ignored
```

There is no Node, no bundler and no static-site generator to install. The
content is already structured data, so turning it into HTML is one Dart script
with no dependencies beyond `dart:io`.

## Build

The site embeds the demo app, so build that first:

```bash
cd ../web_demos
flutter build web --release

cd ../docs_site
dart run tool/build_site.dart
```

Output lands in `build/`, with the Flutter app copied in as `build/demos/`.

Flags:

| Flag | Default | Purpose |
|---|---|---|
| `--out <dir>` | `build` | Output directory. |
| `--demos <dir>` | `../web_demos/build/web` | The Flutter build to embed. |
| `--base <url>` | the GitHub Pages URL | Absolute base for `<link rel=canonical>` and `sitemap.xml`. |

## Preview

```bash
cd build
python -m http.server 8081
```

Then open <http://localhost:8081>. Serve it over HTTP rather than opening the
files directly — `file://` blocks the iframes.

## Deploying

`build/` is a folder of static files: any host works. For GitHub Pages, publish
the folder (a `gh-pages` branch, or an Actions workflow that runs the two build
commands above and uploads `build/`). Pass the real URL with `--base` so the
canonical links and sitemap point at the right origin.

`.nojekyll` is emitted for Pages; without it Jekyll can filter parts of the
Flutter build.

## Editing

Prose lives in `content/doc_content.dart` and nowhere else. Add a page by
appending a `DocPage` to `kDocs` — it picks up its sidebar entry, its
prev/next links and its sitemap row automatically.

Inside a `Prose`, `Note`, `Bullets` or table cell, `` `backticks` `` render as
inline code and `**stars**` as bold. Everything is HTML-escaped first, so a
sample containing `<` is safe.

`DocBlock` is a **sealed** type: adding a block kind is a compile error in
`build_site.dart` until it has been given a look.
