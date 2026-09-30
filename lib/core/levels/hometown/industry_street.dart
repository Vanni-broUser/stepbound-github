import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

// The ASCII map is one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// The street the palazzo past the airliner opens onto, out of its
/// portone `«`, wide open, the one way in to it from the street (it takes
/// the place of the door the palazzo would have had), its front a floor
/// taller than its neighbours', three floors over the hall as inside: a
/// street of
/// Molfetta like the others, its palazzi along
/// the north side over the pavement, the roofs of the next block along
/// the south side. East of the palazzo, a few palazzi on, the long low
/// shed of a big company `Æ`, its gate `Ø` rolled up on the way in
/// (company.dart) and its loading bays shut; between the two, a camp
/// on the pavement with its fire `S`. West, a few palazzi on, the street
/// ends against the corner palazzo and a road goes off it south: a
/// crossroads with its traffic lights `T` at three corners, a zebra
/// crossing over each road, the stop lines before them, the centre line
/// bending round the corner, a give-way sign `/` at the mouth of the road
/// south and the blue plate pointing the way east.
///
/// Glyphs, on top of the outdoor legend in street.dart: `Æ` the
/// company's shed, a wall; `Ø` its gate, rolled up, a door; `«` the
/// palazzo's portone, a door.
// industry-street-rows-start
const List<String> industryStreetRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBHHHHBBBBBBBBBBBBBBBBBBÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆBBB',
  'BBBBHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHfHHHHHHHÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆHHH',
  'BBBBHHHHHHHHHHHfHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆHHH',
  'BBBBHHHHHHHHHHHHHHHHHHHHHHHHHHH«HHHHHHHHHHHHHHHHHHHHÆÆÆÆÆÆÆÆÆÆØØØØÆÆÆÆÆÆÆÆÆÆÆHHH',
  'BBBBT=/===T=F==========================/====S======================/============',
  'BBBB=....Z▏.......:........>.......UU...............r..d..............CC........',
  'BBBB=.ɔ.-Z----------w-----d-----------w-------:--->----------:------------------',
  'BBBB=....Z....CC.............:...........d..............w.XX....>....w....:.....',
  'BBBB=VVVT=============nn========d=====:=========T=======================D=======',
  'BBBB=.|▔=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=.|:=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=.|./BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=.v.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=.v.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=>|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=d|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=.z.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// industry-street-rows-end

final Place _industryStreet = place(PlaceId.industryStreet);

/// The palazzo's portone, seen from the street.
final GridPoint industryStreetPortone = _industryStreet.tileOf('«');

/// The camp on the pavement between the palazzo and the company.
final GridPoint industryStreetCampfireTile = _industryStreet.tileOf('S');

/// The company's gate, rolled up, seen from the street, west to east.
final List<GridPoint> industryStreetGate = _industryStreet.tilesOf('Ø');
