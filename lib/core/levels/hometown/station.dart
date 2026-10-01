import 'dart:math' as math;

import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';

// The ASCII maps are one row per line, however wide the place is.

/// The three places of the station at the top of the block behind the
/// hypermarket (see mall_north_street.dart, where its front stands with
/// its two open doorways). They are drawn as rooms on a dark background
/// like the barracks, but only the underpass is really indoors: over the
/// platforms the roof is gone, so they are lit throughout.
///
/// The two doorways lead to two different corners of the building, and
/// what lies between them leaves no way from one to the other: a hijacked
/// train that came in too fast. Its coach `m` is still standing on the far
/// track, but the car behind it `V` broke away at the coupling, turned over
/// and ploughed on wheels up across the platform and through the back wall
/// of the booking hall, down to its front wall, a heap of rubble `#` along
/// its flanks.
///
/// Only the hall and the platform are rooms, walled on both sides `|`: the
/// tracks run on past them, off both edges of the map, and the cars on
/// them with it, so it is only the wrecks that keep Mario from following.
///
/// West doorway `E`: the booking hall, then the platform through the gap
/// in its back wall. Along the near track, west of the overturned car,
/// the rest of the train shuts the platform off from the tracks: a car `C`
/// still upright, and past a gap the car that came off before it, `H`,
/// over on its side and burning, running on off the west edge. The gap
/// between them, at the west end of the platform, is on fire `?`: the
/// only way onto the tracks, and looking at it says what it would take
/// (see `stationTrackFireTile`). The backpack `9`, two rounds in it, is at
/// the other end of the platform, against the rubble.
///
/// East doorway `O`: the other end of the hall, cut off from the rest by
/// the overturned car. A gap in the back wall reaches the platform, where
/// only a little rubble remains and a railcar `M` stands derailed across
/// the near track beyond it. The stairs `U` down to the underpass are sunk
/// in the floor a few cells in from the front wall, where they show: a
/// flight two cells wide and two deep, got onto only from the north, its
/// last step the way down; the floor goes on below it, shut off from it by
/// the end of the well. The tactile path `p` runs up from the doorway and
/// along to the head of the flight.
///
/// Common glyphs: `x` darkness, `W` back wall, `w` front wall, `|` the side
/// walls, `m` the coach and `C` the car still upright, `V` and `H` the
/// overturned cars, `M` the railcar and `#` the rubble are walls; `T` a
/// bench, `K` a ticket window, `n` a canopy post are obstacles you can see
/// over; `?` burns and cannot be walked through; `.` the hall floor, `=`
/// the platform, `,` ballast, `-` the rails, `:` litter (noisy), `b`
/// blood, `p` the tactile path, `*` a working lamp, `+` a flickering one,
/// `Z` a wanderer. Two wanderers roam the underpass too. `_` is ballast
/// out of reach, a wall: beside the station's rooms under the tracks that
/// run on off the map, and past both ends of the train on the far
/// platform, whose walls go on above it and round the foot of its stairs.
// station-rows-start
const List<String> stationRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  ',,,,,,,,,,,,,,,,,,,,,,,,mmmmmmmmmmmmmmmmmmm',
  '------------------------mmmmmmmmmmmmmmmmmmm',
  ',,,,,,,,,,,,,,,,,,,,,,,,mmmmmmmmmmmmmmmmmmm',
  'HHHH??CCCCCCCCCCCCCCCCC#VVVMMMMMMMMMMMMMMMM',
  'HHHH??CCCCCCCCCCCCCCCCC#VVVMMMMMMMMMMMMMMMM',
  'HHHH??CCCCCCCCCCCCCCCCC#VVVMMMMMMMMMMMMMMMM',
  '___|==================:#VVV##==========|___',
  '___|==nn=====T=====nn=9#VVV#===========|___',
  '___|=================:=#VVV============|___',
  '___|WWWWWWWW....WWWWWWWWVVVWWWW....WWWW|___',
  '___|.Z.:......Z......:..VVV............|___',
  '___|..T....K.........:..VVV..:.ppppp...|___',
  '___|.....b......:......#VVV#b..p...UU..|___',
  '___|..:.............:.##VVV##..p...UU..|___',
  '___|........:.........##VVV##T.p.....:.|___',
  '___|wwwwwwwwEEwwwwwwwwwwwwwwwwwOOwwwwww|___',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// station-rows-end

