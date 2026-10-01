// The ASCII maps are one row per line, however wide the place is.

/// Inside the bank on Via Marsala, down the stairs from its roof: the
/// offices under the roof, and under them the open vault. Glyphs of both:
/// - `x` darkness, `W` the back wall (two courses), `w` the front wall,
///   `I` a partition, `Q` the vault's steel walls, `B` the safe-deposit
///   boxes set in the walls: walls. `G` a glass wall: seen through, not
///   walked through.
/// - `U` the stairs up, `D` the stairs down: doors. `d` a doorway in the
///   glass, `O` the vault's doorway: floor.
/// - Floors: `.` carpet, `=` polished granite, `,` the vault's steel
///   floor.
/// - `T` a desk (or a length of the meeting table), two cells, `h` an
///   office chair, `K` a filing cabinet, `l` a bookcase, `S` an armchair
///   for the clients, `C` the water cooler, `P` the copier, `p` a plant,
///   `L` the vault's shelves, `o` its round door swung open, `r` where the
///   ceiling came down: obstacles.
/// - `:` papers and ceiling tiles (noisy), `z` banknotes, `b` blood, `c` a
///   body, `*` a lamp, `+` a flickering one, `9` the backpack with the gold
///   ingot.
///
/// The offices: the open plan west, and behind their glass the manager's
/// office and the meeting room east. The stairs from the roof come in at
/// the back, the stairs down go on from the front.
// bank-offices-rows-start
const List<String> bankOfficesRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWUUWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xK.....KKp.CK.K..GK.l..K...pKx',
  'x.*..........*...G..*.....:..x',
  'x.TTh..TTh..TTh..d...TT..h...x',
  'x..........:.....G...h..c....x',
  'x.TTh..TTh..TTh.bGS.S....*..px',
  'x......*.....:...GGGGdGGGGGGGx',
  'x.TTh..TTh..TTh..Gp..h.h.h..Kx',
  'x..c.......r.....d.*TTTTTT...x',
  'xP.......:....*..G...h.h.h.b.x',
  'xp..b.........p.KGC.....r...px',
  'xwwwwwwwDDwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// bank-offices-rows-end

/// The floor under them: a granite hall with the safe-deposit boxes along
/// its back, and east of it the vault, its round steel door swung wide
/// open, its shelves stripped, banknotes all over its floor, and in the
/// middle of it a backpack with a gold ingot left in it. A lamp hangs
/// either side of the vault's doorway, and nothing stands in front of it.
// bank-vault-rows-start
const List<String> bankVaultRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWUUWBBBBWWWBBBBBBBBBBBBBx',
  'xBB*==:==:===QLL,z,,LL,,z,Lx',
  'xBB=========oQ,,,*,z,,,,,,,x',
  'x==TT====b==oQL,z,,,,,,,z,Lx',
  'x==h=========O*,,,,z,,,,b*,x',
  'x=====c=====*O,,,,,9,,,,,zLx',
  'x=*======:===Q,,z,,,,,+z,,,x',
  'x==b=====*===QL,,,c,,,,,,,Lx',
  'xr==p======p=QLL,,z,,LL,z,Lx',
  'xwwwwwwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// bank-vault-rows-end
