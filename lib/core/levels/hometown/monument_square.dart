import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

/// The square at the bottom of the road south off the street of the
/// company, drawn on the same map as that street (industry_street.dart,
/// `industryStreetRows`), the road coming in at the top of it. A
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
/// (electronics_shop.dart). Past it a pile-up across the road from
/// pavement to pavement, the cars some ahead of the others and some
/// behind, each touching the next, and one more `v` past them; the road
/// runs on beyond it to the edge of the map, out of reach.
///
/// Glyphs, on top of the outdoor legend in street.dart: `Ω` the monument,
/// an obstacle; `h` the shop's open door; `µ` a backpack with two rounds
/// on the pavement in front of the Farmacia.

final Place _industryStreet = place(PlaceId.industryStreet);

/// The backpack `µ` on the pavement in front of the Farmacia, on the road
/// west of the monument's square, and the two rounds inside it.
const String pharmacyBackpackId = 'backpack-pharmacy';
const int pharmacyBackpackAmmo = 2;
final GridPoint pharmacyBackpackTile = _industryStreet.tileOf('µ');

/// The monument on its island in the middle of the square.
final List<GridPoint> monumentTiles = _industryStreet.tilesOf('Ω');

/// The Elettronica's open door `h` on the road east of the square (the way
/// in from it is [electronicsShopEntrance], electronics_shop.dart).
final GridPoint monumentSquareShopDoor = _industryStreet.tileOf('h');
