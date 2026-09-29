import 'dart:math' as math;

import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';
import 'package:stepbound/core/grid/tile_map.dart';
import 'package:stepbound/core/items/pickup.dart';
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

    // Standing in a doorway, pushing on the way the door leads goes
    // through it, even into its wall: a door can land Mario on itself.
    final doorway = world.portals[position.position];
    if (doorway != null &&
        doorway.facing == direction &&
        (!world.map.contains(target) || !world.map.tileAt(target).isWalkable)) {
      final from = position.position;
      position
        ..position = doorway.to
        ..facing = doorway.facing;
      world.emit(
        TeleportedEvent(entityId: player.id, from: from, to: doorway.to),
      );
      _landOnZombie(world);
      return;
    }

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
    if (world.pickupAt(target) != null) {
      world.emit(
        BlockedEvent(entityId: player.id, at: target, reason: 'pickup'),
      );
      return;
    }

    final previous = position.position;
    position.position = target;
    world.emit(MovedEvent(entityId: player.id, from: previous, to: target));
    final portal = world.portals[target];
    if (portal != null) {
      position
        ..position = portal.to
        ..facing = portal.facing;
      world.emit(
        TeleportedEvent(entityId: player.id, from: target, to: portal.to),
      );
      _landOnZombie(world);
    }
    world.emitNoise(
      origin: position.position,
      radius: world.map.tileAt(position.position).movementNoiseRadius,
      sourceEntityId: player.id,
    );
  }

  /// Through a door straight into a zombie standing right behind it: the
  /// zombies do not get the turn after a door, but this one has Mario in
  /// its arms already, and it is the end of him.
  static void _landOnZombie(WorldState world) {
    final player = world.player;
    final zombie = world.entityAt(
      player.component<PositionComponent>().position,
      excluding: player.id,
    );
    if (zombie == null) {
      return;
    }
    world.damage(
      entityId: player.id,
      amount: player.component<HealthComponent>().current,
      sourceEntityId: zombie.id,
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

    if (world.campfires.contains(target)) {
      world.emit(CampfireUsedEvent(at: target));
      return;
    }

    if (world.travelMaps.contains(target)) {
      world.emit(TravelMapUsedEvent(at: target));
      return;
    }

    final ammo = world.player.component<AmmoComponent>();
    final grapple = world.grapples[target];
    if (grapple != null && ammo.grapplingHook) {
      _grapple(world, grapple);
      return;
    }

    if (world.lookouts.contains(target)) {
      world.emit(LookedOutEvent(at: target));
      return;
    }

    final bars = world.controls.remove(target);
    if (bars != null) {
      for (var y = bars.top; y <= bars.bottom; y++) {
        for (var x = bars.left; x <= bars.right; x++) {
          world.map.setTile(GridPoint(x, y), const Tile(TileKind.floor));
        }
      }
      world
        ..emit(ControlUsedEvent(at: target, opened: bars))
        ..emitNoise(origin: target, radius: 6, sourceEntityId: world.playerId);
      return;
    }

    final pickup = world.pickupAt(target);
    if (pickup != null) {
      pickup
        ..active = false
        ..collected = true;
      ammo
        ..add(pickup.ammo)
        ..molotovs += pickup.molotovs;
      if (pickup.gun) {
        ammo.hasGun = true;
      }
      if (pickup.grapplingHook) {
        ammo.grapplingHook = true;
      }
      world.emit(
        PickedUpEvent(
          pickupId: pickup.id,
          at: target,
          ammo: pickup.ammo,
          gun: pickup.gun,
          molotovs: pickup.molotovs,
          incense: pickup.incense,
          episcopalRing: pickup.episcopalRing,
          cultistRobe: pickup.cultistRobe,
          duomoKey: pickup.duomoKey,
          grapplingHook: pickup.grapplingHook,
        ),
      );
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
      case TileKind.floor ||
          TileKind.wall ||
          TileKind.debris ||
          TileKind.obstacle ||
          TileKind.fire:
        world.emit(NoInteractionEvent(target));
    }
  }

  /// Over the gap to [grapple]'s roof, unless somebody stands on the spot
  /// the hook would put Mario down on.
  static void _grapple(WorldState world, Portal grapple) {
    if (world.entityAt(grapple.to, excluding: world.playerId) != null) {
      world.emit(
        BlockedEvent(
          entityId: world.playerId,
          at: grapple.to,
          reason: 'entity',
        ),
      );
      return;
    }
    final position = world.player.component<PositionComponent>();
    final from = position.position;
    position
      ..position = grapple.to
      ..facing = grapple.facing;
    world.emit(
      TeleportedEvent(
        entityId: world.playerId,
        from: from,
        to: grapple.to,
        grappled: true,
      ),
    );
  }
}

