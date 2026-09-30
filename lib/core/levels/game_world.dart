import 'dart:math' as math;

import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';
import 'package:stepbound/core/grid/tile_map.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/levels/fire_spot.dart';
import 'package:stepbound/core/levels/hometown/hometown.dart';
import 'package:stepbound/core/levels/place.dart';
import 'package:stepbound/core/levels/rome/rome.dart';
import 'package:stepbound/core/levels/train/train.dart';
import 'package:stepbound/core/seeded_random.dart';
import 'package:stepbound/core/world.dart';

export 'package:stepbound/core/levels/fire_spot.dart';
export 'package:stepbound/core/levels/hometown/hometown.dart';
export 'package:stepbound/core/levels/rome/rome.dart';
export 'package:stepbound/core/levels/train/train.dart';

/// Every place of the game, side by side on one grid: Molfetta's, the
/// train and Rome's. Each level's own module (hometown/, train/, rome/)
/// holds its places, what stands in them and the tiles its story needs.
final List<Place> gamePlaces = layOutPlaces(<PlaceSpec>[
  ...hometownPlaces,
  trainPlace,
  ...romePlaces,
]);

final Map<PlaceId, Place> _placesById = <PlaceId, Place>{
  for (final place in gamePlaces) place.id: place,
};

Place place(PlaceId id) => _placesById[id]!;

/// The place [tile] belongs to, if any.
Place? placeAt(GridPoint tile) {
  for (final place in gamePlaces) {
    if (place.bounds.contains(tile)) {
      return place;
    }
  }
  return null;
}

/// What a level puts in the world when a game starts, besides the tiles of
/// its places.
final class LevelContents {
  const LevelContents({
    this.entities = const <Entity>[],
    this.pickups = const <Pickup>[],
    this.portals = const <GridPoint, Portal>{},
    this.alertTriggers = const <String, GridRect>{},
    this.controls = const <GridPoint, GridRect>{},
    this.travelMaps = const <GridPoint>[],
    this.lookouts = const <GridPoint>[],
    this.grapples = const <GridPoint, Portal>{},
    this.stairs = const <GridPoint, Direction>{},
  });

  final List<Entity> entities;
  final List<Pickup> pickups;
  final Map<GridPoint, Portal> portals;
  final Map<String, GridRect> alertTriggers;
  final Map<GridPoint, GridRect> controls;
  final List<GridPoint> travelMaps;
  final List<GridPoint> lookouts;
  final Map<GridPoint, Portal> grapples;
  final Map<GridPoint, Direction> stairs;
}

/// Campfires, by tile, with the name shown in the save slots. Aboard, the
/// table laid with food takes the place of one, and saves as the train.
final Map<GridPoint, String> campfireNames = <GridPoint, String>{
  ...hometownCampfireNames,
  ...romeCampfireNames,
  ...trainCampfireNames,
};

/// Every fire burning out of doors, which the game animates.
List<FireSpot> get outdoorFireSpots => <FireSpot>[
  ...hometownFireSpots,
  ...romeFireSpots,
];

/// The steps of [flight] furthest along [down].
List<GridPoint> lastSteps(List<GridPoint> flight, Direction down) {
  int depth(GridPoint step) => step.x * down.dx + step.y * down.dy;
  final last = flight.map(depth).reduce((a, b) => a > b ? a : b);
  return <GridPoint>[
    for (final step in flight)
      if (depth(step) == last) step,
  ];
}

/// From each of the [doors], climbing north, onto the step above the
/// matching one of the [foot] of a flight got onto southward, facing back
/// along it: the foot itself is the door the other way.
Map<GridPoint, Portal> backOntoFlight(
  List<GridPoint> doors,
  List<GridPoint> foot,
) => <GridPoint, Portal>{
  for (var i = 0; i < doors.length; i++)
    doors[i]: Portal(
      to: foot[i].step(Direction.north),
      facing: Direction.north,
    ),
};

/// Doors [from] one place [to] another, tile by tile in order: stepping on
/// a tile of [from] lands on the tile of [to] one step towards [facing].
Map<GridPoint, Portal> pairedDoors(
  List<GridPoint> from,
  List<GridPoint> to,
  Direction facing,
) {
  return <GridPoint, Portal>{
    for (var i = 0; i < from.length; i++)
      from[i]: Portal(to: to[i].step(facing), facing: facing),
  };
}

