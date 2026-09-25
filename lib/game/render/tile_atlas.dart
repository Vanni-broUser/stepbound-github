import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:stepbound/game/render/asset_image.dart';

/// The tile atlas a converted place is painted from: the art that used to
/// be baked into assets/levels, cut into cells the size of a level tile,
/// with a rule for every glyph saying which cell to take. Made by
/// tools/build_tile_atlas.py, whose docstring is the other half of this
/// contract.
///
/// The place's ASCII rows stay the only place its layout is written down:
/// nothing here knows where anything is, only what a glyph looks like and
/// how its look changes with its neighbours.
const String tileAtlasManifestPath = 'assets/tiles/atlas_manifest.json';

/// The glyphs of a place, as the rules read them.
final class GlyphGrid {
  GlyphGrid(this.rows, {this.outside = 'x', this.ground});

  final List<String> rows;

  /// What lies beyond the edge of the place: the void indoors, more city
  /// outdoors.
  final String outside;

  /// How an outdoor place finds the floor under a cell, if it does.
  final GroundConfig? ground;

  final Map<String, int> _firstRows = <String, int>{};
  late final List<String> _groundRows = ground?.resolve(this) ?? rows;

  int get width => rows.first.length;
  int get height => rows.length;

  bool _inside(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  /// The glyph at [x], [y]; beyond the edge, [outside].
  String glyphAt(int x, int y) => _inside(x, y) ? rows[y][x] : outside;

  /// The floor under [x], [y]: its own glyph, unless [ground] finds it
  /// another (see [GroundConfig]).
  String groundAt(int x, int y) => _inside(x, y) ? _groundRows[y][x] : outside;

  /// The first row holding [glyph], 0 if none does. The platform edge is
  /// the first row with a slab on it, and it is painted differently.
  int firstRowOf(String glyph) => _firstRows.putIfAbsent(glyph, () {
    for (var y = 0; y < height; y++) {
      if (rows[y].contains(glyph)) {
        return y;
      }
    }
    return 0;
  });
}

/// How an outdoor place finds the floor under a cell that is not a floor:
/// a car stands on the carriageway, a lamp post on the pavement, a bench in
/// the park on the lawn. The rules of the ground layer match that floor.
///
/// It is `Level.surface` of tools/build_street_level.py, which the atlas's
/// reference draw calls, so `build_tile_atlas.py --compare` holds the two
/// to the same answer.
final class GroundConfig {
  const GroundConfig({
    required this.buildings,
    required this.roads,
    required this.walks,
    required this.floors,
    required this.footway,
    required this.keep,
    required this.lawn,
    required this.lawnProps,
  });

  factory GroundConfig.fromJson(Map<String, Object?> json) => GroundConfig(
    buildings: json['buildings']! as String,
    roads: json['roads']! as String,
    walks: json['walks']! as String,
    floors: json['floors']! as String,
    footway: json['footway']! as String,
    keep: json['keep']! as String,
    lawn: json['lawn']! as String,
    lawnProps: json['lawnProps']! as String,
  );

  /// Glyphs with no floor under them at all.
  final String buildings;

  /// Glyphs that are the carriageway, whose floor is `.`.
  final String roads;

  /// Glyphs that are the pavement, whose floor is `=`.
  final String walks;

  /// Glyphs that are a floor of their own: paving, a car park, stairs.
  final String floors;

  /// Street furniture: it looks for its floor up and down its column as
  /// well as along its row, since it stands on a footway, not in the road.
  final String footway;

  /// Glyphs that keep their own glyph as their floor: the sea, the pier.
  final String keep;

  /// The lawn, and the props that stand on it when they are next to it.
  final String lawn;
  final String lawnProps;

  static const String _road = '.';
  static const String _walk = '=';

  /// The floors in the order a tie between them is settled.
  String get _order => '$_walk$_road$floors';

  String? _floor(String glyph) {
    if (walks.contains(glyph)) {
      return _walk;
    }
    if (roads.contains(glyph)) {
      return _road;
    }
    if (floors.contains(glyph)) {
      return glyph;
    }
    return null;
  }

  /// The floor under every cell of [grid], row by row.
  List<String> resolve(GlyphGrid grid) => <String>[
    for (var y = 0; y < grid.height; y++)
      <String>[for (var x = 0; x < grid.width; x++) _at(grid, x, y)].join(),
  ];