final class ShootAction extends PlayerAction {
  const ShootAction({this.damage = 1, this.noiseRadius = 14});

  final int damage;
  final int noiseRadius;

  @override
  int get tickCost => 1;

  @override
  void resolve(WorldState world) {
    final player = world.player;
    final ammo = player.component<AmmoComponent>();
    final position = player.component<PositionComponent>();
    if (!ammo.hasGun || ammo.loaded == 0) {
      world.emit(DryFiredEvent(entityId: player.id));
      return;
    }

    ammo.loaded -= 1;
    var cursor = position.position.step(position.facing);
    var impact = position.position;
    String? hitEntityId;
    while (world.map.contains(cursor)) {
      impact = cursor;
      if (world.map.tileAt(cursor).blocksSight) {
        break;
      }
      final target = world.entityAt(cursor, excluding: player.id);
      if (target != null) {
        hitEntityId = target.id;
        world.damage(
          entityId: target.id,
          amount: damage,
          sourceEntityId: player.id,
        );
        break;
      }
      cursor = cursor.step(position.facing);
    }

    world
      ..emit(
        ShotEvent(
          entityId: player.id,
          origin: position.position,
          impact: impact,
          direction: position.facing,
          hitEntityId: hitEntityId,
        ),
      )
      ..emitNoise(
        origin: position.position,
        radius: noiseRadius,
        sourceEntityId: player.id,
      );
  }
}

/// Throws a molotov in an arc, over whatever stands in between, to
/// [target]: everyone on the 3x3 square around it takes [damage], and the
/// blast is heard far off. [target] must be at least [minRange] tiles off
/// on one axis, so the square never reaches Mario, and no further than
/// [maxRange] tiles as the crow flies.
final class ThrowMolotovAction extends PlayerAction {
  const ThrowMolotovAction(
    this.target, {
    this.damage = 3,
    this.noiseRadius = 16,
  });

  final GridPoint target;
  final int damage;
  final int noiseRadius;

  static const int minRange = 2;
  static const int maxRange = 6;

  /// Tiles from the centre of the square to its edge.
  static const int blastRadius = 1;

  /// Whether [target] is a spot Mario, standing on [from], can throw to.
  static bool canReach(GridPoint from, GridPoint target) {
    final dx = target.x - from.x;
    final dy = target.y - from.y;
    return math.max(dx.abs(), dy.abs()) >= minRange &&
        dx * dx + dy * dy <= maxRange * maxRange;
  }

  /// The tiles the blast covers around [centre], those on [map] only.
  static Iterable<GridPoint> blastArea(GridPoint centre, TileMap map) sync* {
    for (var y = centre.y - blastRadius; y <= centre.y + blastRadius; y++) {
      for (var x = centre.x - blastRadius; x <= centre.x + blastRadius; x++) {
        final tile = GridPoint(x, y);
        if (map.contains(tile)) {
          yield tile;
        }
      }
    }
  }

  /// Where Mario turns to throw at [target]: the axis it lies furthest on.
  static Direction facingToward(GridPoint from, GridPoint target) {
    final dx = target.x - from.x;
    final dy = target.y - from.y;
    if (dx.abs() >= dy.abs()) {
      return dx >= 0 ? Direction.east : Direction.west;
    }
    return dy >= 0 ? Direction.south : Direction.north;
  }

  @override
  int get tickCost => 1;

  @override
  void resolve(WorldState world) {
    final player = world.player;
    final ammo = player.component<AmmoComponent>();
    final position = player.component<PositionComponent>();
    if (ammo.molotovs == 0 ||
        !world.map.contains(target) ||
        !canReach(position.position, target)) {
      world.emit(
        BlockedEvent(entityId: player.id, at: target, reason: 'throw'),
      );
      return;
    }
    ammo.molotovs -= 1;
    position.facing = facingToward(position.position, target);
    world.emit(
      MolotovThrownEvent(
        entityId: player.id,
        origin: position.position,
        target: target,
      ),
    );
    for (final tile in blastArea(target, world.map)) {
      final victim = world.entityAt(tile);
      if (victim != null) {
        world.damage(
          entityId: victim.id,
          amount: damage,
          sourceEntityId: player.id,
        );
      }
    }
    world.emitNoise(
      origin: target,
      radius: noiseRadius,
      sourceEntityId: player.id,
    );
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
