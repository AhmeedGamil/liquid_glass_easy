import 'package:flutter/widgets.dart';

import 'plate.dart';
import 'theme.dart';

// =============================================================
// The shop.
//
// An invented catalogue: twelve objects, six makers, four collections.
// Every product carries a HUE rather than a picture — the hue builds
// its plate, its plate builds its thumbnail, and the same hue lights
// the room when you open it. That is why pushing a product changes the
// colour of the whole page, glass included.
// =============================================================

/// One finish an object can be bought in. The swatch is drawn, not
/// photographed, so a colourway is two numbers and a name.
class Colourway {
  const Colourway(this.name, this.swatch, {this.hueShift = 0});

  final String name;
  final Color swatch;

  /// How far this finish moves the product's plate. Choosing "Ink"
  /// re-lights the whole page, which is most of why the picker feels
  /// like it is doing something.
  final double hueShift;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.maker,
    required this.kind,
    required this.hue,
    required this.price,
    required this.category,
    required this.line,
    required this.story,
    required this.spec,
    required this.colourways,
    this.was,
    this.madeToOrder = false,
  });

  final String id;
  final String name;
  final String maker;
  final ObjectKind kind;

  /// The one number the product's whole appearance comes from.
  final double hue;

  /// Pence. Prices are integers everywhere; only [money] ever divides.
  final int price;
  final int? was;

  final String category;

  /// One line, on the card.
  final String line;

  /// The paragraph on the product page.
  final String story;

  /// Rows in the details table.
  final List<(String, String)> spec;

  final List<Colourway> colourways;

  /// Shown instead of a delivery estimate. Some things are not in a
  /// warehouse.
  final bool madeToOrder;

  bool get reduced => was != null && was! > price;

  PlateTone tone([int colourway = 0]) => PlateTone.of(
      hue + (colourway < colourways.length ? colourways[colourway].hueShift : 0));
}

const List<Colourway> _stoneWays = <Colourway>[
  Colourway('Bone', Color(0xFFEDE6D9)),
  Colourway('Clay', Color(0xFFC08462), hueShift: -22),
  Colourway('Ink', Color(0xFF2C2F3A), hueShift: 168),
];

const List<Colourway> _woodWays = <Colourway>[
  Colourway('Oak', Color(0xFFD8B98C)),
  Colourway('Walnut', Color(0xFF6B4630), hueShift: -18),
  Colourway('Ash', Color(0xFFE3DCCE), hueShift: 26),
];

const List<Colourway> _metalWays = <Colourway>[
  Colourway('Brass', Color(0xFFC9A44C)),
  Colourway('Chrome', Color(0xFFC9CDD2), hueShift: 150),
];

