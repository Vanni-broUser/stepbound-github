import 'dart:math' as math;

import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';
import 'package:stepbound/core/grid/tile_map.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/seeded_random.dart';
import 'package:stepbound/core/world.dart';

/// The tutorial: a street in 3/4 view and the inside of the carabinieri
/// barracks, laid out on one grid. The inside sits far to the east, beyond
/// the simulation radius, surrounded by darkness; doors carry the player
/// between the two.
///
/// Street glyphs (tools/build_street_level.py reads these rows to bake the
/// background image, so keep the two in sync):
/// - `B` roof, `H` facade, `f` facade with a burning window, `K` facade of
///   the barracks: walls.
/// - `E` barracks front door, `e` passage through its back: doors.
/// - `=` sidewalk; `.` road; `-` and `|` road with a horizontal or vertical
///   centre line; `Z` and `V` zebra crossings: floor.
/// - `CC` car, `XX` burning car, `UU` overturned car (horizontal pairs),
///   `v`/`k` car / burning car parked north-south (vertical pairs), `D` pile
///   of corpses, `F` burning bin, `T` traffic light: obstacles you can see
///   and shoot over.
/// - `:` debris (walkable but noisy), `d` a lone corpse (walkable).
/// - `S` a camp with a campfire: rest there to save (an obstacle).
/// - `@` player, `w` wanderer.
/// - Backpacks: `1` two rounds, there from the start; `2` four rounds by the
///   accident, waiting there from the start (the zombie guards it).
// level-rows-start
const List<String> streetLevelRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBHHHHHHHHHHHHHHHHHHHHHHHHHHHfHHHHHHHHBBBB',
  'BBBBHHHHHHfHHHHHHHHHHHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBB===============================F====BBBB',
  'BBBB....CC.......................:......BBBB',
  'BBBB-.-.-.-.-.-.-.-.:S-.-.-.-.-.-.-.-.-.BBBB',
  'BBBB........................XX..........BBBB',
  'BBBB====================================BBBB',
  'BBBBBBBBBBBBBBBBeBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKEKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=======BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=:....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.v...=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.v|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|.:=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBF.....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..1..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|.k=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=....k=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.:...=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=...d.=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBHHHHHHHHH=v.|..=HHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHfHHHH=v....=HHHHfHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHHHHHH=..|..=HHHHHHHHHHfHHHHHHHHHBBBB',
  'BBBBHHHHHHHHH=...:.=HHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBB==========VVVVVT==:=====F===========BBBB',
  'BBBB.....CC..Z.....Z..............UU....BBBB',
  'BBBB........:Z.....Z..........XX........BBBB',
  'BBBB-.-@-.-.-Z.....Z-:-.-w-.-.-.-.-.-D-.BBBB',
  'BBBB..:......Z.....Z.............d.2....BBBB',
  'BBBB.........Z.....Z......:...........d.BBBB',
  'BBBB=========T==========================BBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// level-rows-end

/// Inside the barracks, Pokemon-Emerald style: a room on a dark background.
/// - `x` darkness, `W` back wall, `Q` wall with the carabinieri emblem, `N`
///   notice board, `S` shelves, `I` partition, `w` front wall: walls.
/// - `E` entrance, `O` back door to the north street: doors.
/// - `T` desk, `C` counter, `A` filing cabinet, `h` toppled chair:
///   obstacles to hide behind.
/// - `.` floor, `:` scattered papers (noisy), `b` blood stain, `*` ceiling
///   lamp, `+` flickering lamp, `c` where a carabiniere zombie comes out,
///   `3` the backpack with the pistol.
// barracks-rows-start
const List<String> barracksRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWx',
  'xWQWWNWWWSSWWWOWWNWWWx',
  'x...A..I*.:...:..*..Ax',
  'x.3....I.....TT....c.x',
  'x:.*...I..c......TT..x',
  'xIIII.II.TT..........x',
  'x.....:..+.....:.....x',
  'x.TT....TT..TT....TT.x',
  'x....*.......*.......x',
  'x..TT..:.TT.....TT.b.x',
  'x....................x',
  'xCCCCCC.......CCCCCC.x',
  'x..h....*..:.....h...x',
  'x..........b.........x',
  'xwwwwwwwwwEwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxx',
];
// barracks-rows-end

/// Backgrounds baked by tools/build_street_level.py.
const String streetLevelBackground = 'assets/levels/street_01.png';
const String barracksBackground = 'assets/levels/barracks.png';

/// Top-left tile of the barracks interior on the shared grid.
const GridPoint barracksOrigin = GridPoint(84, 0);

