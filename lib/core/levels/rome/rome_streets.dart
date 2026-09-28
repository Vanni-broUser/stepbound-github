// The ASCII maps are one row per line, however wide the place is.

/// Rome's streets round Termini, with the glyphs of Molfetta's (see
/// street.dart), but not its buildings: here the palazzi `H` are Roman,
/// ochre and red under their tiled roofs `B`. On top of those glyphs: `]`
/// the front of Termini, a wall, and `{` its doorways, and `}` a breach
/// in the wall `%` round the tracks, both floor; `"` Santa Maria
/// Maggiore, a wall, and `>` the column in front of it, seen over. Where a
/// street runs off the edge of the map, the game goes no further for now.
library;

/// Piazza dei Cinquecento, out of the concourse: the long front of
/// Termini `]` across the top, its three doorways `{` open, palazzi either
/// side of it, a souvenir shop in the western ones; the paving `P` in
/// front of it with its bus shelters `n` and its trees `A`, and a
/// campfire `S` right in front of the middle doorway, then the four lanes
/// of the road, which runs off the map east and west. Across it Via
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
/// square runs off the map east and west.
// piazza-cinquecento-rows-start
const List<String> piazzaCinquecentoRows = <String>[
  'BBBBBBBBBBBBBBBB]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]BBBBBBBBBBBBBBBB',
  'HHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHH]]]]{{]]]]]]]]]]]]]{{]]]]]]]]]]]]]{{]]]]HHHHHHHHHHHHHHHH',
  '========================================================================',
  'PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP',
  'PPPPPPnnPPPPPPPPPPPPPPnnPPPPPPPPPPPSPPPP:PPPnnPPPPPPPPPPPPPPPPnnPPPPPPPP',
  'PPPPPPPPPPPP:PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP',
  'PPAPPPPPPPPPPPAPPPPPPPPPPPPPPPAPPPPPPPPPAPPPPPPPPPPPPPAPPPPPPPPPPPPPAPPP',
  '========================================================================',
  '...............................................UU.......................',
  '........CC.................:....................................d.......',
  '------------------------------------------------------------------------',
  '..................d......XX...............................CC............',
  '....................................................:...................',
  '===============================ZZZZZZ===================================',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|.d.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...FBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.:|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..k=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|..k=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBB""""""""""""""""""""""":..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBB"""""""""""""""""""""""=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBB"""""""""""""""""""""""=v.|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBB"""""""""""""""""""""""=v.|.:.=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBB"""""""""""""""""""""""/..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBB"""""""""""""""""""""""=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBB"""""""""""""""""""""""=..|..v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBB"""""""""""""""""""""""=..|D.v=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'HHHHHHH"""""""""""""""""""""""=..|...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'HHHHHHH"""""""""""""""""""""""=..|:..=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'HHHHHHH"""""""""""""""""""""""=..|...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  'HHHHHHH"""""""""""""""""""""""=..|...=HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH',
  '=====================""""""=============================================',
  'PPPPPPPPPPPPPPPPPPP:PP"""PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP',
  'PPPPPPPPPPPP:PPPPPPPPPPPPP:PPPPPPPPPPPPPqQqqQPPPPqQqqQqqQqPPPPPPPPPPPPPP',
  'PPPP```PPPPPPPPPPPPPPPPPPPPP:PPPPPPPPPPPPPPPPqPPPPPPPPPPPPqPPPPPPPPPPPPP',
  'PPPPPPPPPPPPPPPPPP>PPPPPPPPPPPPdPPPPPPPPqQqPqPPPPPPQqPPQqPPPPPPPPPPPPPPP',
  'PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP:PPPPPXXPPPPPPPPPPPPPPPPPPPPPPPPPP',
  'PPPPPPPP:PPPPPPPPPPPPPPPPPPPDPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPdPPPPPPPP',
  'PPPPPPPPPPPPPPPPPPPP:PPPPPPPPPPPPPPPPPPPPPPPPPPPPP:PPPPPPPPPPPUUPPPPPPPP',
  'PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP',
  '========================================================================',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
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
