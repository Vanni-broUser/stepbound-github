// The ASCII map is one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// The harbour and the old town, south of the north district (same glyphs
/// as the street): the road from the square comes down between the old
/// town's palazzi to the seafront road, closed by a road block to the west;
/// beyond it the promenade with its palms, then the parapet and the murky
/// sea, scummed with green, where rowboats rot half-sunk. West of the road
/// the Duomo `W` faces the sea between the palazzi, its two bell towers
/// over the roofs.
///
/// To the east a narrow alley climbs north off the seafront road, then
/// turns east to the Bar Arcobaleno, whose door `h` leads inside. The road
/// carries on east as far as the bar, then turns south along the sea: the
/// promenade and its parapet turn the corner with it, and two wooden piers
/// `l` reach west over the water. A rowboat `o` is moored at the end of the
/// second one, a backpack `5` with four rounds on board.
// harbour-rows-start
const List<String> harbourRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBWWWWWWWWWWWWWWWBBBBB=:.|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPhPPPPPPPPPBBBBBBBBB',
  'BBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBPPPPP:PPPPPPPPPPPPwPPBBBBBBBBB',
  'BBBBBBBBBWWWWWWWWWWWWWWWBBBBB=.w|..=BBBBBBBBBBBBBBBBBBBBPPBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|d.=BBBBBBBBBBBBBBBBBBBBPdBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBHHHHHWWWWWWWWWWWWWWWHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHHHHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHHWWWWWWWWWWWWWWWHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHfHHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHHWWWWWWWWWWWWWWWHHHHH=..|..=HHHHHHHHHHHfHHHHHHHHPPHHHHHHHHHHHHHHHHHHHHHfHHBBBB',
  'BBBBHHHHHWWWWWWWWWWWWWWWHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHHHHHHfHHHHHHHHHHHHHHHBBBB',
  'BBBB==========F===============VVVVVT===============F==============================BBBB',
  'BBBBJ.............CC.........Z.....Z........:....................................=BBBB',
  'BBBBJ.......w...........:....Z.....Z.............................................=BBBB',
  'BBBBJ-.-.-.-.-.-.-.-.-.-.-.-.Z.-.-.Z.-d-.-.-.-.-.-.-z-.-.-.-.-.-.-.-.-.-.-.-..c..=BBBB',
  'BBBBJ...UU...................Z.....Z.........w...................................=BBBB',
  'BBBBJ...........d............Z.....Z....XX....................................|..=BBBB',
  'BBBB=======================F=====:==================================F=======..|..=BBBB',
  'BBBBPPPPNPPPPPPPPPNPPPwPPPP:PPPPPPPPPPNPPPPPPPPPNPPPPPPPPPPPPPPPPPNPPPPPPPP=..|..=BBBB',
  'BBBBPPPPPPPPnnPPPPPPPPPPPPPPPPPDPPPPPwPPPPnnPPPPPPPPdPPPPPPPPPPPPPPPnnPPPPP=..|..=BBBB',
  'RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|.:=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|v.=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|v.=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=.w|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=UU|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ooooo~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~o5ooo~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|w.=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBJJJJJJJBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBB',
];
// harbour-rows-end
