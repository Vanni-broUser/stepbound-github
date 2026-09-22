import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile_map.dart';
import 'package:stepbound/core/items/pickup.dart';
import 'package:stepbound/core/seeded_random.dart';
import 'package:stepbound/core/world_event.dart';

final class NoisePulse {
  const NoisePulse({
    required this.origin,
    required this.radius,
    required this.sourceEntityId,
  });

  factory NoisePulse.fromJson(Map<String, Object?> json) {
    return NoisePulse(
      origin: GridPoint.fromJson(json['origin']! as Map<String, Object?>),
      radius: json['radius']! as int,
      sourceEntityId: json['sourceEntityId']! as String,
    );
  }

  final GridPoint origin;
  final int radius;
  final String sourceEntityId;

  Map<String, Object?> toJson() => <String, Object?>{
    'origin': origin.toJson(),
    'radius': radius,
    'sourceEntityId': sourceEntityId,
  };
}

final class WorldState {
  WorldState({
    required this.map,
    required Iterable<Entity> entities,
    required this.playerId,
    required this.random,
    this.tick = 0,
    Iterable<NoisePulse> pendingNoises = const <NoisePulse>[],
    Iterable<WorldEvent> events = const <WorldEvent>[],
    Iterable<Pickup> pickups = const <Pickup>[],
    Map<String, GridRect> alertTriggers = const <String, GridRect>{},
    Map<GridPoint, Portal> portals = const <GridPoint, Portal>{},
    Iterable<GridPoint> campfires = const <GridPoint>[],
    Map<GridPoint, GridRect> controls = const <GridPoint, GridRect>{},
  }) : controls = Map<GridPoint, GridRect>.of(controls),
       portals = Map<GridPoint, Portal>.unmodifiable(portals),
       campfires = Set<GridPoint>.unmodifiable(campfires),
       entities = <String, Entity>{
         for (final entity in entities) entity.id: entity,
       },
       pickups = <String, Pickup>{
         for (final pickup in pickups) pickup.id: pickup,
       },
       alertTriggers = Map<String, GridRect>.of(alertTriggers),
       _pendingNoises = List<NoisePulse>.of(pendingNoises),
       _events = List<WorldEvent>.of(events) {
    if (!this.entities.containsKey(playerId)) {
      throw ArgumentError('The world must contain player $playerId.');
    }
  }

  /// A world from [toJson]. A [map] given here is used instead of the one
  /// in [json], which a save may leave out (see `saveTutorialWorld`).
  factory WorldState.fromJson(Map<String, Object?> json, {TileMap? map}) {
    final encodedEntities = json['entities']! as List<Object?>;
    final encodedNoises = json['pendingNoises']! as List<Object?>;
    final encodedEvents = json['events']! as List<Object?>;
    final encodedPickups =
        json['pickups'] as List<Object?>? ?? const <Object?>[];
    final encodedTriggers =
        json['alertTriggers'] as Map<String, Object?>? ??
        const <String, Object?>{};
    final encodedPortals =
        json['portals'] as List<Object?>? ?? const <Object?>[];
    final encodedCampfires =
        json['campfires'] as List<Object?>? ?? const <Object?>[];
    final encodedControls =
        json['controls'] as List<Object?>? ?? const <Object?>[];
    return WorldState(
      map: map ?? TileMap.fromJson(json['map']! as Map<String, Object?>),
      entities: encodedEntities.map(
        (entity) => Entity.fromJson(entity! as Map<String, Object?>),
      ),
      playerId: json['playerId']! as String,
      random: SeededRandom.fromState(json['randomState']! as int),
      tick: json['tick']! as int,
      pendingNoises: encodedNoises.map(
        (noise) => NoisePulse.fromJson(noise! as Map<String, Object?>),
      ),
      events: encodedEvents.map(
        (event) => WorldEvent.fromJson(event! as Map<String, Object?>),
      ),
      pickups: encodedPickups.map(
        (pickup) => Pickup.fromJson(pickup! as Map<String, Object?>),
      ),
      alertTriggers: <String, GridRect>{
        for (final entry in encodedTriggers.entries)
          entry.key: GridRect.fromJson(entry.value! as Map<String, Object?>),
      },
      campfires: encodedCampfires.map(
        (point) => GridPoint.fromJson(point! as Map<String, Object?>),
      ),
      portals: <GridPoint, Portal>{
        for (final encoded in encodedPortals.cast<Map<String, Object?>>())
          GridPoint.fromJson(encoded['at']! as Map<String, Object?>):
              Portal.fromJson(encoded),
      },
      controls: <GridPoint, GridRect>{
        for (final encoded in encodedControls.cast<Map<String, Object?>>())
          GridPoint.fromJson(encoded['at']! as Map<String, Object?>):
              GridRect.fromJson(encoded['opens']! as Map<String, Object?>),
      },
    );
  }