const List<Product> kCatalogue = <Product>[
  Product(
    id: 'vessel-01',
    name: 'Aperture Vase',
    maker: 'Hale & Stone',
    kind: ObjectKind.vase,
    hue: 24,
    price: 14500,
    category: 'Vessels',
    line: 'Thrown in one piece, banded by hand',
    story:
        'Thrown on a slow wheel and left to stiffen overnight before the '
        'shoulder is turned, which is the only way to get a neck this narrow '
        'over a belly this wide. The band is laid on with a loaded brush in a '
        'single pass — where it thins, that is the pass ending.',
    spec: <(String, String)>[
      ('Material', 'Stoneware, matte glaze'),
      ('Dimensions', 'H 28cm · Ø 17cm'),
      ('Made in', 'Stoke-on-Trent'),
      ('Care', 'Wipe clean. Not dishwasher safe.'),
    ],
    colourways: _stoneWays,
  ),
  Product(
    id: 'light-01',
    name: 'Halo Table Lamp',
    maker: 'Vaness Atelier',
    kind: ObjectKind.lamp,
    hue: 42,
    price: 32000,
    was: 38000,
    category: 'Lighting',
    line: 'A dome, a stem, and nothing else',
    story:
        'The shade is spun from a single disc of aluminium, so there is no '
        'seam anywhere on it. Inside it is painted the warm off-white that '
        'makes the light land yellow rather than grey; outside it is whatever '
        'you chose.',
    spec: <(String, String)>[
      ('Material', 'Spun aluminium, oak stem'),
      ('Dimensions', 'H 44cm · Ø 34cm'),
      ('Fitting', 'E27, 6W LED included'),
      ('Cable', '2m, braided, in-line dimmer'),
    ],
    colourways: _metalWays,
  ),
  Product(
    id: 'seat-01',
    name: 'Low Chair No. 4',
    maker: 'Ostberg',
    kind: ObjectKind.chair,
    hue: 196,
    price: 68000,
    category: 'Seating',
    line: 'Steam-bent back, four splayed legs',
    story:
        'The fourth attempt, and the first one that could be sat in sideways. '
        'The back is bent in one piece over a two-hour steam, then held in the '
        'jig for a fortnight — the wait is the product.',
    spec: <(String, String)>[
      ('Material', 'Steam-bent ash, oiled'),
      ('Dimensions', 'H 74cm · W 52cm · D 49cm'),
      ('Seat height', '43cm'),
      ('Lead time', 'Made to order, 6–8 weeks'),
    ],
    colourways: _woodWays,
    madeToOrder: true,
  ),
  Product(
    id: 'table-01',
    name: 'Morning Mug',
    maker: 'Hale & Stone',
    kind: ObjectKind.mug,
    hue: 8,
    price: 3800,
    category: 'Tabletop',
    line: 'Heavy at the base, thin at the lip',
    story:
        'Weighted low so it does not go over, and thinned at the rim so it '
        'does not feel like drinking from a brick. Those two things fight each '
        'other, which is why it took four years.',
    spec: <(String, String)>[
      ('Material', 'Stoneware, satin glaze'),
      ('Capacity', '340ml'),
      ('Dimensions', 'H 9.5cm · Ø 8.5cm'),
      ('Care', 'Dishwasher and microwave safe'),
    ],
    colourways: _stoneWays,
  ),
  Product(
    id: 'table-02',
    name: 'Field Bottle',
    maker: 'Cormorant',
    kind: ObjectKind.bottle,
    hue: 128,
    price: 5600,
    category: 'Tabletop',
    line: 'For oil, for water, for the table',
    story:
        'Blown into a wooden mould that has been used since the sixties, so no '
        'two shoulders are quite the same width. The label is letterpressed on '
        'the same afternoon the bottle is filled.',
    spec: <(String, String)>[
      ('Material', 'Recycled glass, cork and brass stopper'),
      ('Capacity', '500ml'),
      ('Dimensions', 'H 26cm · Ø 8cm'),
      ('Care', 'Hand wash'),
    ],
    colourways: _stoneWays,
  ),
  Product(
    id: 'time-01',
    name: 'Station Clock',
    maker: 'Merrow Instruments',
    kind: ObjectKind.clock,
    hue: 214,
    price: 24500,
    category: 'Time',
    line: 'Sweep movement, no tick',
    story:
        'The dial is printed rather than applied, so it will not lift in a '
        'bathroom. A sweep movement instead of a stepping one, because the '
        'whole argument for a clock in a bedroom falls apart the moment you '
        'can hear it.',
    spec: <(String, String)>[
      ('Material', 'Powder-coated steel, glass lens'),
      ('Dimensions', 'Ø 30cm · D 5cm'),
      ('Movement', 'Silent sweep quartz'),
      ('Power', 'One AA, about two years'),
    ],
    colourways: _metalWays,
  ),
  Product(
    id: 'sound-01',
    name: 'Column Speaker',
    maker: 'Merrow Instruments',
    kind: ObjectKind.speaker,
    hue: 268,
    price: 44000,
    was: 52000,
    category: 'Sound',
    line: 'One driver, done properly',
    story:
        'A single full-range driver in a sealed column, which is the arrangement '
        'that stops a small speaker sounding like two speakers arguing. It will '
        'not shake a room. It will hold a voice exactly where you put it.',
    spec: <(String, String)>[
      ('Material', 'MDF cabinet, wool felt front'),
      ('Dimensions', 'H 38cm · W 14cm · D 14cm'),
      ('Connection', 'Wi-Fi, Bluetooth 5.3, 3.5mm'),
      ('In the box', 'Speaker, braided cable, felt feet'),
    ],
    colourways: _woodWays,
  ),
  Product(
    id: 'mirror-01',
    name: 'Arch Mirror',
    maker: 'Vaness Atelier',
    kind: ObjectKind.mirror,
    hue: 336,
    price: 39500,
    category: 'Mirrors',
    line: 'Leans, or hangs. It prefers to lean.',
    story:
        'Cut as a true half-round rather than a rectangle with the corners '
        'taken off, which you can only see when it is next to one that is not. '
        'Comes with a wall strap and a rubber foot; most people use the foot.',
    spec: <(String, String)>[
      ('Material', 'Poplar frame, 4mm silvered glass'),
      ('Dimensions', 'H 120cm · W 78cm'),
      ('Weight', '11kg'),
      ('Fixings', 'Strap and foot included'),
    ],
    colourways: _woodWays,
  ),
  Product(
    id: 'vessel-02',
    name: 'Wide Bowl',
    maker: 'Hale & Stone',
    kind: ObjectKind.bowl,
    hue: 58,
    price: 9800,
    category: 'Vessels',
    line: 'Shallow enough to serve from',
    story:
        'Wide and low, so what is in it is the thing you see rather than the '
        'bowl. The glaze is allowed to pool at the rim and is not corrected — '
        'that ring is where the piece stopped moving.',
    spec: <(String, String)>[
      ('Material', 'Stoneware, reactive glaze'),
      ('Dimensions', 'H 9cm · Ø 32cm'),
      ('Made in', 'Stoke-on-Trent'),
      ('Care', 'Dishwasher safe'),
    ],
    colourways: _stoneWays,
  ),
  Product(
    id: 'light-02',
    name: 'Hour Candle',
    maker: 'Cormorant',
    kind: ObjectKind.candle,
    hue: 16,
    price: 2800,
    category: 'Lighting',
    line: 'Fig, cedar, and something like rain',
    story:
        'Poured in small batches at a low temperature so the surface sets flat '
        'instead of cratering. Burns about fifty hours, and the dish is meant '
        'to be kept.',
    spec: <(String, String)>[
      ('Scent', 'Fig leaf, cedar, wet stone'),
      ('Burn time', 'About 50 hours'),
      ('Dimensions', 'H 11cm · Ø 8cm'),
      ('Wax', 'Rapeseed and coconut'),
    ],
    colourways: _stoneWays,
  ),
  Product(
    id: 'seat-02',
    name: 'Reading Chair',
    maker: 'Ostberg',
    kind: ObjectKind.chair,
    hue: 96,
    price: 84000,
    category: 'Seating',
    line: 'Deep, low, and hard to get out of',
    story:
        'Built at the angle you end up at anyway, about twenty minutes into a '
        'book. The seat is webbed rather than sprung, so it gives once and then '
        'holds instead of sinking all evening.',
    spec: <(String, String)>[
      ('Material', 'Oiled oak, wool webbing'),
      ('Dimensions', 'H 78cm · W 66cm · D 74cm'),
      ('Seat height', '38cm'),
      ('Lead time', 'Made to order, 8–10 weeks'),
    ],
    colourways: _woodWays,
    madeToOrder: true,
  ),
  Product(
    id: 'time-02',
    name: 'Desk Clock',
    maker: 'Merrow Instruments',
    kind: ObjectKind.clock,
    hue: 178,
    price: 15500,
    category: 'Time',
    line: 'Small, brass, and slightly too heavy',
    story:
        'Weighted so it stays where it is put on a desk that gets leaned on. '
        'The lens is glass rather than acrylic, which is the whole difference '
        'between an object and a thing.',
    spec: <(String, String)>[
      ('Material', 'Solid brass, glass lens'),
      ('Dimensions', 'Ø 11cm · D 4cm'),
      ('Movement', 'Silent sweep quartz'),
      ('Weight', '640g'),
    ],
    colourways: _metalWays,
  ),
];

