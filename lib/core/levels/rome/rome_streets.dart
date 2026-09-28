// The ASCII maps are one row per line, however wide the place is.

/// Rome's streets round Termini, with the glyphs of Molfetta's (see
/// street.dart), but not its buildings: here the palazzi `H` are Roman,
/// ochre and red under their tiled roofs `B`. On top of those glyphs: `]`
/// the front of Termini, a wall, and `{` its doorways, and `}` a breach
/// in the wall `%` round the tracks, both floor. Where a street runs off
/// the edge of the map, the game goes no further for now.
library;

/// Piazza dei Cinquecento, out of the concourse: the long front of
/// Termini `]` across the top, its three doorways `{` open, palazzi either
/// side of it; the paving `P` in front of it with its bus shelters `n`
/// and its trees `A`, then the four lanes of the road. Across the road a
/// street runs off south between the blocks. The road runs off the map
/// east and west.
// piazza-cinquecento-rows-start
const List<String> piazzaCinquecentoRows = <String>[
  'BBBBBBBBBBBBBBBB]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]BBBBBBBBBBBBBBBB',
  'HHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHH]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]HHHHHHHHHHHHHHHH',
  'HHHHHHHHHHHHHHHH]]]]{{]]]]]]]]]]]]]{{]]]]]]]]]]]]]{{]]]]HHHHHHHHHHHHHHHH',
  '========================================================================',
  'PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP',
  'PPPPPPnnPPPPPPPPPPPPPPnnPPPPPPPPPPPPPPPP:PPPnnPPPPPPPPPPPPPPPPnnPPPPPPPP',
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
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|v..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|v..=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=.:|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=..|...=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
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
