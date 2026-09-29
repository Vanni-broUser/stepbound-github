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
/// the open stairwell `v` going down into it. `>` is the stretch of the
/// east wall knocked down low, where Mario measures the gap: too far to
/// jump, near enough for a grappling hook, as on the roofs past the
/// airliner and at the top of the Duomo's tower. Straight across from it
/// the next block's wall is broken open `<`: where the hook would bring
/// Mario in.
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