Product productById(String id) =>
    kCatalogue.firstWhere((Product p) => p.id == id);

// ── The rest of the shop ─────────────────────────────────────

class Collection {
  const Collection({
    required this.title,
    required this.strap,
    required this.hue,
    required this.kind,
    required this.ids,
  });

  final String title;
  final String strap;
  final double hue;

  /// The object on the collection's own plate.
  final ObjectKind kind;
  final List<String> ids;

  PlateTone get tone => PlateTone.of(hue);
  List<Product> get products => ids.map(productById).toList();
}

const List<Collection> kCollections = <Collection>[
  Collection(
    title: 'The Quiet Room',
    strap: 'Eleven things that do not ask for anything',
    hue: 210,
    kind: ObjectKind.mirror,
    ids: <String>['mirror-01', 'seat-01', 'light-01', 'time-01'],
  ),
  Collection(
    title: 'Second Firing',
    strap: 'Seconds, sold as seconds, priced as seconds',
    hue: 26,
    kind: ObjectKind.vase,
    ids: <String>['vessel-01', 'vessel-02', 'table-01'],
  ),
  Collection(
    title: 'For the Table',
    strap: 'Everything that ends up in the middle of it',
    hue: 128,
    kind: ObjectKind.bowl,
    ids: <String>['table-01', 'table-02', 'vessel-02', 'light-02'],
  ),
  Collection(
    title: 'Long Evenings',
    strap: 'Lamps, wax, and one speaker',
    hue: 274,
    kind: ObjectKind.candle,
    ids: <String>['light-02', 'light-01', 'sound-01'],
  ),
];

