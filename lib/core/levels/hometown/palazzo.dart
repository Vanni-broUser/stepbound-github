import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// The palazzo the roofs past the airliner belong to: the stairwell
/// going down from them comes out on its top floor. Three floors of flats
/// over the entrance hall, the stairs `U` up and `D` down in the middle
/// of every floor, on the landing all of them share: the way up climbs
/// into the back wall of the floor below and comes out of the front wall
/// of the floor above (the hospital's rule). The landings are lit; the
/// flats are dark, a lamp still on here and there.
///
/// Glyphs of all four:
/// - `x` darkness, `W` the back wall (two courses), `w` the front wall,
///   `I` a partition: walls. `L` the one flat door still shut, on the
///   third floor: a wall, until the key found on the first floor opens
///   it for good on the flat behind it; `Y` that door from inside the
///   flat: a door.
/// - `U` the stairs up, `D` the stairs down, `E` the portone onto the
///   street: doors. `P` a flat's door onto the landing, kicked in, and
///   `d` a doorway between two rooms: floor.
/// - Floors: `.` parquet (living rooms, bedrooms, corridors), `,` the
///   kitchen's tiles, `_` the bathroom's, `=` the landing's marble.
/// - `S` a sofa (a run of seats), `a` an armchair, `V` a TV cabinet and
///   `T` a table (two cells each), `h` a chair, `B` a bed (two cells, head
///   to the north), `n` a bedside table, `A` a wardrobe, `l` a bookcase,
///   `K` kitchen units, `O` the cooker, `F` the fridge, `H` a washbasin,
///   `Q` the toilet, `R` the bathtub (two cells), `M` the letterboxes,
///   `p` a potted palm, `r` a heap where the ceiling came down:
///   obstacles.
/// - `:` plaster down off the ceiling (noisy), `b` blood, `c` a body,
///   `*` ceiling lamp, `+` flickering lamp, `Z` a wanderer, `z` a
///   sprinter, `9` the backpack with two rounds, `8` the one with two
///   molotovs, `k` the key of the third floor.
///
/// The entrance hall on the street: the letterboxes on the back wall and
/// the stairs up between them, the portone in the front wall.
// palazzo-ground-rows-start
const List<String> palazzoGroundFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWMMMWWWWWUWWWWWWMMWWWx',
  'xp====================px',
  'x===*======*==:===*====x',
  'x=======b==============x',
  'x==================Z===x',
  'x===c==================x',
  'x=====*========b*======x',
  'x======================x',
  'xwwwwwwwwwwEwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxx',
];
// palazzo-ground-rows-end

/// The first floor: a flat either side of the landing. In the west one,
/// on the bedroom's floor by the bed, the key of the third floor.
// palazzo-first-rows-start
const List<String> palazzoFirstFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWUWWWWWWWWWWWWWWWWWWWWWWx',
  'xKKOKF,,IVV.......lIp=====IVV.....lIKKOKO,,,Fx',
  'x,,,*,,,I..+...Z...I=*====I....*...I,,*,,,,,,x',
  'x,,,,,,,d..........I======I......c.d,,,,,,,,,x',
  'x,hTTh,,I..b.SSSa..I======I.b......I,,hTTh,,,x',
  'xb,,,+,,I.c......:.I======I...SSa..I,,,,,,,Z,x',
  'x,,,,,c,IIIIIdIIIIII====*=I........I,c,,b,,,,x',
  'xIIIIIIIIA.........I======IIIIdIIIIIIIIIIIIIIx',
  'xRR____QI.....b....P======Ill....I......nBn..x',
  'x___*Z__d....*..+r.I======I....Z.d...b+..B...x',
  'x___b___I..c.......I=*====P..+...I.A........:x',
  'xH______IIIIdIIIIIII======I......IIIIIIIIIIIIx',
  'xIIIIIIII.....nBBn.I======I..TTh.I____Q_____Hx',
  'xAA.....I...Z..BB..I======I...*..d______*_b__x',
  'x...+.r.d.........kI====*=Ir..c..I______c____x',
  'x..c....IAA..b.....I=====pI..r...IRR_________x',
  'xwwwwwwwwwwwwwwwwwwwwwwDwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// palazzo-first-rows-end