  String _at(GlyphGrid grid, int x, int y) {
    final glyph = grid.glyphAt(x, y);
    if (buildings.contains(glyph) || keep.contains(glyph)) {
      return glyph;
    }
    if (lawnProps.contains(glyph) &&
        (grid.glyphAt(x - 1, y) == lawn ||
            grid.glyphAt(x + 1, y) == lawn ||
            grid.glyphAt(x, y - 1) == lawn ||
            grid.glyphAt(x, y + 1) == lawn)) {
      return lawn;
    }
    return _surface(grid, x, y);
  }

  /// The nearest floor from [x], [y] one way, and how many cells off it
  /// is, never looking through a building.
  (String?, int) _floorAlong(GlyphGrid grid, int x, int y, int dx, int dy) {
    var nx = x + dx;
    var ny = y + dy;
    var away = 1;
    while (nx >= 0 &&
        ny >= 0 &&
        nx < grid.width &&
        ny < grid.height &&
        !buildings.contains(grid.rows[ny][nx])) {
      final floor = _floor(grid.rows[ny][nx]);
      if (floor != null) {
        return (floor, away);
      }
      nx += dx;
      ny += dy;
      away++;
    }
    return (null, 0);
  }

  String _surface(GlyphGrid grid, int x, int y) {
    final glyph = grid.glyphAt(x, y);
    final own = _floor(glyph);
    if (own != null) {
      return own;
    }
    final onFootway = footway.contains(glyph);
    final found = <(String?, int)>[
      _floorAlong(grid, x, y, -1, 0),
      _floorAlong(grid, x, y, 1, 0),
      if (onFootway) ...<(String?, int)>[
        _floorAlong(grid, x, y, 0, -1),
        _floorAlong(grid, x, y, 0, 1),
      ],
    ];
    int? nearest;
    for (final (floor, away) in found) {
      if (floor != null && (nearest == null || away < nearest)) {
        nearest = away;
      }
    }
    var near = <String>[
      for (final (floor, away) in found)
        if (floor != null && away == nearest) floor,
    ];
    if (onFootway && near.any((floor) => floor != _road)) {
      near = <String>[
        for (final floor in near)
          if (floor != _road) floor,
      ];
    }
    if (near.toSet().length == 1) {
      return near.first;
    }
    final order = _order;
    final votes = <String, int>{for (final f in order.split('')) f: 0};
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final g = grid.glyphAt(x + dx, y + dy);
        final weight = dy == 0 ? 2 : 1;
        final floor = walks.contains(g)
            ? _walk
            : roads.contains(g)
            ? _road
            : floors.contains(g)
            ? g
            : null;
        if (floor != null) {
          votes[floor] = votes[floor]! + weight;
        }
      }
    }
    int count(String f) => near.where((n) => n == f).length;
    final candidates = near.isEmpty ? order.split('') : near;
    var best = candidates.first;
    for (final floor in candidates.skip(1)) {
      final byNear = count(floor).compareTo(count(best));
      final byVotes = votes[floor]!.compareTo(votes[best]!);
      final byOrder = order.indexOf(best).compareTo(order.indexOf(floor));
      if (byNear > 0 ||
          (byNear == 0 && (byVotes > 0 || (byVotes == 0 && byOrder > 0)))) {
        best = floor;
      }
    }
    return best;
  }
}

/// One yes-or-no question about a cell. A rule asks a few of them and
/// their answers, read as bits, choose the bucket of tiles to draw from.
sealed class TileKey {
  const TileKey();