class Maker {
  const Maker(this.name, this.where, this.since, this.hue);

  final String name;
  final String where;
  final String since;
  final double hue;
}

const List<Maker> kMakers = <Maker>[
  Maker('Hale & Stone', 'Stoke-on-Trent', '1974', 22),
  Maker('Vaness Atelier', 'Lisbon', '2009', 340),
  Maker('Ostberg', 'Malmö', '1961', 198),
  Maker('Merrow Instruments', 'Bristol', '1988', 220),
  Maker('Cormorant', 'Whitstable', '2016', 132),
];

/// The shelves. Order matters — this is the order Browse shows them in.
const List<(String, ObjectKind, double)> kCategories =
    <(String, ObjectKind, double)>[
  ('Vessels', ObjectKind.vase, 24),
  ('Lighting', ObjectKind.lamp, 44),
  ('Seating', ObjectKind.chair, 196),
  ('Tabletop', ObjectKind.mug, 8),
  ('Time', ObjectKind.clock, 214),
  ('Sound', ObjectKind.speaker, 268),
  ('Mirrors', ObjectKind.mirror, 336),
];

List<Product> productsIn(String category) =>
    kCatalogue.where((Product p) => p.category == category).toList();

const List<String> kSearchSuggestions = <String>[
  'stoneware',
  'made to order',
  'under £100',
  'Ostberg',
  'brass',
];

// ── The bag ──────────────────────────────────────────────────

/// One line of the bag: what, in which finish, how many.
class BagLine {
  BagLine({required this.product, required this.colourway, this.qty = 1});

  final Product product;
  final int colourway;
  int qty;

  int get total => product.price * qty;
  String get key => '${product.id}/$colourway';
}

/// The shop's only real state.
///
/// A plain [ChangeNotifier] behind an [InheritedNotifier], which is all
/// a bag needs: five pages read it, three write to it, and the tab bar
/// wants a count. See [BagScope].
class Bag extends ChangeNotifier {
  final List<BagLine> _lines = <BagLine>[];
  final Set<String> _saved = <String>{};

  /// Set by the last add, and cleared by the bag page. It is what makes
  /// the newest line able to arrive highlighted.
  String? lastAdded;

  List<BagLine> get lines => List<BagLine>.unmodifiable(_lines);
  int get count => _lines.fold(0, (int n, BagLine l) => n + l.qty);
  int get subtotal => _lines.fold(0, (int n, BagLine l) => n + l.total);

  /// Free over two hundred, which is the number the banner quotes.
  int get delivery => _lines.isEmpty || subtotal >= 20000 ? 0 : 695;
  int get total => subtotal + delivery;

  void add(Product p, int colourway) {
    final String key = '${p.id}/$colourway';
    final BagLine? found =
        _lines.where((BagLine l) => l.key == key).firstOrNull;
    if (found != null) {
      found.qty++;
    } else {
      _lines.insert(0, BagLine(product: p, colourway: colourway));
    }
    lastAdded = key;
    notifyListeners();
  }

  void setQty(BagLine line, int qty) {
    if (qty <= 0) {
      _lines.remove(line);
    } else {
      line.qty = qty;
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    lastAdded = null;
    notifyListeners();
  }

  // ── Saved ──
  bool isSaved(String id) => _saved.contains(id);
  List<Product> get savedProducts =>
      kCatalogue.where((Product p) => _saved.contains(p.id)).toList();

  void toggleSaved(String id) {
    _saved.contains(id) ? _saved.remove(id) : _saved.add(id);
    notifyListeners();
  }
}

/// Puts the [Bag] in the tree and rebuilds anything that read it.
class BagScope extends InheritedNotifier<Bag> {
  const BagScope({super.key, required Bag bag, required super.child})
      : super(notifier: bag);

  static Bag of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BagScope>()!.notifier!;

  /// For callbacks that only want to WRITE — reading through [of] in a
  /// build would subscribe the whole page to every quantity change.
  static Bag read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BagScope>()!.notifier!;
}
