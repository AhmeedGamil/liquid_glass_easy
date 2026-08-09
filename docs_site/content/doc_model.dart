/// The documentation content model.
///
/// A page is a `const` list of blocks — data, not widgets. The renderer
/// decides how each block looks at the current width, which is what lets one
/// page be a two-column desktop layout and a single scrolling phone column
/// without the content being authored twice.
library;

/// One block of documentation content.
sealed class DocBlock {
  const DocBlock();
}

/// A paragraph. Text wrapped in `backticks` renders as inline code.
class Prose extends DocBlock {
  final String text;
  const Prose(this.text);
}

/// A section heading inside a page.
class Heading extends DocBlock {
  final String text;
  const Heading(this.text);
}

/// A copyable Dart (or YAML) sample.
class Code extends DocBlock {
  final String code;

  /// Optional line above the block saying what it is.
  final String? caption;

  const Code(this.code, {this.caption});
}

/// A short list. Each item supports the same `backtick` inline code.
class Bullets extends DocBlock {
  final List<String> items;
  const Bullets(this.items);
}

/// A reference table — the API surface, spelled out.
///
/// Cells support inline code too, so a defaults column can carry `1.0` in the
/// same face the code samples use.
class DocTable extends DocBlock {
  final List<String> headers;
  final List<List<String>> rows;

  /// Relative column widths. Must match [headers] in length when given.
  final List<int>? flex;

  const DocTable({required this.headers, required this.rows, this.flex});
}

/// What a callout is saying, which decides its colour and icon.
enum NoteKind {
  /// Worth knowing.
  info,

  /// Will cost you something if ignored.
  warn,

  /// A shortcut or a better default.
  tip,
}

class Note extends DocBlock {
  final String text;
  final NoteKind kind;
  const Note(this.text, {this.kind = NoteKind.info});
}

/// A link to the running demo that shows this page's subject.
///
/// Prose can describe a spring; only the demo can show you one. Every page
/// that has a matching demo ends with one of these.
class TryIt extends DocBlock {
  /// A `DemoEntry.id` from the demo registry.
  final String demoId;
  final String label;
  const TryIt(this.demoId, {required this.label});
}

/// One page of the docs, addressable as `?p=<id>`.
class DocPage {
  final String id;
  final String title;

  /// One line under the title, and the blurb on the index card.
  final String tagline;
  final List<DocBlock> blocks;

  /// The [id] of the page this one sits under, or null for a top-level page.
  ///
  /// Only the sidebar and the numbering care: a child is listed under its
  /// parent and left unnumbered. Reading order — prev/next, the sitemap — is
  /// the order of `kDocs`, parents and children alike.
  final String? parent;

  const DocPage({
    required this.id,
    required this.title,
    required this.tagline,
    required this.blocks,
    this.parent,
  });
}
