// The ASCII maps are one row per line, however wide the place is.

import 'package:stepbound/core/grid/grid_point.dart';

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
/// them. The first lies in the forward galley, under an emergency light,
/// the first thing Mario sees coming in. Another lies across the aisle past
/// the cross aisle, and there is no stepping round him in it: the way past
/// is over the broken seats beside him. The rest can be given a wide berth.
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
  'xI.K.TTT*.TTT..TrT.::.TTT.MTTT..TTT.*....:Ix',
  'xI.....b....Z.........:.....M....b........Ix',
  'xI..*.......:*........*:.......*........*.Ix',
  'xI*K.TTTM.TrT..TTT.::.TTT.*rrr..TTT.......Ix',
  'xIM:.TTT..TTT..TTT.::.TTT..TTT..TTT...+...Ix',
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
/// `&`. Out of it have walked two zombies on fire `Y`: they go after Mario
/// like wanderers, and every tile they step off catches fire and stays
/// alight, shut for good.
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
  'xW&&&&Y..:.........:...T....Wx',
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
