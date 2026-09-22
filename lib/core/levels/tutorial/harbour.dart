// The ASCII map is one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// The harbour and the old town, south of the north district (same glyphs
/// as the street): the road from the square comes down between the old
/// town's palazzi to the seafront road, which runs a long way west before
/// a road block shuts it; beyond it the promenade with its palms, then the
/// parapet and the murky sea, scummed with green, where rowboats rot
/// half-sunk.
///
/// The Duomo `W` stands well back from the seafront road, hidden behind a
/// row of palazzi: an alley two cells deep climbs off the sidewalk and
/// opens, past the churchyard gate `x`, into the T of the sagrato `P`, wide
/// enough for the whole front of the church and its two bell towers. Don
/// Angelo `s` waits behind the gate, two zombies `t` outside it.
///
/// To the east a narrow alley climbs north off the seafront road, then
/// turns east to the Bar Arcobaleno, whose door `h` leads inside. The road
/// carries on east as far as the bar, then turns south along the sea: the
/// promenade and its parapet turn the corner with it, and two wooden piers
/// `l` reach west over the water. A rowboat `o` is moored at the end of the
/// second one, a backpack `5` with four rounds on board.
// harbour-rows-start
const List<String> harbourRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=:.|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBHHHHHHHHHHHHHHHHHHHHHBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|.v=BBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPhPPPPPPPPPBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWWWBBBBB=..|..=BBBBBBBBBBBBBBBBBBBBPPPPP:PPPPPPPPPPPPwPPBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPPPBBBBB=.w|..=BBBBBBBBBBBBBBBBBBBBPPBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBPPAPPPPPPPPPAPPBBBBB=..|d.=BBBBBBBBBBBBBBBBBBBBPdBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBHHHHHHHHHHHHHHHPPPPPPPsPPPPPPPHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHHHHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHHHHHHHHHHHHHHHHHHxxxHHHHHHHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHfHHHHHHHHHHHHHHHHHHHHBBBB',
  'BBBBHHHHHHHHHHHHHHHHHHHHHtPtHHHHHHHHHHH=..|..=HHHHHHHHHHHfHHHHHHHHPPHHHHHHHHHHHHHHHHHHHHHfHHBBBB',
  'BBBBHHHHHHHHHHHHHHHHHHHHHPPPHHHHHHHHHHH=..|..=HHHHHHHHHHHHHHHHHHHHPPHHHHHHHHfHHHHHHHHHHHHHHHBBBB',
  'BBBB====================F===============VVVVVT===============F==============================BBBB',
  'BBBBJ.......................CC.........Z.....Z........:....................................=BBBB',
  'BBBBJ.......w.....................:....Z.....Z.............................................=BBBB',
  'BBBBJ-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.Z.-.-.Z.-d-.-.-.-.-.-.-z-.-.-.-.-.-.-.-.-.-.-.-..c..=BBBB',
  'BBBBJ.............UU...................Z.....Z.........w...................................=BBBB',
  'BBBBJ.....................d............Z.....Z....XX....................................|..=BBBB',
  'BBBB=================================F=====:==================================F=======..|..=BBBB',
  'BBBBPPPPPPPPPPPPPPNPPPPPPPPPNPPPwPPPP:PPPPPPPPPPNPPPPPPPPPNPPPPPPPPPPPPPPPPPNPPPPPPPP=..|..=BBBB',
  'BBBBPPPPPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPPPPDPPPPPwPPPPnnPPPPPPPPdPPPPPPPPPPPPPPPnnPPPPP=..|..=BBBB',
  'RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|.:=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|v.=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|v.=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=.w|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=UU|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~llllllllllllllllllPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ooooo~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~o5ooo~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|w.=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RNP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~bb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~RPP=..|..=BBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBJJJJJJJBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBB',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBBBBBBBBBBBB',
];
// harbour-rows-end
