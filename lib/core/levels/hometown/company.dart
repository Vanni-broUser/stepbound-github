/// Inside the company on the street out of the palazzo, through its gate:
/// a call centre in a shed, one floor of it drawn so far. Two open-plan
/// wings side by side, the one Mario walks into on the west and the one on
/// the east behind the glass wall `G` down the middle, both in view from
/// the gate; across the top, a corridor that should join them, like an
/// upside-down U, but in the middle of it the staff piled up the desks,
/// the workstations and the computers `r` into a heap nobody gets over.
/// Each wing has its stairs up `U` in the back wall: the way round is by
/// the floor above, not drawn yet. In the east wing, at one of the
/// workstations, Chiara `Y`, still on the phone.
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
///   body, `*` a ceiling lamp, `+` a flickering one, `Z` a wanderer.
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
  'x.:..Z..d..h|h|h|h.......G.h|Y|h|h..h|h|h|h..x',
  'xIIGGGIII.............*..G*.......*.......+..x',
  'x..........h|h|h|h.......G.h|h|h|h..h|h|h|h..x',
  'x...:......B|B|B|B...:...G.B|B|B|B..B|B|B|B..x',
  'xp.........-------.......G.-------..-------..x',
  'x=====*=.......Z.........G*......:...........x',
  'xVFV===......-------.....G.-------..-------..x',
  'x======..*...D|D|D|D.....G.D|D|D|D..D|D|D|D..x',
  'x=:=c==......h|h|h|h.....G.h|h|h|h..h|h|h|h..x',
  'x======b..Z..............G.......+..IIIIIIIdIx',
  'x=====....pRRRR=*========G.b..AAKK..IATTh...px',
  'x==========:=============G..........I.....:..x',
  'xwwwwwwwwwwwwwwwwwwwwEEEEwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// company-rows-end
