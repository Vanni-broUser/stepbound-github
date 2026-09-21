// The ASCII maps below are one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:math' as math;

import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';
import 'package:stepbound/core/grid/tile_map.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/seeded_random.dart';
import 'package:stepbound/core/world.dart';

/// The tutorial: the street where Mario wakes up, the inside of the
/// carabinieri barracks and the north district behind it, laid out on one
/// grid. Each place sits beyond the simulation radius of the others,
/// surrounded by darkness; doors carry the player between them.
///
/// Street glyphs (tools/build_street_level.py reads these rows to bake the
/// background images, so keep the two in sync):
/// - `B` roof, `H` facade, `f` facade with a burning window, `K` facade of
///   the barracks, `M` facade of the hypermarket, `G` facade of the
///   hospital: walls.
/// - `E` barracks front door, `e` passage through its back: doors.
/// - `=` sidewalk; `.` road; `-` and `|` road with a horizontal or vertical
///   centre line; `Z` and `V` zebra crossings: floor.
/// - `CC` car, `XX` burning car, `UU` overturned car (horizontal pairs),
///   `v`/`k` car / burning car parked north-south (vertical pairs), `D` pile
///   of corpses, `F` burning bin, `T` traffic light: obstacles you can see
///   and shoot over.
/// - `:` debris (walkable but noisy), `d` a lone corpse (walkable).
/// - `S` a camp with a campfire: rest there to save (an obstacle).
/// - `I` flagpole on the barracks forecourt (the flag is animated in game).
/// - `P` paving of a square, `L` parking lot, `Y` stairs: floor. `O`
///   fountain, `A` dead tree in its planter, `n` bench, `y` abandoned
///   shopping trolley, `J` concrete road block, `Q` café table, `aa`
///   crashed ambulance: obstacles. `q` toppled chair: debris (noisy).
/// - Zombies: `w` wanderer, `z` sprinter, `u` brute.
/// - `@` player, `w` wanderer.
/// - Backpacks: `1` two rounds, there from the start; `2` four rounds by the
///   accident, waiting there from the start (the zombie guards it).
// level-rows-start
const List<String> streetLevelRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKEKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB======IBBBBBBBBBBBBBBBBBBBBBBBB',
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

/// The north district, behind the barracks (same glyphs as the street): the
/// street out of the barracks' back passage is closed to the east, where a
/// camp burns; to the west it opens on a square with a fountain and a
/// wrecked bar, from which roads lead south (blocked for now), north to a
/// hypermarket and west to the hospital, whose road, forecourt and stairs
/// are packed with hordes far too many to fight through.
// north-rows-start
const List<String> northDistrictRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB==========================BBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=LLLLLLLLLL:LLLLLyLLLLLLLLL=BBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=LLCCLLLLLLLLLLLLLLLLLLLyLL=BBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=LLLLLLLLLLLLLLLLLLLLLLLLLL=BBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=LLLLLLyLLLLLLLLLLLLXXLLLvL=BBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=LLLLLLLLLLLLLLLLLLLLLLLLvL=BBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBB============================BBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBB=.:|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBYYYYYYzYzYYYwYYYBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBYYwYYYYwYYYwYYYYBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBYYYYwYYYYwYYYwYYBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBYYYYYwYzYYwYYYYYBBBBBBBBBBBBBBBBBBBBHHHHHHH=..|..=HHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBPwPPyPPPPPPPPPwPBBBBBBBBBBBBBBBBBBBBHHHHHfH=..|..=HHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBPPPPPPJJJJPPP:PPBBBBBBBBBBBBBBBBBBBBHHHHHHH=..|..=HHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBPaaPPPPPwPPPPPwPHHHHHHHHHHHHHHHHHHHH========PPPPP========HHHHHHHHHHHHHHHHHHHHHHHHHHHHBBB',
  'BBPPPPwPuPPPPaaPPPHHHHHHHHHHfHHHHHHHHH=Qq:PqPPPPPPPPPPPPPF=HHfHHHHHHHHHHHHHHHHHHHHHHHHHBBB',
  'BBPPwDPPPwPPwPPwPPHHfHHHHHHHHHHHHHHHHH=qPPQP:PPPPPPPnnPPAP=HHHHHHHHHHHHHHHHHHHHHHHfHHHHBBB',
  'BBPPPPPwPPPwPuPPPP===u=w==w============PPq:qPPPPPPPPPPPPPP===F=========================BBB',
  'BB...................w.w..d............PQqPPPPOOOOOPPP:PPPP.....CC...............:...UUBBB',
  'BB-.-.-.-.-.-.-.-.-.w.:.w.-w-.-.-.-.-.-qPPdPPwOOOOOPPPPPPPP.-.-.-.-:-.-.-.-.-.-.-.-.S.-BBB',
  'BB....................w..w....XX.......PPdPPPPOOOOOPPPPPPPP..........XX.d..............BBB',
  'BB=================w====w==============PPPPPPPOOOOOwPPPPPP=====================F=======BBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=PPPPPPPOOOOOPPPPPPP=BBBBBBBBBBBBBBBBeBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=PPPPPPPPPPPPPPDPPPP=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=PAPnnPPPPPPPPPPPPAP=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=PPPPPPPPPPPPPPPPPPP=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB========PPPPP========BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|:.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=k.|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=k.|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..d..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBJJJJJJJBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// north-rows-end

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
  'x.....:....+...:.....x',
  'x.TT....TT..TT....TT.x',
  'x....*.........*.....x',
  'x..TT..:.TT.....TT.b.x',
  'x....................x',
  'xCCCCCC.......CCCCCC.x',
  'x..h....*..:.....h...x',
  'x..........b.........x',
  'xwwwwwwwwwEwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxx',
];
// barracks-rows-end

