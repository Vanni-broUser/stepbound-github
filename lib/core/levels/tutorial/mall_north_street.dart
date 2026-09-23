// The ASCII map is one row per line, however wide the place is.

/// Reached only through the hypermarket ground floor's new fire exit (see
/// mall.dart): the loading side of the building, a street closed off on
/// its own to the rest of the north district. The fire door stands in the
/// southern roofline, two rows of parking stalls in front of it, and
/// beyond it a park has gone to seed between the north-side palazzi. Where
/// the road would carry on off-map east and west a wrecked-car pile-up
/// walls it off from house front to house front: four lanes of wrecks with
/// one more shunted up on each pavement, so there is no way round on foot.
/// The wrecks are nosed forward and back of one another rather than lined
/// up, but at each end they all take the same column -- the second from
/// the map edge west, the second from it east -- so the wall never opens.
/// The car park and the park are the same width, each pushed to its own
/// side with palazzi filling the rest of its row: the park east with the
/// palazzi west of it, the car park west with the palazzi east of it,
/// which keeps that part of the block inaccessible.
/// New glyphs, on top of the outdoor legend in street.dart: `g` grass, floor;
/// `p` broken playground equipment, an obstacle; `j` the fire door in the
/// rear wall, stepped onto to go back inside, floor.
// mall-north-rows-start
const List<String> mallNorthStreetRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggggggggggggggggggggggBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggAggggggggggggggpggggBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBgggggggggggAggggggggggBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggggggggnngggggggggpggBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBggggggnngggggggggggggpBBBBBBBBBBBB',
  'HHHHHHHHHHHHHHHHggggggggggggggAggpggggHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHHggggAgggggggggggggggggHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHHggggggggggnnggggggggggHHHHHHHHHHHH',
  'UU==============================================CC',
  '.XX.CC......................................CC.UU.',
  '-XX---------------------------------------------UU',
  'XX---------------------------------------------UU-',
  '.XX..CC....................................CC..UU.',
  'CC=============================================UU=',
  'BBLLLLLLLLCCLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBLLLLLLLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBLLLLLLLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBLLLLLLLLLLLLLwLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBLLLLLLLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBLLLLLLLLLLLLLLLLLLLLLLBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BB======================BBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBjBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// mall-north-rows-end