/// The second floor: one flat west of the landing and two east of it,
/// one behind the other. In the front one's bedroom, a backpack with two
/// rounds.
// palazzo-second-rows-start
const List<String> palazzoSecondFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWUWWWWWWWWWWWWWWWWWWWWWWx',
  'xl..VV.......IA....Ip=====IKKOKF,IVV....lI.Bnx',
  'x..........Z.I...b.I=*====I,,,+,,I....Z..I.B.x',
  'x.....*..a...d..*..I======P,,,,,,I..b+...d...x',
  'x..SSS.......I.c...P======I,hTTh,d.......I.b*x',
  'x............I.....I======I,,,,,,I...SSa.I...x',
  'x......hTTh..IIIIdII====*=I,Z,c,,I.:.....I..cx',
  'x.c.b........IKOK,FI======I,,,,,bI.......IA..x',
  'x.........:rrI,,,*,I======IIIIIIIIIIIIIIIIIIIx',
  'xIIIIIIIIdIIII,TT,hI======IKOKF.VV..I.nBn...Ax',
  'x..nBBn......I+,,b,I=*====I..+.....rI..B.....x',
  'x...BB.......IIdIIII======I....b.*..d....*.9.x',
  'x.*........b.IQ___HI======I.hTT.....I.....b..x',
  'x........Z.+.I_____I======P.........IIIdIIIIIx',
  'x......c.....I_+c__I====*=I...Z.SSa.IQ__+___Hx',
  'xAA.......:..I___RRI=====pIc........I___cRR__x',
  'xwwwwwwwwwwwwwwwwwwwwwwDwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// palazzo-second-rows-end

/// The third floor, the top one, where the stairs from the roof come
/// down: the flat west of the landing and the one in front east of it
/// stand open; the one behind them, east, is locked, `L`, until the key
/// opens it on a map of its own (`palazzoLockedFlatRows`): here nothing
/// of it is drawn, so nothing in it is seen from the landing.
// palazzo-third-rows-start
const List<String> palazzoThirdFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWUWWWWxxxxxxxxxxxxxxxxxxx',
  'x.VV....l..IKKOKKF,Ip=====Ixxxxxxxxxxxxxxxxxxx',
  'x.....a....I,,,,,,,I=*====Ixxxxxxxxxxxxxxxxxxx',
  'x...Z....c.I,,,:,,,I======Ixxxxxxxxxxxxxxxxxxx',
  'x.SS.......I,hTTh,,I======Lxxxxxxxxxxxxxxxxxxx',
  'x....+.TT.bI,,,+,c,I======Ixxxxxxxxxxxxxxxxxxx',
  'x..:.......Ib,,,,,,I====*=Ixxxxxxxxxxxxxxxxxxx',
  'xIIIIdIIIIIIIIIdIIII======Ixxxxxxxxxxxxxxxxxxx',
  'xA...........:.....I======IIIIIIIIIIIIIIIIIIIx',
  'x.+.b...*.Z........P======IKKOKF.VV..IRR____Qx',
  'x................c.I=*====P..*.......d__b+___x',
  'xIIdIIIdIIIIIIIIdIII======I.....Z..c.I______Hx',
  'xRR__QI.nBBn.I....BI======IhTTh..*...IIIIdIIIx',
  'x__*__I..BB..I.:*.BI======I..........InB..*..x',
  'x_b___I..+.Z.I..b..I====*=I..r...SSa.I.B..Z..x',
  'x___H_Ic....AIA....I=====pI.b.r......I...c..Ax',
  'xwwwwwwwwwwwwwwwwwwwwwwDwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// palazzo-third-rows-end

/// The flat behind the third floor's locked door, a map of its own, got
/// into only through it (`Y`, on its west wall): the kitchen and the
/// living room in one, a sprinter shut in there since whoever locked the
/// door, and through the doorway east the bedroom, where the backpack
/// with two molotovs lies.
// palazzo-locked-flat-rows-start
const List<String> palazzoLockedFlatRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWx',
  'xIKKOKF,,SSaInBBn..Ax',
  'xI,,,,,,,...I.BB...Ax',
  'xI,hTTh,..*.I...+...x',
  'xY....c....:I..b...8x',
  'xI..z.......d.......x',
  'xI.........bI..:....x',
  'xIVV.:..+..lIA....clx',
  'xwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxx',
];
// palazzo-locked-flat-rows-end

/// The palazzo's stairwell on every floor, from its back wall to its
/// front wall: the landing, the stairs up and the stairs down, lit
/// throughout (see `PlaceSpec.litAreas`).
const GridRect palazzoStairwell = GridRect(20, 1, 25, 18);

/// How dark the palazzo's flats are between their lamps: dim, not black.
const double palazzoFlatDarkness = 0.72;

/// The palazzo's hall and floors: the walls, the partitions, the
/// letterboxes on the wall and the door still locked are solid, and what
/// furnishes a flat stops a step but not a shot. The plaster down off the
/// ceilings crunches underfoot.
const Legend palazzoLegend = Legend(
  walls: 'xWwILM',
  obstacles: 'SaVThBnAlKOFHQRpr',
);

