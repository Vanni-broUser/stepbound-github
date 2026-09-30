import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// The cramped storeroom behind the locked service door of the Bar
/// Arcobaleno, the bar's cellar: crates `B`, a shelf `K` of spirits, racks
/// of wine `R` along the back wall, wine demijohns `G` in their wicker and
/// open crates of spirits `C`. The episcopal ring is the pickup `8` on the
/// back shelf. `E` returns to the bar.
// bar-backroom-rows-start
const List<String> barBackroomRows = <String>[
  'xxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWx',
  'xIRRR*..RRRR.*..Ix',
  'xI..KKKK.....8..Ix',
  'xIG:............Ix',
  'xIGG*....:....B.Ix',
  'xI...B.....C....Ix',
  'xI.........B...GIx',
  'xI.....C.....:*GIx',
  'xIGG............Ix',
  'xwwwwwwwEwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxx',
];
// bar-backroom-rows-end

/// The storeroom shares the Duomo's indoor masonry vocabulary, with its
/// own furnishings as waist-high obstacles.
const Legend barBackroomLegend = Legend(walls: 'xWwI', obstacles: 'KBGRC');

final Place _barBackroom = place(PlaceId.barBackroom);

/// The storeroom's door `E`, the other side of the bar's service door.
final GridPoint barBackroomDoorTile = _barBackroom.tileOf('E');

/// The episcopal ring `8` on the storeroom's floor.
const String episcopalRingPickupId = 'episcopal-ring';
final GridPoint episcopalRingTile = _barBackroom.tileOf('8');
