import 'dart:math' as math;

import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/world.dart';
import 'package:stepbound/core/world_event.dart';

final class ZombieAi {
  const ZombieAi();

  /// The furthest a zombie ever looks for a way round before giving up and
  /// waiting. What it walks towards is at most a hearing range away —
  /// twenty tiles for the blind one — so this allows a generous detour
  /// while keeping an unreachable target from costing the whole block.
  static const int pathfindingRange = 48;

  /// How far a zombie [distance] tiles from where it is going will look:
  /// three times the straight line, plus a little slack for short hops.
  ///
  /// A flat cap is no help where it hurts most. With the player hemmed in
  /// by the crowd, every zombie a couple of tiles away asks for a path
  /// that does not exist, and a flat [pathfindingRange] lets each of them
  /// comb a couple of thousand tiles to find that out — every zombie,
  /// every tick, exactly when the game is busiest. Tied to the distance
  /// the same answer costs a tenth of that, and a zombie two tiles away
  /// stops considering a walk round the block to get there.
  static int detourFor(int distance) =>
      math.min(distance * 3 + 4, pathfindingRange);

  /// Runs every tick, before the zombie's energy is checked. Each time it
  /// starts going after the player (by sight, by smell, or by walking into
  /// its alert trigger) it raises the alert, even if it had lost him or was
  /// only following a noise, and gets to act on this very tick, so it steps
  /// towards the player at once instead of after a full wait.
  void perceive(WorldState world, Entity zombie) {
    final hearing = zombie.component<HearingComponent>();
    if (!zombie.isAlive || !world.player.isAlive) {
      hearing.hunting = false;
      return;
    }
    final playerPosition = world.player.component<PositionComponent>().position;
    final trigger = world.alertTriggers[zombie.id];
    final triggered = trigger != null && trigger.contains(playerPosition);
    if (!triggered &&
        !_canSeePlayer(world, zombie) &&
        !_isTracking(world, zombie)) {
      hearing.hunting = false;
      return;
    }
    if (triggered) {
      world.alertTriggers.remove(zombie.id);
    }
    hearing.lastHeard = playerPosition;
    if (hearing.hunting) {
      return;
    }
    hearing.hunting = true;
    world.emit(
      AlertedEvent(
        entityId: zombie.id,
        at: zombie.component<PositionComponent>().position,
      ),
    );
    final actor = zombie.component<ActorComponent>();
    actor.energy = actor.tickCost - 1;
  }

  void takeTurn(WorldState world, Entity zombie) {
    if (!zombie.isAlive || !world.player.isAlive) {
      return;
    }

    final zombiePosition = zombie.component<PositionComponent>();
    final playerPosition = world.player.component<PositionComponent>().position;

    if (zombiePosition.position.manhattanDistanceTo(playerPosition) == 1 ||
        _inReach(world, zombie)) {
      zombiePosition.facing = _directionBetween(
        zombiePosition.position,
        playerPosition,
      );
      _attackPlayer(world, zombie);
      return;
    }

    final hearing = zombie.component<HearingComponent>();
    final seesPlayer =
        _canSeePlayer(world, zombie) || _isTracking(world, zombie);
    if (seesPlayer) {
      hearing.lastHeard = playerPosition;
    }
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
      isBlocked: (point) => world.isBlocked(point, excluding: zombie.id),
      maxDistance: detourFor(
        zombiePosition.position.manhattanDistanceTo(target),
      ),
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

    // Unaware zombies see in a cone ahead; a hunting zombie looks all
    // around, so doubling back in front of it does not shake it off.
    final aware = zombie.component<HearingComponent>().lastHeard != null;
    if (!aware) {
      final forward = dx * position.facing.dx + dy * position.facing.dy;
      final lateral = (dx * position.facing.dy - dy * position.facing.dx).abs();
      if (forward <= 0 || lateral > forward) {
        return false;
      }
    }
    return world.map.hasLineOfSight(position.position, playerPosition);
  }

  /// A hunting zombie keeps smelling the player a couple of tiles beyond its
  /// sight, even behind a wall: only real distance loses it.
  bool _isTracking(WorldState world, Entity zombie) {
    if (zombie.component<HearingComponent>().lastHeard == null) {
      return false;
    }
    final vision = zombie.component<VisionComponent>();
    if (vision.range == 0) {
      return false;
    }
    final playerPosition = world.player.component<PositionComponent>().position;
    final position = zombie.component<PositionComponent>().position;
    return position.manhattanDistanceTo(playerPosition) <= vision.range + 2;
  }

  /// A baton hits the player further than one tile away when they stand in
  /// a straight line with nothing (wall, table, body, backpack) in between.
  bool _inReach(WorldState world, Entity zombie) {
    final reach = zombie.component<ActorComponent>().attackReach;
    if (reach < 2) {
      return false;
    }
    final from = zombie.component<PositionComponent>().position;
    final to = world.player.component<PositionComponent>().position;
    final distance = from.manhattanDistanceTo(to);
    if (distance < 2 ||
        distance > reach ||
        (from.x != to.x && from.y != to.y)) {
      return false;
    }
    final direction = _directionBetween(from, to);
    var cursor = from.step(direction);
    while (cursor != to) {
      if (!world.map.tileAt(cursor).isWalkable ||
          world.entityAt(cursor, excluding: zombie.id) != null ||
          world.pickupAt(cursor) != null) {
        return false;
      }
      cursor = cursor.step(direction);
    }
    return true;
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
