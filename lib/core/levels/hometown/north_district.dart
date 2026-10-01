import 'package:stepbound/core/grid/grid_point.dart';
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
/// [caparezzaZombieId]).
///
/// Off the map, ` `, are the cells the camera never shows: wherever Mario
/// stands, on any screen, the view (clamped to the place's rectangle)
/// does not reach them, so cutting them away changes nothing on screen.
/// test/levels/north_district_test.dart holds the map to it.
// north-rows-start
const List<String> northDistrictRows = <String>[
  '                                                              BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB                         ',
  '                                                   ..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB             ',
  '                                                   CC|..=BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=..|..=BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=..|..=BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=..|UU=BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=..|..=BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=.:|.d=BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=..|..=BBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMBBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=..|..=BBBBBBBBBMMMMMMMMMMMmmmMMMMMMMMMMMMBBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBBkUU?XXvBBBBBBBBB==========================BBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBBkCC?CCvBBBBBBBBB=LLLLLLLLL:LLLLLyLLLLLLLL=BBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=..|..=BBBBBBBBB=LCCLLLLLLLLLLLLLLLLLLLyL=BBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=d.|>.=BBBBBBBBB=LLLLLLLLLLLzLLLLLLLLLLLL=BBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=.UU.:=BBBBBBBBB=LLLLLyLLLLLLLLLLLLXXLLLv=BBBBBBBBBBBBBBB             ',
  '                                   BBBBBBBBBBBBBBB=.>|D.=BBBBBBBBB4LLLLLLLLLLLLLLLLLLLLLLLv=BBBBBBBBBBBBBBB             ',
  '  GGGGGGGGGGGGGGGG                 BBBBBBBBBBBBBBB=:.|>d=BBBBBBBBB==========================BBBBBBBBBBBBBBB             ',
  '  GGGGGGGGGGGGGGGG                 BBBBBBBBBBBBBBB=.wUU.=BBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBB             ',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBB      BBBBBBBBBBBBBBB=d.|.>=BBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBB             ',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBB  BBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBB             ',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBB  BBBBBBBBBBBBBBB=>:|XX=HHHHHHHHHHHHHHHHHH=..|..=BBBBBBBBBBBBBBBBBBBBBBBBB             ',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBB  BBBBBBBBBBBBBBB=..|..=HHHHHfHHHHHHHHHHHH=..|..=BBBBBBBBBBBBBBBBBBBBBBBBB             ',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBB  BBBBBBBBBBBBBBBTVVVVVTHHHHHHHHHHHHHHHHHH=..|..=BBBBBBBBBBBBBBBBBBBBBBBBB             ',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBB  BBBBBBBBBBBBBBB=..CC.====================..|..=BBBBBBBBBBBBBBBBBBBBBBBBB             ',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBB  BBBBBBBBBBBBBBB=.>UU..Z>.d..UU.........Z...|.v=BBBBBBBBBBBBBBBBBBBBBBBBB             ',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBB  BBBBBBBBBBBBBBB=d...D.Z-D-w-:-.-.-.-.-.Z...|.v=BBBBBBBBBBBBBBBBBBBBBBBBB             ',
  'BBGGGGGGGGGGGGGGGGBBBBBBBBBBBBBBB  BBBBBBBBBBBBBBB=.UU>..ZCC.>..d.........Z...|..=BBBBBBBBBBBBBBBBBBBBBB                ',
  r'BBGGGGGGG$$GGGGGGGBBBBBBBBBBBBBBB  BBBBBBBBBBBBBBB=.:.d.=T==================.:|..=BBBBBBBBBBBBBBBBBBBBBB                ',
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
  '                                                     BBBBBBBBBBBBBBBBBBBBBB=..|:.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  '                                                     BBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBB                ',
  '                                                     BBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBB                ',
  '                                                     BBBBBBBBBBBBBBBBBBBBBB=k.|..=BBBBBBBBBBBBBBBBBBBBBB                ',
  '                                                     BBBBBBBBBBBBBBBBBBBBBB=k.|..=BBBBBBBBBBBBBBBBBBBBBB                ',
  '                                                            BBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBB                       ',
  '                                                            BBBBBBBBBBBBBBB=..d..=BBBBBBBBBBBBBBB                       ',
  '                                                            BBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBB                       ',
  '                                                            BBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBB                       ',
  '                                                            BBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBB                       ',
  '                                                            BBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBB                       ',
  '                                                            BBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBB                       ',
  '                                                            BBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBB                       ',
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
