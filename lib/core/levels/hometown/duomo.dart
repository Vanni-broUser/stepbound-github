import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

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

/// The nave: the indoor masonry vocabulary, with its furnishings as
/// waist-high obstacles.
const Legend duomoLegend = Legend(walls: 'xWwIA', obstacles: 'PTMKFVYG12p');

final Place _duomo = place(PlaceId.duomo);
final Place _duomoUpper = place(PlaceId.duomoUpper);
final Place _duomoSecond = place(PlaceId.duomoSecondFloor);
final Place _duomoTower = place(PlaceId.duomoTower);
final Place _duomoBells = place(PlaceId.duomoBells);

/// The cultist's robe `R` on the community's floor.
const String cultistRobePickupId = 'cultist-robe';

/// People and the guarded door upstairs inside the Duomo: the door
/// [duomoStairEntryTile] is in the back wall, straight behind the cultist
/// who stands in front of it.
final GridPoint duomoPriestTile = _duomo.tileOf('p');
final GridPoint duomoStairCultistTile = _duomo.tileOf('1');
final GridPoint duomoWelcomingCultistTile = _duomo.tileOf('2');
final GridPoint duomoStairCultistMovedTile = _duomo.tileOf('3');
final GridPoint duomoStairEntryTile = _duomo.tileOf('U');
final GridPoint duomoUpperStairTile = _duomoUpper.tileOf('D');
final GridPoint duomoUpperLockedDoorTile = _duomoUpper.tileOf('L');
final GridPoint duomoUpperRobeTile = _duomoUpper.tileOf('R');

/// The way up from the door the key opens to the top of the bell tower:
/// on each floor the stairs `D` Mario comes up by and the doorway `U` he
/// goes on up through, and on the roof the hatch he comes out of
/// ([duomoRoofHatchTile], duomo_tower_roof.dart).
final GridPoint duomoSecondFloorStairTile = _duomoSecond.tileOf('D');
final GridPoint duomoSecondFloorUpTile = _duomoSecond.tileOf('U');
final GridPoint duomoTowerStairTile = _duomoTower.tileOf('D');
final GridPoint duomoTowerUpTile = _duomoTower.tileOf('U');
final GridPoint duomoBellsStairTile = _duomoBells.tileOf('D');
final GridPoint duomoBellsUpTile = _duomoBells.tileOf('U');

/// What the mass leaves behind in the nave, once the community has eaten
/// of the crucified zombie and turned on Don Angelo: the four mutated
/// cultists `c` across the aisle between the first two blocks of pews,
/// his body `d` behind them and, beside it, the backpack `9` with the key
/// of the upper floor. None of it is there before the mass: the zombies
/// are raised by the Duomo's script, the body is put where it lies and the
/// backpack starts inactive.
final List<GridPoint> duomoCultistSpawns = _duomo.tilesOf('c');

/// The crucified zombie over the altar, on the shared grid: it hangs from
/// the moment the mass is over, and is scenery, so it has no glyph and no
/// entity of its own (see [duomoCrucifixSpot]).
final GridPoint duomoCrucifixTile = GridPoint(
  _duomo.origin.x + duomoCrucifixSpot.x,
  _duomo.origin.y + duomoCrucifixSpot.y,
);
final GridPoint duomoPriestCorpseTile = _duomo.tileOf('d');
final GridPoint duomoKeyTile = _duomo.tileOf('9');

/// Their ids, `duomo-cultist-0` to `duomo-cultist-3`.
const String duomoCultistPrefix = 'duomo-cultist-';
const String duomoKeyPickupId = 'duomo-key';

/// One of the mutated cultists of the Duomo, raised where the mass left
/// him: he looks out of the aisle, away from Don Angelo's body -- east at
/// the east end of the pews, west at the west end.
Entity createDuomoCultist(String id, GridPoint position) {
  return EntityFactory(BalanceConfig.standard()).zombie(
    id: id,
    kind: EntityKind.cultist,
    position: position,
    facing: position.x < duomoPriestCorpseTile.x
        ? Direction.west
        : Direction.east,
  );
}

/// The Duomo's open portal behind its story-gated churchyard and, inside
/// it, the guarded door up to the first floor, the locked door on up to
/// the second, and on up the bell tower's two flights to the hatch out
/// onto its roof: every door and flight is in the back wall of the floor
/// it leaves and lands Mario on the step above the stairs in the front
/// wall of the next; the hatch is in the roof's floor. All both ways.
final Map<GridPoint, Portal> duomoPortals = <GridPoint, Portal>{
  ...pairedDoors(
    <GridPoint>[duomoPortalTile],
    <GridPoint>[_duomo.tileOf('E')],
    Direction.north,
  ),
  ...pairedDoors(
    <GridPoint>[_duomo.tileOf('E')],
    <GridPoint>[duomoPortalTile],
    Direction.south,
  ),
  ...pairedDoors(
    <GridPoint>[duomoStairEntryTile],
    <GridPoint>[duomoUpperStairTile],
    Direction.north,
  ),
  ...pairedDoors(
    <GridPoint>[duomoUpperStairTile],
    <GridPoint>[duomoStairEntryTile],
    Direction.south,
  ),
  for (final (below, above) in <(GridPoint, GridPoint)>[
    (duomoUpperLockedDoorTile, duomoSecondFloorStairTile),
    (duomoSecondFloorUpTile, duomoTowerStairTile),
    (duomoTowerUpTile, duomoBellsStairTile),
    (duomoBellsUpTile, duomoRoofHatchTile),
  ]) ...<GridPoint, Portal>{
    ...pairedDoors(<GridPoint>[below], <GridPoint>[above], Direction.north),
    ...pairedDoors(<GridPoint>[above], <GridPoint>[below], Direction.south),
  },
};