/// The map of the level as the player finds it: every place's tiles on
/// the shared grid, wall in the gaps between them. Laid out once: the
/// places never change while the game runs, and every game, every save
/// and every restore measures itself against these same tiles.
final ({int width, int height, List<Tile> tiles}) _levelMap = () {
  final width = gamePlaces
      .map((place) => place.bounds.right + 1)
      .reduce(math.max);
  final height = gamePlaces
      .map((place) => place.bounds.bottom + 1)
      .reduce(math.max);
  final kinds = List<TileKind>.filled(width * height, TileKind.wall);
  for (final place in gamePlaces) {
    for (final (point, glyph) in place.glyphs) {
      kinds[point.y * width + point.x] = place.kindOf(glyph);
    }
  }
  return (
    width: width,
    height: height,
    tiles: List<Tile>.unmodifiable(<Tile>[
      for (final kind in kinds) Tile(kind),
    ]),
  );
}();

/// A fresh copy of the level's map, to be walked on and changed.
TileMap _levelTileMap() => TileMap(
  width: _levelMap.width,
  height: _levelMap.height,
  tiles: _levelMap.tiles,
);

/// The level as [createGameWorld] builds it, read and never written: what
/// a save leaves out (the doors, the travel maps, whoever it does not know
/// yet) is taken from here, instead of from a world built anew on every
/// save and every read of a slot. A game to play comes from
/// [createGameWorld], which builds its own.
final WorldState _levelWorld = createGameWorld();

/// Where the game goes no further yet: every walkable tile at the edge of
/// any place, in any level, that is not a door to another place, with the
/// way back into its place. A street, a platform or a track that runs off
/// its map has no next map to lead to, so stepping on its last tile shows
/// the work-in-progress screen (`WorkInProgressScript`) and puts Mario
/// back a step inside. Nothing needs listing: a new place gets it for its
/// open edges, and a new map joined to one of them by a door takes it
/// away. Edges that are shut (walls, wrecks, fire) are not walkable and
/// are not in it; a closed-off pocket past a fire is, harmlessly, until
/// someone gets there.
final Map<GridPoint, Direction> workInProgressEnds = <GridPoint, Direction>{
  for (final place in gamePlaces)
    for (final MapEntry(key: tile, value: back) in place.edgeEnds.entries)
      if (!_levelWorld.portals.containsKey(tile)) tile: back,
};

/// Doors to places that have no map yet: the last step of a flight of
/// stairs, a doorway or a hatch inside a place, drawn as the way into a
/// building nobody has drawn the inside of. Stepping on one shows the
/// work-in-progress screen, as an open edge does, and puts Mario back
/// where he stepped from. When the place behind one is drawn, its tiles
/// leave this list for a pair of doors (`pairedDoors`), as an open edge
/// does (docs/level_pipeline.md).
final Set<GridPoint> workInProgressDoors = <GridPoint>{
  ...hometownWorkInProgressDoors,
  ...romeWorkInProgressDoors,
};

/// Its entities, backpacks, doors and travel maps as a save holds them,
/// encoded once. Only ever read: [restoreGameWorld] hands the same maps
/// to `WorldState.fromJson`, which copies what it needs out of them.
final Map<String, Object?> _levelJson = _levelWorld.toJson(includeMap: false);

/// The game as the player finds it at the start: the map of every place,
/// and what each level puts in it (see [LevelContents]).
WorldState createGameWorld({int seed = 20260920}) {
  final factory = EntityFactory(BalanceConfig.standard());
  final levels = <LevelContents>[
    hometownContents(factory),
    trainContents(),
    romeContents(factory),
  ];
  return WorldState(
    map: _levelTileMap(),
    entities: <Entity>[for (final level in levels) ...level.entities],
    pickups: <Pickup>[for (final level in levels) ...level.pickups],
    alertTriggers: <String, GridRect>{
      for (final level in levels) ...level.alertTriggers,
    },
    portals: <GridPoint, Portal>{for (final level in levels) ...level.portals},
    campfires: campfireNames.keys,
    controls: <GridPoint, GridRect>{
      for (final level in levels) ...level.controls,
    },
    travelMaps: <GridPoint>[for (final level in levels) ...level.travelMaps],
    lookouts: <GridPoint>[for (final level in levels) ...level.lookouts],
    grapples: <GridPoint, Portal>{
      for (final level in levels) ...level.grapples,
    },
    stairs: <GridPoint, Direction>{for (final level in levels) ...level.stairs},
    playerId: 'player',
    random: SeededRandom(seed),
  );
}

