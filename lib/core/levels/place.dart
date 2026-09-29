import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/world.dart';

/// The side of one tile, in pixels: the unit the tile atlas is cut at
/// (`TILE` in tools/build_street_level.py) and the one the renderer draws
/// the grid with. A place is therefore drawn `width * levelTileSize` by
/// `height * levelTileSize` pixels; test/levels/tile_atlas_test.dart holds
/// the atlas to it.
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
  romeTermini,
  duomoSecondFloor,
  duomoTower,
  duomoBells,
  duomoTowerRoof,
  hospitalFirstFloor,
  hospitalSecondFloor,
  hospitalThirdFloor,
  hospitalRoof,
  terminiOverpass,
  terminiFarPlatform,
  terminiConcourse,
  piazzaCinquecento,
  viaMarsala,
  termeDiocleziano,
  palazzoThirdFloor,
  palazzoSecondFloor,
  palazzoFirstFloor,
  palazzoGroundFloor,
  industryStreet,
}

/// The levels of the game, one city each. The train Mario and Luigi live
/// in is the one place they share: it stands at the station of whichever
/// level they last travelled to (see `parkTrain`).
enum LevelId {
  /// Molfetta, where Mario wakes up: the tutorial.
  hometown,

  /// Rome, reached by the train from Molfetta.
  rome,
}

/// A part of a level whose places are loaded together: their pictures are
/// composed while Mario is in the area, or one door away from it, and
/// released once he has left. A level is split into a few of them so its
/// places need not all be in memory at once, however much it grows.
enum AreaId {
  /// Molfetta from the street Mario wakes up in to the station: the
  /// barracks, the north district with the hypermarket and the hospital,
  /// the airliner and the station's three places.
  hometownTown(LevelId.hometown),

  /// Molfetta's harbour and old town: the Duomo and its tower, the Bar
  /// Arcobaleno and the church of San Nicola.
  hometownHarbour(LevelId.hometown),

  /// The train, shared by every level. It counts as Molfetta's, where it
  /// is found.
  train(LevelId.hometown),

  /// Roma Termini: its platforms, the overpass and the concourse.
  romeTermini(LevelId.rome),

  /// The streets just outside Termini, and the Baths of Diocletian at
  /// the end of one of them.
  romeStreets(LevelId.rome);

  const AreaId(this.level);

  final LevelId level;
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

/// A place as a level describes it: its ASCII [rows] and what they mean.
/// The renderer paints it from those same rows out of the tile atlas, so
/// they are the only place its layout is written down. Indoors (a
/// room on a dark background) it is lit by its lamps, `*` (steady) and
/// `+` (flickering), and by daylight at the [daylight] glyphs, unless it
/// is [lit] throughout. A place with a [cardImage] is announced, on the
/// way in, by that picture and its [name] between two fades to black.
final class PlaceSpec {
  const PlaceSpec({
    required this.id,
    required this.rows,
    required this.legend,
    required this.area,
    this.indoor = false,
    this.lit = false,
    this.daylight = '',
    this.name,
    this.cardImage,
    this.torches = const <GridPoint>[],
    this.lamps = const <GridPoint>[],
    this.flickeringLamps = const <GridPoint>[],
    this.darkness = defaultDarkness,
    this.litAreas = const <GridRect>[],
    this.art,
  });

  /// How dark an unlit room is, between its lamps: nearly black.
  static const double defaultDarkness = 0.9;

  final PlaceId id;
  final List<String> rows;
  final Legend legend;
  final bool indoor;

  /// An indoor place with every light on: it sounds and is entered like a
  /// room, but no darkness is drawn over it.
  final bool lit;
  final String daylight;
  final String? name;
  final String? cardImage;

  /// Burning torches, in the place's own tile coordinates: fixed to walls
  /// and columns, so they are not glyphs of their own. The game draws
  /// their flames and they light the room like its lamps.
  final List<GridPoint> torches;

