import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

// The ASCII map is one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// The harbour and the old town, south of the north district (same glyphs
/// as the street): the road from the square comes down between the old
/// town's palazzi and ends against them, the pavement carried across its
/// mouth; the seafront road it feeds runs a long way west, and beyond
/// that the promenade with its palms, then the parapet and the murky sea,
/// scummed with green, where rowboats rot half-sunk.
///
/// West of the Duomo the alleys of the old town climb off the seafront
/// road and cross one another, narrow and paved, the way they run in a
/// Puglia old town; deep in them, on its own small square, stands the
/// church of San Nicola `#`, a plainer and smaller thing than the Duomo.
/// Nobody barred it the way Don Angelo barred his: its portal `(` stands
/// open on the dark of the nave, and stepping into it goes inside (see
/// church.dart).
///
/// The road ends at the shipyard: its wall `%` closes it head on and the
/// way in is round the side, off the promenade. Inside, a hull `*` sits up
/// on the stocks under the gantry crane `i`, and the slipway `l` runs down
/// into the water. In the yard, by the hull, the workmen left a backpack
/// `6` with two rounds.
///
/// The Duomo `W` stands well back from the seafront road, hidden behind a
/// row of palazzi: an alley two cells deep climbs off the sidewalk and
/// opens, past the churchyard gate `x`, into the T of the sagrato `P`, wide
/// enough for the whole front of the church and its two bell towers. Don
/// Angelo `s` waits behind the gate, two zombies `t` outside it. A campfire
/// `S` burns on the sagrato, unreachable until the incense opens the gate.
///
/// To the east a narrow alley climbs north off the seafront road, then
/// turns east to the Bar Arcobaleno, whose door `h` leads inside. The road
/// carries on east as far as the bar, then turns south along the sea: the
/// promenade and its parapet turn the corner with it, and two wooden piers
/// `l` reach west over the water. A rowboat `o` is moored at the end of the
/// second one, a backpack `5` with two rounds on board. The harbour road
/// ends short of the south-east corner, the pavement carried across its
/// end, and past it on the quay stands the children's carousel `ç`, the
/// glass pavilion of Molfetta's harbour; another campfire `S` burns beside
/// it.
/// A second backpack `7`, also with two rounds, lies at the northern end of
/// the rightmost blind alley in the old town.
// harbour-rows-start
const List<String> harbourRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBHH#######BBBBBBBBBHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBHH#######BBBBBBBBBHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPP#######BBBBBBBBBPPBBBBBBBBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPP#######BBBBBBBBBPPBBBBBBBBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPP#######HHHHHHHHHPPBBBBBBBBBBBBBBBBBBBHHBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPP###(###HHHHHHHHHPPBBBBBBBBBBBBBBBBBBBHHBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBBBBBBBBB7PBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPP:PPPPPBBBBBBBBBBBBBBBBBBBPPBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPP:PPPPPPPBBBBBBBPwHHHHHHHHHHHHHHHHHHHPPBBBBWWWWWWWWWWWWWWWBBBBB=:.|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPBBBBBBBPPHHHHHHHPPHHHHHHHHHHHHHHHHHHHPPBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPBBBBBBBPPPPPPPPPPPPPPPPP:PPPPPPPPPPPPP:BBBBWWWWWWWWWWWWWWWBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  '%%%%%%%%%%%%%%%%%%BBBBPPBBBBBBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPBBBBWWWWWWWWWWWWWWWBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPhPPPPPPPPPBBBBBBBBB',
  '%%%%%%%%%%%%%%%%%%BBBBPPHHHHHHHPPBBBBBBBPPPP&P!!P&PPPPBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBPPPPP:PPPPPPPPPPPPwPPBBBBBBBBB',
  '%,,,,,,,,,,,,,iii%BBBBPPHHHHHHHPPHHHHHHHPPPP&:!!P&PPPPBBBBBBBBBBBBBPPPPPPPPPPPPPPPBBBBB=.w|..=BBBBBBBBBBBBBBBBBBBBPPBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,,,,,,,,,,,iii%BBBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBBBPPAPPPPPPPSPAPPBBBBB=..|d.=BBBBBBBBBBBBBBBBBBBBPdBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,*********,iii%BBBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBBBPPPPPPPsPPPPPPPHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHHHHHHHHHHHHHHHHHHHHHHBBBB',
  '%,,,*********,iii%BBBBPPBBBBBBB:PBBBBBBBPPBBBBBBBBBBPwBBBBBBBBBBBBBBBBBBBxxxBBBBBBHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHfHHHHHHHHHHHHHHHHHHHHBBBB',
  '%,,,*********,,,,%HHHHP:HHHHHHHPPHHHHHHHPPHHHHHHHHHHPPHHHHHHHHHHHHHHHHHHHtPtHHHHHHHHHHH=..|..=HHHHHHHHHHHfHHHHHHHHPPHHHHHHHHHHHHHHHHHHHHHfHHBBBB',
  '%,,,*********,,,,%HHHHPPHHHHHHHPPHHHHHHHPPHHHHHHHHHHPPHHHHHHHHHHHHHHHHHHHPPPHHHHHHHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHHHHHHfHHHHHHHHHHHHHHHBBBB',
  '%,,,*********,,,,%======================================================F===============VVVVVT===============F==============================BBBB',
  '%,,,*********,,,,%=........:................................................CC.........Z.....Z........:....................................=BBBB',
  '%,,,,,,,,,,,,,:,,%=...........w.............................w.....................:....Z.....Z.............................................=BBBB',
  '%,:,,,,,w,,,,,,,,%=-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.Z.-.-.Z.-d-.-.-.-.-.-.-z-.-.-.-.-.-.-.-.-.-.-.-..c..=BBBB',
  '%,,,,,,,,,,,,,,,,%=........................UU.....................UU...................Z.....Z.........w...................................=BBBB',
  '%,,,,,,,,:,,,6,,,%=..............................:........................d............Z.....Z....XX....................................|..=BBBB',
  '%,,,,,,,,,,,,,,,,%===================================================================F=====:==================================F=======..|..=BBBB',
  '%,,:,,,,,,,,:,,,,,PPPNPPPPPPPPPPPNPPPPPPPPPPPNPPPPPPPPPPPPPPPPPPPPNPPPPPPPPPNPPPwPPPP:PPPPPPPPPPNPPPPPPPPPNPPPPPPPPPPPPPPPPPNPPPPPPPP=..|..=BBBB',
  '%,,,,,,,,,,,,,,,,,PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPPPPDPPPPPwPPPPnnPPPPPPPPdPPPPPPPPPPPPPPPnnPPPPP=..|..=BBBB',
  'RRRRRRllllRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRPP=..|..=BBBB',
  '~~~~~~llll~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~llll~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~llll~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~llll~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|.:=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|v.=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|v.=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=.w|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=UU|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ooooo~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~o5ooo~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|w.=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=======BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNPPPPPPPPBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPPçççççPPBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPPçççççPSBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPPçççççPPBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPPPPPPPPPBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBB',
];
// harbour-rows-end

