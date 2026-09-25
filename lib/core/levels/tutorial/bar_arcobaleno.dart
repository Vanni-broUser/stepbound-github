/// Inside the Bar Arcobaleno, off the harbour's alley (the barracks'
/// style, a room on a dark background):
/// - `x` darkness, `W` the back wall, bottles on its shelves and the
///   rainbow painted over them, `w` the front wall with its window: walls.
/// - `D` the locked service door in the top-right corner: a wall.
/// - `E` the door onto the alley.
/// - `K` the counter, `T` a table still standing, `J` the jukebox:
///   obstacles.
/// - `.` floor, `:` broken glass and `q` a chair knocked over (both
///   noisy), `b` blood, `*` ceiling lamp, `+` flickering lamp.
/// - `U` the drunk zombie, the last customer, still at the bar: it
///   staggers about the room at random, whether it has seen Mario or not.
// bar-rows-start
const List<String> barArcobalenoRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWx',
  'x...*......*......*.Dx',
  'xKKKKKKKKKKKK........x',
  'x...:...q.U.....JJ...x',
  'x.q..TT.....:........x',
  'x...:TT..b....q..TT..x',
  'x..q....PPPP.*...TT..x',
  'x......:PPPP.q.......x',
  'x.TTPPPP..q......:...x',
  'x.TTPPPP:.....+....q.x',
  'xwwwwwwwwwwEwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxx',
];
// bar-rows-end
