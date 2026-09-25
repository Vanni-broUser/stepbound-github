// The ASCII map is one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// The inside of Luigi's train, seen from above. Two passenger coaches are
/// joined by narrow gangways and lead into the locomotive on the right.
/// Mario enters through `E`. Seats `S`, tables `T` and luggage `L` are
/// obstacles, while the central aisle stays clear.
///
/// The locomotive is where the two of them live. Its back half, walled off
/// from the middle by two stacks of luggage, is split by the aisle: Mario
/// above it, his cot `B` and a crate of open books `k` with loose sheets
/// `f` all round; Luigi below, his cot `b` among bin bags `u` and empty
/// bottles and cans `o` rolling on the floor, and Luigi himself `l`. In the
/// middle stands the table with the yellowed route map spread over it `P`.
/// Past it the two drivers' seats `h`, one above the other in line with
/// the table, face the controls `C`, which follow the tapered nose round
/// to the windscreen `V`. The bottles and the sheets are walked over.
// train-interior-rows-start
const List<String> trainInteriorRows = <String>[
  'xWWWWWWWWWWWWWWWWWWWWIIIWWWWWWWWWWWWWWWWWWWWIIIWWWWWWWWWWWWWWWWWWWWWWWxxxxxxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SS..WI.IWBBB....f..LL........CCVxxxxxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SS..WI.IW...*..kk..LL..........CCVxxxx',
  'xW....*........*....WI.IW....*........*....WI.IW.f.......fLL...*.......CCVxxx',
  'xW..TT....LL....TT..WI.IW..TT....LL....TT..WI.IW....f.....LL...........*CCVxx',
  'x.............................................................PPPP...h..CCVxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SS..WI.IW..u....o..LL..PPPP...h..CCVxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SS..WI.IWo.........LL...........*CCVxx',
  'xW....*........*....WI.IW....*........*....WI.IW...*......LL...........CCVxxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SS..WI.IW.o..l...u.LL..........CCVxxxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SS..WI.IWbbb....o..LL........CCVxxxxxx',
  'xwwwwwwwEwwwwwwwwwwwwiiiwwwwwwwwwwwwwwwwwwwwiiiwwwwwwwwwwwwwwwwwwwwwwwxxxxxxx',
];
// train-interior-rows-end
