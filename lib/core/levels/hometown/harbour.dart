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
/// promenade turns the corner with it, jutting out square into the sea
/// there, its parapet turning the corners of it (`ò` inside, `ó` at the
/// point), and on it, a cell of paving all round, stands the wrecked
/// newsstand `ê`; two wooden piers
/// `l` reach west over the water. A rowboat `o` is moored at the end of the
/// second one, a backpack `5` with two rounds on board. The harbour road
/// ends short of the south-east corner, the pavement carried across its
/// end, and past it on the quay stands the children's carousel `ç`, the
/// glass pavilion of Molfetta's harbour; another campfire `S` burns west
/// of it, a cell clear of it and of the parapet over the sea.
/// A second backpack `7`, also with two rounds, lies at the northern end of
/// the rightmost blind alley in the old town west of the Duomo, in front
/// of one of the doors `Ħ` damaged enough that a crowbar could open them.
///
/// East of the road going down to the carousel the old town starts again:
/// two alleys leave the road, the upper one climbing to a little square
/// with a fountain `!` between two flower beds `&`, the lower one coming
/// back to the road from it, and three short blind alleys run off them.
// harbour-rows-start
const List<String> harbourRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBHH#######BBBBBBBBBHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBHH#######BBBBBBBBBHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPP#######BBBBBBBBBPPBBBBBBBBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPP#######BBBBBBBBBPPBBBBBBBBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPP#######HHHHHHHHHPPBBBBBBBBBBBBBBBBBBBBHHBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPP###(###HHHHHHHHHPPBBBBBBBBBBBBBBBBBBBBĦHBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBBBBBBBBBB7PBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPP:PPPPPBBBBBBBBBBBBBBBBBBBBPPBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPP:PPPPPPPBBBBBBBPwHHHHHHHHHHHHHHHHHHHHPPBBBWWWWWWWWWWWWWWWBBBBB=:.|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPBBBBBBBPPHHHHHHHPPHHHHĦHHHHHHHHHHHHHHHPPBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBPPBBBBBBBPPPPPPPPPPPPPPPPP:PPPPPPPPPPPPP:PBBBWWWWWWWWWWWWWWWBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '%%%%%%%%%%%%%%%%%%%BBBPPBBBBBBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPBBBWWWWWWWWWWWWWWWBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPhPPPPPPPPPBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '%%%%%%%%%%%%%%%%%%%BBBPPHHHHHHHPPBBBBBBBPPPP&P!!P&PPPPBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBPPPPP:PPPPPPPPPPPPwPPBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,,,,,,,,,,,iii,%BBBPPHHHHHHHPPHHHHHHHPPPP&:!!P&PPPPBBBBBBBBBBBBBPPPPPPPPPPPPPPPBBBBB=.w|..=BBBBBBBBBBBBBBBBBBBBPPBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,,,,,,,,,,,iii,%BBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBBBPPAPPPPPPPSPAPPBBBBB=..|d.=BBBBBBBBBBBBBBBBBBBBPdBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,*********,iii,%BBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBBBPPPPPPPsPPPPPPPHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,*********,iii,%BBBPPBBBBBBB:PBBBBBBBPPBBBBBBBBBBPwBBBBBBBBBBBBBBBBBBBxxxBBBBBBHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHfHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,*********,,,,,%HHHP:HHHHHHHPPHHHHHHHPPHHHHHHHHHHPPHHHHHHHHHHHHHHHHHHHtPtHHHHHHHHHHH=..|..=HHHHHHHHHHHfHHHHHHHHPPHHHHHfHHHHHHHHHHHHHHHfHHBBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,*********,,,,,%HHHPPHHHHHHHPPHHHHHHHPPHHHHHHHHHHPPHHHHHHHHHHHHHHHHHHHPPPHHHHHHHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHHHHHHHHHHHHHHHHHHHHHHBBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,*********,,,,,%=====================================================F===============VVVVVT===============F==============================BBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,*********,,,,,%=.......:................................................CC.........Z.....Z........:....................................=BBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,,,,,,,,,,,:,,,%=..........w.............................w.....................:....Z.....Z.............................................=BBBBBBBBBBBBBBBBBBBBBBB',
  '%,:,,,,,w,,,,,,,,,%=.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.Z.-.-.Z.-d-.-.-.-.-.-.-z-.-.-.-.-.-.-.-.-.-.-.-..c..=BBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,,,,,,,,,,,,,,,%=.......................UU.....................UU...................Z.....Z.........w...................................=BBBBBBBBBBBBBBBBBBBBBBB',
  '%,,,,,,,,:,,,6,,,,%=.............................:........................d............Z.....Z....XX....................................|..=BBBBHHBBBBBBBBBBBBBBBBB',
  '%,,,,,,,,,,,,,,,,,%==================================================================F=====:==================================F=======..|..=BBBBHHBBBBBBBBBBBBBBBBB',
  '%,,:,,,,,,,,:,,,,,,PPNPPPPPPPPPPPNPPPPPPPPPPPNPPPPPPPPPPPPPPPPPPPPNPPPPPPPPPNPPPwPPPP:PPPPPPPPPPNPPPPPPPPPNPPPPPPPPPPPPPPPPPNPPPPPPPP=..|..=BBBBPPBBBBBBBBBBBBBBBBB',
  '%,,,,,,,,,,,,,,,,,,PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPPPPDPPPPPwPPPPnnPPPPPPPPdPPPPPPPPPPPPPPPnnPnnPP=..|..=BBBBPPBBBBBBBBBBBBBBBBB',
  'RRRRRRllllRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRòPPPPPPPP=..|..=HHHHPPHHHHHHHHHHHHBBBBB',
  '~~~~~~llll~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPêêêPPPP=..|..=HHHHPPHHHHHHHHHHHHBBBBB',
  '~~~~~~llll~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPêêêPPPP=..|..=PPPPPPPPPPPPPPPPPwBBBBB',
  '~~~~~~llll~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPPPPPPPP=..|..=PPP:PPPPPPPPPPPPPPBBBBB',
  '~~~~~~llll~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~óRRRRRòNP=..|..=BBBBBBBBBP&P!!P&PPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|.:=BBBBBBBBBP&P!!P&PPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBBBBBBBPPdPPPPPPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBBBBBBBPPPPPPPPPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|v.=BBBBBBBBBBBBBBBBPPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|v.=BBBBBBBBBBBBBBBBPPHHHBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBBBBBBBBBBBBBBPPHHHBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBBBBBBBBBBBBBBPPPPPBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBBBBBBBBBBBBBBPPPPPBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=.w|..=BBBBBBBBBBBBBBBBPPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=HHHHHHHHHHHHHHHHPPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=HHHHHHHHHHHĦHHHHPPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNP=..|..=PPPPPPPPPPPwPPPPPPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=PPPPPP:PPPPPPPPPPPBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBBBBBBPPBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=UU|..=BBBBBBBBPPBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|..=BBBBBBBBPPBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|..=BBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ooooo~~~~~~~~~~~~~~RPP=..|..=BBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~o5ooo~~~~~~~~~~~~~~RPP=..|..=BBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|w.=BBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=======BBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNPPPPPPPPBBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPPPçççççPBBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPSPçççççPBBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPPPçççççPBBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPPPPPPPPPBBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
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

/// The palazzo doors `Ħ` in the old town's alleys, damaged enough that a
/// crowbar could force them, in reading order: the one above the backpack
/// `7`, at the northern end of the rightmost blind alley, the one facing
/// the fountain on the little square west of the Duomo and one on the
/// lower alley of the old town east of the road down to the carousel.
/// Looking at one says so.
final List<GridPoint> oldTownDamagedDoorTiles = _harbour.tilesOf('Ħ');

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
/// the road Mario walks down. Every scene of his plays here, the price,
/// the welcome and the warning alike.
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
