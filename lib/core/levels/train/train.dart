import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/game_world.dart';
import 'package:stepbound/core/levels/place.dart';
import 'package:stepbound/core/world.dart';

export 'package:stepbound/core/levels/train/train_interior.dart';

/// Inside the train the shell, the windscreen and the gangway partitions
/// are walls. Seats, tables, luggage, the controls, the driver's seat and
/// the map table can be seen over but not walked through, and so can the
/// two cots, the bin bags, the books, Mario's ammunition crate, the table
/// laid for eating and Luigi.
const Legend trainLegend = Legend(
  walls: 'xWwIiV',
  obstacles: 'STLCPhbBuklaGKqYRO',
);

/// Luigi's train, the one place every level shares: it carries Mario from
/// one to the next. It counts as Molfetta's, where it is found.
const PlaceSpec trainPlace = PlaceSpec(
  id: PlaceId.trainInterior,
  area: AreaId.train,
  rows: trainInteriorRows,
  legend: trainLegend,
  indoor: true,
  // Luigi keeps the lights on: the whole train is bright, end to end.
  lit: true,
);

final Place _train = place(PlaceId.trainInterior);

/// The door through which Mario enters and leaves the first passenger car.
final GridPoint trainExitTile = _train.tileOf('E');

/// The table in the middle of the locomotive, the yellowed Europe map
/// spread over the whole of it: any side of it opens the map.
final List<GridPoint> trainMapTiles = _train.tilesOf('P');

/// Where Mario stands aboard when the story puts him there: at the map
/// table, below it, looking up at it ([trainMapFacing]).
final GridPoint trainMapStandTile = GridPoint(
  trainMapTiles.first.x + 1,
  trainMapTiles.last.y + 1,
);

/// Which way Mario faces from [trainMapStandTile]: at the table.
const Direction trainMapFacing = Direction.north;

/// Which way Mario faces when the story puts him aboard at
/// [trainMapStandTile]: away from the table, so a stray tap does not open
/// the map again at once.
const Direction trainArrivalFacing = Direction.south;

/// The part of the map Mario looks at from [trainMapStandTile], where the
/// glint shows once there is somewhere to go.
final GridPoint trainMapPanelTile = trainMapStandTile.step(trainMapFacing);

/// The train's door opens onto the platform of the level it stands in:
/// Molfetta's far platform or Roma Termini. The door back aboard from
/// either platform is always there; only the way out moves with it.
void parkTrain(WorldState world, LevelId level) {
  final platformDoor = switch (level) {
    LevelId.hometown => stationTrainDoorTile,
    LevelId.rome => terminiTrainDoorTile,
  };
  world.portals[trainExitTile] = Portal(
    to: platformDoor.step(Direction.south),
    facing: Direction.south,
  );
}

/// What a save made aboard is called in the slots.
const String trainPlaceName = 'Treno';

/// Luigi, at home in his corner of the locomotive.
final GridPoint trainLuigiTile = _train.tileOf('l');

/// The middle of Mario's desk, the abacus and the calculator: there he
/// reads up on the zombie types met so far.
final List<GridPoint> trainBookTiles = _train.tilesOf('k');

/// Mario's wardrobe, a rail with his clothes on it: what to wear.
final List<GridPoint> trainWardrobeTiles = _train.tilesOf('R');

/// Mario's cot: the figures of the adventure, city by city, and from them
/// the memories.
final List<GridPoint> trainCotTiles = _train.tilesOf('B');

/// Mario's ammunition crate by his cot: interacting with it brings his
/// rounds up to [trainAmmoRefill], whenever he has fewer.
final List<GridPoint> trainAmmoTiles = _train.tilesOf('a');

/// The narrow table against the wall above the map table, laid with cured
/// meats, cheese and bread: stopping to eat there saves the game, as
/// resting at a campfire does. Its middle tile is where it glints.
final List<GridPoint> trainFoodTiles = _train.tilesOf('G');

/// How many rounds the crate in the locomotive loads Mario up to.
const int trainAmmoRefill = 5;

/// The table laid with food aboard saves like a campfire, and saves as the
/// train.
final Map<GridPoint, String> trainCampfireNames = <GridPoint, String>{
  for (final tile in trainFoodTiles) tile: trainPlaceName,
};

/// What the train holds when a game starts: the doors between it and the
/// platforms it stops at, its map of Europe and what can be looked at
/// aboard.
LevelContents trainContents() => LevelContents(
  portals: <GridPoint, Portal>{
    ...pairedDoors(
      <GridPoint>[stationTrainDoorTile],
      <GridPoint>[trainExitTile],
      Direction.north,
    ),
    // Where the train's own door leads is up to where it stands: see
    // parkTrain. A new game starts with it in Molfetta.
    ...pairedDoors(
      <GridPoint>[trainExitTile],
      <GridPoint>[stationTrainDoorTile],
      Direction.south,
    ),
    ...pairedDoors(
      <GridPoint>[terminiTrainDoorTile],
      <GridPoint>[trainExitTile],
      Direction.north,
    ),
  },
  travelMaps: trainMapTiles,
  lookouts: <GridPoint>[
    trainLuigiTile,
    ...trainBookTiles,
    ...trainWardrobeTiles,
    ...trainCotTiles,
    ...trainAmmoTiles,
  ],
);
