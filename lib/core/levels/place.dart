import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/world.dart';

/// The side of one tile, in pixels: the unit the baked backgrounds in
/// assets/levels are painted at (`TILE` in tools/build_*.py) and the one
/// the renderer draws the grid with. A place's background is therefore
/// `width * levelTileSize` by `height * levelTileSize` pixels, an
/// invariant checked by test/levels/level_background_dimensions_test.dart.
const double levelTileSize = 16;

/// Every place of the game, so code can name the one it means.
enum PlaceId {
  street,
  barracks,
  northDistrict,
  harbour,
  mallGround,
  mallFirst,
  mallNorthStreet,
  barArcobaleno,
  church,
  station,
  stationUnderpass,
  stationFarSide,
  trainInterior,
  airlinerCabin,
  airlinerRoofs,
  duomo,
  barBackroom,
  duomoUpper,
}

/// What the glyphs of a place's ASCII map mean for movement and sight: the
/// ones in [walls] block both, the ones in [obstacles] block movement but
/// not sight (a wreck you can shoot over), the ones in [debris] are
/// walkable but noisy. Anything else is floor.
final class Legend {
  const Legend({
    required this.walls,
    required this.obstacles,
    this.debris = ':',
    this.fire = '',
  });

  final String walls;
  final String obstacles;
  final String debris;

  /// Ground already burning when the level starts.
  final String fire;

  TileKind kindOf(String glyph) {
    if (walls.contains(glyph)) {
      return TileKind.wall;
    }
    if (obstacles.contains(glyph)) {
      return TileKind.obstacle;
    }
    if (debris.contains(glyph)) {
      return TileKind.debris;
    }
    if (fire.contains(glyph)) {
      return TileKind.fire;
    }
    return TileKind.floor;
  }
}

/// A ceiling lamp, or daylight through a door, inside a building, or a
/// burning [torch], which throws a wider, warmer light.
final class LightSpot {
  const LightSpot(this.tile, {this.flickers = false, this.torch = false});

  final GridPoint tile;
  final bool flickers;
  final bool torch;
}

/// A place as a level describes it: its ASCII [rows], what they mean, and
/// its baked [background] -- or no background at all, for a place the
/// renderer paints from those same rows out of the tile atlas. Indoors (a
/// room on a dark background) it is lit by its lamps, `*` (steady) and
/// `+` (flickering), and by daylight at the [daylight] glyphs, unless it
/// is [lit] throughout. A place with a [cardImage] is announced, on the
/// way in, by that picture and its [name] between two fades to black.
final class PlaceSpec {
  const PlaceSpec({
    required this.id,
    required this.rows,
    required this.legend,
    this.background,
    this.indoor = false,
    this.lit = false,
    this.daylight = '',
    this.name,
    this.cardImage,
    this.alternateBackground,
    this.torches = const <GridPoint>[],
    this.darkness = defaultDarkness,
  });

  /// How dark an unlit room is, between its lamps: nearly black.
  static const double defaultDarkness = 0.9;

  final PlaceId id;
  final List<String> rows;
  final Legend legend;

  /// The picture of this place, painted from [rows] by a baker in tools/,
  /// or null when the place is drawn from the tile atlas instead.
  final String? background;
  final bool indoor;

  /// An indoor place with every light on: it sounds and is entered like a
  /// room, but no darkness is drawn over it.
  final bool lit;
  final String daylight;
  final String? name;
  final String? cardImage;

  /// A second baked view of the same place, selected by the game when
  /// story state changes something visual without changing the layout.
  final String? alternateBackground;

  /// Burning torches, in the place's own tile coordinates: fixed to walls
  /// and columns, so they are not glyphs of their own. The game draws
  /// their flames and they light the room like its lamps.
  final List<GridPoint> torches;

  /// How dark the room is between its lights, 0 to 1; only for indoor
  /// places that are not [lit].
  final double darkness;
}

/// A place laid on the level's grid at [origin].
final class Place {
  Place(this.spec, this.origin);

  final PlaceSpec spec;

  /// Top-left tile on the shared grid.
  final GridPoint origin;

  PlaceId get id => spec.id;
  List<String> get rows => spec.rows;
  String? get background => spec.background;
  String? get alternateBackground => spec.alternateBackground;
  bool get indoor => spec.indoor;
  bool get lit => spec.lit;
  String? get name => spec.name;
  String? get cardImage => spec.cardImage;
  double get darkness => spec.darkness;

  /// The [PlaceSpec.torches], on the shared grid.
  late final List<GridPoint> torches = <GridPoint>[
    for (final torch in spec.torches)
      GridPoint(origin.x + torch.x, origin.y + torch.y),
  ];

  int get width => rows.first.length;
  int get height => rows.length;

  late final GridRect bounds = GridRect(
    origin.x,
    origin.y,
    origin.x + width - 1,
    origin.y + height - 1,
  );

  /// Every tile on the shared grid, with its glyph.
  Iterable<(GridPoint, String)> get glyphs sync* {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        yield (GridPoint(origin.x + x, origin.y + y), rows[y][x]);
      }
    }
  }

  TileKind kindOf(String glyph) => spec.legend.kindOf(glyph);

  /// The tiles showing [glyph], row by row.
  List<GridPoint> tilesOf(String glyph) => <GridPoint>[
    for (final (tile, found) in glyphs)
      if (found == glyph) tile,
  ];

  /// The one tile showing [glyph].
  GridPoint tileOf(String glyph) => tilesOf(glyph).single;

  /// The top row of a door drawn with [glyph], west to east.
  List<GridPoint> doorRow(String glyph) {
    final tiles = tilesOf(glyph);
    return tiles.where((tile) => tile.y == tiles.first.y).toList();
  }

  /// The walkable tiles of the place's row [y], west to east.
  List<GridPoint> walkableRow(int y) => <GridPoint>[
    for (var x = 0; x < width; x++)
      if (Tile(kindOf(rows[y][x])).isWalkable)
        GridPoint(origin.x + x, origin.y + y),
  ];

  /// Indoors, the lamps and the daylight at the doors; none outdoors.
  late final List<LightSpot> lights = <LightSpot>[
    if (indoor)
      for (final (tile, glyph) in glyphs)
        if (glyph == '*' || spec.daylight.contains(glyph))
          LightSpot(tile)
        else if (glyph == '+')
          LightSpot(tile, flickers: true),
    if (indoor)
      for (final torch in torches) LightSpot(torch, torch: true),
  ];
}

/// Lays [specs] left to right on one grid, top-aligned, each farther from
/// the others than the simulation reaches: what happens in one place never
/// wakes the zombies of another. Places are joined by doors and roads.
List<Place> layOutPlaces(List<PlaceSpec> specs) {
  const gap = WorldState.simulationRadius + 2;
  final places = <Place>[];
  var x = 0;
  for (final spec in specs) {
    final place = Place(spec, GridPoint(x, 0));
    places.add(place);
    x += place.width + gap;
  }
  return places;
}