  factory TileKey.fromJson(Map<String, Object?> json) {
    final kind = json['kind']! as String;
    return switch (kind) {
      'parity' => const ParityKey(),
      'neighbour' => NeighbourKey(
        dx: (json['dx']! as num).toInt(),
        dy: (json['dy']! as num).toInt(),
        glyphs: json['glyphs']! as String,
        ground: json['ground'] == true,
      ),
      'any' => AnyKey(
        cells: <(int, int)>[
          for (final cell in json['cells']! as List<Object?>) _pair(cell)!,
        ],
        glyphs: json['glyphs']! as String,
      ),
      'pattern' => PatternKey(
        a: (json['a']! as num).toInt(),
        b: (json['b']! as num).toInt(),
        mod: (json['mod']! as num).toInt(),
        equals: (json['equals']! as num).toInt(),
        divX: (json['divX'] as num?)?.toInt() ?? 1,
        divY: (json['divY'] as num?)?.toInt() ?? 1,
        values: (json['values'] as List<Object?>?)
            ?.map((value) => (value! as num).toInt())
            .toSet(),
      ),
      'firstRow' => FirstRowKey(
        glyph: json['glyph']! as String,
        offset: (json['offset']! as num).toInt(),
        atMost: json['compare'] == 'le',
      ),
      'beforeRun' => BeforeRunKey(glyphs: json['glyphs']! as String),
      'between' => BetweenKey(glyph: json['glyph']! as String),
      'rowHas' => RowHasKey(
        dy: (json['dy']! as num).toInt(),
        glyph: json['glyph']! as String,
      ),
      _ => throw FormatException('unknown tile key "$kind"'),
    };
  }

  bool holds(GlyphGrid grid, int x, int y);
}

/// Which way the floor alternates: the bakers lay their slabs on the
/// parity of x + y.
final class ParityKey extends TileKey {
  const ParityKey();

  @override
  bool holds(GlyphGrid grid, int x, int y) => (x + y).isOdd;
}

/// Whether the cell [dx], [dy] away shows one of [glyphs]: what tells a
/// wall it is the top course, a bench that it is the end of the row. With
/// [ground] it asks about the floor under that cell instead.
final class NeighbourKey extends TileKey {
  const NeighbourKey({
    required this.dx,
    required this.dy,
    required this.glyphs,
    this.ground = false,
  });

  final int dx;
  final int dy;
  final String glyphs;
  final bool ground;

  @override
  bool holds(GlyphGrid grid, int x, int y) => glyphs.contains(
    ground ? grid.groundAt(x + dx, y + dy) : grid.glyphAt(x + dx, y + dy),
  );
}

/// Whether any of the [cells] round this one shows one of [glyphs]: the
/// ground is scorched all round the crashed airliner.
final class AnyKey extends TileKey {
  const AnyKey({required this.cells, required this.glyphs});

  final List<(int, int)> cells;
  final String glyphs;

  @override
  bool holds(GlyphGrid grid, int x, int y) => cells.any(
    (cell) => glyphs.contains(grid.glyphAt(x + cell.$1, y + cell.$2)),
  );
}

/// A pattern the bakers write straight into the position, like the
/// graffiti on every ninth stretch of station wall. [divX] and [divY] read
/// the position in blocks of that many cells, as the roofs of the city are
/// laid out; [values], if given, accepts any of those remainders.
final class PatternKey extends TileKey {
  const PatternKey({
    required this.a,
    required this.b,
    required this.mod,
    required this.equals,
    this.divX = 1,
    this.divY = 1,
    this.values,
  });

  final int a;
  final int b;
  final int mod;
  final int equals;
  final int divX;
  final int divY;
  final Set<int>? values;

  @override
  bool holds(GlyphGrid grid, int x, int y) {
    final value = ((x ~/ divX) * a + (y ~/ divY) * b) % mod;
    return values?.contains(value) ?? value == equals;
  }
}

/// Where the cell lies against the first row holding [glyph]: on that row
/// ([atMost] false) or no lower than it ([atMost] true).
final class FirstRowKey extends TileKey {
  const FirstRowKey({
    required this.glyph,
    required this.offset,
    required this.atMost,
  });

  final String glyph;
  final int offset;
  final bool atMost;

  @override
  bool holds(GlyphGrid grid, int x, int y) {
    final row = grid.firstRowOf(glyph) + offset;
    return atMost ? y <= row : y == row;
  }
}

/// Whether something other than [glyph] lies above the cell in its column
/// and something other than [glyph] lies below it: what tells the gap
/// between two roofs, which is dark all the way down, from the darkness
/// off the edge of the map.
final class BetweenKey extends TileKey {
  const BetweenKey({required this.glyph});

  final String glyph;

  @override
  bool holds(GlyphGrid grid, int x, int y) {
    var above = false;
    for (var row = 0; row < y && !above; row++) {
      above = grid.glyphAt(x, row) != glyph;
    }
    var below = false;
    for (var row = y + 1; row < grid.height && !below; row++) {
      below = grid.glyphAt(x, row) != glyph;
    }
    return above && below;
  }
}