/// The world as a save stores it: everything that can change (Mario, the
/// zombies, dead or alive, wherever they stand, the backpacks and whether
/// they were collected, the panels), but of the map only the tiles that
/// differ from the level's (the lifted shutter): the level rebuilds the
/// rest. The dark gaps between places made a full map most of a save.
///
/// The map is compared tile by tile against the level's, by index: the
/// grid is over a hundred thousand cells, and this runs at every campfire.
Map<String, Object?> saveGameWorld(WorldState world) {
  final map = world.map;
  if (map.width != _levelMap.width || map.height != _levelMap.height) {
    throw ArgumentError('not the map of the level: ${map.width}x${map.height}');
  }
  final level = _levelMap.tiles;
  final tiles = map.tiles;
  return <String, Object?>{
    ...world.toJson(includeMap: false),
    'mapChanges': <Object?>[
      for (var index = 0; index < tiles.length; index++)
        if (tiles[index].kind != level[index].kind)
          <String, Object?>{
            'x': index % map.width,
            'y': index ~/ map.width,
            'kind': tiles[index].kind.name,
          },
    ],
  };
}

/// A world resumed from a [saveGameWorld] save: the level's map with
/// the saved changes, and everything else as it was.
WorldState restoreGameWorld(Map<String, Object?> json) {
  final map = _levelTileMap();
  for (final change
      in (json['mapChanges']! as List<Object?>).cast<Map<String, Object?>>()) {
    map.setTile(
      GridPoint(change['x']! as int, change['y']! as int),
      Tile(TileKind.values.byName(change['kind']! as String)),
    );
  }
  // Saves keep the complete pickup and entity lists. When a newer level
  // adds a backpack or a zombie, an older save therefore knows nothing
  // about it even though the current map around it has already been
  // rebuilt above. Merge only missing defaults: saved state (including
  // collected backpacks and dead zombies) wins, while newly shipped
  // inhabitants and items appear where the level puts them.
  final savedPickups = (json['pickups'] as List<Object?>? ?? const <Object?>[])
      .cast<Map<String, Object?>>();
  final savedPickupIds = <String>{
    for (final pickup in savedPickups) pickup['id']! as String,
  };
  final savedEntities =
      (json['entities'] as List<Object?>? ?? const <Object?>[])
          .cast<Map<String, Object?>>();
  final savedEntityIds = <String>{
    for (final entity in savedEntities) entity['id']! as String,
  };
  final levelEntities = (_levelJson['entities']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final levelPickups = (_levelJson['pickups']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final migrated = <String, Object?>{
    ...json,
    // Doors between places, travel maps and what can be looked at are
    // level structure rather than player state. Taking the current
    // definitions lets older saves enter the newly added train, use its
    // locomotive map and reach Mario's desk from any of its cells.
    'portals': _levelJson['portals'],
    'travelMaps': _levelJson['travelMaps'],
    'lookouts': _levelJson['lookouts'],
    'grapples': _levelJson['grapples'],
    'stairs': _levelJson['stairs'],
    'entities': <Object?>[
      ...savedEntities,
      for (final entity in levelEntities)
        if (!savedEntityIds.contains(entity['id']! as String)) entity,
    ],
    'pickups': <Object?>[
      ...savedPickups,
      for (final pickup in levelPickups)
        if (!savedPickupIds.contains(pickup['id']! as String)) pickup,
    ],
  };
  return WorldState.fromJson(migrated, map: map);
}

/// Whether [tile] lies in one of [level]'s places.
bool isInLevel(GridPoint tile, LevelId level) => placeAt(tile)?.level == level;

/// The level [tile] belongs to; the dark between places counts as
/// Molfetta's, like the train.
LevelId levelAt(GridPoint tile) => placeAt(tile)?.level ?? LevelId.hometown;

/// The level of the campfire called [name], the train's table Molfetta's.
LevelId campfireLevel(String name) {
  for (final MapEntry(key: tile, value: fire) in campfireNames.entries) {
    if (fire == name) {
      return levelAt(tile);
    }
  }
  return LevelId.hometown;
}

GridPoint _pointOf(Object? json) =>
    GridPoint.fromJson(json! as Map<String, Object?>);

GridPoint _positionOf(Map<String, Object?> entity) => _pointOf(
  (entity['components']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .firstWhere((component) => component['type'] == 'position')['position'],
);

/// Where the game starts everyone, and every backpack, by id.
final Map<String, GridPoint> _startingEntities = <String, GridPoint>{
  for (final entity
      in (_levelJson['entities']! as List<Object?>)
          .cast<Map<String, Object?>>())
    entity['id']! as String: _positionOf(entity),
};
final Map<String, GridPoint> _startingPickups = <String, GridPoint>{
  for (final pickup
      in (_levelJson['pickups']! as List<Object?>).cast<Map<String, Object?>>())
    pickup['id']! as String: _pointOf(pickup['position']),
};

/// The level whose inhabitant [id] is: the one the level puts it in, or,
/// for someone the story raised, the one it stands [at] now. A zombie that
/// followed Mario aboard is still its city's.
LevelId entityLevel(String id, GridPoint at) =>
    levelAt(_startingEntities[id] ?? at);

/// [saved], a world as [saveGameWorld] stores it, with [level] as the game
/// starts it (its zombies, backpacks, panels, the tiles it changed) and
/// every other level exactly as it was: starting a level over leaves the
/// other cities alone. Mario is left as he is, unless [freshPlayer]: then
/// he is as the game starts him too.
Map<String, Object?> restartLevelWorld(
  Map<String, Object?> saved,
  LevelId level, {
  bool freshPlayer = false,
}) {
  final playerId = saved['playerId']! as String;
  bool entityOfLevel(Map<String, Object?> entity) =>
      entity['id'] != playerId &&
      entityLevel(entity['id']! as String, _positionOf(entity)) == level;
  LevelId pickupLevel(Map<String, Object?> pickup) =>
      levelAt(_startingPickups[pickup['id']] ?? _pointOf(pickup['position']));
  List<Map<String, Object?>> listOf(Map<String, Object?> json, String key) =>
      (json[key] as List<Object?>? ?? const <Object?>[])
          .cast<Map<String, Object?>>();
  // Points, or entries placed with an 'at', of both worlds: the level's
  // from the game's start, the others' as they were.
  List<Object?> byPlace(String key, GridPoint Function(Object? entry) at) =>
      <Object?>[
        for (final entry in saved[key] as List<Object?>? ?? const <Object?>[])
          if (levelAt(at(entry)) != level) entry,
        for (final entry in _levelJson[key]! as List<Object?>)
          if (levelAt(at(entry)) == level) entry,
      ];
  GridPoint entryAt(Object? entry) =>
      _pointOf((entry! as Map<String, Object?>)['at']);
  final savedEntities = listOf(saved, 'entities');
  final levelEntities = listOf(_levelJson, 'entities');
  final savedTriggers =
      saved['alertTriggers'] as Map<String, Object?>? ??
      const <String, Object?>{};
  final levelTriggers = _levelJson['alertTriggers']! as Map<String, Object?>;
  final standing = <String, GridPoint>{
    for (final entity in savedEntities)
      entity['id']! as String: _positionOf(entity),
  };
  LevelId triggerLevel(String zombie) => levelAt(
    _startingEntities[zombie] ?? standing[zombie] ?? const GridPoint(0, 0),
  );
  return <String, Object?>{
    ...saved,
    'entities': <Object?>[
      for (final entity in savedEntities)
        if (entity['id'] == playerId)
          freshPlayer
              ? levelEntities.firstWhere((fresh) => fresh['id'] == playerId)
              : entity
        else if (!entityOfLevel(entity))
          entity,
      for (final entity in levelEntities)
        if (entityOfLevel(entity)) entity,
    ],
    'pickups': <Object?>[
      for (final pickup in listOf(saved, 'pickups'))
        if (pickupLevel(pickup) != level) pickup,
      for (final pickup in listOf(_levelJson, 'pickups'))
        if (pickupLevel(pickup) == level) pickup,
    ],
    'alertTriggers': <String, Object?>{
      for (final MapEntry(:key, :value) in savedTriggers.entries)
        if (triggerLevel(key) != level) key: value,
      for (final MapEntry(:key, :value) in levelTriggers.entries)
        if (triggerLevel(key) == level) key: value,
    },
    'controls': byPlace('controls', entryAt),
    'lookouts': byPlace('lookouts', _pointOf),
    'campfires': byPlace('campfires', _pointOf),
    'mapChanges': <Object?>[
      for (final change in listOf(saved, 'mapChanges'))
        if (levelAt(GridPoint(change['x']! as int, change['y']! as int)) !=
            level)
          change,
    ],
    // Whatever was on its way when the level was left is not any more.
    'pendingNoises': const <Object?>[],
    'events': const <Object?>[],
  };
}

/// Every zombie [level] can hold: the ones there from the start and the
/// ones its story raises, by kind.
List<EntityKind> levelZombieKinds(LevelId level) => <EntityKind>[
  for (final entity in _levelWorld.entities.values)
    if (entity.kind != EntityKind.player &&
        isInLevel(entity.component<PositionComponent>().position, level))
      entity.kind,
  ...switch (level) {
    LevelId.hometown => hometownRaisedZombies,
    LevelId.rome => const <EntityKind>[],
  },
];

/// The names of the campfires of [level].
Set<String> levelCampfires(LevelId level) => <String>{
  for (final MapEntry(key: tile, value: name) in campfireNames.entries)
    // The table aboard saves like a fire but is not one to find.
    if (isInLevel(tile, level) && !trainFoodTiles.contains(tile)) name,
};
