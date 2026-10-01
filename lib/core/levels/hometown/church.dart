import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// Inside San Nicola, the small church deep in the alleys of the old town
/// (the barracks' style, a room on a dark background). Nobody sheltered
/// here the way they did at the Duomo: the roof has fallen in, the pews
/// are shoved out of line, and the sacristy has been emptied by whoever
/// got here first. What they left behind is the censer's incense, in a
/// backpack against the east wall.
/// - `x` darkness, `W` the apse wall behind the altar, `w` the front wall
///   with the portal in it, `I` the side walls, `A` the altar: walls.
/// - `E` the portal onto the little square, the way in and out: two
///   cells wide from inside, like the aisle it opens on.
/// - `T` a pew, `K` a toppled column drum: obstacles.
/// - `.` flagstones, `:` fallen plaster and glass (noisy), `b` blood,
///   `^` daylight through a hole in the roof, `Z` a wanderer, `9` the
///   backpack with the incense.
// church-rows-start
const List<String> churchRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWx',
  'xI.:.....AAAA.....:...Ix',
  'xI..b....AAAA....:....Ix',
  'xI...:.....^.....b....Ix',
  'xI..:......Z......:...Ix',
  'xI.TTTT..:....TTTT....Ix',
  'xI.TTTT.......TTTT..b.Ix',
  'xI.TTTT..:....TTTT....Ix',
  'xI.::.........TTTT...9Ix',
  'xI.TTTT.......:.:.....Ix',
  'xI.TTTT..b....TTTT....Ix',
  'xI.TTTT..:....TTTT..:.Ix',
  'xI.TTTT.......TT::....Ix',
  'xI..:.....^.......Z..:Ix',
  'xIK..:..........b....KIx',
  'xI..b......:.....^....Ix',
  'xwwwwwwwwwwEEwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxx',
];
// church-rows-end

/// San Nicola: the altar `A` and the side walls `I` are as solid as the
/// outer ones, the pews `T` and the column drums `K` are waist high.
const Legend churchLegend = Legend(walls: 'xWwIA', obstacles: 'TK');

final Place _church = place(PlaceId.church);
final Place _harbour = place(PlaceId.harbour);

/// The backpack `9` against the east wall of San Nicola: the incense Don
/// Angelo asked for.
const String incenseBackpackId = 'backpack-incense';
final GridPoint incenseBackpackTile = _church.tileOf('9');

/// The wanderers `Z` standing in the dark of the nave.
final List<GridPoint> churchZombieTiles = _church.tilesOf('Z');

/// The portal of San Nicola, standing open on the church's little square.
final GridPoint churchPortalTile = _harbour.tileOf('(');

/// The two cells of the portal `E` seen from inside the nave, west to
/// east.
final List<GridPoint> churchPortalInside = _church.doorRow('E');

/// The open portal of San Nicola, deep in the old town, both ways: from
/// the square Mario comes in at its west cell, and either cell takes him
/// back out onto the square.
final Map<GridPoint, Portal> churchPortals = <GridPoint, Portal>{
  ...pairedDoors(
    <GridPoint>[churchPortalTile],
    <GridPoint>[churchPortalInside.first],
    Direction.north,
  ),
  ...pairedDoors(churchPortalInside, <GridPoint>[
    for (final _ in churchPortalInside) churchPortalTile,
  ], Direction.south),
};
