import 'package:stepbound/core/grid/grid_point.dart';

/// Inside the Duomo on the harbour: a broad basilica, larger than San
/// Nicola, with three naves. Rows of columns `P` separate the central nave,
/// where the pews `T` face the altar `A`, from the side aisles and their
/// statues `S`. The stair `U` in the north-east corner leads deeper into the
/// church, but cultist `1` stands in front of it. Cultist `2` welcomes Mario
/// in the west aisle and Don Angelo `p` waits by the altar.
///
/// `E` is the open main portal, `*` are steady lamps and `:` is debris.
/// Torches burn on every column and on the wall behind the altar
/// ([duomoTorches]).
// duomo-rows-start
const List<String> duomoRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xI...........AAAAAAAA........UU.Ix',
  'xI....*......AAAAAAAA.......*UU.Ix',
  'xI..S....P......p.......P....1..Ix',
  'xI.........:.....*..............Ix',
  'xI...........................3..Ix',
  'xI...........TTTTTTTT...........Ix',
  'xI.:.....P..............P.......Ix',
  'xI....S...............:.........Ix',
  'xI...........TTTTTTTT.........:.Ix',
  'xI...2...........*.........S....Ix',
  'xI....*..P..............P.......Ix',
  'xI...........TTTTTTTT.......*...Ix',
  'xI..S...........................Ix',
  'xI..............................Ix',
  'xI.......P...TTTTTTTT...P....S..Ix',
  'xI.....:........................Ix',
  'xI...............*........:.....Ix',
  'xI....S......TTTTTTTT...........Ix',
  'xI.......P..............P..S....Ix',
  'xI..............................Ix',
  'xwwwwwwwwwwwwwwwEwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// duomo-rows-end

/// Where the Duomo's torches burn, in its own tiles: one on each of the ten
/// columns `P`, and four on the back wall behind the altar, two each side
/// of its middle.
const List<GridPoint> duomoTorches = <GridPoint>[
  GridPoint(9, 5),
  GridPoint(24, 5),
  GridPoint(9, 9),
  GridPoint(24, 9),
  GridPoint(9, 13),
  GridPoint(24, 13),
  GridPoint(9, 17),
  GridPoint(24, 17),
  GridPoint(9, 21),
  GridPoint(24, 21),
  GridPoint(13, 2),
  GridPoint(15, 2),
  GridPoint(18, 2),
  GridPoint(20, 2),
];
