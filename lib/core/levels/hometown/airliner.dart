import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';
import 'package:stepbound/core/world.dart';

// The ASCII maps are one row per line, however wide the place is.

/// Inside the airliner that came down on the crossroads behind the
/// hypermarket (see mall_north_street.dart, where its body lies across the
/// junction). Drawn as a room on a dark background like the barracks, and
/// lit like one: the cabin lost its main power long ago, but a line of
/// emergency lamps still marks the aisle and daylight falls in at the two
/// breaks in the hull.
///
/// The map runs the way the aeroplane does, nose west, tail east. Mario
/// comes in through the tear in the belly `E`, under the forward galley at
/// the west end, where the forward body rests in the road, and the only
/// other way out is the tail break `O` at the east end, torn in the belly
/// too: the tail lies along the top of the roofs it stopped in (see the
/// rooftops below), so Mario climbs down out of it onto them, south, the
/// same way he walks out of it on the roofs' map. Between the two the only
/// way is the aisle: the seats `T` stand in their blocks either side of it,
/// and where the floor buckled, halfway down, the rows are torn open into a
/// cross aisle of loose panelling `::`. Here and there a seat was torn off
/// its rails in the crash, and the broken seats `r` are climbed over.
///
/// The passengers who lost their legs in the crash lie where they fell, the
/// mutilated zombies `M`: they never move, but bite whoever passes next to
/// them. The first lies at the head of the aisle, past the forward
/// galley, a few steps from the tear Mario comes in through. The next,
/// past the first block of seats, lies just off the aisle, where an
/// emergency light on the floor of the aisle two cells from him lets him be
/// made out. Another lies across the aisle past the cross aisle, and there
/// is no stepping round him in it: the way past is over the broken seats
/// beside him. The rest can be given a wide berth.
/// The flight bag `9` between two blocks of seats has rounds, whatever
/// Mario came in with.
///
/// Glyphs: `x` darkness, `W` the roof of the hull, `w` its belly, `I` its
/// sides, all walls; `T` a block of seats and `K` a galley trolley on its
/// side, obstacles you can see over; `.` the aisle and the vestibules,
/// `:` panelling and cabin baggage and `r` a broken seat (both walked over,
/// noisily), `b` blood, `*` an emergency light still burning and `+` one
/// that flickers, `Z` a wanderer, `M` a mutilated zombie, `9` the flight
/// bag, `E` the tear onto the road, `O` the tail break onto the roofs.
// airliner-cabin-rows-start
const List<String> airlinerCabinRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xI...TTT..TTT9.TTT.::.TTT..TTT..TTT..b.Z:.Ix',
  'xI.:.TTT..TTT..TTT.::.TTT..TTT..TTT.......Ix',
  'xI.K.TTT..TTT..TrT.::.TTT.MTTT..TTT.*....:Ix',
  'xI.M...b*...Z.........:.....M....b........Ix',
  'xI..*.......:*........*:.......*........*.Ix',
  'xI.K.TTTM.TrT..TTT.::.TTT.*rrr..TTT.......Ix',
  'xI.:.TTT..TTT..TTT.::.TTT..TTT..TTT...+...Ix',
  'xI...TTT..TTT..TTT.::.TTT..TTT..TTT..K.K..Ix',
  'xwwEEwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwOOwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// airliner-cabin-rows-end

/// Emergency lights hung over what has a glyph of its own: two over the
/// loose panelling of the cross aisle, where the floor buckled, and one
/// over the seats amidships.
const List<GridPoint> airlinerCabinLamps = <GridPoint>[
  GridPoint(19, 3),
  GridPoint(20, 8),
  GridPoint(27, 3),
];

