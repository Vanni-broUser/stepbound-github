import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:stepbound/game/render/asset_image.dart';

/// The tile atlas a converted place is painted from: the art that used to
/// be baked into assets/levels, cut into cells the size of a level tile,
/// with a rule for every glyph saying which cell to take. Made by tools/build_tile_atlas.py, whose docstring is the other
/// half of this contract.
///
/// The place's ASCII rows stay the only place its layout is written down:
/// nothing here knows where anything is, only what a glyph looks like and
/// how its look changes with its neighbours.
const String tileAtlasManifestPath = 'assets/tiles/atlas_manifest.json';

/// The glyphs of a place, as the rules read them.
final class GlyphGrid {
  GlyphGrid(this.rows);

  final List<String> rows;
  final Map<String, int> _firstRows = <String, int>{};

  int get width => rows.first.length;
  int get height => rows.length;

  /// The glyph at [x], [y]; outside the place everything is the void.
  String glyphAt(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) {
      return 'x';
    }
    return rows[y][x];
  }

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
      ),
      'pattern' => PatternKey(
        a: (json['a']! as num).toInt(),
        b: (json['b']! as num).toInt(),
        mod: (json['mod']! as num).toInt(),
        equals: (json['equals']! as num).toInt(),
      ),
      'firstRow' => FirstRowKey(
        glyph: json['glyph']! as String,
        offset: (json['offset']! as num).toInt(),
        atMost: json['compare'] == 'le',
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
/// wall it is the top course, a bench that it is the end of the row.
final class NeighbourKey extends TileKey {
  const NeighbourKey({
    required this.dx,
    required this.dy,
    required this.glyphs,
  });

  final int dx;
  final int dy;
  final String glyphs;

  @override
  bool holds(GlyphGrid grid, int x, int y) =>
      glyphs.contains(grid.glyphAt(x + dx, y + dy));
}

/// A pattern the bakers write straight into the position, like the
/// graffiti on every ninth stretch of station wall.
final class PatternKey extends TileKey {
  const PatternKey({
    required this.a,
    required this.b,
    required this.mod,
    required this.equals,
  });

  final int a;
  final int b;
  final int mod;
  final int equals;

  @override
  bool holds(GlyphGrid grid, int x, int y) => (x * a + y * b) % mod == equals;
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

/// For these [glyphs], on this [layer], take a tile out of the bucket the
/// [keys] point at. An empty bucket draws nothing.
final class TileRule {
  const TileRule({
    required this.layer,
    required this.glyphs,
    required this.keys,
    required this.buckets,
  });

  factory TileRule.fromJson(Map<String, Object?> json) {
    final keys = <TileKey>[
      for (final key in json['keys']! as List<Object?>)
        TileKey.fromJson(key! as Map<String, Object?>),
    ];
    final buckets = <List<int>>[
      for (final bucket in json['buckets']! as List<Object?>)
        <int>[
          for (final tile in bucket! as List<Object?>) (tile! as num).toInt(),
        ],
    ];
    if (buckets.length != 1 << keys.length) {
      throw FormatException(
        'a rule with ${keys.length} keys needs ${1 << keys.length} '
        'buckets, not ${buckets.length}',
      );
    }
    return TileRule(
      layer: json['layer']! as String,
      glyphs: json['glyphs']! as String,
      keys: keys,
      buckets: buckets,
    );
  }

  final String layer;
  final String glyphs;
  final List<TileKey> keys;
  final List<List<int>> buckets;

  bool covers(String glyph) => glyphs.contains(glyph);

  /// The tiles this cell may be drawn with.
  List<int> bucketFor(GlyphGrid grid, int x, int y) {
    var index = 0;
    for (var bit = 0; bit < keys.length; bit++) {
      if (keys[bit].holds(grid, x, y)) {
        index |= 1 << bit;
      }
    }
    return buckets[index];
  }
}

/// Something too big for one cell -- a railcar, a door two tiles high --
/// drawn over the run of its [glyph]. [tiles] is the size that run has to
/// be, checked by test/levels/tile_atlas_test.dart against the rows.
final class TileObject {
  const TileObject({
    required this.glyph,
    required this.image,
    required this.offsetY,
    required this.tiles,
    required this.whenOpen,
  });

  factory TileObject.fromJson(Map<String, Object?> json) {
    final tiles = json['tiles'] as List<Object?>?;
    return TileObject(
      glyph: json['glyph']! as String,
      image: json['image']! as String,
      offsetY: (json['offsetY'] as num?)?.toInt() ?? 0,
      tiles: tiles == null
          ? null
          : ((tiles[0]! as num).toInt(), (tiles[1]! as num).toInt()),
      whenOpen: json['whenOpen'] as String?,
    );
  }

  final String glyph;
  final String image;

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
  });

  factory TilePlaceArt.fromJson(Map<String, Object?> json) => TilePlaceArt(
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
  );

  static ui.Color _colour(String hex) =>
      ui.Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

  /// What shows where the place does not reach.
  final ui.Color voidColour;

  /// The glyph that is meant to stay empty: nothing paints it.
  final String voidGlyph;
  final List<TileRule> rules;
  final List<TileObject> objects;

  /// The glyphs no rule and no object paints: a place with any of these
  /// would be drawn with holes in it.
  Set<String> unpainted(Iterable<String> glyphs) => <String>{
    for (final glyph in glyphs)
      if (glyph != voidGlyph &&
          !rules.any((rule) => rule.covers(glyph)) &&
          !objects.any((object) => object.glyph == glyph))
        glyph,
  };
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
