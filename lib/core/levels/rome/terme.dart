/// Inside the Baths of Diocletian, through the portal of Santa Maria degli
/// Angeli at the west end of the road past Termini: a vestibule, then the
/// great hall -- the baths' frigidarium, which Michelangelo made into the
/// church -- its vault still standing on the eight columns of red granite
/// the Romans set up, the pews shoved about, and the meridian, the brass
/// line let into the floor to read the noon sun by, running the length of
/// it. Daylight comes down from the thermal windows high in its walls.
/// - `x` darkness, `W` the north wall, `I` the side walls and the wall
///   between the hall and the vestibule, `w` the front wall, `O` a column,
///   `A` the high altar: walls.
/// - `E` the portal onto the road, the way in and out.
/// - `T` a pew, `K` a column drum on its side: obstacles.
/// - `.` marble floor, `m` the meridian, `:` fallen plaster and glass
///   (noisy), `b` blood, `^` daylight from a thermal window.
// terme-rows-start
const List<String> termeRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xI.....O.......O..AAAA..O.......O.....Ix',
  'xI.......:........AAAA................Ix',
  'xI..^.......b.........:.....m......^..Ix',
  'xI...TTTT..TTTT.....TTTT....m..TTTT...Ix',
  'xI...TTTT..TTTT.....TTTT....m..TTTT...Ix',
  'xI...........T..:..........bm.......:.Ix',
  'xI...TTTT..TTTT.....TTTT....m..TTTT...Ix',
  'xI...TTTT..TTTT.....TTTT....m..TTTT...Ix',
  'xI.K......^.......b.......:.m.^.......Ix',
  'xI..:..O.......O........O...m...O.....Ix',
  'xIIIIIIIIIIIIIIIII....IIIIIIIIIIIIIIIIIx',
  'xxxxxxxxxxxI................Ixxxxxxxxxxx',
  'xxxxxxxxxxxI....b.......:...Ixxxxxxxxxxx',
  'xxxxxxxxxxxI..:.............Ixxxxxxxxxxx',
  'xxxxxxxxxxxI.......:.....b..Ixxxxxxxxxxx',
  'xxxxxxxxxxxI................Ixxxxxxxxxxx',
  'xxxxxxxxxxxwwwwwwwwEwwwwwwwwwxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// terme-rows-end
