import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// Inside the hospital at the end of the north district's west road, up
/// the stairs packed with the horde, through the PRONTO SOCCORSO doors.
/// Three floors, the way up and the way down in the same column on every
/// one (the Duomo's rule): the stairs `U` climb into the back wall of the
/// floor below and come out on the stairs `D` in the front wall of the
/// floor above.
///
/// Glyphs of all three floors:
/// - `x` darkness, `W` the back wall (two courses), `N` a notice board on
///   it, `w` the front wall, `I` a partition: walls.
/// - `E` the glass doors onto the stairs outside, `U` the stairs up, `D`
///   the stairs down: doors. `d` a doorway in a partition.
/// - `C` a counter, `T` a desk (two cells), `A` a filing cabinet or a
///   medicine cupboard, `h` a waiting-room chair, `L` an examination couch
///   (two cells), `V` a vending machine, `p` a potted plant, `s` a
///   stretcher (two cells), `r` a wheelchair, `H` a basin, `B` a hospital
///   bed (two cells, head to the north), `n` its bedside table, `f` a drip
///   stand, `M` a monitor on its trolley, `S` linen shelves: obstacles.
/// - `.` floor, `:` papers and glass (noisy), `b` blood, `*` ceiling lamp,
///   `+` flickering lamp, `Z` a wanderer.
///
/// The first floor is the emergency department: the waiting room with its
/// rows of chairs inside the doors, the reception counter with the staff
/// behind it to the west, the hall to the stairs, and the first three
/// consulting rooms along the back wall.
// hospital-first-rows-start
const List<String> hospitalFirstFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWNWWWWWWWWWWWUWWWWWWNWWWWWWNWWWWWNWWx',
  'xAA.....AAI........IA....HIA....HIA...Hx',
  'x.TT..TT..I........I.TT...I.TT...ITT...x',
  'x.:.......I...*....I...*LLI:...LLI...LLx',
  'x...b+....I........I..Z...I..*...I.b*..x',
  'x.........I........I.....:I......I.....x',
  'xCCCCCCCC.I........IIIdIIIIIIdIIIIIdIIIx',
  'x.....:................ss............r.x',
  'xr......*.......:...*...b......*...:...x',
  'xV.p.................................pVx',
  'x..hhhhhh..hhhhhh........hhhhhh..hhhh..x',
  'x.....*.:....+..............*......*...x',
  'x..hhhhhh..hhhhhh........hhhhhh..hhhh..x',
  'xV...b.....Z........*.............:...Vx',
  'xp.....:..............................px',
  'xwwwwwwwwwwwwwwwwwwEEwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// hospital-first-rows-end

/// The second floor, a ward: a corridor down the middle and the rooms
/// either side of it, two beds each, and the linen room at the east end.
/// The stairs are a landing of their own between the rooms.
// hospital-second-rows-start
const List<String> hospitalSecondFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWUWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xnB..BnInB..BnI...InB..BnInB..BnInB..BnISSSx',
  'x.B*.B.I.B*.B.I...I.B*.B.I.B*:B.I.B*.B.I...x',
  'x......I.f....I.*.I....f.I......I.f....I.*.x',
  'x.Z....I......I...I......I....Z.I......I...x',
  'xA....:IA.....I...IA.....IA.....IA....bIS..x',
  'xIIdIIIIIIIdIII...IIIdIIIIIIIdIIIIIdIIIIIdIx',
  'x....*........:........*...ss.....*..r.....x',
  'x..r.....b.........................:.......x',
  'xIIIdIIIIIdIIII...IIIIdIIIIIdIIIIIIIdIIIIdIx',
  'x......I......I...I......I.....:I......I...x',
  'xA.....I.....AI.*.IA.....I.....AIA..Z..ICC.x',
  'x..f...I.:f...I...I..f...Ib.f...I..f...I.*.x',
  'x.B*.B.I.B*.B.I...I.B*.B.I.B+.B.I.B*.B.I...x',
  'xnB..BnInB..BnI...InB..BnInB..BnInB..BnIA.Ax',
  'xwwwwwwwwwwwwwwwDwwwwwwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// hospital-second-rows-end

