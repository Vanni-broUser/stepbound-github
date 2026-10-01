import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

// The ASCII map is one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// The north district, behind the barracks (same glyphs as the street): the
/// street out of the barracks' back passage is closed to the east, where a
/// camp burns; to the west it opens on a square with a fountain and a
/// wrecked bar, from which roads lead south to the harbour, north to a
/// hypermarket (a sprinter prowls the middle of its car park) and west to
/// the hospital. Up the road north, before the car park, a branch turns
/// west to a crossroads: north, a pile-up of cars closes the road, the one
/// lane with no car in it burning with the fuel they spilt (looking at it
/// says what it would take, see [northDistrictFireTile]); south, a side
/// road comes back down onto the road west of the square. Round that
/// crossroads lie the worst of the crashes: overturned cars, wrecks nosed
/// into one another, the dead and their blood. Past the side road, the road
/// west runs on between shops -- among them a pizzeria and a kebab shop --
/// to the hospital, whose road, forecourt and stairs are packed with hordes
/// of wanderers, carabinieri among them, far too many to fight through. At
/// the top of the stairs `$` are the hospital's PRONTO SOCCORSO doors
/// (hospital.dart).
/// By the camp, the Elettronica: the same shop as the one on the road east
/// of the monument's square, its shutter down over the door `¦` (an
/// obstacle) until Mario opens it from inside (electronics_shop.dart).
/// By the fountain, `♪` is the Caparezza wanderer (see
/// [caparezzaZombieId]). Up the side road, a few steps short of the
/// burning pile-up, a second camp ([northDistrictBlazeCampTile]).
///
/// Off the map, ` `: above the road north two rows past the pile-up, and
/// above the hospital's front and the palazzi west of the side road; the
/// hypermarket's block keeps its height. The camera stops at those edges
/// as at the edge of the map ([northDistrictCameraZones]).
// north-rows-start
const List<String> northDistrictRows = <String>[
  '                                                         BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                                         BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                                         BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                                         BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                                         BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                                         BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                                         BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                                         BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                    BBBBBBBBBBBBBB=..|..=BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                    BBBBBBBBBBBBBB=..|..=BBBBBBBBBMMMMMMMMMMMmmmMMMMMMMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                    BBBBBBBBBBBBBBkXX?XXvBBBBBBBBB==========================BBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                    BBBBBBBBBBBBBBkCC?CCvBBBBBBBBB=LLLLLLLLL:LLLLLyLLLLLLLL=BBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                    BBBBBBBBBBBBBB=.d|..=BBBBBBBBB=LCCLLLLLLLLLLLLLLLLLLLyL=BBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                    BBBBBBBBBBBBBB=..|>.=BBBBBBBBB=LLLLLLLLLLLzLLLLLLLLLLLL=BBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                    BBBBBBBBBBBBBB=SUU.:=BBBBBBBBB=LLLLLyLLLLLLLLLLLLXXLLLv=BBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                    BBBBBBBBBBBBBB=.>|D.=BBBBBBBBB4LLLLLLLLLLLLLLLLLLLLLLLv=BBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=:.|>d=BBBBBBBBB==========================BBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..UU.=BBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=d.|.>=BBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=>:|XX=HHHHHHHHHHHHHHHHHH=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.w|..=HHHHHfHHHHHHHHHHHH=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBTVVVVVTHHHHHHHHHHHHHHHHHH=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..CC.====================..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.>UU..Z>.d..UU.........Z...|.v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=d...D.Z-D-w-:-.-.-.-.-.Z...|.v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.UU>..ZCC.>..d.........Z...|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  r'BBGGGGGGG$$GGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.:.d.=T==================.:|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBYYYYYYwYwYYYrYYYBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBTVVVVV=BBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBYYwYYYYwYYYwYYYYBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.UU..=BBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBYYYYwYYYYwYYYrYYBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.>|..=BBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBYYYYYwYwYYwYYYYYBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.w|CC=BBBBBBBBBBBHHHHHHH=..|..=HHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBPwPPyPPPPPPPPPwPBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=d.|..=BBBBBBBBBBBHHHHHfH=..|..=HHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBPPPPPPJJJJPPP:PPBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|>:=BBBBBBBBBBBHHHHHHH=..|..=HHHHHHHBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBPaaPPPPPrPPPPPwPHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH=.>|..=HHHfHHHHHHH========PPPPP========HHHHHHHHHHHHHHHHHHHHHHHHHHHHBBB',
  'BBPPPPwPwPPPPaaPPPHHHHHHHHHfHHHHHHHHHHHHHHHHHHHHHH=..|.d=HHHHHHHHHHH=Qq:PqPPPPPPPPPPPPPF=HHfHHHHHHHHHHHHHHHHHHHHHHHHHBBB',
  'BBPPwDPPPwPPrPPwPPHHHHHHHHHHHHHHHHHHHHHHHfHHHHHHHH=..|..=HHHHHHHfHHH=qPPQP:PPPPPPPnnPPAP=HHHHHHHfHHHHHHHHHHHHHHHHHHHHBBB',
  'BBPPPPPwPPPwPwPPPP=============w=r==w==============VVVVV=============PPq:qPPPPPPPPPPPPPP===F====================¦====BBB',
  'BB.............................w.w....:.....d........................PQqPPPPOOOOOPPP:PPPP.....CC...............:...UUBBB',
  'BB-.-.-.-.-.-.-.-.-.-.-.-.-.-.w.:.w.-r-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-qPPdPPwOOOOOPPPPPPPP.-.-.-.-:-.-.-.-.-.-.-.-.S.-BBB',
  'BB..............................w..w........................XX.......PPdPPPPOOOOOPPPPPPPP..........CC.d..............BBB',
  'BB===========================w====w==================================PPPPPPPOOOOO♪PPPPPP=====================F=======BBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=PPPPPPPOOOOOPPPPPPP=BBBBBBBBBBBBBBBBeBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=PPPPPPPPPPPPPPDPPPP=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=PAPnnPPPPPPPPPPPPAP=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=PPPPPPPPPPPPPPPPPPP=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB========PPPPP========BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|:.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=k.|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=k.|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..d..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// north-rows-end

final Place _north = place(PlaceId.northDistrict);

/// A tribute to Caparezza, Molfetta's own: the wanderer `♪` east of the
/// fountain wears his great mop of dark curls, a black T-shirt and black
/// trousers. Only the look is his: he walks and bites like any wanderer,
/// has no portrait and is not among the known zombies.
const String caparezzaZombieId = 'caparezza';

/// The back door of the barracks, `e`, seen from the north district.
final GridPoint northDistrictBackExitTile = _north.tileOf('e');

/// The bin `F` nearest that door: the one fire of the district that is
/// out, so the way out of the barracks is not into flames.
final GridPoint extinguishedNorthDistrictBinTile = _north
    .tilesOf('F')
    .reduce(
      (nearest, candidate) =>
          candidate.manhattanDistanceTo(northDistrictBackExitTile) <
              nearest.manhattanDistanceTo(northDistrictBackExitTile)
          ? candidate
          : nearest,
    );

/// The fuel burning across the one free lane of the pile-up that closes
/// the side road north of the crossroads: its south end, the cell Mario
/// faces coming up the road. Looking at it says what it would take.
final GridPoint northDistrictFireTile = _north
    .tilesOf('?')
    .reduce((a, b) => a.y > b.y ? a : b);

/// Where the camera stops short of the north district's edges, so it never
/// shows what is off the map: up the side road north of the crossroads,
/// two rows past the pile-up; in the hypermarket's car park, at the
/// palazzi west of it. Each zone begins where its edge is still out of
/// view, so the camera slides to it unseen. Over the hospital nothing is
/// needed: from the road and the forecourt the view never reaches that
/// high. test/camera_zones_test.dart holds them to it.
const List<CameraZone> northDistrictCameraZones = <CameraZone>[
  CameraZone(area: GridRect(50, 0, 56, 21), limits: GridRect(0, 8, 119, 63)),
  CameraZone(area: GridRect(57, 0, 119, 16), limits: GridRect(57, 0, 119, 63)),
];

/// The second camp of the north district, `S` on the side road north of
/// the crossroads, a few steps short of the burning pile-up: sheltered
/// behind the overturned car, by the pavement. Its own name in the save
/// slots (the other is the camp behind the barracks).
final GridPoint northDistrictBlazeCampTile = _north
    .tilesOf('S')
    .reduce((a, b) => a.y < b.y ? a : b);
