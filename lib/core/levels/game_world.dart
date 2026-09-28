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
  });

  final List<Entity> entities;
  final List<Pickup> pickups;
  final Map<GridPoint, Portal> portals;
  final Map<String, GridRect> alertTriggers;
  final Map<GridPoint, GridRect> controls;
  final List<GridPoint> travelMaps;
  final List<GridPoint> lookouts;
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

/// Doors [from] one place [to] another, tile by tile in order: stepping on
/// a tile of [from] lands on the tile of [to] one step towards [facing].
Map<GridPoint, Portal> pairedDoors(
  List<GridPoint> from,
  List<GridPoint> to,
  Direction facing,
) {
  assert(from.length == to.length, 'doors of different widths');
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
    // Doors between places and travel maps are level structure rather than
    // player state. Taking the current definitions lets older saves enter
    // the newly added train and use its locomotive map.
    'portals': _levelJson['portals'],
    'travelMaps': _levelJson['travelMaps'],
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