/// Backgrounds baked by tools/build_street_level.py and
/// tools/build_barracks.py.
const String streetLevelBackground = 'assets/levels/street_01.png';
const String northDistrictBackground = 'assets/levels/north_district.png';
const String barracksBackground = 'assets/levels/barracks.png';

/// Top-left tile of the barracks interior on the shared grid.
const GridPoint barracksOrigin = GridPoint(84, 0);

/// Top-left tile of the north district on the shared grid, east of the
/// barracks and beyond the simulation radius of anything in the other
/// places.
const GridPoint northDistrictOrigin = GridPoint(140, 0);

const GridPoint _streetOrigin = GridPoint(0, 0);

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

GridRect _boundsOf(GridPoint origin, List<String> rows) => GridRect(
  origin.x,
  origin.y,
  origin.x + rows.first.length - 1,
  origin.y + rows.length - 1,
);

/// The street, the north district and, last, the barracks interior.
final List<LevelRegion> levelRegions = <LevelRegion>[
  LevelRegion(
    bounds: _boundsOf(_streetOrigin, streetLevelRows),
    background: streetLevelBackground,
  ),
  LevelRegion(
    bounds: _boundsOf(northDistrictOrigin, northDistrictRows),
    background: northDistrictBackground,
  ),
  LevelRegion(
    bounds: _boundsOf(barracksOrigin, barracksRows),
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

/// Every tile of [rows] placed at [origin] on the shared grid, with its glyph.
Iterable<(GridPoint, String)> _glyphs(
  GridPoint origin,
  List<String> rows,
) sync* {
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      yield (GridPoint(origin.x + x, origin.y + y), rows[y][x]);
    }
  }
}

/// The outdoor places: the street and the north district.
Iterable<(GridPoint, String)> _outdoorGlyphs() sync* {
  yield* _glyphs(_streetOrigin, streetLevelRows);
  yield* _glyphs(northDistrictOrigin, northDistrictRows);
}

/// Campfires outdoors, by tile, with the name shown in the save slots.
Map<GridPoint, String> campfireNames() => <GridPoint, String>{
  for (final (point, glyph) in _outdoorGlyphs())
    if (_campNames.containsKey(glyph)) point: _campNames[glyph]!,
};

/// The forecourt in front of the barracks: reaching it makes Mario speak.
const GridRect barracksForecourt = GridRect(13, 17, 19, 18);

/// The flagpole planted on the forecourt, where the tricolour flies.
GridPoint flagpoleTile() => _outdoorTile('I');

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
  'B' || 'H' || 'f' || 'K' || 'M' || 'G' => TileKind.wall,
  'C' ||
  'X' ||
  'U' ||
  'v' ||
  'k' ||
  'D' ||
  'F' ||
  'T' ||
  'S' ||
  'O' ||
  'y' ||
  'J' ||
  'Q' ||
  'a' ||
  'A' ||
  'n' ||
  'I' => TileKind.obstacle,
  ':' || 'q' => TileKind.debris,
  _ => TileKind.floor,
};

TileKind _barracksKind(String glyph) => switch (glyph) {
  'x' || 'W' || 'Q' || 'N' || 'S' || 'I' || 'w' => TileKind.wall,
  'T' || 'C' || 'A' || 'h' => TileKind.obstacle,
  ':' => TileKind.debris,
  _ => TileKind.floor,
};

