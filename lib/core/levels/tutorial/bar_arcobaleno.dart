import 'package:stepbound/core/grid/grid_point.dart';

/// Inside the Bar Arcobaleno, off the harbour's alley (the barracks'
/// style, a room on a dark background):
/// - `x` darkness, `W` the back wall, bottles on its shelves and the
///   rainbow painted over them, `w` the front wall with its window: walls.
/// - `D` the locked service door in the back wall, top-right corner: a
///   wall until the key opens it, used facing north from the floor below.
/// - `E` the door onto the alley.
/// - `K` the counter, `T` a table still standing, `J` the jukebox:
///   obstacles.
/// - `.` floor, `:` broken glass and `q` a chair knocked over (both
///   noisy), `b` blood, `*` ceiling lamp, `+` flickering lamp.
/// - `U` the drunk zombies, the last customers, still at the bar: each
///   staggers about the room at random, whether it has seen Mario or not.
///   One is up by the service door Mario needs the key for.
// bar-rows-start
const List<String> barArcobalenoRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWDx',
  'x...*......*......*..x',
  'xKKKKKKKKKKKK......U.x',
  'x...:...q.U.....JJ...x',
  'x.q..TT.....:........x',
  'x.U.:TT..b....q..TT..x',
  'x..q....PPPP.*...TT..x',
  'x......:PPPP.q...U...x',
  'xTTPPPP...q......:...x',
  'xTTPPPP.:.....+....q.x',
  'xwwwwwwwwwwEwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxx',
];
// bar-rows-end

/// Lamps hung over what has a glyph of its own: three along the BAR
/// ARCOBALENO sign over the shelf of the back wall, and one over each of
/// the two pool tables `P`.
const List<GridPoint> barArcobalenoLamps = <GridPoint>[
  GridPoint(8, 2),
  GridPoint(11, 2),
  GridPoint(13, 2),
  GridPoint(9, 8),
  GridPoint(5, 10),
];