/// The roofs the tail came to rest in, out of the tail break `D` at the
/// top of the map, torn in the underside of the tail: it is the cabin's `O`,
/// in the belly there as well, so that Mario leaves the aeroplane going
/// south on both maps and comes back into it going north.
///
/// Two terraces, one stepped down from the other over a
/// low parapet `^` broken in two places, with chimney stacks `T` and
/// aerial masts `n` standing about them and slate and gravel `:` thrown
/// over both by the crash. The tail `#` lies along the top of the map with
/// the break `D` torn in its side. A backpack `9` with two rounds waits in
/// the south-east corner of the lower terrace.
///
/// The lower terrace ends, south, at the parapet along the street front.
/// There the roof of the next block stands just across the gap, two
/// cells of drop, near enough to look at and too far to jump: `>` is the
/// low stretch of the parapet where Mario stops to measure it, `x` the
/// drop into the street between the two blocks, and `%` the roof on the
/// far side, flat and walkable, built like this one -- walled `W` round
/// it and with its parapet `^` along the front -- with its own chimney
/// stacks `k`, gravel `;` and the open stairwell `S` going down into that
/// block, eastward: its head at the west end, its foot at the east. Its
/// wall is broken open `<` straight across from `>`: where the grappling
/// hook brings Mario in, and where it takes him back from. Only the hook,
/// found in Rome, gets him over there. The block below is the palazzo
/// (palazzo.dart): the last step of the stairs is the door down into its
/// top floor.
///
/// The airliner struck the building at the north-west corner of the upper
/// terrace on its way down, and the fuel it spilt there is still burning
/// `&`. Out of it have walked two zombies on fire `Y`, one of them already
/// halfway to the tail, near enough to see Mario climb down out of it:
/// they go after Mario like wanderers, and every tile they step off catches
/// fire and stays alight, shut for good. Should the fire shut Mario in
/// where no way off the roofs can be reached, the game says so and offers
/// the campfire or the level again.
///
/// Glyphs: `x` the drop and the sky, `W` the party walls and the roofline
/// the tail sits in and `#` the tail itself, all walls; `T`, `n`, `k`,
/// `^` and `>` obstacles you can see over; `.` the roof deck, `%` the next
/// roof's, `:` slate and gravel (noisy), `;` the next roof's gravel, `b`
/// blood, `&` the roof on fire, `Y` a burning zombie, `9` the backpack,
/// `D` the tail break, `S` the next roof's stairs down, `<` the opening
/// in its wall (an obstacle you can see over).
// airliner-roof-rows-start
const List<String> airlinerRoofRows = <String>[
  'xxxxxxxxxxx########xxxxxxxxxxx',
  'xWWWWWWWWWW###DD###WWWWWWWWWWx',
  'xW&&&&&.....::::::..........Wx',
  'xW&&&&...:Y........:...T....Wx',
  'xW&&Y..n.......b.......:....Wx',
  'xW&.:........T.........n....Wx',
  'xW.......:........:.........Wx',
  'xW..n.......:..........T....Wx',
  'xW^^^^^^^...^^^^^^...^^^^^^^Wx',
  'xW..........:......:........Wx',
  'xW...T.....b.........:..T...Wx',
  'xW......:........n..........Wx',
  'xW..:..........:........:...Wx',
  'xW.......................:.9Wx',
  'x^^^^^^^^^^^^^^>^^^^^^^^^^^^^x',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWW<WWWWWWWWWWWWWx',
  'xW%%%%%%%%%%%%%%%%%%%%%%%%%%Wx',
  'xW%%%k%%%%%%%%%%%%%%%SSS%%%%Wx',
  'xW%%%%%%%%%;%%%%%%%%%SSS%k%%Wx',
  'xW%%;%%%%%%%%%%%%%%%%%%;%%%%Wx',
  'xW%%%%%%%%%%%%%%%%%%%%%%%%%%Wx',
  'x^^^^^^^^^^^^^^^^^^^^^^^^^^^^x',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// airliner-roof-rows-end

/// Inside the crashed airliner the hull is a wall all round; the blocks of
/// seats `T` and the galley trolleys `K` are waist high, and the buckled
/// panelling `:` and the broken seats `r` are walked over, noisily.
const Legend airlinerLegend = Legend(
  walls: 'xWwI',
  obstacles: 'TK',
  debris: ':r',
);

/// The roofs the tail came down in: the drop `x`, the party walls `W` and
/// the tail `#` are all walls, while the parapets `^`, the low stretch `>`
/// Mario measures the gap from, the chimney stacks `T` and `k` and the
/// aerial masts `n` can be seen over, and the corner on fire `&` burns
/// from the start. The roof across the gap `%` is walked on like any
/// other, by whoever gets there.
const Legend rooftopLegend = Legend(
  walls: 'xW#',
  obstacles: 'Tnk^><',
  fire: '&',
);

final Place _airlinerCabin = place(PlaceId.airlinerCabin);
final Place _airlinerRoofs = place(PlaceId.airlinerRoofs);
final Place _mallNorthStreet = place(PlaceId.mallNorthStreet);

/// The two wanderers `Z` left in the cabin of the crashed airliner.
const String airlinerZombiePrefix = 'airliner-wanderer-';
final List<GridPoint> airlinerZombieTiles = _airlinerCabin.tilesOf('Z');

/// The mutilated zombies `M` lying in the cabin of the crashed airliner.
const String airlinerMutilatedPrefix = 'airliner-mutilated-';
final List<GridPoint> airlinerMutilatedTiles = _airlinerCabin.tilesOf('M');

/// The row of the aisle down the middle of the cabin: lying on the floor,
/// each mutilated zombie looks towards it.
final int airlinerCabinAisleRow =
    _airlinerCabin.origin.y + airlinerCabinRows.length ~/ 2;

/// The flight bag `9` in the airliner's cabin: enough rounds for the
/// mutilated zombie lying in the way out, whatever Mario came in with.
const String airlinerBackpackId = 'backpack-airliner';
const int airlinerBackpackAmmo = 2;
final GridPoint airlinerBackpackTile = _airlinerCabin.tileOf('9');

/// The backpack in the south-east corner of the first roof after the
/// airliner, and the two rounds it holds.
const String rooftopBackpackId = 'backpack-airliner-roof';
const int rooftopBackpackAmmo = 2;
final GridPoint rooftopBackpackTile = _airlinerRoofs.tileOf('9');

/// The zombies on fire `Y` that walked out of the burning corner of the
/// roofs past the airliner, `rooftop-burning-<n>`.
const String rooftopBurningZombiePrefix = 'rooftop-burning-';
final List<GridPoint> rooftopBurningZombieTiles = _airlinerRoofs.tilesOf('Y');

/// The first of them.
const String rooftopBurningZombieId = '${rooftopBurningZombiePrefix}0';

/// Whether Mario, standing at [at] on the roofs past the airliner, can
/// still get off them: through any way out he can walk to -- the tail
/// break, the next block's stairs -- or, with the grappling hook, across a
/// gap from beside its edge. Only the map counts: the fire the burning
/// zombies leave behind never goes out, while a zombie in the way can be
/// shot. Anywhere but on the roofs the answer is always yes.
bool hasRooftopWayOut(
  WorldState world,
  GridPoint at, {
  required bool grapplingHook,
}) {
  if (!_airlinerRoofs.bounds.contains(at)) {
    return true;
  }
  final reached = world.map.floodFillDistances(
    at,
    maxDistance: _airlinerRoofs.width * _airlinerRoofs.height,
  );
  if (reached.keys.any(world.portals.containsKey)) {
    return true;
  }
  return grapplingHook &&
      world.grapples.keys.any(
        (edge) => Direction.values.any(
          (side) => reached.containsKey(edge.step(side)),
        ),
      );
}

/// The tear in the belly of the airliner, in the lane the wreck left open
/// at the crossroads behind the hypermarket: two tiles wide, like the
/// aisle it opens on.
final List<GridPoint> airlinerTear = _mallNorthStreet.doorRow('[');

/// The two breaks in the hull, seen from inside: the tear `E` back out
/// onto the road, and the tail break `O` out onto the roofs.
final List<GridPoint> airlinerCabinTear = _airlinerCabin.doorRow('E');
final List<GridPoint> airlinerTailBreak = _airlinerCabin.doorRow('O');

/// Where the tail break lands, in the roofline it came to rest in.
final List<GridPoint> airlinerRoofBreak = _airlinerRoofs.doorRow('D');

/// The low stretch of parapet at the south edge of the lower terrace,
/// where the next block stands just across the gap: without the grappling
/// hook, looking at it is all Mario can do about it.
final GridPoint rooftopGapTile = _airlinerRoofs.tileOf('>');

/// The next block's wall broken open straight across from
/// [rooftopGapTile]: the way back with the grappling hook.
final GridPoint rooftopFarEdgeTile = _airlinerRoofs.tileOf('<');

/// The open stairwell `S` going down eastward into the block across the
/// gap past the airliner, three steps deep: got onto from its head, the
/// west end, and down step by step to the last, the door down into the
/// palazzo's top floor.
final List<GridPoint> rooftopFarStairs = _airlinerRoofs.tilesOf('S');

/// The last steps of [rooftopFarStairs], at its east end.
final List<GridPoint> rooftopFarStairsFoot = lastSteps(
  rooftopFarStairs,
  Direction.east,
);

/// The stairwell on the roofs, each step with the way up it (see
/// `WorldState.stairs`).
final Map<GridPoint, Direction> rooftopStairs = <GridPoint, Direction>{
  for (final step in rooftopFarStairs) step: Direction.east,
};

/// The tear in the belly of the crashed airliner, off the lane it left
/// open at the crossroads behind the hypermarket, and the break in its
/// tail at the far end of the cabin, out onto the roofs it stopped in:
/// both breaks are in a roof, so either way Mario lands below the one he
/// steps through. Both ways.
final Map<GridPoint, Portal> airlinerPortals = <GridPoint, Portal>{
  ...pairedDoors(airlinerTear, airlinerCabinTear, Direction.north),
  ...pairedDoors(airlinerCabinTear, airlinerTear, Direction.south),
  // The tail break is in the belly: Mario climbs down out of it south onto
  // the roofs, and back up into the cabin north.
  ...pairedDoors(airlinerTailBreak, airlinerRoofBreak, Direction.south),
  ...pairedDoors(airlinerRoofBreak, airlinerTailBreak, Direction.north),
};
