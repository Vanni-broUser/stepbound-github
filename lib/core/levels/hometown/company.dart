import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// Inside the company on the street out of the palazzo, through its gate:
/// a call centre in an office block, three floors of it. Two open-plan
/// wings side by side, the one Mario walks into on the west and the one on
/// the east behind the glass wall `G` down the middle, both in view from
/// the gate; across the top, a corridor that should join them, like an
/// upside-down U, but in the middle of it the staff piled up the desks,
/// the workstations and the computers `r` into a heap nobody gets over.
/// Each wing has its stairs up `U` in the back wall: the way round is by
/// the floors above. In the east wing, at one of the workstations, Chiara
/// `Y`, still on the phone, and two of her colleagues `Q` further along,
/// out of sight from the west wing.
///
/// Glyphs:
/// - `x` darkness, `W` the back wall (two courses), `w` the front wall,
///   `I` a partition, `G` the glass wall between the wings and round the
///   manager's office: walls.
/// - `E` the gate in from the street, `U` the stairs up: doors. `d` a
///   doorway: floor.
/// - Floors: `.` the carpet tiles of the open plan, `=` the grey vinyl of
///   the entrance, the corridor and the break corner.
/// - `D` a workstation facing the way in, its screen towards the room,
///   `B` one facing away, the back of its screen to the room, `h` an
///   office chair, `|` and `-` the cubicles' fabric panels, `R` the
///   reception counter, `T` the meeting table, `A` a filing cabinet, `K`
///   the photocopier, `V` a vending machine, `F` the water cooler, `p` a
///   potted plant, `r` the heap, `Y` where Chiara stands: obstacles.
/// - `:` paper and broken plastic strewn about (noisy), `b` blood, `c` a
///   body, `*` a ceiling lamp, `+` a flickering one.
/// - `Q` an operator turned, the handset still at its ear on its cord to
///   the desk beside it (see `TetherComponent`), `9` a backpack.
/// - `v` the stairs down, in the front wall of the floors above.
// company-rows-start
const List<String> companyRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWUWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWUWWWWx',
  'x====*======:====b===rrrrrrrrr=====*=====:===x',
  'x=b========*===:=====rrrrrrrrr=:========*===bx',
  'xIIIIIIII=:==========rrrrGrrrr===============x',
  'x..TT...I............:...G...............:...x',
  'x.hTTh*.I..-------.......G.-------..-------.Ax',
  'x..TT...I..D|D|D|D.......G.D|D|D|D..D|D|D|D..x',
  'x.:.....d..h|h|h|h.......G.h|Y|h|h..h|Q|h|Q..x',
  'xIIGGGIII.............*..G*.......*.......+..x',
  'x..........h|h|h|h.......G.h|h|h|h..h|h|h|h..x',
  'x...:......B|B|B|B...:...G.B|B|B|B..B|B|B|B..x',
  'xp.........-------.......G.-------..-------..x',
  'x=====*=.................G*......:...........x',
  'xVFV===......-------.....G.-------..-------..x',
  'x======..*...D|D|D|D.....G.D|D|D|D..D|D|D|D..x',
  'x=:=c==......h|h|h|h.....G.h|h|h|h..h|h|h|h..x',
  'x======b.................G.......+..IIIIIIIdIx',
  'x=====....pRRRR=*========G.b..AAKK..IATTh...px',
  'x==========:=============G..........I.....:..x',
  'xwwwwwwwwwwwwwwwwwwwwEEEEwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// company-rows-end

/// The first floor. Split again down the middle: the partition between the
/// west and the east half has its one doorway choked with another heap.
/// Each half has its stairs down `v` in the front wall, over the flight up
/// from the ground floor, and its stairs up `U` in the back wall. The
/// operators are at their desks on both sides.
// company-first-rows-start
const List<String> companyFirstRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWUWWWWWWWWWWWWWWWWWWWWUWWWWWWWWWWWx',
  'x========================I==========b======AAx',
  'x==========:=============I===================x',
  'x......*...........*.....I....*.........*....x',
  'x..-------....-------....I..-------..-------.x',
  'x..D|D|D|D....D|D|D|D....I..D|D|D|D..D|D|D|D.x',
  'x..h|h|Q|h....h|h|h|h....I..h|Q|h|h..h|h|h|h.x',
  'x.......................rr...................x',
  'x..h|h|h|h....h|h|Q|h...rrr.h|h|h|h..h|h|Q|h.x',
  'x.cB|B|B|B....B|B|B|B....rr.B|B|B|B..B|B|B|B.x',
  'x..-------....-------....I.:-------..-------.x',
  'x..........+..IIGGGGGIIIII.........*.........x',
  'x.-------.....I........A.I..-------..-------.x',
  'x.D|D|D|D.....I..TTh.....I..D|D|D|D..D|D|D|D.x',
  'x.Q|h|h|h.....d.hTT......I..h|h|h|h..h|h|h|Q.x',
  'x.........b...I.....*....I..................+x',
  'xp..........:.IA.......p.IKK.................x',
  'xwwwwvwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwvwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// company-first-rows-end

