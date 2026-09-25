/// Inside San Nicola, the small church deep in the alleys of the old town
/// (the barracks' style, a room on a dark background). Nobody sheltered
/// here the way they did at the Duomo: the roof has fallen in, the pews
/// are shoved out of line, and the sacristy has been emptied by whoever
/// got here first. What they left behind is the censer's incense, in a
/// backpack against the east wall.
/// - `x` darkness, `W` the apse wall behind the altar, `w` the front wall
///   with the portal in it, `I` the side walls, `A` the altar: walls.
/// - `E` the portal onto the little square, the way in and out.
/// - `T` a pew, `K` a toppled column drum: obstacles.
/// - `.` flagstones, `:` fallen plaster and glass (noisy), `b` blood,
///   `^` daylight through a hole in the roof, `Z` a wanderer, `9` the
///   backpack with the incense.
// church-rows-start
const List<String> churchRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWx',
  'xI.:.....AAAA.....:...Ix',
  'xI..b....AAAA....:....Ix',
  'xI...:.....^.....b....Ix',
  'xI..:......Z......:...Ix',
  'xI.TTTT..:....TTTT....Ix',
  'xI.TTTT.......TTTT..b.Ix',
  'xI.TTTT..:....TTTT....Ix',
  'xI.::.........TTTT...9Ix',
  'xI.TTTT.......:.:.....Ix',
  'xI.TTTT..b....TTTT....Ix',
  'xI.TTTT..:....TTTT..:.Ix',
  'xI.TTTT.......TT::....Ix',
  'xI..:.....^.......Z..:Ix',
  'xIK..:..........b....KIx',
  'xI..b......:.....^....Ix',
  'xwwwwwwwwwwwEwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxx',
];
// church-rows-end