final Place _palazzoGround = place(PlaceId.palazzoGroundFloor);
final Place _palazzoFirst = place(PlaceId.palazzoFirstFloor);
final Place _palazzoSecond = place(PlaceId.palazzoSecondFloor);
final Place _palazzoThird = place(PlaceId.palazzoThirdFloor);
final Place _palazzoFlat = place(PlaceId.palazzoLockedFlat);

/// The palazzo's stairs, bottom to top: on each floor the flight `U` up
/// in the back wall, and where it comes out, the flight `D` down in the
/// front wall of the floor above.
final List<(GridPoint, GridPoint)> palazzoFlights = <(GridPoint, GridPoint)>[
  (_palazzoGround.tileOf('U'), _palazzoFirst.tileOf('D')),
  (_palazzoFirst.tileOf('U'), _palazzoSecond.tileOf('D')),
  (_palazzoSecond.tileOf('U'), _palazzoThird.tileOf('D')),
];

/// The top of the palazzo's stairwell, on the third floor: up it, the
/// stairs on the roof past the airliner.
final GridPoint palazzoRoofStairs = _palazzoThird.tileOf('U');

/// The portone, from the hall (from the street it is
/// [industryStreetPortone]).
final GridPoint palazzoPortone = _palazzoGround.tileOf('E');

/// The flat door on the third floor still locked, until the key opens it.
final GridPoint palazzoLockedDoorTile = _palazzoThird.tileOf('L');

/// The same door from inside the flat behind it.
final GridPoint palazzoLockedFlatDoor = _palazzoFlat.tileOf('Y');

/// The sprinter shut in the flat behind the locked door.
const String palazzoSprinterId = 'palazzo-sprinter';
final GridPoint palazzoSprinterTile = _palazzoFlat.tileOf('z');

/// The backpack with two molotovs, in the bedroom of the flat behind the
/// locked door.
const String palazzoMolotovBackpackId = 'backpack-palazzo-molotov';
final GridPoint palazzoMolotovBackpackTile = _palazzoFlat.tileOf('8');

/// The backpack with two rounds, in the second floor's front flat.
const String palazzoBackpackId = 'backpack-palazzo';
final GridPoint palazzoBackpackTile = _palazzoSecond.tileOf('9');

/// The key of the third floor, on the first floor's bedroom floor.
const String palazzoKeyPickupId = 'palazzo-key';
final GridPoint palazzoKeyTile = _palazzoFirst.tileOf('k');

/// The wanderers `Z` left in the palazzo, top floor first,
/// `palazzo-wanderer-<n>`.
const String palazzoZombiePrefix = 'palazzo-wanderer-';
final List<GridPoint> palazzoZombieTiles = <GridPoint>[
  for (final floor in <Place>[
    _palazzoThird,
    _palazzoSecond,
    _palazzoFirst,
    _palazzoGround,
  ])
    ...floor.tilesOf('Z'),
];

/// Down the stairwell on the roof past the airliner into the palazzo's top
/// floor and back up onto its lowest step but one, the flights between the
/// floors, the locked door into the flat behind it, and the portone onto
/// the street. All both ways.
final Map<GridPoint, Portal> palazzoPortals = <GridPoint, Portal>{
  for (final step in rooftopFarStairsFoot)
    step: Portal(
      to: palazzoRoofStairs.step(Direction.south),
      facing: Direction.south,
    ),
  palazzoRoofStairs: Portal(
    to: rooftopFarStairsFoot.first.step(Direction.west),
    facing: Direction.west,
  ),
  for (final (below, above) in palazzoFlights) ...<GridPoint, Portal>{
    ...pairedDoors(<GridPoint>[below], <GridPoint>[above], Direction.north),
    ...pairedDoors(<GridPoint>[above], <GridPoint>[below], Direction.south),
  },
  // The locked door is a wall until the key opens it: then it leads into
  // the flat behind it, and back.
  ...pairedDoors(
    <GridPoint>[palazzoLockedDoorTile],
    <GridPoint>[palazzoLockedFlatDoor],
    Direction.east,
  ),
  ...pairedDoors(
    <GridPoint>[palazzoLockedFlatDoor],
    <GridPoint>[palazzoLockedDoorTile],
    Direction.west,
  ),
  ...pairedDoors(
    <GridPoint>[palazzoPortone],
    <GridPoint>[industryStreetPortone],
    Direction.south,
  ),
  ...pairedDoors(
    <GridPoint>[industryStreetPortone],
    <GridPoint>[palazzoPortone],
    Direction.north,
  ),
};
