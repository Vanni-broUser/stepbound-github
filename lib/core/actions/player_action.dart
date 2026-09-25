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
    }
    world.emitNoise(
      origin: position.position,
      radius: world.map.tileAt(position.position).movementNoiseRadius,
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

    if (world.campfires.contains(target)) {
      world.emit(CampfireUsedEvent(at: target));
      return;
    }

    if (world.travelMaps.contains(target)) {
      world.emit(TravelMapUsedEvent(at: target));
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
      final ammo = world.player.component<AmmoComponent>()..add(pickup.ammo);
      if (pickup.gun) {
        ammo.hasGun = true;
      }
      world.emit(
        PickedUpEvent(
          pickupId: pickup.id,
          at: target,
          ammo: pickup.ammo,
          gun: pickup.gun,
          incense: pickup.incense,
          episcopalRing: pickup.episcopalRing,
          cultistRobe: pickup.cultistRobe,
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

final class WaitAction extends PlayerAction {
  const WaitAction();

  @override
  int get tickCost => 1;

  @override
  void resolve(WorldState world) {
    world.emit(WaitedEvent(world.playerId));
  }
}