/// The name on the card shown on the way into the harbour.
const String harbourName = 'Porto e centro storico';

final Place _harbour = place(PlaceId.harbour);
final Place _north = place(PlaceId.northDistrict);

/// The harbour's backpacks `5`, `6` and `7`: what each holds is in
/// `hometownContents`.
const String boatBackpackId = 'backpack-boat';
const String shipyardBackpackId = 'backpack-shipyard';
const String oldTownBackpackId = 'backpack-old-town';

/// The two new harbour backpacks, named separately so saves keep tracking
/// each one even though both hold the same two rounds.
final GridPoint shipyardBackpackTile = _harbour.tileOf('6');
final GridPoint oldTownBackpackTile = _harbour.tileOf('7');

/// The two harbour fires, in row order: first on the gated Duomo sagrato,
/// then at the south-east end of the harbour road.
final GridPoint duomoCampfireTile = _harbour.tilesOf('S').first;
final GridPoint harbourRoadCampfireTile = _harbour.tilesOf('S').last;

/// Where Don Angelo waits, on the sagrato just beyond the churchyard gate.
final GridPoint priestTile = _harbour.tileOf('s');

/// The three wrought-iron gate tiles across the alley. The extended priest
/// scene turns them into floor, leaving the open leaves drawn at the sides.
final List<GridPoint> priestGateTiles = _harbour.tilesOf('x');
final GridRect priestGate = GridRect(
  priestGateTiles.first.x,
  priestGateTiles.first.y,
  priestGateTiles.last.x,
  priestGateTiles.last.y,
);

/// The Duomo's open portal is directly north of Don Angelo's original spot.
/// The gate, not this doorway, keeps Mario out until the incense is delivered.
final GridPoint duomoPortalTile = GridPoint(priestTile.x, priestTile.y - 2);

/// The two zombies pressed against the gate, west to east: the priest asks
/// Mario to get rid of them before he will talk.
final List<GridPoint> priestZombieTiles = _harbour.tilesOf('t');

/// Their ids, `priest-zombie-0` and `priest-zombie-1`.
const String priestZombiePrefix = 'priest-zombie-';

/// The alley between the seafront road and the churchyard gate: standing
/// here is standing in front of Don Angelo.
final GridRect priestGateFront = () {
  final alley = priestGateTiles;
  return GridRect(
    alley.first.x,
    alley.first.y + 1,
    alley.last.x,
    alley.last.y + 2,
  );
}();

/// Coming this close to the alley is close enough for Don Angelo to hail
/// Mario: the alley itself and the whole width of the seafront road in
/// front of it, sidewalk to sidewalk, so he calls out whichever side of
/// the road Mario walks down.
final GridRect priestSceneTrigger = () {
  final rows = _harbour.rows;
  final x = priestGateFront.left - _harbour.origin.x;
  // From the sidewalk under the palazzi, across the lanes, down to the
  // sidewalk along the promenade.
  var y = priestGateFront.bottom - _harbour.origin.y + 1;
  do {
    y++;
  } while (rows[y][x] != '=');
  return GridRect(
    priestGateFront.left - 2,
    priestGateFront.top,
    priestGateFront.right + 2,
    _harbour.origin.y + y,
  );
}();

/// The road leaving the bottom of the north district, which is the one
/// entering the top of the harbour, both ways.
final Map<GridPoint, Portal> harbourPortals = () {
  final northEdge = _north.walkableRow(_north.height - 1);
  final harbourEdge = _harbour.walkableRow(0);
  return <GridPoint, Portal>{
    ...pairedDoors(northEdge, harbourEdge, Direction.south),
    ...pairedDoors(harbourEdge, northEdge, Direction.north),
  };
}();