/// An area the camera stays inside, with its baked background.
final class LevelRegion {
  const LevelRegion({
    required this.bounds,
    required this.background,
    this.indoor = false,
  });

  final GridRect bounds;
  final String background;

  /// Indoor regions are dimly lit.
  final bool indoor;
}

final List<LevelRegion> levelRegions = <LevelRegion>[
  LevelRegion(
    bounds: GridRect(
      0,
      0,
      streetLevelRows.first.length - 1,
      streetLevelRows.length - 1,
    ),
    background: streetLevelBackground,
  ),
  LevelRegion(
    bounds: GridRect(
      barracksOrigin.x,
      barracksOrigin.y,
      barracksOrigin.x + barracksRows.first.length - 1,
      barracksOrigin.y + barracksRows.length - 1,
    ),
    background: barracksBackground,
    indoor: true,
  ),
];

/// The zombie waiting on the east arm of the crossroads.
const String tutorialZombieId = 'wanderer-0';

/// Backpack ids, see the glyph lists above.
const String ammoBackpackId = 'backpack-ammo';
const String accidentBackpackId = 'backpack-accident';
const String gunBackpackId = 'backpack-gun';

/// Walking into the crossroads makes the tutorial zombie notice the player
/// even if it is not looking that way.
const GridRect tutorialZombieTrigger = GridRect(14, 43, 23, 49);

/// Camps where the player can save, and what a save there is called.
const Map<String, String> _campNames = <String, String>{
  'S': 'Accampamento dietro la caserma',
};

/// Campfires on the street, by tile, with the name shown in the save slots.
Map<GridPoint, String> campfireNames() => <GridPoint, String>{
  for (var y = 0; y < streetLevelRows.length; y++)
    for (var x = 0; x < streetLevelRows[y].length; x++)
      if (_campNames.containsKey(streetLevelRows[y][x]))
        GridPoint(x, y): _campNames[streetLevelRows[y][x]]!,
};

/// The forecourt in front of the barracks: reaching it makes Mario speak.
const GridRect barracksForecourt = GridRect(13, 17, 19, 18);

enum FireKind { car, bin, window, campfire }

/// Where an animated fire burns, in tile coordinates of its tile (the left
/// or top tile for a car).
final class FireSpot {
  const FireSpot(this.tile, this.kind, {this.vertical = false});

  final GridPoint tile;
  final FireKind kind;

  /// True for a car parked north-south.
  final bool vertical;
}

/// A ceiling lamp inside a building.
final class LightSpot {
  const LightSpot(this.tile, {this.flickers = false});

  final GridPoint tile;
  final bool flickers;
}

TileKind _streetKind(String glyph) => switch (glyph) {
  'B' || 'H' || 'f' || 'K' => TileKind.wall,
  'C' ||
  'X' ||
  'U' ||
  'v' ||
  'k' ||
  'D' ||
  'F' ||
  'T' ||
  'S' => TileKind.obstacle,
  ':' => TileKind.debris,
  _ => TileKind.floor,
};

TileKind _barracksKind(String glyph) => switch (glyph) {
  'x' || 'W' || 'Q' || 'N' || 'S' || 'I' || 'w' => TileKind.wall,
  'T' || 'C' || 'A' || 'h' => TileKind.obstacle,
  ':' => TileKind.debris,
  _ => TileKind.floor,
};

List<FireSpot> streetFireSpots({List<String> rows = streetLevelRows}) {
  final spots = <FireSpot>[];
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final glyph = rows[y][x];
      final carStart = glyph == 'X' && (x == 0 || rows[y][x - 1] != 'X');
      final verticalCarStart =
          glyph == 'k' && (y == 0 || rows[y - 1][x] != 'k');
      final spot = switch (glyph) {
        'F' => FireSpot(GridPoint(x, y), FireKind.bin),
        'f' => FireSpot(GridPoint(x, y), FireKind.window),
        'S' => FireSpot(GridPoint(x, y), FireKind.campfire),
        _ when carStart => FireSpot(GridPoint(x, y), FireKind.car),
        _ when verticalCarStart => FireSpot(
          GridPoint(x, y),
          FireKind.car,
          vertical: true,
        ),
        _ => null,
      };
      if (spot != null) {
        spots.add(spot);
      }
    }
  }
  return spots;
}

Iterable<GridPoint> _barracksTiles(String glyphs) sync* {
  for (var y = 0; y < barracksRows.length; y++) {
    for (var x = 0; x < barracksRows[y].length; x++) {
      if (glyphs.contains(barracksRows[y][x])) {
        yield GridPoint(barracksOrigin.x + x, barracksOrigin.y + y);
      }
    }
  }
}