/// The underpass under the tracks: a tiled corridor two cells deep, dark
/// but for the few lamps still burning, the stairs `D` back up into the
/// booking hall at one end and the stairs `U` up to the far platform at
/// the other.
// underpass-rows-start
const List<String> stationUnderpassRows = <String>[
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  '|WWWWWWWWWWWWWWWWWWWWWWWWWWWW|',
  '|WDDWWWWWWWWWWWWWWWWWWWWWWUUW|',
  '|...:......*..Z....:...Z..:..|',
  '|.b........:...+..........b..|',
  '|..:...*.........:.....*.....|',
  '|wwwwwwwwwwwwwwwwwwwwwwwwwwww|',
  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
];
// underpass-rows-end

/// The far side of the station, up the second flight `D`, two steps deep
/// through the wall south of the platform: one long
/// platform under what is left of its canopy and a railcar `M` that is
/// filthy but whole, filling the strip between the wall and the platform.
/// `P` is its passenger door: still part of the wall until Luigi has
/// been rescued, then the game opens it onto the train interior. Only the
/// platform is walled at the sides `|`; the tracks run on past it. The
/// repeated `l` and `r` cells carry the two damaged Molfetta station signs.
// far-platform-rows-start
const List<String> stationFarSideRows = <String>[
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  'WWWWllllllllWWWWWWWWWWWWrrrrrrrrWWWW',
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  '_MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM_',
  '_MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM_',
  '_MMMMMPMMMMMMMMMMMMMMMMMMMMMMMMMMMM_',
  '|==================================|',
  '|==nn======T=========nn=====T======|',
  '|=:=========================:======|',
  '|==================================|',
  '|WWWWWWWWWWWWWWWWDDWWWWWWWWWWWWWWWW|',
  'WWWWWWWWWWWWWWWWWDDWWWWWWWWWWWWWWWWW',
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
];
// far-platform-rows-end

/// The three places of the station: the side walls `|`, the hijacked
/// train's cars `m` and `C` and its overturned ones `V` and `H`, the
/// railcar `M` and the rubble `#` shut the way like walls, the benches
/// `T`, the ticket windows `K` and the canopy posts `n` can be seen over,
/// the far-platform signs `l` and `r` hang against the wall, and the gap by
/// the burning car `?` is on fire.
const Legend stationLegend = Legend(
  walls: 'xWwMmCVHP#|lr_',
  obstacles: 'TKn',
  fire: '?',
);

final Place _station = place(PlaceId.station);
final Place _underpass = place(PlaceId.stationUnderpass);
final Place _farSide = place(PlaceId.stationFarSide);
final Place _mallNorthStreet = place(PlaceId.mallNorthStreet);

/// The backpack `9` in the ballast between the two wrecks, at the dead end
/// of the station's tracks: two rounds.
const String stationBackpackId = 'backpack-station';
const int stationBackpackAmmo = 2;
final GridPoint stationBackpackTile = _station.tileOf('9');

/// The wanderers `Z` standing in the dark of the booking hall.
final List<GridPoint> stationHallZombieTiles = _station.tilesOf('Z');

/// The two wanderers roaming the station's underground corridor.
const String stationUnderpassZombiePrefix = 'station-underpass-wanderer-';
final List<GridPoint> stationUnderpassZombieTiles = _underpass.tilesOf('Z');

/// The station's two doorways on the forecourt, west and east: neither
/// leads where the other does.
final List<GridPoint> stationWestDoor = _mallNorthStreet.doorRow('(');
final List<GridPoint> stationEastDoor = _mallNorthStreet.doorRow(')');