  /// Ceiling lamps over something that has a glyph of its own -- a pool
  /// table, a sign on the wall -- in the place's own tile coordinates:
  /// they light the room like its `*`.
  final List<GridPoint> lamps;

  /// Lamps fixed over a wall or another occupied tile that flicker like
  /// the `+` lamps in the place's map.
  final List<GridPoint> flickeringLamps;

  /// How dark the room is between its lights, 0 to 1; only for indoor
  /// places that are not [lit].
  final double darkness;

  /// Parts of a room that are not [lit] as a whole where every light is
  /// on, so no darkness falls there at all: the stairwell of a block of
  /// flats, whose flats stay dim. In the place's own tile coordinates.
  final List<GridRect> litAreas;

  /// The place whose art in the tile atlas this one is painted with, when
  /// it has none of its own: its rows then keep to that place's glyphs.
  final PlaceId? art;

  /// The area the place is loaded with.
  final AreaId area;

  /// The level the place belongs to. The train, shared by all of them,
  /// counts as Molfetta's, where it is found.
  LevelId get level => area.level;
}

/// A place laid on the level's grid at [origin].
final class Place {
  Place(this.spec, this.origin);

  final PlaceSpec spec;

  /// Top-left tile on the shared grid.
  final GridPoint origin;

  PlaceId get id => spec.id;
  List<String> get rows => spec.rows;
  bool get indoor => spec.indoor;
  bool get lit => spec.lit;
  String? get name => spec.name;
  String? get cardImage => spec.cardImage;

  AreaId get area => spec.area;
  LevelId get level => spec.level;

  /// The place whose art in the tile atlas paints this one.
  PlaceId get artId => spec.art ?? id;
  double get darkness => spec.darkness;

  /// [PlaceSpec.litAreas], on the level's grid.
  late final List<GridRect> litAreas = <GridRect>[
    for (final area in spec.litAreas)
      GridRect(
        origin.x + area.left,
        origin.y + area.top,
        origin.x + area.right,
        origin.y + area.bottom,
      ),
  ];

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

  /// The walkable tiles on the place's outer edge, each with the way back
  /// into the place: where a street, a platform or a track runs off the
  /// map. Past them there is only the wall between places, so each one is
  /// a way that goes nowhere yet (see `workInProgressEnds`).
  ///
  /// The way back is to a walkable tile off the edge, straight in if it
  /// can be. A tile with none, shut in by wrecks or fire, is left out:
  /// nobody gets there but along the edge, through a tile that is in.
  late final Map<GridPoint, Direction> edgeEnds = () {
    bool walkable(int x, int y) =>
        x >= 0 &&
        y >= 0 &&
        x < width &&
        y < height &&
        Tile(kindOf(rows[y][x])).isWalkable;
    bool onEdge(int x, int y) =>
        x == 0 || y == 0 || x == width - 1 || y == height - 1;
    final ends = <GridPoint, Direction>{};
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!onEdge(x, y) || !walkable(x, y)) {
          continue;
        }
        final inward = <Direction>[
          if (x == 0) Direction.east,
          if (x == width - 1) Direction.west,
          if (y == 0) Direction.south,
          if (y == height - 1) Direction.north,
        ];
        for (final back in <Direction>[...inward, ...Direction.values]) {
          final (dx, dy) = (back.dx, back.dy);
          if (walkable(x + dx, y + dy) && !onEdge(x + dx, y + dy)) {
            ends[GridPoint(origin.x + x, origin.y + y)] = back;
            break;
          }
        }
      }
    }
    return Map<GridPoint, Direction>.unmodifiable(ends);
  }();

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
    if (indoor)
      for (final lamp in spec.lamps)
        LightSpot(GridPoint(origin.x + lamp.x, origin.y + lamp.y)),
    if (indoor)
      for (final lamp in spec.flickeringLamps)
        LightSpot(
          GridPoint(origin.x + lamp.x, origin.y + lamp.y),
          flickers: true,
        ),
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