/// What lies before the run this cell belongs to: walk west along the row
/// while the glyph stays the cell's own, and ask whether the cell where it
/// stops shows one of [glyphs]. A camp bed three tiles long has its pillow
/// at the end against a wall, and the middle tile has to know which end.
final class BeforeRunKey extends TileKey {
  const BeforeRunKey({required this.glyphs});

  final String glyphs;

  @override
  bool holds(GlyphGrid grid, int x, int y) {
    final glyph = grid.glyphAt(x, y);
    var start = x;
    while (grid.glyphAt(start - 1, y) == glyph) {
      start--;
    }
    return glyphs.contains(grid.glyphAt(start - 1, y));
  }
}

/// Whether the row [dy] away holds [glyph] anywhere: the aisle of a cabin is
/// every row with no seat in it, whatever the columns say.
final class RowHasKey extends TileKey {
  const RowHasKey({required this.dy, required this.glyph});

  final int dy;
  final String glyph;

  @override
  bool holds(GlyphGrid grid, int x, int y) {
    final row = y + dy;
    return row >= 0 && row < grid.height && grid.rows[row].contains(glyph);
  }
}

/// Where a rule draws beyond its own cell: [dx], [dy] away, one tile per
/// tile of each bucket, so the choice of variant that picks the cell's
/// tile picks the piece that goes with it and a picture never comes apart.
final class TilePiece {
  const TilePiece({required this.dx, required this.dy, required this.buckets});

  factory TilePiece.fromJson(Map<String, Object?> json) => TilePiece(
    dx: (json['dx']! as num).toInt(),
    dy: (json['dy']! as num).toInt(),
    buckets: _buckets(json['buckets']),
  );

  final int dx;
  final int dy;
  final List<List<int>> buckets;
}

/// Two numbers written as a JSON list, `[x, y]`, if there are any.
(int, int)? _pair(Object? json) {
  if (json == null) {
    return null;
  }
  final list = json as List<Object?>;
  return ((list[0]! as num).toInt(), (list[1]! as num).toInt());
}

List<List<int>> _buckets(Object? json) => <List<int>>[
  for (final bucket in json! as List<Object?>)
    <int>[for (final tile in bucket! as List<Object?>) (tile! as num).toInt()],
];

/// For these [glyphs], on this [layer], take a tile out of the bucket the
/// [keys] point at. An empty bucket draws nothing.
///
/// A rule may also draw beyond its cell, [pieces]: what a monitor on a desk
/// leans out over the cell above, or the second half of a car two cells
/// long.
///
/// The ground layer matches the floor under a cell ([GlyphGrid.groundAt]),
/// every other layer its glyph; [onGround] says which this rule does.
final class TileRule {
  const TileRule({
    required this.layer,
    required this.glyphs,
    required this.keys,
    required this.buckets,
    this.pieces = const <TilePiece>[],
    bool? onGround,
  }) : onGround = onGround ?? layer == 'ground';

  factory TileRule.fromJson(Map<String, Object?> json) {
    final keys = <TileKey>[
      for (final key in json['keys']! as List<Object?>)
        TileKey.fromJson(key! as Map<String, Object?>),
    ];
    final buckets = _buckets(json['buckets']);
    if (buckets.length != 1 << keys.length) {
      throw FormatException(
        'a rule with ${keys.length} keys needs ${1 << keys.length} '
        'buckets, not ${buckets.length}',
      );
    }
    final pieces = <TilePiece>[
      for (final piece in json['pieces'] as List<Object?>? ?? const <Object?>[])
        TilePiece.fromJson(piece! as Map<String, Object?>),
    ];
    for (final piece in pieces) {
      if (piece.buckets.length != buckets.length) {
        throw const FormatException('a piece needs a bucket per bucket');
      }
      for (var i = 0; i < buckets.length; i++) {
        if (piece.buckets[i].isNotEmpty &&
            piece.buckets[i].length != buckets[i].length) {
          throw const FormatException(
            'a piece must hold as many tiles as its bucket, or the pieces '
            'of a picture would part',
          );
        }
      }
    }
    final on = json['on'] as String?;
    return TileRule(
      layer: json['layer']! as String,
      glyphs: json['glyphs']! as String,
      keys: keys,
      buckets: buckets,
      pieces: pieces,
      onGround: on == null ? null : on == 'ground',
    );
  }

