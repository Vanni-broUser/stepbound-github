import 'package:stepbound/core/grid/grid_point.dart';

/// Inside the Duomo on the harbour: a broad basilica, larger than San
/// Nicola, with three naves. Two rows of great columns `P`, each two tiles
/// by two, separate the central nave, where the pews `T` face the altar
/// `A`, from the side aisles. Against the side walls stand six statues,
/// each two by two and each a saint of its own: the Madonna `M`, Saint
/// Peter with his keys `K` and Saint Francis `F` on the west wall, Saint
/// Conrad the bishop `V`, Saint Michael with his sword `Y` and Saint Joseph
/// with his lily `G` on the east wall.
///
/// The door `U` in the back wall, in the north-east corner, opens on the
/// stairs to the floor above; its jambs are wall, so the only way to it is
/// the tile in front, where cultist `1` stands until the ring is handed
/// over and then steps aside to `3`. The stairs themselves are the upper
/// floor's. Cultist `2` welcomes Mario in the west aisle and Don Angelo
/// `p` waits by the altar.
///
/// The aisle between the first two blocks of pews is where the mass ends:
/// once it has, Don Angelo's body `d` lies in it and the backpack `9`
/// beside it holds the key of the upper floor, and the four mutated
/// cultists `c` shut both its ends: two shoulder to shoulder at the east
/// end of the pews, looking east, and two at the west end, looking west.
/// All four glyphs are plain floor until then, and the pews close the
/// aisle north and south, so the key is only reached by getting past one
/// pair of them.
///
/// `E` is the open main portal, `*` are steady lamps and `:` is debris.
/// Torches burn on every column and on the wall behind the altar
/// ([duomoTorches]).
// duomo-rows-start
const List<String> duomoRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWUWWWx',
  'xI...........AAAAAAAA........1.3Ix',
  'xI....*......AAAAAAAA.......*...Ix',
  'xI......PP......p.......PP......Ix',
  'xIMM....PP.:.....*......PP....VVIx',
  'xIMM..........................VVIx',
  'xI...........TTTTTTTT...........Ix',
  'xI..:.......c.....9..c..........Ix',
  'xI......PP..c.....d..c:.PP.:....Ix',
  'xI......PP...TTTTTTTT...PP......Ix',
  'xIKK..........................YYIx',
  'xIKK..2..........*............YYIx',
  'xI....*......TTTTTTTT.......*...Ix',
  'xI......PP..............PP......Ix',
  'xI......PP..............PP......Ix',
  'xI...........TTTTTTTT...........Ix',
  'xIFF...:......................GGIx',
  'xIFF.............*............GGIx',
  'xI......PP...TTTTTTTT...PP......Ix',
  'xI......PP..............PP:.....Ix',
  'xI..........:...................Ix',
  'xwwwwwwwwwwwwwwwEwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// duomo-rows-end

/// Where the zombie hangs crucified, in the Duomo's own tiles: the top-left
/// corner of the two-tile-wide prop, on the back wall over the middle of
/// the altar and between the two inner torches. Nothing changes on the map
/// for it -- that row is wall like the rest of the wall -- and nothing of
/// it is there before the mass: the game hangs it up afterwards
/// (`CrucifiedZombieComponent`).
const GridPoint duomoCrucifixSpot = GridPoint(16, 1);

/// Where the Duomo's torches burn, in its own tiles: one on each of the
/// eight columns `P`, on the side of its shaft that faces the central nave,
/// and four on the back wall behind the altar, two each side of its middle.
const List<GridPoint> duomoTorches = <GridPoint>[
  GridPoint(9, 5),
  GridPoint(24, 5),
  GridPoint(9, 10),
  GridPoint(24, 10),
  GridPoint(9, 15),
  GridPoint(24, 15),
  GridPoint(9, 20),
  GridPoint(24, 20),
  GridPoint(13, 2),
  GridPoint(15, 2),
  GridPoint(18, 2),
  GridPoint(20, 2),
];
