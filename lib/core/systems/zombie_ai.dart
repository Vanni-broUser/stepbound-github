import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/world.dart';
import 'package:stepbound/core/world_event.dart';

final class ZombieAi {
  const ZombieAi();

  void takeTurn(WorldState world, Entity zombie) {
    if (!zombie.isAlive || !world.player.isAlive) {
      return;
    }

    final zombiePosition = zombie.component<PositionComponent>();
    final playerPosition = world.player.component<PositionComponent>().position;

    if (zombiePosition.position.manhattanDistanceTo(playerPosition) == 1) {
      _attackPlayer(world, zombie);
      return;
    }

    final hearing = zombie.component<HearingComponent>();
    final seesPlayer = _canSeePlayer(world, zombie);
    final target = seesPlayer ? playerPosition : hearing.lastHeard;
    if (target == null) {
      world.emit(WaitedEvent(zombie.id));
      return;
    }

    if (target == zombiePosition.position) {
      if (!seesPlayer) {
        hearing.lastHeard = null;
      }
      world.emit(WaitedEvent(zombie.id));
      return;
    }

    final next = world.map.shortestNextStep(
      start: zombiePosition.position,
      target: target,
      blocked: world.occupiedPoints(excluding: zombie.id),
    );
    if (next == null) {
      world.emit(WaitedEvent(zombie.id));
      return;
    }

    zombiePosition.facing = _directionBetween(zombiePosition.position, next);
    if (next == playerPosition) {
      _attackPlayer(world, zombie);
      return;
    }
    if (world.entityAt(next, excluding: zombie.id) != null) {
      world.emit(BlockedEvent(entityId: zombie.id, at: next, reason: 'entity'));
      return;
    }

    final previous = zombiePosition.position;
    zombiePosition.position = next;
    world.emit(MovedEvent(entityId: zombie.id, from: previous, to: next));
  }

  bool _canSeePlayer(WorldState world, Entity zombie) {
    final vision = zombie.component<VisionComponent>();
    if (vision.range == 0) {
      return false;
    }

    final position = zombie.component<PositionComponent>();
    final playerPosition = world.player.component<PositionComponent>().position;
    final dx = playerPosition.x - position.position.x;
    final dy = playerPosition.y - position.position.y;
    if (dx.abs() + dy.abs() > vision.range) {
      return false;
    }

    final forward = dx * position.facing.dx + dy * position.facing.dy;
    final lateral = (dx * position.facing.dy - dy * position.facing.dx).abs();
    if (forward <= 0 || lateral > forward) {
      return false;
    }
    return world.map.hasLineOfSight(position.position, playerPosition);
  }

  void _attackPlayer(WorldState world, Entity zombie) {
    final damage = zombie.component<ActorComponent>().contactDamage;
    world.damage(
      entityId: world.playerId,
      amount: damage,
      sourceEntityId: zombie.id,
    );
  }

  Direction _directionBetween(GridPoint from, GridPoint to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    if (dx.abs() >= dy.abs()) {
      return dx >= 0 ? Direction.east : Direction.west;
    }
    return dy >= 0 ? Direction.south : Direction.north;
  }
}
