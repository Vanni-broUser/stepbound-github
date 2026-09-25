// The ASCII maps are one row per line, however wide the place is.

/// Inside the airliner that came down on the crossroads behind the
/// hypermarket (see mall_north_street.dart, where its body lies across the
/// junction). Drawn as a room on a dark background like the barracks, and
/// lit like one: the cabin lost its power long ago and what light there is
/// falls in at the two breaks in the hull.
///
/// The map runs the way the aeroplane does, nose west, tail east. Mario
/// comes in through the tear in the belly `E`, at the west end where the
/// forward body rests in the road, and the only other way out is the tail
/// break `O` at the east end, which opens on the roofs it stopped in (see
/// the rooftops below). Between the two the cabin walks end to end: the
/// seats `T` stand in their blocks either side of the aisle, and where the
/// floor buckled, halfway down, the rows are torn open into a cross aisle
/// of loose panelling `::`.
///
/// The passengers who lost their legs in the crash lie where they fell, the
/// mutilated zombies `M`: they never move, but bite whoever passes next to
/// them. Most can be given a wide berth: the one in the aisle by walking the
/// other half of it, or the lower aisle round it. The one under the tail
/// break cannot: a trolley `K` closes the other half of the break, and the
/// way out is past him. The flight bag `9` between two blocks of seats has
/// the rounds for it, whatever Mario came in with.
///
/// Glyphs: `x` darkness, `W` the roof of the hull, `w` its belly, `I` its
/// sides, all walls; `T` a block of seats and `K` a galley trolley on its
/// side, obstacles you can see over; `.` the aisle and the vestibules,
/// `:` panelling and cabin baggage (noisy), `b` blood, `*` an emergency
/// light still burning and `+` one that flickers, `Z` a wanderer, `M` a
/// mutilated zombie, `9` the flight bag, `E` the tear onto the road, `O` the
/// tail break onto the roofs.
// airliner-cabin-rows-start
const List<String> airlinerCabinRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWOOWWWWWx',
  'xI...TTT..TTT9.TTT.::.TTT..TTT..TTT.MK.K..Ix',
  'xI.:.TTT..TTT..TTT.::.TTT..TTT..TTT...+...Ix',
  'xI.K.TTT..TTT..TTT.::.TTT.MTTT..TTT......:Ix',
  'xI.....b....Z.........:.....M....b........Ix',
  'xI..*.......:..........:.......*..........Ix',
  'xI.K.TTTM.TTT..TTT.::.TTT..TTT..TTT.......Ix',
  'xIM:.TTT..TTT..TTT.::.TTT..TTT..TTT.......Ix',
  'xI...TTT..TTT..TTT.::.TTT..TTT..TTT..b.Z:.Ix',
  'xI..:...........+.........:...............Ix',
  'xwwwwEEwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// airliner-cabin-rows-end

/// The roofs the tail came to rest in, out of the tail break `D` at the
/// top of the map. Two terraces, one stepped down from the other over a
/// low parapet `^` broken in two places, with chimney stacks `T` and
/// aerial masts `n` standing about them and slate and gravel `:` thrown
/// over both by the crash. The tail `#` lies along the top of the map with
/// the break `D` torn in its side.
///
/// The lower terrace ends, south, at the parapet along the street front.
/// There the roof of the next block stands just across the gap, near
/// enough to look at and too far to jump: `>` is the low stretch of the
/// parapet where Mario stops to measure it, `x` the drop into the street
/// between the two blocks, and `%` the roof on the far side.
///
/// The fuel that came down with the tail is still burning in the south-east
/// corner of the lower terrace `&`, and out of it has walked a zombie on
/// fire `Y`: it goes after Mario like a wanderer, and every tile it steps
/// off catches fire and stays alight, shut for good.
///
/// Glyphs: `x` the drop and the sky, `W` the party walls and the roofline
/// the tail sits in, `#` the tail itself and `%` the next roof, all walls;
/// `T`, `n`, `^` and `>` obstacles you can see over; `.` the roof deck,
/// `:` slate and gravel (noisy), `b` blood, `&` the roof on fire, `Y` the
/// burning zombie, `D` the tail break.
// airliner-roof-rows-start
const List<String> airlinerRoofRows = <String>[
  'xxxxxxxxxxx########xxxxxxxxxxx',
  'xWWWWWWWWWW###DD###WWWWWWWWWWx',
  'xW..........::::::..........Wx',
  'xW..T....:.........:...T....Wx',
  'xW.....n.......b.......:....Wx',
  'xW..:........T.........n....Wx',
  'xW.......:........:.........Wx',
  'xW..n.......:..........T....Wx',
  'xW^^^^^^^...^^^^^^...^^^^^^^Wx',
  'xW..........:......:........Wx',
  'xW...T.....b.........:..T...Wx',
  'xW......:........n.......Y&&Wx',
  'xW..:..........:........:&&&Wx',
  'xW.....................&&&&&Wx',
  'xW^^^^^^^^^^^^^>^^^^^^^^^^^^Wx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'x%%%%%%%%%%%%%%%%%%%%%%%%%%%%x',
  'x%%%%%%%%%%%%%%%%%%%%%%%%%%%%x',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// airliner-roof-rows-end