/// The third floor, the last: another ward like the one below, with the
/// monitors of the patients who were worst off. Its stairs `U` go on up
/// to the roof.
// hospital-third-rows-start
const List<String> hospitalThirdFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWUWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xnB.MBnInBM.BnI...IMB..BMInB..BnInB..BnISSSx',
  'x.B*.B.I.B*.B.I...I.B*.B.I.B+.B.I.B*bB.I...x',
  'x.f....I....f.I.*.I.f..f.I......I......I.*.x',
  'x......I.:....I...I..Z...I......I.Z....I...x',
  'xA.....I.....AI...I......IA...:.I.....AIS..x',
  'xIIdIIIIIIIdIII...IIIdIIIIIIIdIIIIIdIIIIIdIx',
  'x.:..*...b....r........*..........*........x',
  'x......ss..............:.......b.......ss..x',
  'xIIIdIIIIIdIIII...IIIIdIIIIIdIIIIIIIdIIIIdIx',
  'x......I......I...I......I......I......I...x',
  'xA..Z..I.....AI.*.IA.....I.:...AIA.....I.S.x',
  'x..f...Ib.f...I...I..f...I..f...I..f.Z.I.*.x',
  'x.B*.B.I.B+.B.I...I.B*.B.I.B*.B.I.B*.B.I...x',
  'xnB..BMIMB..BnI...InB..BnInBM.BnInB..BnIS.Sx',
  'xwwwwwwwwwwwwwwwDwwwwwwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// hospital-third-rows-end

/// The hospital's roof, up the stairs from the third floor: they come out
/// of the hatch `D` in the felt. A flat roof walled `W` on three sides and
/// with its parapet `^` along the front, stacks `T` and aerials `n` about
/// it, gravel `:` and blood `b`, and in the middle a camp someone made up
/// here, out of the horde's reach: the fire `S`, where Mario can rest.
///
/// East, across the gap `x` to the street far below, stands the next
/// block, built like this one: walled `W` round its roof, the parapet `^`
/// along its front, its own stacks `T`, aerial `n` and gravel `:`, and
/// the open stairwell `v` going down into it, onto its top floor
/// (east_block.dart). `>` is the stretch of the
/// east wall knocked down low, where Mario measures the gap: too far to
/// jump, near enough for a grappling hook, as on the roofs past the
/// airliner and at the top of the Duomo's tower. Straight across from it
/// the next block's wall is broken open `<`: where the hook would bring
/// Mario in, and where it takes him back from.
// hospital-roof-rows-start
const List<String> hospitalRoofRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWxxWWWWWWWWWWx',
  'xW...T.......:......n.WxxW..T.....Wx',
  'xW..........b.........WxxW........Wx',
  'xW.:..............T...WxxW.:......Wx',
  'xW.......:............WxxW........Wx',
  'xW....................WxxW........Wx',
  'xW.........S..........>xx<........Wx',
  'xW..T.................WxxW...vv.:.Wx',
  'xW..........:.....n...WxxW.n.vv...Wx',
  'xW....................WxxW........Wx',
  'xW.....:..........T...WxxWT.......Wx',
  'xW....D.........b.....WxxW....:...Wx',
  'xW..........:.........WxxW.......TWx',
  'x^^^^^^^^^^^^^^^^^^^^^^xx^^^^^^^^^^x',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// hospital-roof-rows-end

/// The hospital's three floors: the walls and partitions are solid, and
/// everything a ward or a waiting room is furnished with stops a step but
/// not a shot.
const Legend hospitalLegend = Legend(
  walls: 'xWwIN',
  obstacles: 'CTAhLVpsrHBnfMS',
);

/// The hospital's roof: its walls and the drop are walls, the parapet, the
/// wall knocked down low `>`, the stacks, the aerials and the camp's fire
/// can be seen over, and the gravel is noisy.
const Legend hospitalRoofLegend = Legend(walls: 'xW', obstacles: '^><TnS');

final Place _hospitalFirst = place(PlaceId.hospitalFirstFloor);
final Place _hospitalSecond = place(PlaceId.hospitalSecondFloor);
final Place _hospitalThird = place(PlaceId.hospitalThirdFloor);
final Place _hospitalRoof = place(PlaceId.hospitalRoof);
final Place _north = place(PlaceId.northDistrict);

/// The hospital's glass doors at the top of its stairs, in the north
/// district, and the same doors seen from inside the waiting room.
final List<GridPoint> hospitalDoors = _north.doorRow(r'$');
final List<GridPoint> hospitalEntrance = _hospitalFirst.doorRow('E');

