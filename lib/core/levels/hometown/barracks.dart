import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

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
  'x.3....I.....TT......x',
  'x:.*...I.........TT..x',
  'xIIII*II.TT.c......c.x',
  'x.....:....+...:.....x',
  'x.TT....TT..TT....TT.x',
  'x....*.........*.....x',
  'x..TT..:.TT.*...TT.b.x',
  'x....................x',
  'xCCCCCC.......CCCCCC.x',
  'x..h....*..:.....h...x',
  'x..........b.........x',
  'xwwwwwwwwwEwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxx',
];
// barracks-rows-end

/// The barracks' glyphs: its walls, the cells and the desks are solid, the
/// tables, the chairs, the cabinets and the hatstand can be seen over.
const Legend barracksLegend = Legend(walls: 'xWQNSIw', obstacles: 'TCAh');

final Place _barracks = place(PlaceId.barracks);
final Place _street = place(PlaceId.street);

/// The backpack `3` in the barracks, with the pistol in it.
const String gunBackpackId = 'backpack-gun';
final GridPoint gunBackpackTile = _barracks.tileOf('3');

/// Where the carabinieri zombies come out in the barracks.
final List<GridPoint> carabiniereSpawns = _barracks.tilesOf('c');

/// A carabiniere zombie coming out of the dark at [position].
Entity createCarabiniere(String id, GridPoint position) {
  return EntityFactory(BalanceConfig.standard()).zombie(
    id: id,
    kind: EntityKind.carabiniere,
    position: position,
    facing: Direction.south,
  );
}

/// The barracks' front door on the street and its back door onto the
/// north district, both ways.
final Map<GridPoint, Portal> barracksPortals = <GridPoint, Portal>{
  ...pairedDoors(
    <GridPoint>[_street.tileOf('E')],
    <GridPoint>[_barracks.tileOf('E')],
    Direction.north,
  ),
  ...pairedDoors(
    <GridPoint>[_barracks.tileOf('E')],
    <GridPoint>[_street.tileOf('E')],
    Direction.south,
  ),
  ...pairedDoors(
    <GridPoint>[_barracks.tileOf('O')],
    <GridPoint>[northDistrictBackExitTile],
    Direction.north,
  ),
  ...pairedDoors(
    <GridPoint>[northDistrictBackExitTile],
    <GridPoint>[_barracks.tileOf('O')],
    Direction.south,
  ),
};
