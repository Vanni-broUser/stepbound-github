/// The street where Mario wakes up, a crossroads under the barracks. Up the
/// road north, past the backpack, a dead-end street turns east, a zombie
/// standing on the road a few steps past where it opens and another four
/// rows further up; further up still, before the barracks, a pile-up.
///
/// Glyphs of the outdoor places (the street, the north district and the
/// harbour share them; tools/build_street_level.py reads these rows to
/// bake the backgrounds, so keep the two in sync):
/// - `B` roof, `H` facade, `f` facade with a burning window, `K` facade of
///   the barracks, `M` facade of the hypermarket, `G` facade of the
///   hospital, `W` the Duomo on the harbour, `0` the station behind the
///   hypermarket: walls.
/// - `E` barracks front door, `e` passage through its back, `m` the
///   hypermarket's open entrance: doors.
/// - `=` sidewalk; `.` road; `-` and `|` road with a horizontal or vertical
///   centre line; `c` where a centre line bends from west to south, `ɔ`
///   from east to south; `Z` and `V` zebra crossings; `▔` and `▏` a stop
///   line along the north or west edge of the lane: floor.
/// - `CC` car, `XX` burning car, `UU` overturned car (horizontal pairs),
///   `v`/`k` car / burning car parked north-south (vertical pairs), `D` pile
///   of corpses, `F` burning bin, `T` traffic light: obstacles you can see
///   and shoot over. `/` a road sign on its post.
/// - `:` debris (walkable but noisy), `d` a lone corpse (walkable), `>` a
///   pool of blood on the road (walkable).
/// - `S` a camp with a campfire: rest there to save (an obstacle).
/// - `I` flagpole on the barracks forecourt (the flag is animated in game).
/// - `P` paving of a square, `L` parking lot, `Y` stairs: floor. `O`
///   fountain, `A` dead tree in its planter, `n` bench, `y` abandoned
///   shopping trolley, `J` concrete road block, `Q` café table, `aa`
///   crashed ambulance: obstacles. `q` toppled chair: debris (noisy).
/// - Seafront: `~` sea, `R` stone parapet, `N` palm in its planter, `bb`
///   half-sunk rowboat: obstacles you can see over. `l` wooden pier and
///   `o` deck of a moored rowboat: floor.
/// - Park: `g` grass, floor; `p` broken playground ride and `^` the park
///   railing, obstacles you can see over; `<` a gate in that railing,
///   floor. `;` a heap of rubbish too deep to step on, an obstacle.
/// - `$` the hospital's glass doors at the top of its stairs: a door.
/// - `h` door of the Bar Arcobaleno, `j` where the hypermarket's fire exit
///   lands behind it, `(` the station's open doorways: doors.
/// - Duomo: `x` the churchyard gate, an obstacle you can see through; `s`
///   where Don Angelo waits behind it (floor, he is drawn in game).
/// - Old town: `#` the small church of San Nicola, at the far end of the
///   warren of alleys from the Duomo: a wall. The alleys are paved with
///   `P`, and one of them opens into a piazzetta where `&` are the raised
///   flower beds and `!` the stone drinking fountain in its basin (both
///   obstacles, the fountain two cells by two).
/// - Shipyard, at the west end of the seafront road: `%` its wall, which
///   closes the road (the way in is round the side, off the promenade);
///   `*` a hull up on the stocks and `i` the gantry crane, obstacles; the
///   yard itself is `,` poured concrete and `l` the slipway down into the
///   water.
/// - Zombies: `w` wanderer, `z` sprinter, `u` brute, `r` carabiniere; `t`
///   the two wanderers outside the churchyard gate.
/// - `@` player, `w` wanderer; `9` the two wanderers on the road north,
///   which have ids of their own: one just past the dead-end street, the
///   other four rows further up and to the east, under the overturned car,
///   looking south, there for whoever goes round the first.
/// - Backpacks: `1` four rounds, there from the start; `2` two rounds by the
///   accident, waiting there from the start (the zombie guards it); `3` two
///   rounds at the far end of the dead-end street off the road north; `4` two
///   rounds at the far corner of the hypermarket's car park; `5` two rounds
///   on the rowboat moored at the harbour's second pier; `6` two rounds in
///   the shipyard; `7` two rounds at the rightmost old-town dead end; `8`
///   two rounds where the campfire used to stand north of the mall.
// level-rows-start
const List<String> streetLevelRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBKKKKKEKKKKKBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB======IBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=:....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=CC..UUBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|.9=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=HHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBBBBBBBBBB=.....=HHHHHHHHHHHHHfHHHHHHBBBB',
  'BBBBBBBBBBBBB=..9..=HHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBBBBBBBBBB=.....=======:=============BBBB',
  'BBBBBBBBBBBBB=..|.....>..CC...d....D..>.BBBB',
  'BBBBBBBBBBBBB=.......d....v......>..CC..BBBB',
  'BBBBBBBBBBBBB=..|...-.-.-.v.-d-.->-.-.3.BBBB',
  'BBBBBBBBBBBBB=........UU....>...D...k.>.BBBB',
  'BBBBBBBBBBBBB=......>....XX.....>...k..dBBBB',
  'BBBBBBBBBBBBB=.....==========:==========BBBB',
  'BBBBBBBBBBBBB=..|.:=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBF.....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..1..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|.k=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=....k=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.:...=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=...d.=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB=.....=BBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBHHHHHHHHH=v.|..=HHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHfHHHH=v....=HHHHfHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHHHHHH=..|..=HHHHHHHHHHfHHHHHHHHHBBBB',
  'BBBBHHHHHHHHH=...:.=HHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBB==========VVVVVT==:=====F===========BBBB',
  'BBBB.....CC..Z.....Z..............UU....BBBB',
  'BBBB........:Z.....Z..........XX........BBBB',
  'BBBB-.-@-.-.-Z.....Z-:w.-.-.-.-.-.-.-D-.BBBB',
  'BBBB..:......Z.....Z.............d.2....BBBB',
  'BBBB.........Z.....Z......:...........d.BBBB',
  'BBBB=========T==========================BBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// level-rows-end
