import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('every street and barracks row has the same width', () {
    for (final rows in <List<String>>[streetLevelRows, barracksRows]) {
      final width = rows.first.length;
      expect(rows.every((row) => row.length == width), isTrue);
    }
  });

  test('the player starts unarmed with no bullets', () {
    final ammo = createStreetWorld().player.component<AmmoComponent>();
    expect(ammo.hasGun, isFalse);
    expect(ammo.loaded, 0);
    expect(ammo.reserve, 0);
  });

  test('the crossroads opens north and east but not south', () {
    final map = createStreetWorld().map;
    expect(map.tileAt(const GridPoint(16, 30)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(30, 46)).isWalkable, isTrue);
    expect(map.tileAt(const GridPoint(16, 50)).isWalkable, isFalse);
  });

  test('the streets end against buildings, the north one at the barracks', () {
    final map = createStreetWorld().map;
    expect(map.tileAt(const GridPoint(3, 46)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(40, 46)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(15, 16)).isWalkable, isFalse);
    expect(map.tileAt(const GridPoint(16, 16)).isWalkable, isTrue);
  });

  test('the only zombie outside waits east of the crossroads', () {
    final world = createStreetWorld();
    final zombies = world.entities.values
        .where((entity) => entity.kind != EntityKind.player)
        .toList();
    expect(zombies, hasLength(1));
    expect(zombies.single.id, tutorialZombieId);
    final position = zombies.single.component<PositionComponent>().position;
    // The view is 24 tiles wide and starts clamped to the west end.
    expect(position.x, greaterThanOrEqualTo(24));
  });

  test('backpacks: ammo on the street and by the accident, pistol in the '
      'barracks', () {
    final pickups = createStreetWorld().pickups;
    expect(pickups[ammoBackpackId]!.active, isTrue);
    expect(pickups[ammoBackpackId]!.ammo, 2);
    expect(pickups[accidentBackpackId]!.active, isTrue);
    expect(pickups[accidentBackpackId]!.ammo, 4);
    final gun = pickups[gunBackpackId]!;
    expect(gun.gun, isTrue);
    expect(levelRegions.last.indoor, isTrue);
    expect(levelRegions.last.bounds.contains(gun.position), isTrue);
  });

  test('interacting with a backpack collects its content', () {
    final world = createStreetWorld();
    final backpack = world.pickups[ammoBackpackId]!;
    world.player.component<PositionComponent>()
      ..position = backpack.position.step(Direction.south)
      ..facing = Direction.north;

    const MoveAction(Direction.north).resolve(world);
    expect(
      world.player.component<PositionComponent>().position,
      backpack.position.step(Direction.south),
      reason: 'a backpack blocks its tile',
    );

    final events = const TurnScheduler().advance(world, const InteractAction());
    final pickedUp = events.whereType<PickedUpEvent>().single;
    expect(pickedUp.ammo, 2);
    expect(backpack.active, isFalse);
    expect(backpack.collected, isTrue);
    final ammo = world.player.component<AmmoComponent>();
    expect(ammo.loaded, 2);
    expect(ammo.hasGun, isFalse);
  });

  test('without the pistol the player cannot shoot', () {
    final world = createStreetWorld();
    world.player.component<AmmoComponent>().loaded = 2;
    final events = const TurnScheduler().advance(world, const ShootAction());
    expect(events.whereType<DryFiredEvent>(), hasLength(1));
    expect(world.player.component<AmmoComponent>().loaded, 2);
  });

  test('stepping into the crossroads alerts the zombie at once', () {
    final world = createStreetWorld();
    world.player.component<PositionComponent>().position = const GridPoint(
      13,
      45,
    );
    final events = const TurnScheduler().advance(
      world,
      const MoveAction(Direction.east),
    );
    expect(events.whereType<AlertedEvent>().single.entityId, tutorialZombieId);
    expect(
      events.whereType<MovedEvent>().where(
        (event) => event.entityId == tutorialZombieId,
      ),
      hasLength(1),
      reason: 'it steps towards the player on the turn it notices them',
    );
  });

  group('doors', () {
    GridPoint walk(WorldState world, GridPoint from, Direction direction) {
      world.player.component<PositionComponent>().position = from;
      final events = const TurnScheduler().advance(
        world,
        MoveAction(direction),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      return world.player.component<PositionComponent>().position;
    }

    bool inside(GridPoint tile) => levelRegions.last.bounds.contains(tile);

    test('the front door leads inside the barracks and back out', () {
      final world = createStreetWorld();
      final inDoor = walk(world, const GridPoint(16, 17), Direction.north);
      expect(inside(inDoor), isTrue);
      final outDoor = walk(world, inDoor, Direction.south);
      expect(outDoor, const GridPoint(16, 17));
    });

    test('the back door opens on the street north of the barracks', () {
      final world = createStreetWorld();
      final backDoor = world.portals.keys.firstWhere(
        (tile) => inside(tile) && tile.y == barracksOrigin.y + 2,
      );
      final out = walk(world, backDoor.step(Direction.south), Direction.north);
      expect(out, const GridPoint(16, 9));
      expect(world.map.tileAt(out).isWalkable, isTrue);
    });
  });

  test('the barracks has lamps and two carabinieri waiting in the dark', () {
    expect(barracksLights(), isNotEmpty);
    expect(barracksLights().where((light) => light.flickers), isNotEmpty);
    expect(carabiniereSpawns(), hasLength(2));
    final world = createStreetWorld();
    for (final spawn in carabiniereSpawns()) {
      expect(world.map.tileAt(spawn).isWalkable, isTrue);
    }
  });

  test('the carabiniere in the middle steps south into the lamp light', () {
    final world = createStreetWorld();
    // Mario a few steps past the front door, where the carabinieri come out.
    world.player.component<PositionComponent>().position = GridPoint(
      barracksOrigin.x + 10,
      barracksOrigin.y + 11,
    );
    final spawn = carabiniereSpawns().firstWhere(
      (tile) => tile.x == barracksOrigin.x + 10,
    );
    final carabiniere = createCarabiniere('carabiniere-0', spawn);
    world.entities[carabiniere.id] = carabiniere;
    final position = carabiniere.component<PositionComponent>();
    var before = position.position;
    while (true) {
      const TurnScheduler().advance(world, const WaitAction());
      if (position.position.y > before.y) {
        break;
      }
      before = position.position;
    }
    bool lit(GridPoint tile) => barracksLights().any(
      (light) =>
          (light.tile.x - tile.x).abs() + (light.tile.y - tile.y).abs() <= 1,
    );
    expect(lit(before), isFalse, reason: 'still in the dark at $before');
    expect(
      lit(position.position),
      isTrue,
      reason: 'lit at ${position.position}',
    );
  });

  test('fires burn on three cars, three bins and five windows', () {
    final spots = streetFireSpots();
    int count(FireKind kind) => spots.where((s) => s.kind == kind).length;
    expect(count(FireKind.car), 3);
    expect(count(FireKind.bin), 3);
    expect(count(FireKind.window), 5);
  });

  test('resting at the camp beyond the barracks asks the game to save', () {
    final world = createStreetWorld();
    final camp = world.campfires.single;
    expect(campfireNames()[camp], 'Accampamento dietro la caserma');
    expect(world.map.tileAt(camp).isWalkable, isFalse);
    world.player.component<PositionComponent>()
      ..position = camp.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(events.whereType<CampfireUsedEvent>().single.at, camp);
  });

  test('the whole world survives a save and a load', () {
    final world = createStreetWorld();
    world.pickups[ammoBackpackId]!
      ..active = false
      ..collected = true;
    world.player.component<AmmoComponent>().loaded = 2;
    final restored = WorldState.fromJson(
      jsonDecode(jsonEncode(world.toJson())) as Map<String, Object?>,
    );
    expect(restored.toJson(), world.toJson());
    expect(restored.campfires, world.campfires);
    expect(restored.portals.length, world.portals.length);
    expect(restored.pickups[ammoBackpackId]!.collected, isTrue);
  });
}
