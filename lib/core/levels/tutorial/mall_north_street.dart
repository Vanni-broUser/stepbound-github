// The ASCII map is one row per line, however wide the place is.

/// Reached only through the hypermarket ground floor's new fire exit (see
/// mall.dart): the loading side of the building and the block behind it,
/// closed off on its own from the rest of the north district. Four strips,
/// south to north: the fire door in the southern roofline with two rows of
/// parking stalls in front of it, the four-lane road behind them, the
/// park, and beyond the park a shopping street. The two streets are joined
/// at the east end by a north-south street between the palazzi, so the
/// block walks as a circuit rather than a dead end.
///
/// What is closed, and by what. West, both streets stop at the map edge:
/// the four-lane road behind a wrecked-car pile-up from house front to
/// house front, wrecks in every lane and one more shunted up on each
/// pavement, the shopping street behind concrete road blocks laid across
/// it by the living. The wrecks are nosed forward and back of one another
/// rather than lined up, but they all take the second column from the map
/// edge, so the wall never opens. A second pile-up stands midway between
/// the park's two south gates and cuts the four-lane road in half, which
/// leaves the park the only way from one half to the other. East, nothing
/// blocks anything: the streets simply run into the buildings.
///
/// The car park and the park are the same width, each pushed to its own
/// side with palazzi filling the rest of its row: the park east with the
/// palazzi west of it, the car park west with the palazzi east of it,
/// which keeps that part of the block inaccessible. The park is railed all
/// round, with three gates on its paths: one north onto the shopping
/// street, two south onto the road. Its paths make a spine down from the
/// north gate to a walk right across it, then a branch down to each south
/// gate, and the trees, benches and playground stand in the lawns between
/// them. Rubbish has been heaped in the south-west corner of the car park
/// and out over the pavement there, deep enough to climb over at its edges
/// and not at its heart.
///
/// At the top of the map, where the shopping street opens into its
/// forecourt, stands the station: a low provincial building of the kind
/// the south is full of, a long body of round-arched openings under a
/// raised middle bay with the clock and the town's name on it. Its two
/// doorways stand open, and each one goes in: the west one `(` into the
/// booking hall and its platform, the east one `)` into the far end of
/// the hall, cut off from the first by the fall (see station.dart).
///
/// New glyphs, on top of the outdoor legend in street.dart: `g` grass,
/// floor; `p` broken playground equipment and `^` the park railing,
/// obstacles you can see over; `<` a gate in that railing, floor; `;` a
/// heap of rubbish too deep to step on, an obstacle, with `:` the rubbish
/// spilled around it, walkable but noisy; `0` the station building, a
/// wall, with `(` and `)` its two open doorways, floor; `j` the fire door
/// in the rear wall, stepped onto to go back inside, floor.
// mall-north-rows-start
const List<String> mallNorthStreetRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB000000000000000000',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB000000000000000000',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB000000000000000000',
  'HHHHHHHHHfHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH000000000000000000',
  'HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHfHHHHHHHHHHHHHHHHHHHHHH000000000000000000',
  'HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH00((000000))000000',
  'CC/===================F============:=============/=====TPPPPPPP:PPPPPPPBBB',
  '.UU.........CC...........:........................Z....=PPPPPCCPPPPPCCPBBB',
  'CC----------------------------------------------..Z....=PPPPPPPPPPPPPPPBBB',
  '.UU....S..........:...........UU..................Z....=PPPPPPPPUUPPPPPBBB',
  'CC======:=========================================TVVVV=PPPNPPPPPPPPPNPBBB',
  'BBBBBBBBBBBBBBBB^^^^^^^^^^<^^^^^^^^^^^BBBBBBBBBBBB=....=BBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggggggggggPgggggggggggBBBBBBBBBBBB=....=BBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggAggggAggPgggAggggAggBBBBBBBBBBBB=....=BBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggggggggggPgggggggggggBBBBBBBBBBBB=.||.=BBBBBBBBBBBBBBBB+B',
  'BBBBBBBBBBBBBBBBggnnggnnggPgggnnggnnggBBBBBBBBBBBB=.||.=B++BBBBBBBBBBBB++B',
  'BBBBBBBBBBBBBBBBPPPPPPPPPPPPPrPPPPPPPPBBBBBBBBBBBB=v||.=B++BBBBBBBBBBBB++B',
  'BBBBBBBBBBBBBBBBggggPggggggggggggPggggBBBBBBBBBBBB=v||.=+++BBBBBBBBBBBB+__',
  'BBBBBBBBBBBBBBBBgAggPnnggggggggnnPggAgBBBBBBBBBBBB=.||.=+++BBBBBBBBBB_____',
  'BBBBBBBBBBBBBBBBggggPggggpgpgpgggPggggBBBBBBBBBBBB=.||.++++BBBBBBB________',
  'HHHHHHHHHHHHHHHHggggPggggggggggggPggggHHHHHHHHHHHH=.||.++++BBBB_________++',
  'HHHHHHHHHHHHHHHHggAgPgggAggggAgggPgAggHHHHHHHHHHHH/....++++B_________BBBBB',
  'HHHHHHHHHHHHHHHH^^^^<^^^^^^^^^^^^<^^^^HHHHHHHHHHHH=...+++_________BBBBBBBB',
  'UU=======================CC==============:::=======VVV_________BBBBBBBBBBB',
  '.XX.CC....................UU............CC::..._____________+BBBBBBBBBBBBB',
  '-XX----------------------UU---------------::_____________++++BBBBBBBBBBBBB',
  'XX------------------------UU----------------__[[______.=B+++++BBBBBBBBBBBB',
  '.XX..CC..................UU............UU.::::..::Z:...=BB+++++BBBBBBBBBBB',
  'CC========================CC================::===/T=====BBBB++++BBBBBBBBBB',
  'BBLLLLLLLLCCLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB+++BBBBBBBBBB',
  'BBLLLLLLLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB::LLLLLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB;;::LLLLLLLLLwLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB;;;::LLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB;;;;:::LLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB;;;:::================BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBjBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// mall-north-rows-end