  final TileMap map;
  final Map<String, Entity> entities;

  /// Backpacks lying on the map, by id.
  final Map<String, Pickup> pickups;

  /// Zombies that notice the player as soon as they step into the area,
  /// whatever the zombie is facing. Each trigger fires once.
  final Map<String, GridRect> alertTriggers;

  /// Doors that move the player to another place (e.g. inside a building).
  final Map<GridPoint, Portal> portals;

  /// Camps where the player can rest and save.
  final Set<GridPoint> campfires;

  /// Control panels not used yet, by tile, with the bars each one opens.
  final Map<GridPoint, GridRect> controls;
  final String playerId;
  final SeededRandom random;
  final List<NoisePulse> _pendingNoises;
  final List<WorldEvent> _events;
  int tick;

  Entity get player => entities[playerId]!;

  Entity? entityAt(GridPoint point, {String? excluding}) {
    for (final entity in entities.values) {
      if (entity.id == excluding || !entity.isAlive) {
        continue;
      }
      if (entity.component<PositionComponent>().position == point) {
        return entity;
      }
    }
    return null;
  }

  Pickup? pickupAt(GridPoint point) {
    for (final pickup in pickups.values) {
      if (pickup.active && pickup.position == point) {
        return pickup;
      }
    }
    return null;
  }

  /// Tiles (Manhattan) around the player within which actors take turns.
  static const int simulationRadius = 40;

  Iterable<Entity> actorsInSimulationRadius({
    int radius = simulationRadius,
  }) sync* {
    final playerPosition = player.component<PositionComponent>().position;
    for (final entity in entities.values) {
      if (entity.kind == EntityKind.player || !entity.isAlive) {
        continue;
      }
      final position = entity.component<PositionComponent>().position;
      if (position.manhattanDistanceTo(playerPosition) <= radius) {
        yield entity;
      }
    }
  }

  Set<GridPoint> occupiedPoints({String? excluding}) {
    return <GridPoint>{
      for (final entity in entities.values)
        if (entity.id != excluding && entity.isAlive)
          entity.component<PositionComponent>().position,
      for (final pickup in pickups.values)
        if (pickup.active) pickup.position,
    };
  }

  void emit(WorldEvent event) {
    _events.add(event);
  }

  void emitNoise({
    required GridPoint origin,
    required int radius,
    required String sourceEntityId,
  }) {
    final pulse = NoisePulse(
      origin: origin,
      radius: radius,
      sourceEntityId: sourceEntityId,
    );
    _pendingNoises.add(pulse);
    emit(
      NoiseEvent(
        origin: origin,
        radius: radius,
        sourceEntityId: sourceEntityId,
      ),
    );
  }

  List<NoisePulse> takePendingNoises() {
    final noises = List<NoisePulse>.of(_pendingNoises);
    _pendingNoises.clear();
    return noises;
  }

  List<WorldEvent> drainEvents() {
    final events = List<WorldEvent>.of(_events);
    _events.clear();
    return events;
  }

  void damage({
    required String entityId,
    required int amount,
    required String sourceEntityId,
  }) {
    final entity = entities[entityId]!;
    final health = entity.component<HealthComponent>();
    if (!health.isAlive) {
      return;
    }
    health.current = (health.current - amount).clamp(0, health.maximum);
    emit(
      DamagedEvent(
        entityId: entityId,
        amount: amount,
        sourceEntityId: sourceEntityId,
      ),
    );
    if (!health.isAlive) {
      emit(DiedEvent(entityId));
    }
  }

  /// Everything, [map] included unless [includeMap] is false: a save of a
  /// known level only stores how its map differs from the level's.
  Map<String, Object?> toJson({bool includeMap = true}) => <String, Object?>{
    if (includeMap) 'map': map.toJson(),
    'entities': entities.values.map((entity) => entity.toJson()).toList(),
    'playerId': playerId,
    'randomState': random.state,
    'tick': tick,
    'pendingNoises': _pendingNoises.map((noise) => noise.toJson()).toList(),
    'events': _events.map((event) => event.toJson()).toList(),
    'pickups': pickups.values.map((pickup) => pickup.toJson()).toList(),
    'alertTriggers': <String, Object?>{
      for (final entry in alertTriggers.entries)
        entry.key: entry.value.toJson(),
    },
    'campfires': <Object?>[for (final point in campfires) point.toJson()],
    'portals': <Object?>[
      for (final entry in portals.entries)
        <String, Object?>{'at': entry.key.toJson(), ...entry.value.toJson()},
    ],
    'controls': <Object?>[
      for (final entry in controls.entries)
        <String, Object?>{
          'at': entry.key.toJson(),
          'opens': entry.value.toJson(),
        },
    ],
  };
}
