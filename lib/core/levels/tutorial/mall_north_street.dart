// The ASCII map is one row per line, however wide the place is.

/// Reached only through the hypermarket ground floor's new fire exit (see
/// mall.dart): the loading side of the building, a block closed off on its
/// own to the rest of the north district. Four strips, south to north: the
/// fire door in the southern roofline with two rows of parking stalls in
/// front of it, the four-lane road behind them, the park, and beyond the
/// park a second street lined with the shops that served the block.
///
/// Both roads are sealed where they would carry on off-map. The four-lane
/// one is walled off by a wrecked-car pile-up from house front to house
/// front, wrecks in every lane and one more shunted up on each pavement;
/// they are nosed forward and back of one another rather than lined up,
/// but at each end they all take the same column -- the second from the
/// map edge west, the second from it east -- so the wall never opens. The
/// shopping street is closed the way the living closed it, with concrete
/// road blocks across both ends, pavements included.
///
/// The car park and the park are the same width, each pushed to its own
/// side with palazzi filling the rest of its row: the park east with the
/// palazzi west of it, the car park west with the palazzi east of it,
/// which keeps that part of the block inaccessible. The park is railed all
/// round, with three gates on its paths: one north onto the shopping
/// street, two south onto the road. Its paths make a spine down from the
/// north gate to a walk right across it, then a branch down to each south
/// gate, and the trees, benches and playground stand in the lawns between
/// them. Rubbish has been heaped in the south-west corner of the car park,
/// deep enough to climb over at its edges and not at its heart.
///
/// New glyphs, on top of the outdoor legend in street.dart: `g` grass,
/// floor; `p` broken playground equipment and `^` the park railing,
/// obstacles you can see over; `<` a gate in that railing, floor; `;` a
/// heap of rubbish too deep to step on, an obstacle, with `:` the rubbish
/// spilled around it, walkable but noisy; `j` the fire door in the rear
/// wall, stepped onto to go back inside, floor.
// mall-north-rows-start
const List<String> mallNorthStreetRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'HHHHHHHHHfHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHfHHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  '=J====================F============:============J=',
  '.J..........CC...........:......................J.',
  '-J----------------------------------------------J-',
  '.J................:...........UU................J.',
  '=J======:=======================================J=',
  'BBBBBBBBBBBBBBBB^^^^^^^^^^<^^^^^^^^^^^BBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggggggggggPgggggggggggBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggAggggAggPgggAggggAggBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggggggggggPgggggggggggBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggnnggnnggPgggnnggnnggBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBPPPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggggPggggggggggggPggggBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBgAggPnnggggggggnnPggAgBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggggPggggpgpgpgggPggggBBBBBBBBBBBB',
  'HHHHHHHHHHHHHHHHggggPggggggggggggPggggHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHHggAgPgggAggggAgggPgAggHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHH^^^^<^^^^^^^^^^^^<^^^^HHHHHHHHHHHH',
  'UU==============================================CC',
  '.XX.CC......................................CC.UU.',
  '-XX---------------------------------------------UU',
  'XX---------------------------------------------UU-',
  '.XX..CC....................................CC..UU.',
  'CC=============================================UU=',
  'BBLLLLLLLLCCLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBLLLLLLLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB::LLLLLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB;;::LLLLLLLLLwLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB;;;::LLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB;;;;:::LLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB======================BBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBjBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// mall-north-rows-end
