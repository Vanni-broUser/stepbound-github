// The ASCII maps are one row per line, however wide the place is.

/// The palazzo beside the bank on Via Marsala, through its open portone:
/// the entrance hall, two floors of flats over it and, up the last flight,
/// the terrace on its roof. Built like the palazzo past the airliner in
/// Molfetta (palazzo.dart), and with its glyphs, but smaller and Roman: two
/// flats to a floor, either side of the landing, each floor laid out its
/// own way. The stairs `U` up climb into the back wall, the stairs `D` down
/// come out of the front wall; the landings are lit, the flats dim.
///
/// The entrance hall on the street: the portone `E` in the front wall, the
/// stairs up in the back one between the letterboxes, and in the west
/// corner the porter's lodge.
// rome-palazzo-ground-rows-start
const List<String> romePalazzoGroundFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWMMMWWWUWWWWMMMWWWWWWx',
  'x.TT..AIp=====:=========p====x',
  'x...*..I=====b============c==x',
  'x.a.:..d==*=========*========x',
  'x......I=========r===========x',
  'x......I===c========:=====b==x',
  'xIIIIIII=====================x',
  'x==*=========:========*======x',
  'xwwwwwwwwwwwwwwEwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// rome-palazzo-ground-rows-end

/// The first floor: west, the kitchen and the living room at the back,
/// the bathroom and the bedroom at the front; east, the bedroom and the
/// kitchen at the back, the living room at the front with the bathroom in
/// its corner.
// rome-palazzo-first-rows-start
const List<String> romePalazzoFirstFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWUWWWWWWWWWWWWWx',
  'xKKOF,I..l..I====InBn.AIKKOKFx',
  'x,*,,,d.....I====I.B.*.I,,*,,x',
  'x,hTThI.SSS.P====I..b..I,hTThx',
  'x,,,b,I..*a.I=*==I.....d,,c,,x',
  'xIIdIII.:...I====I.:..lI,,,,Fx',
  'xQ__HIIIIdIII====IIIdIIIIIdIIx',
  'x_*__I.nBn..I====I.VV...*I_*Qx',
  'xRR__I..B..AI==p=P.SSa...d__Hx',
  'x__b_I.*....I:===I...c...IRR_x',
  'x____I.c..:.I====Il.....pI___x',
  'xwwwwwwwwwwwwwDwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// rome-palazzo-first-rows-end

/// The second floor: west, one long living room across the back and the
/// bedroom, the kitchen and the bathroom under it; east, a studio, the
/// kitchen corner and the bed in one room, the bathroom walled off at the
/// back. The stairs up go on to the roof.
// rome-palazzo-second-rows-start
const List<String> romePalazzoSecondFloorRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWUWWWWWWWWWWWWWx',
  'xl.SSS...VV.I====IQ__HIKKOK,Fx',
  'x...*...a...P====I_*__I,,*,,,x',
  'x.c...b.....I=*==IRR__d,,b,,,x',
  'xIIIdIIIIdIII====IIIIII...hTTx',
  'xnBn..IKOKF,I====P.....:.....x',
  'x.B...I,hTThI====InBn...*..lax',
  'x..*..I,,,b,Ip===I.B..c......x',
  'xA.:..IIIdIII====I...SSS..VV.x',
  'x.....I_*__QI===bI.b.........x',
  'x..r..IRR__HI====IA....r...pAx',
  'xwwwwwwwwwwwwwDwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// rome-palazzo-second-rows-end

/// The roof, up the last flight: it comes out of the door `D` of the
/// stairwell's little house `H` on the palazzo's terrace, east. The terrace
/// is paved in cotto `.`, walled round by its parapet `^`, with the water
/// tanks `T`, an aerial `n`, the posts of the washing lines `l`, a deck
/// chair `a`, the lemon trees in their pots `p`, a satellite dish `s` and,
/// towards the terrace's south-east corner, a campfire `S`.
/// Everywhere past what can be walked on the roofs of Rome begin, tiles
/// `R`. West, across the drop `x` to the street, the bank's flat roof:
/// gravel `,`, its own parapet `^`, the air conditioners `k`, a skylight
/// `o`, and the stairs `v` going down inside it, to a bank with no map yet
/// (`workInProgressDoors`). `<` is the stretch of the terrace's parapet
/// knocked down low, where Mario measures the gap: near enough for the
/// grappling hook. Straight across, the bank's parapet is broken `>`:
/// where the hook brings him in, and where it takes him back from.
/// `:` rubble, `b` blood, `c` a body.
// rome-palazzo-roof-rows-start
const List<String> romePalazzoRoofRows = <String>[
  'RRRRRRRRRRRRRRRRRRRxxxRRRRRRRRRRRRRRRRRRRRRRRR',
  'RRRRRRRRRRRRRRRRRRRxxxRRRRRRRRRRRRRRRRRRRRRRRR',
  'RRRRRRRRRRRRRRRRRRRxxx^^^^^^^^^^^^^^^^^^^^^^RR',
  'RR^^^^^^^^^^^^^^^^^xxx^............HHHH....^RR',
  'RR^,,,,,,,,,,,,,,,^xxx^.TT....p....HHHH..n.^RR',
  'RR^,kk,,,,oo,,,,,,^xxx^............HDHH....^RR',
  'RR^,,,,,,,,,,,,,,,^xxx^....c...............^RR',
  'RR^,,,,,,,,,,,:,,,^xxx^.....l....l.....:...^RR',
  'RR^,,,,,,,,,b,,,,,>xxx<....................^RR',
  'RR^,,,vv,,,,,,,,,,^xxx^......:.......b.....^RR',
  'RR^,,,vv,,,,,k,,,,^xxx^.................s..^RR',
  'RR^,,,,,:,,,,,,,:,^xxx^...a....p...........^RR',
  'RR^,,,,,,,,,,,,,,,^xxx^...........:.....S.p^RR',
  'RR^^^^^^^^^^^^^^^^^xxx^....................^RR',
  'RRRRRRRRRRRRRRRRRRRxxx^^^^^^^^^^^^^^^^^^^^^^RR',
  'RRRRRRRRRRRRRRRRRRRxxxRRRRRRRRRRRRRRRRRRRRRRRR',
  'RRRRRRRRRRRRRRRRRRRxxxRRRRRRRRRRRRRRRRRRRRRRRR',
];
// rome-palazzo-roof-rows-end
