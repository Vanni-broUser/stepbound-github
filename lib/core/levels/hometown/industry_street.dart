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
/// the south side. East of the palazzo, a few palazzi on, the office
/// block of a call centre `Æ`, its front all tinted glass, its way in `Ø`
/// under a red canopy with its name on it, the glass doors broken open
/// (company.dart); between the two, a camp
/// on the pavement with its fire `S`. Past the company, at the east edge of
/// the map, a pile-up shuts the street from pavement to pavement: cars,
/// burning `XX` and overturned `UU`, some ahead of the others and some
/// behind, each touching the next so there is no way between them, and
/// one more `k` burning past them. West, a few palazzi on, the street
/// ends against the corner palazzo and a road goes off it south: a
/// crossroads with its traffic lights `T` at three corners, a zebra
/// crossing over each road, the stop lines before them, the centre line
/// bending round the corner, a give-way sign `/` at the mouth of the road
/// south and the blue plate pointing the way east.
///
/// The road south runs on, on the same map, down to the monument's square
/// at the bottom of it (monument_square.dart): its roundabout, the road
/// west to the Farmacia and the road east past the Elettronica to a
/// second pile-up, the road running on past it to the edge of the map.
///
/// Glyphs, on top of the outdoor legend in street.dart: `Æ` the call
/// centre's office block, a wall; `Ø` its glass doors, open, a door; `«`
/// the palazzo's portone, a door; and the square's own, in
/// monument_square.dart.
// industry-street-rows-start
const List<String> industryStreetRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBHHHHBBBBBBBBBBBBBBBBBBBBÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHfHHHHHHHHHÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆHHH',
  'BBBBBBBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHfHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆHHH',
  'BBBBBBBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHHHHHHH«HHHHHHHHHHHHHHHHHHHHHHÆÆÆÆÆÆÆÆØØØØÆÆÆÆÆÆÆÆÆÆÆHHH',
  'BBBBBBBBBBBBBBBBBBBBBBBBBT=/===T=F========================S=/===========================/=========UU=',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=....Z▏.......:........>.......UU...............r..d..............CC...XX..k',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.ɔ.-Z----------w-----d-----------w-------:--->----------:--------------CC-k',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=....Z....CC.............:...........d..............w.XX....>....w....XX....',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=VVVT=============nn========d=====:=========T=======================D===CC==',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|▔=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|:=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|./BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.v.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.v.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=>|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=d|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.z.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.d.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBB=.|.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBHHHHHHHH=.|.=HHHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBHHHHHHHH=.|.=HHHHfHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBHHHHHHHH=.|.=HHHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=======T=VVV=T=======BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=..CC........d......=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBHHHHHHHHHHHHHH=.-.-.-w-.-.-.-.-.-.=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'BBBHHHHHHHHHHHfHH=................CC.=HHHHHHHHHHHHHHHHHHHHfHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'BBBHHHHHHHHHHHHHH=...====:========...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'BBB===:=µ=======/=.|.=PAPPPPPPPAP=.|.=========h=============FCC======================================',
  'BBB=....UU.......Z...=PPPPΩΩΩPPP:=...Z......w..>...........UU..v.....................................',
  'BBB=.-.-.-w-.-.-.Z.|.=PPPPΩΩΩPPPP=.|.Z.-.-.-.-.-.-.-.-.-z-.-XX.v.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.',
  'BBB=.D.......d...Z...=PPPPΩΩΩPPPP=...Z...d..........CC........CC.....................................',
  'BBB===============v|.=PAPnnPnnPAP=.|.=/==========:===========UU======================================',
  'BBBBBBBBBBBBBBBBB=v..=============.w.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=...........>.......=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=.-.-d-.-.-.-.-.-.-.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB=...D.........XX....=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBB==========F==========BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// industry-street-rows-end

final Place _industryStreet = place(PlaceId.industryStreet);

/// The palazzo's portone, seen from the street.
final GridPoint industryStreetPortone = _industryStreet.tileOf('«');

/// The camp on the pavement between the palazzo and the company.
final GridPoint industryStreetCampfireTile = _industryStreet.tileOf('S');

/// The company's gate, rolled up, seen from the street, west to east.
final List<GridPoint> industryStreetGate = _industryStreet.tilesOf('Ø');
