import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  GridPoint mario(WorldState world) =>
      world.player.component<PositionComponent>().position;

  List<WorldEvent> interact(WorldState world) =>
      const TurnScheduler().advance(world, const InteractAction());

  test('the grappling hook lies in a backpack in the Baths of Diocletian', () {
    final world = createGameWorld();
    final hook = world.pickups[grapplingHookPickupId]!;
    expect(hook.grapplingHook, isTrue);
    expect(hook.active, isTrue);
    expect(hook.position, grapplingHookTile);
    expect(placeAt(hook.position)?.id, PlaceId.termeDiocleziano);
    expect(
      world.pickups.values.where((pickup) => pickup.grapplingHook),
      hasLength(1),
    );
    // It can be walked up to from the portal.
    final entrance = world.portals[termePortalTile]!.to;
    final reached = world.map.floodFillDistances(entrance, maxDistance: 2000);
    expect(
      Direction.values.any(
        (side) => reached.containsKey(hook.position.step(side)),
      ),
      isTrue,
    );
  });

  test('picking it up gives Mario the hook and says so', () {
    final world = createGameWorld();
    final hook = world.pickups[grapplingHookPickupId]!;
    world.player.component<PositionComponent>()
      ..position = hook.position.step(Direction.north)
      ..facing = Direction.south;
    final events = interact(world);
    expect(events.whereType<PickedUpEvent>().single.grapplingHook, isTrue);
    expect(world.player.component<AmmoComponent>().grapplingHook, isTrue);
    expect(hook.collected, isTrue);
  });

  test('every gap in Molfetta, and the one in Rome, is crossed both '
      'ways', () {
    final world = createGameWorld();
    expect(world.grapples, <GridPoint, Portal>{
      ...hometownGrapples,
      ...romeGrapples,
    });
    expect(world.grapples, hasLength(8));
    for (final MapEntry(key: edge, value: grapple) in world.grapples.entries) {
      expect(world.map.tileAt(edge).isWalkable, isFalse, reason: '$edge');
      expect(world.map.tileAt(grapple.to).isWalkable, isTrue, reason: '$edge');
      expect(placeAt(grapple.to), placeAt(edge), reason: 'one roofscape');
      // The way back lands where the way there was thrown from.
      final far = grapple.to.step(grapple.facing.opposite);
      final back = world.grapples[far];
      expect(back, isNotNull, reason: 'no way back from $far');
      expect(back!.to, edge.step(grapple.facing.opposite));
    }
  });

  group('at the edge of a roof', () {
    for (final (name, edge) in <(String, GridPoint Function())>[
      ('past the airliner', () => rooftopGapTile),
      ('on the Duomo tower', () => duomoTowerLookoutTile),
      ('on the hospital', () => hospitalRoofLookoutTile),
    ]) {
      test('$name, without the hook Mario only looks over', () {
        final world = createGameWorld();
        final from = world.grapples[edge()]!;
        world.player.component<PositionComponent>()
          ..position = edge().step(from.facing.opposite)
          ..facing = from.facing;
        final events = interact(world);
        expect(events.whereType<LookedOutEvent>().single.at, edge());
        expect(events.whereType<TeleportedEvent>(), isEmpty);
      });

      test('$name, with the hook he crosses, and comes back', () {
        final world = createGameWorld();
        world.player.component<AmmoComponent>().grapplingHook = true;
        final there = world.grapples[edge()]!;
        final start = edge().step(there.facing.opposite);
        world.player.component<PositionComponent>()
          ..position = start
          ..facing = there.facing;

        var events = interact(world);
        final swing = events.whereType<TeleportedEvent>().single;
        expect(swing.grappled, isTrue);
        expect(swing.from, start);
        expect(mario(world), there.to);
        expect(events.whereType<LookedOutEvent>(), isEmpty);

        // Turned round, the far edge is right in front of him.
        world.player.component<PositionComponent>().facing =
            there.facing.opposite;
        events = interact(world);
        expect(events.whereType<TeleportedEvent>().single.grappled, isTrue);
        expect(mario(world), start);
        expect(
          world.player.component<PositionComponent>().facing,
          there.facing.opposite,
        );
      });
    }
  });

  test('the hook does not land Mario on a zombie', () {
    final world = createGameWorld();
    world.player.component<AmmoComponent>().grapplingHook = true;
    final there = world.grapples[rooftopGapTile]!;
    final zombie = world.entities.values.firstWhere(
      (entity) => entity.kind != EntityKind.player,
    );
    zombie.component<PositionComponent>().position = there.to;
    final start = rooftopGapTile.step(there.facing.opposite);
    world.player.component<PositionComponent>()
      ..position = start
      ..facing = there.facing;
    final events = interact(world);
    expect(events.whereType<TeleportedEvent>(), isEmpty);
    expect(events.whereType<BlockedEvent>().single.at, there.to);
    expect(mario(world), start);
  });

  test('the backpack on the other tower is reached with the hook', () {
    final world = createGameWorld();
    final landing = world.grapples[duomoTowerLookoutTile]!.to;
    final reached = world.map.floodFillDistances(landing, maxDistance: 400);
    expect(
      Direction.values.any(
        (side) => reached.containsKey(duomoFarTowerBackpackTile.step(side)),
      ),
      isTrue,
    );
  });

  test('the hook and the ways across survive a save', () {
    final world = createGameWorld();
    world.player.component<AmmoComponent>().grapplingHook = true;
    final saved = saveGameWorld(world);
    final restored = restoreGameWorld(saved);
    expect(restored.player.component<AmmoComponent>().grapplingHook, isTrue);
    final all = <GridPoint, Portal>{...hometownGrapples, ...romeGrapples};
    expect(restored.grapples.keys, unorderedEquals(all.keys));
    for (final MapEntry(key: edge, value: grapple) in all.entries) {
      expect(restored.grapples[edge]!.to, grapple.to);
      expect(restored.grapples[edge]!.facing, grapple.facing);
    }

    final without = restoreGameWorld(saveGameWorld(createGameWorld()));
    expect(without.player.component<AmmoComponent>().grapplingHook, isFalse);
  });

  test('the backpack on the other tower holds a round for the rocket '
      'launcher, and Mario carries it without the launcher', () {
    final world = createGameWorld();
    final backpack = world.pickups[duomoFarTowerBackpackId]!;
    expect(backpack.rockets, duomoFarTowerBackpackRockets);
    expect(backpack.rockets, 2);
    expect(backpack.ammo, 0);
    world.player.component<PositionComponent>()
      ..position = backpack.position.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(events.whereType<PickedUpEvent>().single.rockets, 2);
    final ammo = world.player.component<AmmoComponent>();
    expect(ammo.rockets, 2);
    expect(ammo.hasRocketLauncher, isFalse);

    final restored = restoreGameWorld(saveGameWorld(world));
    expect(restored.player.component<AmmoComponent>().rockets, 2);
  });

  test("two cultists wait on the other tower's roof from the start, "
      'walkable to Mario and not on the backpack', () {
    final world = createGameWorld();
    final landing = world.grapples[duomoTowerLookoutTile]!.to;
    final reached = world.map.floodFillDistances(landing, maxDistance: 400);
    final cultists = <Entity>[
      for (final entity in world.entities.values)
        if (entity.id.startsWith(duomoFarTowerCultistPrefix)) entity,
    ];
    expect(cultists, hasLength(2));
    for (final cultist in cultists) {
      final at = cultist.component<PositionComponent>().position;
      expect(cultist.kind, EntityKind.cultist);
      expect(duomoFarTowerCultistTiles, contains(at));
      expect(placeAt(at)?.id, PlaceId.duomoTowerRoof);
      expect(world.map.tileAt(at).isWalkable, isTrue);
      expect(reached.containsKey(at), isTrue);
      expect(at, isNot(duomoFarTowerBackpackTile));
    }
  });
}
