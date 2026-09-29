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
///   third floor: a wall, the flat behind it not drawn at all.
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
///   `*` ceiling lamp, `+` flickering lamp, `Z` a wanderer, `9` the
///   backpack with two rounds, `k` the key of the third floor.
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
/// stand open; the one behind them, east, is locked, `L`, and nothing of
/// it is drawn.
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