/// The second floor, the top one: one open plan from wall to wall, the
/// boss's office behind glass in the middle of the back wall. The flights
/// down from the west half and to the east half of the first floor are
/// both here: across it is the way round. A backpack with two rounds lies
/// against the west wall.
// company-second-rows-start
const List<String> companySecondRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xVFV============:==G====A=G==================x',
  'x==================GhTT===G=:================x',
  'x......*.......*...G.TT...G...*..........*...x',
  'x..-------.........G.....pG..-------.-------.x',
  'x..D|D|D|D.........Gc.....G..D|D|D|D.D|D|D|D.x',
  'x..h|Q|h|h.........GGGdGGGG..h|Q|h|h.h|Q|h|h.x',
  'x............................................x',
  'x9.h|h|h|h.-----...........c.h|h|h|Q.h|h|h|h.x',
  'x..B|B|B|B.D|D|D....---......B|B|B|B.B|B|B|B*x',
  'x.b-------.h|Q|h....D|D......-------.-------.x',
  'x.........+.........h|Q......................x',
  'x..-------.h|h|h.............-------.-------.x',
  'x..D|D|D|D.B|B|B....h|h......D|D|D|D.D|D|D|D.x',
  'x..h|h|Q|h.-----....B|B......h|h|h|h.h|h|h|Q.x',
  'x...........:.......---...+..................x',
  'xp...............*................b.........px',
  'xwwwwwwwwwwwvwwwwwwwwwwwwwwwwwwwwvwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// company-second-rows-end

/// The company past the palazzo: the walls, the partitions and the glass
/// between the wings are solid; the workstations, their panels and chairs,
/// what else furnishes an office, the heap across the corridor and Chiara
/// stop a step but not a shot. What is strewn over the floor crunches
/// underfoot.
const Legend companyLegend = Legend(
  walls: 'xWwIG',
  obstacles: 'DBh|-RTAKVFprY',
);

/// How dark the company is between its lamps: the lights left on here and
/// there over the open plan, enough to see across to the other wing.
const double companyDarkness = 0.55;

final Place _company = place(PlaceId.companyGround);
final Place _companyFirst = place(PlaceId.companyFirst);
final Place _companySecond = place(PlaceId.companySecond);

/// The company's glass doors, broken open, seen from inside, west to east
/// (from the street it is [industryStreetGate]).
final List<GridPoint> companyGate = _company.tilesOf('E');

/// The company's two flights up, one in each wing, west first: the way
/// round from one wing to the other is by the floors above.
final List<GridPoint> companyStairs = _company.tilesOf('U');

/// The company's flights, bottom to top, west before east: on each floor
/// the flight `U` up in the back wall and where it comes out, the flight
/// `v` down in the front wall of the floor above. The ground floor's west
/// flight and the first floor's west one lead up to the second floor, and
/// down from it the east ones back to the ground floor's east wing.
final List<(GridPoint, GridPoint)> companyFlights = <(GridPoint, GridPoint)>[
  for (final (below, above) in <(Place, Place)>[
    (_company, _companyFirst),
    (_companyFirst, _companySecond),
  ])
    for (final (index, up) in below.tilesOf('U').indexed)
      (up, above.tilesOf('v')[index]),
];

/// The backpack with two rounds, against the west wall of the top floor.
const String companyBackpackId = 'backpack-company';
final GridPoint companyBackpackTile = _companySecond.tileOf('9');

/// The company's two wings, either side of the glass wall, from the back
/// wall to the front one: the west one Mario walks into, the east one
/// behind the glass.
final GridRect companyWestWing = GridRect(
  _company.origin.x + 1,
  _company.origin.y + 1,
  _glassColumn - 1,
  _company.origin.y + companyRows.length - 2,
);
final GridRect companyEastWing = GridRect(
  _glassColumn + 1,
  _company.origin.y + 1,
  _company.origin.x + _company.width - 2,
  _company.origin.y + companyRows.length - 2,
);

/// The column of the glass wall between the wings, on the shared grid.
final int _glassColumn = _company.tilesOf('G').first.x;

/// Chiara, at her workstation in the east wing, her back to the room.
final GridPoint chiaraTile = _company.tileOf('Y');

/// The call-centre operators turned, `company-caller-<n>`, floor by floor:
/// each on the cord of its handset to the desk beside it.
const String companyCallerPrefix = 'company-caller-';

/// How far the cord of a handset reaches from its desk, in tiles.
const int companyCordLength = 3;

/// The operators `Q`, floor by floor from the ground up, each with the
/// desk it is tied to: the workstation next to it.
final List<(GridPoint, GridPoint)> companyCallers = <(GridPoint, GridPoint)>[
  for (final floor in <Place>[_company, _companyFirst, _companySecond])
    for (final tile in floor.tilesOf('Q')) (tile, _deskOf(floor, tile)),
];

GridPoint _deskOf(Place floor, GridPoint tile) =>
    <GridPoint>[
      for (final direction in Direction.values) tile.step(direction),
    ].firstWhere(
      (next) => 'DB'.contains(
        floor.rows[next.y - floor.origin.y][next.x - floor.origin.x],
      ),
    );

/// The company's gate, from the street and from inside, and the flights
/// between its floors (in the back wall of the floor below, onto the
/// stairs in the front wall of the one above), both ways.
final Map<GridPoint, Portal> companyPortals = <GridPoint, Portal>{
  ...pairedDoors(industryStreetGate, companyGate, Direction.north),
  ...pairedDoors(companyGate, industryStreetGate, Direction.south),
  for (final (below, above) in companyFlights) ...<GridPoint, Portal>{
    ...pairedDoors(<GridPoint>[below], <GridPoint>[above], Direction.north),
    ...pairedDoors(<GridPoint>[above], <GridPoint>[below], Direction.south),
  },
};
