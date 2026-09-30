import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

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

/// The glyphs of the outdoor places: this street, the north district
/// (north_district.dart), the harbour (harbour.dart), the street north of
/// the hypermarket (mall_north_street.dart), the street out of the palazzo
/// (industry_street.dart) and the monument's square past it
/// (monument_square.dart): `Ω` the monument and `¦` the Elettronica's door
/// behind the barracks while its shutter is down are obstacles.
const Legend outdoorLegend = Legend(
  walls: 'BHfKMGW#%0_Æ',
  obstacles: 'CXUvkDFTSOyJQaAnI~RNbpx*i&!^;/+Ω¦',
  debris: ':q',
  fire: '?',
);

final Place _street = place(PlaceId.street);

/// The zombie waiting on the east arm of the crossroads.
const String tutorialZombieId = 'wanderer-0';

/// The wanderer on the road north, `9`, a few steps past where the
/// dead-end street opens: it is in the way to the barracks, and the street
/// is where there is room to draw it and go round it. Its own id, so that
/// it does not take the tutorial zombie's for being further up the map.
const String barracksRoadZombieId = 'barracks-road-wanderer';

/// The other `9`, four rows up the road north from [barracksRoadZombieId]
/// and to the east of it, closer to the barracks and looking south: going
/// round the first, Mario walks into it.
const String barracksRoadUpperZombieId = 'barracks-road-upper-wanderer';

/// Both `9`, in reading order: the upper one is the one further up the
/// road.
final List<GridPoint> barracksRoadZombieTiles = _street.tilesOf('9');

/// The backpacks `1` to `4` of the outdoor glyphs, on this street and in
/// the north district: what each holds is in `hometownContents`.
const String ammoBackpackId = 'backpack-ammo';
const String parkingBackpackId = 'backpack-parking';
const String accidentBackpackId = 'backpack-accident';
const String alleyBackpackId = 'backpack-alley';

/// Walking into the crossroads makes the tutorial zombie notice the player
/// even if it is not looking that way: from the west zebra crossing to a
/// few steps down the east arm, between the two sidewalks.
final GridRect tutorialZombieTrigger = () {
  final crossing = _street.tilesOf('V').first;
  return GridRect(crossing.x - 1, crossing.y, crossing.x + 9, crossing.y + 6);
}();

/// The flagpole planted on the forecourt, where the tricolour flies.
final GridPoint flagpoleTile = _street.tileOf('I');

/// The forecourt in front of the barracks, from the flagpole west along
/// the sidewalk and the row of road under it: reaching it makes Mario
/// speak.
final GridRect barracksForecourt = GridRect(
  flagpoleTile.x - 6,
  flagpoleTile.y,
  flagpoleTile.x,
  flagpoleTile.y + 1,
);

/// Fires burning on the first street.
final List<FireSpot> streetFireSpots = firesIn(_street);
