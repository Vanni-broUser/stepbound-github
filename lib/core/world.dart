import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile_map.dart';
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
  }) : entities = <String, Entity>{
         for (final entity in entities) entity.id: entity,
       },
       _pendingNoises = List<NoisePulse>.of(pendingNoises),
       _events = List<WorldEvent>.of(events) {
    if (!this.entities.containsKey(playerId)) {
      throw ArgumentError('The world must contain player $playerId.');
    }
  }

  factory WorldState.fromJson(Map<String, Object?> json) {
    final encodedEntities = json['entities']! as List<Object?>;
    final encodedNoises = json['pendingNoises']! as List<Object?>;
    final encodedEvents = json['events']! as List<Object?>;
    return WorldState(
      map: TileMap.fromJson(json['map']! as Map<String, Object?>),
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
    );
  }

  final TileMap map;
  final Map<String, Entity> entities;
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

  Iterable<Entity> actorsInSimulationRadius({int radius = 40}) sync* {
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

  Map<String, Object?> toJson() => <String, Object?>{
    'map': map.toJson(),
    'entities': entities.values.map((entity) => entity.toJson()).toList(),
    'playerId': playerId,
    'randomState': random.state,
    'tick': tick,
    'pendingNoises': _pendingNoises.map((noise) => noise.toJson()).toList(),
    'events': _events.map((event) => event.toJson()).toList(),
  };
}
