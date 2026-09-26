// The bell tower of the harbour Duomo, climbed in two flights. In both
// Mario comes up through the stairs `D` in the front wall and climbs a
// broad flight `s`, four steps deep and three wide, set against the east
// wall with the doorway `U` over the middle of its head and a railing `|`
// down its open side. As on every floor above the nave, the way up is
// right above the way down, two columns in from the east wall. `o` are
// the arrow slits the daylight comes in by, `*` a lantern, `:` rubble.

/// The first flight, past the crates `K` the sacristan kept up here.
// duomo-tower-rows-start
const List<String> duomoTowerRows = <String>[
  'xxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWx',
  'xWWWWWWWWWUWWx',
  'xI.KK...|sssIx',
  'xI......|sssIx',
  'xo....:.|sssIx',
  'xI......|sssIx',
  'xI..........Ix',
  'xI.....*....Ix',
  'xo..........Ix',
  'xI..:.......Ix',
  'xI..........Ix',
  'xwwwwwwwwwDwwx',
  'xxxxxxxxxxxxxx',
];
// duomo-tower-rows-end

/// The bell chamber at the top of the tower: the bell `O` hangs in it,
/// the openings `o` in the east wall let the wind in, and the last flight
/// climbs to the doorway `U` out onto the roof.
// duomo-bells-rows-start
const List<String> duomoBellsRows = <String>[
  'xxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWx',
  'xWWWWWWWWWUWWx',
  'xI......|sssIx',
  'xI......|sssox',
  'xI..OO..|sssIx',
  'xI..OO..|sssIx',
  'xI..........Ix',
  'xI.....*....ox',
  'xI....:.....Ix',
  'xI.:........Ix',
  'xI..........Ix',
  'xwwwwwwwwwDwwx',
  'xxxxxxxxxxxxxx',
];
// duomo-bells-rows-end
