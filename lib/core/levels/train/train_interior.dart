// The ASCII map is one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// The inside of Luigi's train, seen from above. Two passenger coaches are
/// joined by narrow gangways and lead into the locomotive on the right.
/// Mario enters through `E`; the rear end, on the left, is closed. Seats
/// `S`, tables `T` and luggage `L` are obstacles, while the central aisle
/// stays clear.
///
/// The locomotive is where the two of them live. Its back half is split
/// by the aisle: Mario above it, his cot `B` and a crate for a desk three
/// cells long: on its left end the open books `K`, in the middle the
/// abacus and the calculator `k`, and on the right end `q` his mug and a
/// candle (any of the three, and he reads up on the zombie types met so
/// far); more
/// books and notes `f` all round, and beside the cot his weapons table
/// `a`, with the shotgun, the pistol and the boxes of rounds: whenever he
/// comes back to it with fewer than three rounds, he loads up to three,
/// and an empty rocket launcher gets one rocket.
/// Along the wall past it his two suitcases `Y`, one lying flat and one
/// standing, and his wardrobe `R`, a bare rail with his clothes hung on
/// it: there he chooses what to wear. Luigi below, his cot `b` among bin
/// bags `u` and empty bottles and cans `o` rolling on the floor, his
/// suitcases `O` lying open and spilling clothes, more of his clothes `c`
/// thrown about the floor with underpants and socks `m` (all walked
/// over), and Luigi himself `l`. In the middle stands the table with
/// the map of Europe spread over it `P`,
/// and above it, against the wall on Mario's side, the narrow table they
/// eat at `G`, laid with cured meats, cheese and bread: a bite there
/// saves, like a camp.
/// Past it the two drivers' seats `h`, one above the other in line with
/// the table, face the controls `C`, which follow the tapered nose round
/// to the windscreen `V`. The bottles and the sheets are walked over.
///
/// In the second coach, the one in the middle, in the bottom right corner
/// between the last seats, Chiara's corner once she is aboard: her camp
/// bed `b` like Luigi's, her suitcases `O` open on the floor, her washing
/// hung out to dry on a line strung from one seat to the other `~`, her
/// clothes `c` and empty cans `o` about, and where she stands `j`. Until
/// she comes aboard none of it is there: the corner is bare floor.
// train-interior-rows-start
const List<String> trainInteriorRows = <String>[
  'xWWWWWWWWWWWWWWWWWWWWIIIWWWWWWWWWWWWWWWWWWWWIIIWWWWWWWWWWWWWWWWWWWWWWWxxxxxxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SS..WI.IWBBB.aaafYYRRR.GGG...CCVxxxxxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SS..WI.IW...*...Kkq............CCVxxxx',
  'xW....*........*....WI.IW....*........*....WI.IW.f.................*...CCVxxx',
  'xW..TT....LL....TT..WI.IW..TT....LL....TT..WI.IW....f...f..............*CCVxx',
  'xW............................................................PPPP...h..CCVxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SS..WI.IW..u....om.....PPPP...h..CCVxx',
  'xW..SS....SS....SS..WI.IW..SS....SS~~~~SS..WI.IWoc...m...cc...PPPP.....*CCVxx',
  'xW....*........*....WI.IW....*......o.*...oWI.IW...*c..cm..O...........CCVxxx',
  'xW..SS....SS....SS..WI.IW..SS....SS....SSjcWI.IW.o..l.m.uccm..........CCVxxxx',
  'xW..SS....SS....SS..WI.IW..SS....SSbbboSSOOWI.IWbbbm...oc.OO........CCVxxxxxx',
  'xwwwwwwwEwwwwwwwwwwwwiiiwwwwwwwwwwwwwwwwwwwwiiiwwwwwwwwwwwwwwwwwwwwwwwxxxxxxx',
];
// train-interior-rows-end