/// Fires burning in [rows], placed at [origin] on the shared grid.
List<FireSpot> streetFireSpots({
  List<String> rows = streetLevelRows,
  GridPoint origin = _streetOrigin,
}) {
  final spots = <FireSpot>[];
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final glyph = rows[y][x];
      final tile = GridPoint(origin.x + x, origin.y + y);
      final carStart = glyph == 'X' && (x == 0 || rows[y][x - 1] != 'X');
      final verticalCarStart =
          glyph == 'k' && (y == 0 || rows[y - 1][x] != 'k');
      final spot = switch (glyph) {
        'F' => FireSpot(tile, FireKind.bin),
        'f' => FireSpot(tile, FireKind.window),
        'S' => FireSpot(tile, FireKind.campfire),
        _ when carStart => FireSpot(tile, FireKind.car),
        _ when verticalCarStart => FireSpot(tile, FireKind.car, vertical: true),
        _ => null,
      };
      if (spot != null) {
        spots.add(spot);
      }
    }
  }
  return spots;
}

/// Fires of every outdoor place.
List<FireSpot> outdoorFireSpots() => <FireSpot>[
  ...streetFireSpots(),
  ...streetFireSpots(rows: northDistrictRows, origin: northDistrictOrigin),
];

Iterable<GridPoint> _barracksTiles(String glyphs) sync* {
  for (final (point, glyph) in _glyphs(barracksOrigin, barracksRows)) {
    if (glyphs.contains(glyph)) {
      yield point;
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

GridPoint _outdoorTile(String glyph) =>
    _outdoorGlyphs().firstWhere((tile) => tile.$2 == glyph).$1;

/// Doors in both directions between the street, the barracks and the north
/// district.
Map<GridPoint, Portal> _portals() {
  final frontDoor = _outdoorTile('E');
  final backPassage = _outdoorTile('e');
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
  final regions = levelRegions.map((region) => region.bounds);
  final width = regions.map((bounds) => bounds.right + 1).reduce(math.max);
  final height = regions.map((bounds) => bounds.bottom + 1).reduce(math.max);
  final kinds = List<TileKind>.filled(width * height, TileKind.wall);
  final zombieCounts = <EntityKind, int>{};

  for (final (point, glyph) in _outdoorGlyphs()) {
    kinds[point.y * width + point.x] = _streetKind(glyph);
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
      case 'w' || 'z' || 'u':
        final kind = switch (glyph) {
          'z' => EntityKind.sprinter,
          'u' => EntityKind.brute,
          _ => EntityKind.wanderer,
        };
        final index = zombieCounts[kind] ?? 0;
        zombieCounts[kind] = index + 1;
        entities.add(
          factory.zombie(
            id: '${kind.name}-$index',
            kind: kind,
            position: point,
          ),
        );
      case '1':
        pickups.add(Pickup(id: ammoBackpackId, position: point, ammo: 2));
      case '2':
        pickups.add(Pickup(id: accidentBackpackId, position: point, ammo: 4));
    }
  }
  for (final (point, glyph) in _glyphs(barracksOrigin, barracksRows)) {
    kinds[point.y * width + point.x] = _barracksKind(glyph);
    if (glyph == '3') {
      pickups.add(Pickup(id: gunBackpackId, position: point, gun: true));
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

/// A world resumed from a save, on the current layout of the level.
///
/// Saves made before the layout changed (e.g. before the north district
/// was split from the street) carry the old map: the map, doors and camps
/// are taken from the current level, the zombies new to it are added, and
/// Mario, who always saves beside a campfire, is put back beside the one
/// the level has now.
WorldState restoreStreetWorld(Map<String, Object?> json) {
  final saved = WorldState.fromJson(json);
  final current = createStreetWorld();
  final sameLayout =
      saved.map.width == current.map.width &&
      saved.map.height == current.map.height &&
      saved.campfires.length == current.campfires.length &&
      saved.campfires.containsAll(current.campfires);
  if (sameLayout) {
    return saved;
  }
  final entities = <String, Entity>{
    for (final entity in current.entities.values)
      if (entity.kind != EntityKind.player) entity.id: entity,
    ...saved.entities,
  };
  final camp = current.campfires.first;
  final (facing, restSpot) = Direction.values
      .map((direction) => (direction, camp.step(direction.opposite)))
      .firstWhere((spot) => current.map.tileAt(spot.$2).isWalkable);
  entities[saved.playerId]!.component<PositionComponent>()
    ..position = restSpot
    ..facing = facing;
  return WorldState(
    map: current.map,
    entities: entities.values,
    playerId: saved.playerId,
    random: saved.random,
    tick: saved.tick,
    pickups: saved.pickups.values,
    alertTriggers: saved.alertTriggers,
    portals: current.portals,
    campfires: current.campfires,
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
