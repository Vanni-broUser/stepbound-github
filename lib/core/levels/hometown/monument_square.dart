import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

// The ASCII map is one row per line, however wide the place is.

/// The square at the bottom of the road south off the street of the
/// company (industry_street.dart), the way in at the top of the map. A
/// roundabout round an island of paving, and on the island Molfetta's
/// monument `Ω`: a car crushed flat between two great blocks of stone on
/// a plinth, the wheels and the bodywork sticking out either side. Round
/// it the trees, the benches, the ring road and its palazzi.
///
/// From the square a road goes west and one east. The west one ends a
/// few palazzi on, against the pavement down its end and the palazzi
/// past it; on it the Farmacia, shut and looted like every other shop.
/// On the east one, the Elettronica `h`: its shutter up, its sign whole,
/// the one shop in town still open, and its door the way into it
/// (electronics_shop.dart). Past it the road runs on to the east edge.
///
/// Glyphs, on top of the outdoor legend in street.dart: `Ω` the monument,
/// an obstacle; `h` the shop's open door; `µ` a backpack with two rounds
/// on the pavement in front of the Farmacia.
// monument-square-rows-start
const List<String> monumentSquareRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.d.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBHHHHHHHH=.|.=HHHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBHHHHHHHH=.|.=HHHHfHHHBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBHHHHHHHH=.|.=HHHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=======T=VVV=T=======BBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=..CC........d......=BBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBHHHHHHHHHHHHHH=.-.-.-w-.-.-.-.-.-.=HHHHHHHHHHHHHHHHHHHHHHHHHH',
  'BBBHHHHHHHHHHHfHH=................CC.=HHHHHHHHHHHHHHHHHHHHfHHHHH',
  'BBBHHHHHHHHHHHHHH=...====:========...=HHHHHHHHHHHHHHHHHHHHHHHHHH',
  'BBB===:=µ=======/=.|.=PAPPPPPPPAP=.|.=========h=============F===',
  'BBB=....UU.......Z...=PPPPΩΩΩPPP:=...Z......w..>................',
  'BBB=.-.-.-w-.-.-.Z.|.=PPPPΩΩΩPPPP=.|.Z.-.-.-.-.-.-.-.-.-z-.-.-.-',
  'BBB=.D.......d...Z...=PPPPΩΩΩPPPP=...Z...d..........CC..........',
  'BBB===============v|.=PAPnnPnnPAP=.|.=/==========:==============',
  'BBBBBBBBBBBBBBBBB=v..=============.w.=BBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=...........>.......=BBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=.-.-d-.-.-.-.-.-.-.=BBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=...D.........XX....=BBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB==========F==========BBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// monument-square-rows-end

final Place _monumentSquare = place(PlaceId.monumentSquare);
final Place _industryStreet = place(PlaceId.industryStreet);

/// The backpack `µ` on the pavement in front of the Farmacia, on the road
/// west of the monument's square, and the two rounds inside it.
const String pharmacyBackpackId = 'backpack-pharmacy';
const int pharmacyBackpackAmmo = 2;
final GridPoint pharmacyBackpackTile = _monumentSquare.tileOf('µ');

/// The road south off the street of the company, where it runs off the
/// bottom of that map, and where it comes into the top of the monument's
/// square, west to east.
final List<GridPoint> industryStreetSouthEdge = _industryStreet.walkableRow(
  _industryStreet.height - 1,
);
final List<GridPoint> monumentSquareNorthEdge = _monumentSquare.walkableRow(0);

/// The monument on its island in the middle of the square.
final List<GridPoint> monumentTiles = _monumentSquare.tilesOf('Ω');

/// The Elettronica's open door `h` on the road east of the square (the way
/// in from it is [electronicsShopEntrance], electronics_shop.dart).
final GridPoint monumentSquareShopDoor = _monumentSquare.tileOf('h');

/// The road between the street of the company and the square, both ways.
final Map<GridPoint, Portal> monumentSquarePortals = <GridPoint, Portal>{
  ...pairedDoors(
    industryStreetSouthEdge,
    monumentSquareNorthEdge,
    Direction.south,
  ),
  ...pairedDoors(
    monumentSquareNorthEdge,
    industryStreetSouthEdge,
    Direction.north,
  ),
};
