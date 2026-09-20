import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';
import 'package:stepbound/core/world.dart';
import 'package:stepbound/core/world_event.dart';

sealed class PlayerAction {
  const PlayerAction();

  int get tickCost;

  void resolve(WorldState world);
}

final class MoveAction extends PlayerAction {
  const MoveAction(this.direction);

  final Direction direction;

  @override
  int get tickCost => 1;

  @override
  void resolve(WorldState world) {
    final player = world.player;
    final position = player.component<PositionComponent>()..facing = direction;
    final target = position.position.step(direction);

    if (!world.map.contains(target) || !world.map.tileAt(target).isWalkable) {
      world.emit(
        BlockedEvent(entityId: player.id, at: target, reason: 'terrain'),
      );
      return;
    }
    if (world.entityAt(target, excluding: player.id) != null) {
      world.emit(
        BlockedEvent(entityId: player.id, at: target, reason: 'entity'),
      );
      return;
    }

    final previous = position.position;
    position.position = target;
    world
      ..emit(MovedEvent(entityId: player.id, from: previous, to: target))
      ..emitNoise(
        origin: target,
        radius: world.map.tileAt(target).movementNoiseRadius,
        sourceEntityId: player.id,
      );
  }
}

final class InteractAction extends PlayerAction {
  const InteractAction();

  @override
  int get tickCost => 1;

  @override
  void resolve(WorldState world) {
    final playerPosition = world.player.component<PositionComponent>();
    final target = playerPosition.position.step(playerPosition.facing);
    if (!world.map.contains(target)) {
      world.emit(NoInteractionEvent(target));
      return;
    }

    final tile = world.map.tileAt(target);
    switch (tile.kind) {
      case TileKind.closedDoor:
        world.map.setTile(target, const Tile(TileKind.openDoor));
        world
          ..emit(DoorChangedEvent(at: target, isOpen: true))
          ..emitNoise(
            origin: target,
            radius: 4,
            sourceEntityId: world.playerId,
          );
      case TileKind.openDoor:
        if (world.entityAt(target) != null) {
          world.emit(
            BlockedEvent(
              entityId: world.playerId,
              at: target,
              reason: 'occupied door',
            ),
          );
          return;
        }
        world.map.setTile(target, const Tile(TileKind.closedDoor));
        world
          ..emit(DoorChangedEvent(at: target, isOpen: false))
          ..emitNoise(
            origin: target,
            radius: 4,
            sourceEntityId: world.playerId,
          );
      case TileKind.floor || TileKind.wall || TileKind.debris:
        world.emit(NoInteractionEvent(target));
    }
  }
}

final class WaitAction extends PlayerAction {
  const WaitAction();

  @override
  int get tickCost => 1;

  @override
  void resolve(WorldState world) {
    world.emit(WaitedEvent(world.playerId));
  }
}
