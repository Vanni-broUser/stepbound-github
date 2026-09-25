/// Inside the barracks, Pokemon-Emerald style: a room on a dark background.
/// - `x` darkness, `W` back wall, `Q` wall with the carabinieri emblem, `N`
///   notice board, `S` shelves, `I` partition, `w` front wall: walls.
/// - `E` entrance, `O` back door to the north street: doors.
/// - `T` desk, `C` counter, `A` filing cabinet, `h` toppled chair:
///   obstacles to hide behind.
/// - `.` floor, `:` scattered papers (noisy), `b` blood stain, `*` ceiling
///   lamp, `+` flickering lamp, `c` where a carabiniere zombie comes out,
///   `3` the backpack with the pistol.
// barracks-rows-start
const List<String> barracksRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWx',
  'xWQWWNWWWSSWWWOWWNWWWx',
  'x...A..I*.:...:..*..Ax',
  'x.3....I.....TT....c.x',
  'x:.*...I..c......TT..x',
  'xIIII.II.TT..........x',
  'x.....:....+...:.....x',
  'x.TT....TT..TT....TT.x',
  'x....*.........*.....x',
  'x..TT..:.TT.....TT.b.x',
  'x....................x',
  'xCCCCCC.......CCCCCC.x',
  'x..h....*..:.....h...x',
  'x..........b.........x',
  'xwwwwwwwwwEwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxx',
];
// barracks-rows-end
