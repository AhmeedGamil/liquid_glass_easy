// Builds the static docs site.
//
//   dart run tool/build_site.dart
//
// Reads the pages from `content/`, writes plain HTML into `build/`, and
// copies the Flutter demo app in beside them as `build/demos/`. No Node, no
// bundler, no second package manager — the content is already structured
// data, so the generator is the whole toolchain.
//
// Flags:
//   --out <dir>     output directory        (default: build)
//   --demos <dir>   Flutter web build to embed
//                   (default: ../web_demos/build/web)
//   --base <url>    absolute site URL for canonical links + sitemap

import 'dart:io';

import '../content/demos.dart';
import '../content/doc_content.dart';
import '../content/doc_model.dart';

const String kDefaultBase = 'https://ahmeedgamil.github.io/liquid_glass_easy';
const String kPubUrl = 'https://pub.dev/packages/liquid_glass_easy';
const String kRepoUrl = 'https://github.com/AhmeedGamil/liquid_glass_easy';
const String kVersion = '3.5.0';

late String siteBase;

/// A short digest of the demo bundle, appended to every URL pointing into the
/// demo app. Empty when there is no build to embed.
String demoVersion = '';

void main(List<String> args) {
  final Directory root = File.fromUri(Platform.script).parent.parent;
  final Map<String, String> flags = _flags(args);

  siteBase = (flags['base'] ?? kDefaultBase).replaceAll(RegExp(r'/$'), '');

  final Directory out = Directory(_abs(root, flags['out'] ?? 'build'));
  final Directory demos = Directory(
    _abs(root, flags['demos'] ?? '../web_demos/build/web'),
  );

  // Stamped into every URL that reaches the demo app, so a rebuilt bundle can
  // never be answered from a browser cache holding the last one.
  demoVersion = _hash(File('${demos.path}/main.dart.js'));

  // Empty the directory rather than remove it: on Windows a preview server
  // running inside `build/` holds a handle on the folder itself, and deleting
  // it fails mid-way — leaving a half-built site behind.
  out.createSync(recursive: true);
  for (final entity in out.listSync()) {
    entity.deleteSync(recursive: true);
  }

  // Pages.
  _write(out, 'index.html', _landing());
  for (final page in kDocs) {
    _write(out, '${page.id}.html', _docPage(page));
  }

  // Assets, verbatim.
  for (final name in ['styles.css', 'site.js']) {
    File('${root.path}/assets/$name').copySync('${out.path}/$name');
  }

  // Crawler files. `.nojekyll` keeps GitHub Pages from filtering the Flutter
  // build's own files.
  _write(out, 'sitemap.xml', _sitemap());
  _write(out, 'robots.txt',
      'User-agent: *\nAllow: /\nSitemap: $siteBase/sitemap.xml\n');
  _write(out, '.nojekyll', '');

  // The interactive island.
  if (demos.existsSync()) {
    _copyDir(demos, Directory('${out.path}/demos'));
    _rebaseFlutterApp(File('${out.path}/demos/index.html'));
    _dropServiceWorker(
      File('${out.path}/demos/index.html'),
      File('${out.path}/demos/flutter_bootstrap.js'),
    );
    stdout.writeln('  demos    ← ${demos.path}');
  } else {
    stdout.writeln('  WARNING: no Flutter build at ${demos.path}');
    stdout.writeln('           run `flutter build web --release` in web_demos');
  }

  stdout.writeln('Built ${out.path}');
  stdout.writeln('  ${kDocs.length + 1} pages · base $siteBase');
}

// ── page templates ──────────────────────────────────────────────────

String _shell({
  required String title,
  required String description,
  required String canonical,
  required String body,
  String? currentId,
  String wrapClass = 'wrap',
}) {
  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(title)}</title>
<meta name="description" content="${_esc(description)}">
<link rel="canonical" href="$siteBase/$canonical">
<meta property="og:type" content="website">
<meta property="og:title" content="${_esc(title)}">
<meta property="og:description" content="${_esc(description)}">
<meta property="og:url" content="$siteBase/$canonical">
<meta name="twitter:card" content="summary">
<link rel="stylesheet" href="styles.css">
</head>
<body>
<details class="topbar">
  <summary>${currentId == null ? 'Documentation' : _esc(_titleOf(currentId))}</summary>
  ${_nav(currentId)}