  final String layer;
  final String glyphs;
  final List<TileKey> keys;
  final List<List<int>> buckets;
  final List<TilePiece> pieces;
  final bool onGround;

  bool covers(String glyph) => glyphs.contains(glyph);

  /// The glyph this rule matches at [x], [y].
  String matched(GlyphGrid grid, int x, int y) =>
      onGround ? grid.groundAt(x, y) : grid.glyphAt(x, y);

  /// Which bucket this cell draws from.
  int bucketIndex(GlyphGrid grid, int x, int y) {
    var index = 0;
    for (var bit = 0; bit < keys.length; bit++) {
      if (keys[bit].holds(grid, x, y)) {
        index |= 1 << bit;
      }
    }
    return index;
  }

  /// The tiles this cell may be drawn with.
  List<int> bucketFor(GlyphGrid grid, int x, int y) =>
      buckets[bucketIndex(grid, x, y)];
}

/// Something too big for one cell -- a railcar, a door two tiles high --
/// drawn over the run of its [glyph]. [tiles] is the size that run has to
/// be, checked by test/levels/tile_atlas_test.dart against the rows.
///
/// An object that is not one run of a glyph -- the shopfronts along a wall,
/// each with its own name, or the nose of a train, which follows the shape
/// of its windscreen -- says where it goes, [at], and carries the rows it
/// was painted over, [under]: the test fails when they are no longer the
/// rows of the place, so a picture is never left over an arrangement it
/// was not painted for.
final class TileObject {
  const TileObject({
    required this.glyph,
    required this.image,
    required this.offsetY,
    required this.tiles,
    required this.whenOpen,
    this.at,
    this.under,
    this.underAt,
  });

  factory TileObject.fromJson(Map<String, Object?> json) => TileObject(
    glyph: json['glyph'] as String?,
    image: json['image']! as String,
    offsetY: (json['offsetY'] as num?)?.toInt() ?? 0,
    tiles: _pair(json['tiles']),
    whenOpen: json['whenOpen'] as String?,
    at: _pair(json['at']),
    under: <String>[
      for (final row in json['under'] as List<Object?>? ?? const <Object?>[])
        row! as String,
    ],
    underAt: _pair(json['underAt']),
  );

  /// The glyph whose run it is drawn over, unless it says [at].
  final String? glyph;
  final String image;

  /// The top-left cell it is drawn from, when it does not follow a glyph.
  final (int, int)? at;

  /// The rows of the place it was painted over, from [underCorner].
  final List<String>? under;

  /// Where [under] starts, if not at [at]: a building's picture reaches
  /// past its own cells -- the light from its door over the pavement --
  /// and it is its own cells that it was painted for.
  final (int, int)? underAt;

  /// The top-left cell of [under].
  (int, int)? get underCorner => underAt ?? at;

  /// How far above its glyph the image starts, in tiles.
  final int offsetY;

  /// The size of the run of [glyph] this image was painted for.
  final (int, int)? tiles;

  /// A second image, for when the story has opened it.
  final String? whenOpen;
}

/// Everything the renderer needs for one converted place.
final class TilePlaceArt {
  const TilePlaceArt({
    required this.voidColour,
    required this.voidGlyph,
    required this.rules,
    required this.objects,
    this.outside = 'x',
    this.ground,
  });

  factory TilePlaceArt.fromJson(Map<String, Object?> json) {
    final ground = json['ground'] as Map<String, Object?>?;
    return TilePlaceArt(
      voidColour: _colour(json['void']! as String),
      voidGlyph: json['voidGlyph']! as String,
      rules: <TileRule>[
        for (final rule in json['rules']! as List<Object?>)
          TileRule.fromJson(rule! as Map<String, Object?>),
      ],
      objects: <TileObject>[
        for (final object in json['objects']! as List<Object?>)
          TileObject.fromJson(object! as Map<String, Object?>),
      ],
      outside: json['outside'] as String? ?? 'x',
      ground: ground == null ? null : GroundConfig.fromJson(ground),
    );
  }

  static ui.Color _colour(String hex) =>
      ui.Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

  /// What shows where the place does not reach.
  final ui.Color voidColour;

  /// The glyph that is meant to stay empty: nothing paints it.
  final String voidGlyph;
  final List<TileRule> rules;
  final List<TileObject> objects;