/// The hospital's stairs, bottom to top: on each floor the flight `U` up
/// out of its back wall and, on the floor above, the stairs `D` in the
/// front wall it comes out on; from the third floor, the hatch `D` in the
/// roof.
final List<(GridPoint, GridPoint)> hospitalFlights = <(GridPoint, GridPoint)>[
  (_hospitalFirst.tileOf('U'), _hospitalSecond.tileOf('D')),
  (_hospitalSecond.tileOf('U'), _hospitalThird.tileOf('D')),
  (_hospitalThird.tileOf('U'), _hospitalRoof.tileOf('D')),
];

/// The camp on the hospital's roof, out of the horde's reach.
final GridPoint hospitalRoofCampfireTile = _hospitalRoof.tileOf('S');

/// The fires on the roof: the camp's.
final List<FireSpot> hospitalRoofFireSpots = firesIn(_hospitalRoof);

/// The stretch of the roof's east wall knocked down low, facing the next
/// block across the gap: looking over it, Mario measures the gap.
final GridPoint hospitalRoofLookoutTile = _hospitalRoof.tileOf('>');

/// The next block's wall broken open straight across from
/// [hospitalRoofLookoutTile]: the way back with the grappling hook.
final GridPoint hospitalNextRoofEdgeTile = _hospitalRoof.tileOf('<');

/// The hospital's stairs `Y` in the north district and the forecourt at
/// their foot, where the ambulances crashed: the horde there mills about,
/// each of them turned its own way (see [hospitalForecourtFacings]). The
/// ones out on the street, past it, all look west.
final GridRect hospitalForecourt = GridRect(
  _north.origin.x + 2,
  _north.origin.y + 24,
  _north.origin.x + 17,
  _north.origin.y + 33,
);

/// A sprinter in the middle of the forecourt, among the horde: placed by
/// hand rather than drawn, so the other sprinters keep their numbers.
final GridPoint hospitalForecourtSprinterTile = GridPoint(
  _north.origin.x + 10,
  _north.origin.y + 31,
);
const String hospitalForecourtSprinterId = 'hospital-forecourt-sprinter';

/// The ways the zombies in [hospitalForecourt] face, handed out in turn
/// row by row: every way about as often, and no two neighbours alike.
const List<Direction> hospitalForecourtFacings = <Direction>[
  Direction.south,
  Direction.east,
  Direction.north,
  Direction.west,
  Direction.east,
  Direction.south,
  Direction.west,
  Direction.north,
];

/// The wanderers `Z` left in the hospital, floor by floor,
/// `hospital-wanderer-<n>`.
const String hospitalZombiePrefix = 'hospital-wanderer-';
final List<GridPoint> hospitalZombieTiles = <GridPoint>[
  for (final floor in <Place>[_hospitalFirst, _hospitalSecond, _hospitalThird])
    ...floor.tilesOf('Z'),
];

/// The open stairwell `v` going down southward into the block east of the
/// hospital's roof, two steps deep: its last step is the door onto the
/// block's top floor (see `eastBlockPortals`).
final List<GridPoint> hospitalNextRoofStairs = _hospitalRoof.tilesOf('v');

/// The last steps of [hospitalNextRoofStairs], at its south end.
final List<GridPoint> hospitalNextRoofStairsFoot = lastSteps(
  hospitalNextRoofStairs,
  Direction.south,
);

/// That stairwell, each step with the way up it (see `WorldState.stairs`).
final Map<GridPoint, Direction> hospitalStairs = <GridPoint, Direction>{
  for (final step in hospitalNextRoofStairs) step: Direction.south,
};

/// The hospital's glass doors at the top of its stairs, and inside it the
/// flights up from each floor to the next (in the back wall of the floor
/// below, onto the stairs in the front wall of the one above). All both
/// ways.
final Map<GridPoint, Portal> hospitalPortals = <GridPoint, Portal>{
  ...pairedDoors(hospitalDoors, hospitalEntrance, Direction.north),
  ...pairedDoors(hospitalEntrance, hospitalDoors, Direction.south),
  for (final (below, above) in hospitalFlights) ...<GridPoint, Portal>{
    ...pairedDoors(<GridPoint>[below], <GridPoint>[above], Direction.north),
    ...pairedDoors(<GridPoint>[above], <GridPoint>[below], Direction.south),
  },
};