</details>
<div class="layout">
  <aside class="sidebar">
    <a class="brand" href="index.html">
      <span class="eyebrow">LIQUID GLASS EASY</span>
      <span class="name">Documentation</span>
      <span class="ver">v$kVersion</span>
    </a>
    ${_nav(currentId)}
    <div class="nav-foot">
      <a href="demos/index.html">Live demos ↗</a>
      <a href="$kPubUrl">pub.dev ↗</a>
      <a href="$kRepoUrl">GitHub ↗</a>
    </div>
  </aside>
  <main class="content">
    <div class="$wrapClass">
$body
    </div>
  </main>
</div>
<script src="site.js" defer></script>
</body>
</html>
''';
}

/// The sidebar. Top-level pages are numbered in reading order; a page with a
/// `parent` is listed under it, unnumbered, in a nested list.
String _nav(String? currentId) {
  final b = StringBuffer('<ul class="nav">');
  int n = 0;

  for (final p in kDocs.where((p) => p.parent == null)) {
    n++;
    final cur = p.id == currentId ? ' aria-current="page"' : '';
    final List<DocPage> kids =
        kDocs.where((c) => c.parent == p.id).toList(growable: false);

    b.write('<li><a href="${p.id}.html"$cur>'
        '<span class="n">$n</span>${_esc(p.title)}</a>');

    if (kids.isNotEmpty) {
      b.write('<ul class="sub">');
      for (final c in kids) {
        final kcur = c.id == currentId ? ' aria-current="page"' : '';
        b.write('<li><a href="${c.id}.html"$kcur>${_esc(c.title)}</a></li>');
      }
      b.write('</ul>');
    }
    b.write('</li>');
  }
  return (b..write('</ul>')).toString();
}

String _titleOf(String id) {
  for (final p in kDocs) {
    if (p.id == id) return p.title;
  }
  return 'Documentation';
}

String _docPage(DocPage page) {
  // The demo is pulled out of the reading order and given its own column:
  // wide enough and it rides along on the right, pinned, while the prose
  // scrolls past it. Narrow, the two columns stack and it lands back at the
  // bottom of the page — the same place it has always been.
  final demo = StringBuffer();
  for (final block in page.blocks.whereType<TryIt>()) {
    demo.writeln(_block(block));
  }
  final bool split = demo.toString().trim().isNotEmpty;

  final prose = StringBuffer()
    ..writeln('<h1>${_esc(page.title)}</h1>')
    ..writeln('<p class="tagline">${_esc(page.tagline)}</p>');

  for (final block in page.blocks) {
    if (split && block is TryIt) continue;
    prose.writeln(_block(block));
  }

  final body = StringBuffer();
  if (split) {
    body
      ..writeln('<div class="doc-split">')
      ..writeln('<div class="doc-main">')
      ..write(prose)
      ..writeln('</div>')
      ..writeln('<aside class="doc-demo">')
      ..write(demo)
      ..writeln('</aside>');
  } else {
    body.write(prose);
  }

  final int i = kDocs.indexWhere((p) => p.id == page.id);
  final DocPage? prev = i > 0 ? kDocs[i - 1] : null;
  final DocPage? next = i < kDocs.length - 1 ? kDocs[i + 1] : null;

  if (prev != null || next != null) {
    body.writeln('<nav class="pager">');
    if (prev != null) {
      body.writeln('<a href="${prev.id}.html"><span class="dir">PREVIOUS</span>'
          '${_esc(prev.title)}</a>');
    }
    if (next != null) {
      body.writeln('<a class="next" href="${next.id}.html">'
          '<span class="dir">NEXT</span>${_esc(next.title)}</a>');
    }
    body.writeln('</nav>');
  }

  if (split) body.writeln('</div>');

  return _shell(
    title: '${page.title} · Liquid Glass Easy',
    description: page.tagline,
    canonical: '${page.id}.html',
    currentId: page.id,
    wrapClass: split ? 'wrap wide' : 'wrap',
    body: body.toString(),
  );
}

String _landing() {
  final hero = kSiteDemos.first;
  final b = StringBuffer()
    ..writeln('<div class="hero">')
    ..writeln('<h1>Real glass for Flutter.</h1>')
    ..writeln('<p class="lede">A shader lens that refracts, magnifies and '
        'tints what is behind it, and answers a finger like a soft body — '
        'Apple&rsquo;s Liquid Glass, the iOS 26 and iOS 27 material, on '
        'Impeller and on the web.</p>')
    ..writeln('<div class="cta">')
    ..writeln('<a class="btn primary" href="${kDocs.first.id}.html">'
        'Get started</a>')
    ..writeln('<button class="btn mono copy-inline" type="button">'
        '<code>flutter pub add liquid_glass_easy</code></button>')
    ..writeln('<a class="btn" href="$kPubUrl">pub.dev ↗</a>')
    ..writeln('</div>')
    ..writeln('</div>')
    // The hero demo loads eagerly: it is the argument for the package, and
    // a lazy one would leave a hole above the fold.
    ..writeln('<figure class="demo" style="margin-top:34px">')
    ..writeln('<div class="demo-frame">')
    ..writeln('<iframe src="${_v(hero.embedHref)}" title="${_esc(hero.title)} '
        'demo" allow="clipboard-write"></iframe>')
    ..writeln('</div>')
    ..writeln('<figcaption>Live, in your browser — press the card and drag '
        'it. <a href="${_v(hero.href)}">Open full screen ↗</a></figcaption>')
    ..writeln('</figure>')
    ..writeln('<section class="section">')
    ..writeln('<h2>Documentation</h2>')
    ..writeln('<p class="sub">From installing it to the knobs you will '
        'actually turn.</p>')
    ..writeln('<div class="cards">');

  for (int i = 0; i < kDocs.length; i++) {
    final p = kDocs[i];
    b.writeln('<a class="card" href="${p.id}.html">'
        '<div class="t"><span class="n">${i + 1}</span>${_esc(p.title)}</div>'
        '<div class="d">${_esc(p.tagline)}</div></a>');
  }

  b
    ..writeln('</div>')
    ..writeln('</section>')
    ..writeln('<section class="section">')
    ..writeln('<h2>Live demos</h2>')
    ..writeln('<p class="sub">Running in your browser — not a recording. '
        'Each opens the demo app with its own notes and code.</p>')
    ..writeln('<div class="cards two">');

  for (final d in kSiteDemos.where((d) => d.feature)) {
    b.writeln('<a class="card" href="${_v(d.href)}">'
        '<div class="t">${_esc(d.title)}</div>'
        '<div class="d">${_esc(d.blurb)}</div></a>');
  }

  b
    ..writeln('</div>')
    ..writeln('</section>')
    ..writeln('<div class="note" style="margin-top:34px">')
    ..writeln('<span class="label">ON THE WEB</span>')
    ..writeln('<p>The web is always Skia, never Impeller, so every demo here '
        'is wrapped in a <code>LiquidGlassView</code> — otherwise the glass '
        'would degrade to a plain frosted blur. On a phone none of that setup '
        'is needed.</p>')
    ..writeln('</div>')
    ..writeln('<footer class="site">')
    ..writeln('<span>MIT · built by Ahmed Gamil</span>')
    ..writeln('<span><a href="$kRepoUrl">GitHub</a> · '
        '<a href="$kPubUrl">pub.dev</a> · v$kVersion</span>')
    ..writeln('</footer>');

  return _shell(
    title: 'Liquid Glass Easy — real glass for Flutter',
    description: 'Documentation and live browser demos for liquid_glass_easy: '
        'a Flutter package for Apple’s Liquid Glass, the iOS 26 and iOS 27 '
        'material — refraction, touch deformation, metaball blending and '
        'drop-in glass components.',
    canonical: 'index.html',
    body: b.toString(),
  );
}

// ── blocks ──────────────────────────────────────────────────────────

String _block(DocBlock block) {
  switch (block) {
    case Prose(:final text):
      return '<p>${_inline(text)}</p>';

    case Heading(:final text):
      final String id = _slug(text);
      return '<h2 id="$id">${_esc(text)}'
          '<a class="anchor" href="#$id" aria-label="Link to this section">#</a>'
          '</h2>';

    case Code(:final code, :final caption):
      final cap = caption == null
          ? ''
          : '<div class="caption">${_esc(caption).toUpperCase()}</div>';
      return '<div class="code">$cap'
          '<button class="copy" type="button">Copy</button>'
          '<pre><code>${_esc(code)}</code></pre></div>';

    case Bullets(:final items):
      final li = items.map((i) => '<li>${_inline(i)}</li>').join();
      return '<ul class="bullets">$li</ul>';

    case DocTable(:final headers, :final rows):
      final b = StringBuffer('<table><thead><tr>');
      for (final h in headers) {
        b.write('<th>${_esc(h)}</th>');
      }
      b.write('</tr></thead><tbody>');
      for (final row in rows) {
        b.write('<tr>');
        for (int c = 0; c < row.length; c++) {
          // data-label carries the header into the stacked mobile layout,
          // where <thead> is hidden.
          final label = c < headers.length ? _esc(headers[c]) : '';
          b.write('<td data-label="$label">${_inline(row[c])}</td>');
        }
        b.write('</tr>');
      }
      return (b..write('</tbody></table>')).toString();

    case Note(:final text, :final kind):
      final (String cls, String label) = switch (kind) {
        NoteKind.info => ('note', 'NOTE'),
        NoteKind.warn => ('note warn', 'WATCH OUT'),
        NoteKind.tip => ('note tip', 'TIP'),
      };
      return '<aside class="$cls"><span class="label">$label</span>'
          '<p>${_inline(text)}</p></aside>';

    case TryIt(:final demoId, :final label):
      final SiteDemo? demo = siteDemoById(demoId);
      if (demo == null) return '';
      // Lazy still: in the narrow layout the demo is at the bottom, so a
      // page nobody scrolls never downloads CanvasKit. In the wide one it
      // starts on screen, and loading it is the point.
      return '<figure class="demo">'
          '<div class="demo-frame">'
          '<iframe src="${_v(demo.embedHref)}" loading="lazy" '
          'title="${_esc(demo.title)} demo"></iframe>'
          '</div>'
          '<figcaption>${_esc(label)} — '
          '<a href="${_v(demo.href)}">open full screen ↗</a></figcaption>'
          '</figure>';
  }
}

// ── text ────────────────────────────────────────────────────────────

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Escapes first, then turns the inline marks into tags — so `<` inside a
/// sample is safe and the marks themselves survive escaping untouched.
String _inline(String raw) => _marks(_esc(raw));

/// The mark pass, on text that is already escaped. Split out so a link label
/// can be run through it without being escaped a second time.
String _marks(String s) {
  final b = StringBuffer();

  int i = 0;
  while (i < s.length) {
    if (s[i] == '`') {
      final int end = s.indexOf('`', i + 1);
      if (end > i) {
        b.write('<code>${s.substring(i + 1, end)}</code>');
        i = end + 1;
        continue;
      }
    }
    if (s[i] == '*' && i + 1 < s.length && s[i + 1] == '*') {
      final int end = s.indexOf('**', i + 2);
      if (end > i) {
        b.write('<strong>${s.substring(i + 2, end)}</strong>');
        i = end + 2;
        continue;
      }
    }
    // [label](href) — the third mark, for cross-page links.
    if (s[i] == '[') {
      final int close = s.indexOf(']', i + 1);
      if (close > i && close + 1 < s.length && s[close + 1] == '(') {
        final int end = s.indexOf(')', close + 2);
        if (end > close) {
          final String label = s.substring(i + 1, close);
          final String href = s.substring(close + 2, end);
          b.write('<a href="$href">${_marks(label)}</a>');
          i = end + 1;
          continue;
        }
      }
    }
    b.write(s[i]);
    i++;
  }
  return b.toString();
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

String _sitemap() {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final loc in ['index.html', ...kDocs.map((p) => '${p.id}.html')]) {
    b.writeln('  <url><loc>$siteBase/$loc</loc></url>');
  }
  return (b..writeln('</urlset>')).toString();
}

// ── files ───────────────────────────────────────────────────────────

Map<String, String> _flags(List<String> args) {
  final map = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    if (args[i].startsWith('--') && i + 1 < args.length) {
      map[args[i].substring(2)] = args[i + 1];
      i++;
    }
  }
  return map;
}

String _abs(Directory root, String path) =>
    path.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(path)
        ? path
        : '${root.path}/$path';

void _write(Directory dir, String name, String content) {
  File('${dir.path}/$name').writeAsStringSync(content);
}

void _copyDir(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync()) {
    final String name = entity.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .last;
    if (entity is Directory) {
      _copyDir(entity, Directory('${to.path}/$name'));
    } else if (entity is File) {
      entity.copySync('${to.path}/$name');
    }
  }
}

/// Retargets the Flutter app for a subdirectory.
///
/// `flutter build web` writes `<base href="/">`, which sends every asset
/// request to the domain root — fine when the app IS the site, fatal when it
/// lives at `/docs/demos/`. A relative base resolves against the app's own
/// folder wherever the site is hosted.
void _rebaseFlutterApp(File index) {
  if (!index.existsSync()) return;
  final String html = index.readAsStringSync();
  index.writeAsStringSync(
    html.replaceAll(RegExp(r'<base href="[^"]*">'), '<base href="./">'),
  );
}

/// FNV-1a over the file's bytes, as short hex. Not a security digest — it
/// only has to change when the bundle does.
/// Stamps a demo URL with the bundle's version, so a link or an iframe can
/// never resolve to a document the browser cached for the previous build.
String _v(String url) => demoVersion.isEmpty ? url : '$url&amp;v=$demoVersion';

String _hash(File f) {
  if (!f.existsSync()) return '';
  int h = 0xcbf29ce484222325;
  for (final int b in f.readAsBytesSync()) {
    h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(16, '0').substring(0, 10);
}

/// Takes the Flutter service worker out of the copied build.
///
/// An offline cache is wrong for this app. The demos are an island inside a
/// docs site that is rebuilt whenever the docs change, and a registered
/// worker keeps serving the *previous* `main.dart.js` until every tab is
/// closed — so a page can embed `?d=<new demo>`, the stale bundle will not
/// know that id, and the app silently falls back to its index. The symptom
/// reads as "the wrong demo is on this page" and no reload fixes it.
///
/// Two edits, because both halves matter: stop registering one, and unregister
/// whatever a previous visit already installed.
void _dropServiceWorker(File index, File bootstrap) {
  if (bootstrap.existsSync()) {
    String js = bootstrap.readAsStringSync().replaceAll(
          RegExp(r'serviceWorkerSettings:\s*\{[^}]*\}\s*,?\s*', dotAll: true),
          '',
        );
    // The entrypoint is fetched by name, so the name has to carry the build.
    if (demoVersion.isNotEmpty) {
      js = js.replaceAll('"mainJsPath":"main.dart.js"',
          '"mainJsPath":"main.dart.js?v=$demoVersion"');
    }
    bootstrap.writeAsStringSync(js);
  }

  if (!index.existsSync()) return;
  String html = index.readAsStringSync();
  if (demoVersion.isNotEmpty) {
    html = html.replaceAll(
        'src="flutter_bootstrap.js"', 'src="flutter_bootstrap.js?v=$demoVersion"');
  }
  if (html.contains('serviceWorker.getRegistrations')) return;
  index.writeAsStringSync(html.replaceFirst(
    '<body>',
    '<body>\n'
    '  <script>\n'
    "    // Kills a worker left by an older build of this site.\n"
    "    navigator.serviceWorker?.getRegistrations()\n"
    '      .then(function (rs) { rs.forEach(function (r) { r.unregister(); }); });\n'
    '  </script>',
  ));
}
