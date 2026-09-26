// The ASCII map is one row per line, however wide the place is.

import 'package:stepbound/core/grid/grid_point.dart';

/// Roma Termini, where the train from Molfetta pulls in: the first place
/// of the Rome level. It is painted with the rules of Molfetta's far
/// platform (station.dart), so it keeps to its glyphs: `x` darkness, `W`
/// the back wall, `,` ballast, `-` the rails, `M` the train, `P` its
/// passenger door, `=` the platform, `T` a bench, `n` a canopy post,
/// `D` the stairs and `:` litter.
///
/// The train stands on the near track with its door open onto the first
/// platform; past a second pair of tracks runs the next platform, where
/// the dead of the station still wander (see [terminiZombieSpots]). The
/// stairs `D` in its far wall are the way out of the station: the rest of
/// Rome is still to be made, so they end the playable game for now.
// termini-rows-start
const List<String> terminiRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'x,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,x',
  'x--------------------------------------------------x',
  'x,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,x',
  'x,,,MMMMMMMMMMMMMMMMMMMMMMMMMMM,,,,,,,,,,,,,,,,,,,,x',
  'x---MMMMMMMMMMMMMMMMMMMMMMMMMMM--------------------x',
  'x,,,MMMMPMMMMMMMMMMMMMMMMMMMMMM,,,,,,,,,,,,,,,,,,,,x',
  'x==================================================x',
  'x==nn======T=========nn=====T=========nn======T====x',
  'x=:===========================:====================x',
  'x==================================================x',
  'x,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,x',
  'x--------------------------------------------------x',
  'x,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,x',
  'x==================================================x',
  'x=====T======nn=========T=====nn=========T====nn===x',
  'x==================================================x',
  'xWWWWWWWWWWWWWWWWWWWWWWWDDWWWWWWWWWWWWWWWWWWWWWWWWWx',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// termini-rows-end

/// The wanderers on the platforms, in the place's own tile coordinates:
/// the art has no glyph for them, so they stand on the platform's own.
const List<GridPoint> terminiZombieSpots = <GridPoint>[
  GridPoint(41, 17),
  GridPoint(46, 14),
];