/// The far platform, where Luigi is waiting in the cab of the one train
/// still in one piece: coming up the stairs onto it plays his scene. The
/// whole platform, so there is no walking past him.
final GridRect stationPlatform = () {
  final rows = _farSide.rows;
  final top = rows.indexWhere((row) => row.contains('='));
  final bottom = rows.lastIndexWhere((row) => row.contains('='));
  return GridRect(
    _farSide.origin.x + 1,
    _farSide.origin.y + top,
    _farSide.origin.x + _farSide.width - 2,
    _farSide.origin.y + bottom,
  );
}();

/// The passenger door in the train on the far platform. Its tile starts as
/// a wall and is made walkable by the game as soon as Luigi is rescued.
final GridPoint stationTrainDoorTile = _farSide.tileOf('P');

/// The flight `U` down to the underpass, sunk in the booking hall's floor a
/// few cells in from its front wall so that it shows: got onto from the
/// north, its head under the green sign, and two steps deep.
final List<GridPoint> stationHallStairs = _station.tilesOf('U');

/// The last steps of [stationHallStairs]: the door down into the
/// underpass. The floor below them is shut off from them, as the sides are
/// (see `WorldState.canStep`): the flight is got onto only from its head.
final List<GridPoint> stationHallStairsFoot = lastSteps(
  stationHallStairs,
  Direction.south,
);

/// The flight `D` down from the far platform, through its wall and one
/// step further.
final List<GridPoint> stationFarStairs = _farSide.tilesOf('D');

/// The last steps of [stationFarStairs]: the door down into the underpass.
final List<GridPoint> stationFarStairsFoot = lastSteps(
  stationFarStairs,
  Direction.south,
);

/// The station's two flights, each step with the way up it (see
/// `WorldState.stairs`).
final Map<GridPoint, Direction> stationStairs = <GridPoint, Direction>{
  for (final step in stationHallStairs) step: Direction.south,
  for (final step in stationFarStairs) step: Direction.south,
};

/// The flames along the overturned car `H` burning at the west end of the
/// station's tracks, one every two cells from its west end.
final List<FireSpot> stationWreckFireSpots = () {
  final car = _station.tilesOf('H');
  final west = car.map((tile) => tile.x).reduce(math.min);
  final east = car.map((tile) => tile.x).reduce(math.max);
  final middle = car.map((tile) => tile.y).reduce(math.min) + 1;
  return <FireSpot>[
    for (var x = west; x < east; x += 2)
      FireSpot(GridPoint(x, middle), FireKind.car),
  ];
}();

/// The east end of the fire in the one gap between the station's burning
/// car and the car still upright, on the platform side: the only way onto
/// the tracks, and looking at it says what it would take.
final GridPoint stationTrackFireTile = _station
    .tilesOf('?')
    .reduce((a, b) => a.y > b.y || (a.y == b.y && a.x > b.x) ? a : b);

/// The station's two doorways, each into its own corner of the booking
/// hall, and the two flights of the underpass that join the far end of
/// that hall to the far platform (every flight climbs into the back wall
/// of the place it leaves, so Mario lands on the step below it -- south,
/// but for the flight up onto the far platform, whose wall runs along the
/// bottom of the map). All both ways.
final Map<GridPoint, Portal> stationPortals = <GridPoint, Portal>{
  ...pairedDoors(stationWestDoor, _station.doorRow('E'), Direction.north),
  ...pairedDoors(_station.doorRow('E'), stationWestDoor, Direction.south),
  ...pairedDoors(stationEastDoor, _station.doorRow('O'), Direction.north),
  ...pairedDoors(_station.doorRow('O'), stationEastDoor, Direction.south),
  // Down the last step of each flight into the underpass, and back up
  // onto the step above it, facing up the flight.
  ...pairedDoors(
    stationHallStairsFoot,
    _underpass.doorRow('D'),
    Direction.south,
  ),
  ...backOntoFlight(_underpass.doorRow('D'), stationHallStairsFoot),
  ...backOntoFlight(_underpass.doorRow('U'), stationFarStairsFoot),
  ...pairedDoors(
    stationFarStairsFoot,
    _underpass.doorRow('U'),
    Direction.south,
  ),
};
