// The ASCII maps are one row per line, however wide the place is.
// ignore_for_file: lines_longer_than_80_chars

/// Rome's streets round Termini, with the glyphs of Molfetta's (see
/// street.dart), but not its buildings: here the palazzi `H` are Roman,
/// ochre and red under their tiled roofs `B`. On top of those glyphs: `]`
/// the front of Termini, a wall, and `{` its doorways, and `}` a breach
/// in the wall `%` round the tracks, both floor; `"` Santa Maria
/// Maggiore, a wall, and `>` the column in front of it, seen over; `§`
/// the Baths of Diocletian, a wall, `¶` the portal in them, and `¤` the
/// brown sign with their name, seen over. Where a
/// street runs off the edge of the map, the game goes no further for now.
library;

/// Piazza dei Cinquecento, out of the concourse: the long front of
/// Termini `]` across the top, its three doorways `{` open, palazzi either
/// side of it, a souvenir shop in the western ones; the paving `P` in
/// front of it with its bus shelters `n` and its trees `A`, and a
/// campfire `S` right in front of the middle doorway, then the four lanes
/// of the road, which runs off the map east. West it runs on past more
/// palazzi, their little shops shut, up to the Baths of Diocletian `§`:
/// their brick front along the north side, a wing of them across the end
/// of the road. Across it Via
/// Cavour goes south between the blocks, straight, cars left parked along
/// both kerbs, a sheet strung across it with the end of the world painted
/// on it, down to Piazza di Santa Maria Maggiore: the basilica `"` on the
/// north side of the square, right against the street so its bell tower
/// is seen all the way down, half fallen, its rubble spilt over the
/// pavement (`"` too), the Column of Peace `>` in front of it and a
/// placard `` ` `` stuck up on the square; palazzi either side of it, and
/// across the street a bar and a trattoria, their tables `Q` and chairs
/// `q` still out on the square, and an accountants' office, all shut up,
/// a palazzo with no shop between each of them and the next. The
/// square runs off the map east.
// piazza-cinquecento-rows-start
const List<String> piazzaCinquecentoRows = <String>[
  '§§§§§§§§§§§§§§§§§§§BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]BBBBBBBBBBBBBBBB',
  '§§§§§§§§§§§§§§§§§§§HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHH',
  '§§§§§§§§§§§§§§§§§§§HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHH',
  '§§§§§§§§§§§§§§§§§§§HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHH',
  '§§§§§§§§§¶§§§§§§§§§HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH]]]]{{]]]]]]]]]]]]]{{]]]]]]]]]]]]]{{]]]]HHHHHHHHHHHHHHHH',
  '§§§§============¤====================================================================================================',
  '§§§§PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP',
  '§§§§PPPPPPPPPPPPPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPnnPPPPPPPPPPPSPPPP:PPPnnPPPPPPPPPPPPPPPPnnPPPPPPPP',
  '§§§§PPPPPPPPPPPPPP:PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP:PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP',
  '§§§§PPPPAPPPPPPPAPPPPPPPAPPPPPPPAPPPPPPPAPPPPPPAPPPPPPPPPPPAPPPPPPPPPPPPPPPAPPPPPPPPPAPPPPPPPPPPPPPAPPPPPPPPPPPPPAPPP',
  '§§§§=================================================================================================================',
  '§§§§..............................CC........................................................UU.......................',
  '§§§§.....d............XX.............................CC.................:....................................d.......',
  '§§§§-----------------------------------------------------------------------------------------------------------------',
  '§§§§..........UU........................:......................d......XX...............................CC............',
  '§§§§........................d....................................................................:...................',
  '§§§§========================================================================VVVVVV===================================',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|.d.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...FBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.:|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..k=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..k=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB""""""""""""""""""""""":..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=v.|.:.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""/..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"""""""""""""""""""""""=..|D.v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBHHHHHHH"""""""""""""""""""""""=..|...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBHHHHHHH"""""""""""""""""""""""=..|:..=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBHHHHHHH"""""""""""""""""""""""=..|...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBHHHHHHH"""""""""""""""""""""""=..|...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=====================""""""=============================================',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPPPPPPP:PP"""PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPP:PPPPPPPPPPPPP:PPPPPPPPPPPPPqQqqQPPPPqQqqQqqQqPPPPPPPPPPPPPP',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPPPP```PPPPPPPPPPPPPPPPPPPPP:PPPPPPPPPPPPPPPPqPPPPPPPPPPPPqPPPPPPPPPPPPP',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPPPPPP>PPPPPPPPPPPPdPPPPPPPPqQqPqPPPPPPQqPPQqPPPPPPPPPPPPPPP',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP:PPPPPXXPPPPPPPPPPPPPPPPPPPPPPPPPP',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPPPPPPPP:PPPPPPPPPPPPPPPPPPPDPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPdPPPPPPPP',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPPPPPPPP:PPPPPPPPPPPPPPPPPPPPPPPPPPPPP:PPPPPPPPPPPUUPPPPPPPP',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB========================================================================',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// piazza-cinquecento-rows-end

/// Via Marsala, the street behind the station, reached through the breach
/// `}` in the wall `%` round the tracks: the fronts of its palazzi across
/// the road, which runs off the map east and west.
// via-marsala-rows-start
const List<String> viaMarsalaRows = <String>[
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  '=================================:==========================',
  '....................:...................XX..................',
  '------------------------------------------------------------',
  '............CC..............................................',
  '.............................................:....UU........',
  '========:=================F=================================',
  '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%}}%%%%%%%%%%%%%%%%%%%%%%%%%%%%',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
];
// via-marsala-rows-end
