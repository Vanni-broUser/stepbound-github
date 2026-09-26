// The ASCII map is one row per line, however wide the place is.

import 'package:stepbound/core/grid/grid_point.dart';

/// Roma Termini, where the train from Molfetta pulls in: the first place
/// of the Rome level. It is painted with the rules of Molfetta's far
/// platform (station.dart) and laid out like it: the train fills the whole
/// track from one edge of the map to the other, so the only way on is the
/// platform, and there is no walking round either end of it. Glyphs: `x`
/// darkness, `W` the walls, `M` the train, `P` its passenger door, `=` the
/// platform, `T` a bench, `n` a canopy post, `:` litter, `|` the side
/// walls of the platform.
///
/// Rome's name is up twice, on the blue boards of every Italian station:
/// `Q`, ROMA TERMINI high on the back wall above the train, and `o`, ROMA
/// on its posts at the edge of the platform, a few steps from the door.
/// Unlike Molfetta's, the stairs `D` in the front wall go up, to the
/// concourse: the rest of Rome is still to be made, so they end the
/// playable game for now. The dead of the station wander the platform (see
/// [terminiZombieSpots]).
// termini-rows-start
const List<String> terminiRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'xWWWWWWWWWWWWWWWWQQQQQQQQQQWWWWWWWWWWWWWWWWx',
  'xWWWWWWWWWWWWWWWWQQQQQQQQQQWWWWWWWWWWWWWWWWx',
  'xMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMx',
  'xMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMx',
  'xMMMMPMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMx',
  '|=========ooo==============================|',
  '|==nn======T=========nn=====T=========nn===|',
  '|=:===========================:============|',
  '|========T=======nn=============T==========|',
  '|====:=====================:===============|',
  '|WWWWWWWWWWWWWWWWWWWDDWWWWWWWWWWWWWWWWWWWWW|',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// termini-rows-end

/// The wanderers on the platforms, in the place's own tile coordinates:
/// the art has no glyph for them, so they stand on the platform's own.
const List<GridPoint> terminiZombieSpots = <GridPoint>[
  GridPoint(33, 8),
  GridPoint(38, 10),
];