  /// What lies past the edge of the place, for the rules that look there.
  final String outside;

  /// How an outdoor place finds the floor under its props, if it does.
  final GroundConfig? ground;

  /// The rows of a place, as this art's rules read them.
  GlyphGrid gridFor(List<String> rows) =>
      GlyphGrid(rows, outside: outside, ground: ground);

  /// The glyphs of the cells nothing paints -- no rule, no object over
  /// them: a place with any of these would be drawn with holes in it.
  Set<String> unpainted(GlyphGrid grid) {
    final covered = <(int, int)>{};
    for (final object in objects) {
      final corner = object.underCorner;
      final under = object.under;
      if (corner == null || under == null || under.isEmpty) {
        continue;
      }
      for (var y = 0; y < under.length; y++) {
        for (var x = 0; x < under.first.length; x++) {
          covered.add((corner.$1 + x, corner.$2 + y));
        }
      }
    }
    final glyphObjects = <String?>{for (final o in objects) o.glyph};
    return <String>{
      for (var y = 0; y < grid.height; y++)
        for (var x = 0; x < grid.width; x++)
          if (grid.glyphAt(x, y) != voidGlyph &&
              !covered.contains((x, y)) &&
              !glyphObjects.contains(grid.glyphAt(x, y)) &&
              !rules.any((rule) => rule.covers(rule.matched(grid, x, y))))
            grid.glyphAt(x, y),
    };
  }
}

/// The manifest as it is written in assets/tiles/atlas_manifest.json.
final class TileAtlasManifest {
  const TileAtlasManifest({
    required this.tileWidth,
    required this.tileHeight,
    required this.columns,
    required this.atlasPath,
    required this.places,
  });

  factory TileAtlasManifest.parse(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final format = json['format']! as String;
    if (format != 'stepbound-tile-atlas-v1') {
      throw FormatException('unknown tile atlas format "$format"');
    }
    final places = json['places']! as Map<String, Object?>;
    return TileAtlasManifest(
      tileWidth: (json['tileWidth']! as num).toInt(),
      tileHeight: (json['tileHeight']! as num).toInt(),
      columns: (json['columns']! as num).toInt(),
      atlasPath: json['atlas']! as String,
      places: <String, TilePlaceArt>{
        for (final entry in places.entries)
          entry.key: TilePlaceArt.fromJson(
            entry.value! as Map<String, Object?>,
          ),
      },
    );
  }

  final int tileWidth;
  final int tileHeight;
  final int columns;
  final String atlasPath;
  final Map<String, TilePlaceArt> places;

  /// Where tile [index] sits in the atlas image.
  ui.Rect tileRect(int index) => ui.Rect.fromLTWH(
    (index % columns) * tileWidth.toDouble(),
    (index ~/ columns) * tileHeight.toDouble(),
    tileWidth.toDouble(),
    tileHeight.toDouble(),
  );
}

/// The manifest with its images decoded, loaded once for the whole game.
final class LoadedTileAtlas {
  LoadedTileAtlas({
    required this.manifest,
    required this.atlas,
    required this.objects,
  });

  final TileAtlasManifest manifest;
  final ui.Image atlas;

  /// The objects' images, by the file name the manifest gives them.
  final Map<String, ui.Image> objects;
}

Future<LoadedTileAtlas>? _loading;

/// Loads the atlas, once: every converted place shares these images.
Future<LoadedTileAtlas> loadTileAtlas({
  String manifestPath = tileAtlasManifestPath,
}) => _loading ??= _load(manifestPath);

Future<LoadedTileAtlas> _load(String manifestPath) async {
  final manifest = TileAtlasManifest.parse(
    await rootBundle.loadString(manifestPath),
  );
  final objects = <String, ui.Image>{};
  for (final place in manifest.places.values) {
    for (final object in place.objects) {
      for (final name in <String?>[object.image, object.whenOpen]) {
        if (name != null && !objects.containsKey(name)) {
          objects[name] = await loadAssetImage('assets/tiles/objects/$name');
        }
      }
    }
  }
  return LoadedTileAtlas(
    manifest: manifest,
    atlas: await loadAssetImage(manifest.atlasPath),
    objects: objects,
  );
}

/// Forgets the loaded atlas; for tests that load it more than once.
void resetTileAtlasCache() => _loading = null;