/// Ceiling lamps inside the barracks, on the shared grid.
List<LightSpot> barracksLights() => <LightSpot>[
  for (final tile in _barracksTiles('*')) LightSpot(tile),
  for (final tile in _barracksTiles('+')) LightSpot(tile, flickers: true),
  // daylight through the doors
  for (final tile in _barracksTiles('EO')) LightSpot(tile),
];

/// Where the carabinieri zombies come out, on the shared grid.
List<GridPoint> carabiniereSpawns() => _barracksTiles('c').toList();

GridPoint _barracksTile(String glyph) => _barracksTiles(glyph).single;

GridPoint _streetTile(String glyph) {
  for (var y = 0; y < streetLevelRows.length; y++) {
    final x = streetLevelRows[y].indexOf(glyph);
    if (x >= 0) {
      return GridPoint(x, y);
    }
  }
  throw StateError('No $glyph on the street.');
}

/// Doors in both directions between the street and the barracks.
Map<GridPoint, Portal> _portals() {
  final frontDoor = _streetTile('E');
  final backPassage = _streetTile('e');
  final entrance = _barracksTile('E');
  final backDoor = _barracksTile('O');
  return <GridPoint, Portal>{
    frontDoor: Portal(
      to: entrance.step(Direction.north),
      facing: Direction.north,
    ),
    entrance: Portal(
      to: frontDoor.step(Direction.south),
      facing: Direction.south,
    ),
    backDoor: Portal(
      to: backPassage.step(Direction.north),
      facing: Direction.north,
    ),
    backPassage: Portal(
      to: backDoor.step(Direction.south),
      facing: Direction.south,
    ),
  };
}

WorldState createStreetWorld({int seed = 20260920}) {
  final factory = EntityFactory(BalanceConfig.standard());
  final entities = <Entity>[];
  final pickups = <Pickup>[];
  final width = math.max(
    streetLevelRows.first.length,
    barracksOrigin.x + barracksRows.first.length,
  );
  final height = math.max(
    streetLevelRows.length,
    barracksOrigin.y + barracksRows.length,
  );
  final kinds = List<TileKind>.filled(width * height, TileKind.wall);
  var zombieIndex = 0;

  for (var y = 0; y < streetLevelRows.length; y++) {
    final row = streetLevelRows[y];
    for (var x = 0; x < row.length; x++) {
      final glyph = row[x];
      final point = GridPoint(x, y);
      kinds[y * width + x] = _streetKind(glyph);
      switch (glyph) {
        case '@':
          // The tutorial starts unarmed and without bullets.
          entities.add(
            factory.player(
              id: 'player',
              position: point,
              health: 1,
              loadedAmmo: 0,
              reserveAmmo: 0,
              hasGun: false,
            ),
          );
        case 'w':
          entities.add(
            factory.zombie(
              id: 'wanderer-${zombieIndex++}',
              kind: EntityKind.wanderer,
              position: point,
            ),
          );
        case '1':
          pickups.add(Pickup(id: ammoBackpackId, position: point, ammo: 2));
        case '2':
          pickups.add(Pickup(id: accidentBackpackId, position: point, ammo: 4));
      }
    }
  }
  for (var y = 0; y < barracksRows.length; y++) {
    final row = barracksRows[y];
    for (var x = 0; x < row.length; x++) {
      final point = GridPoint(barracksOrigin.x + x, barracksOrigin.y + y);
      kinds[point.y * width + point.x] = _barracksKind(row[x]);
      if (row[x] == '3') {
        pickups.add(Pickup(id: gunBackpackId, position: point, gun: true));
      }
    }
  }

  return WorldState(
    map: TileMap(
      width: width,
      height: height,
      tiles: <Tile>[for (final kind in kinds) Tile(kind)],
    ),
    entities: entities,
    pickups: pickups,
    alertTriggers: const <String, GridRect>{
      tutorialZombieId: tutorialZombieTrigger,
    },
    portals: _portals(),
    campfires: campfireNames().keys,
    playerId: 'player',
    random: SeededRandom(seed),
  );
}

/// A carabiniere zombie coming out of the dark at [position].
Entity createCarabiniere(String id, GridPoint position) {
  return EntityFactory(BalanceConfig.standard()).zombie(
    id: id,
    kind: EntityKind.carabiniere,
    position: position,
    facing: Direction.south,
  );
}
