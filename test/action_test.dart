import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

import 'test_world.dart';

void main() {
  test('interact opens the faced door and emits events', () {
    final world = playerOnlyWorld(
      rows: const <String>['#####', '#.+.#', '#####'],
    );

    final events = const TurnScheduler().advance(world, const InteractAction());

    expect(world.tick, 1);
    expect(world.map.tileAt(const GridPoint(2, 1)).kind, TileKind.openDoor);
    expect(events.whereType<DoorChangedEvent>(), hasLength(1));
    expect(events.whereType<NoiseEvent>(), hasLength(1));
  });

  test('interact with a travel map emits its dedicated event', () {
    const map = GridPoint(2, 1);
    final world = playerOnlyWorld(travelMaps: const <GridPoint>[map]);

    final events = const TurnScheduler().advance(world, const InteractAction());

    expect(events.whereType<TravelMapUsedEvent>().single.at, map);
    expect(events.whereType<NoInteractionEvent>(), isEmpty);
    expect(world.travelMaps, contains(map));
  });

  test('interact with a lookout says so, and leaves it to be looked at '
      'again', () {
    const gap = GridPoint(2, 1);
    final world = playerOnlyWorld(lookouts: const <GridPoint>[gap]);

    final events = const TurnScheduler().advance(world, const InteractAction());

    expect(events.whereType<LookedOutEvent>().single.at, gap);
    expect(events.whereType<NoInteractionEvent>(), isEmpty);
    expect(world.lookouts, contains(gap));
  });

  test('shooting consumes ammo and hits the first zombie in line', () {
    final world = corridorWorld(
      EntityKind.wanderer,
      zombiePosition: const GridPoint(4, 1),
    );

    final events = const TurnScheduler().advance(world, const ShootAction());

    expect(world.tick, 1);
    expect(world.player.component<AmmoComponent>().loaded, 5);
    expect(world.entities['zombie']!.isAlive, isFalse);
    expect(events.whereType<ShotEvent>().single.hitEntityId, 'zombie');
    expect(events.whereType<NoiseEvent>().single.radius, 14);
  });

  test('a cultist zombie needs three pistol shots to go down', () {
    final world = corridorWorld(
      EntityKind.cultist,
      zombiePosition: const GridPoint(4, 1),
    );
    final zombie = world.entities['zombie']!;

    const TurnScheduler().advance(world, const ShootAction());

    expect(zombie.isAlive, isTrue);
    expect(zombie.component<HealthComponent>().current, 2);

    const TurnScheduler().advance(world, const ShootAction());

    expect(zombie.isAlive, isTrue);
    expect(zombie.component<HealthComponent>().current, 1);

    const TurnScheduler().advance(world, const ShootAction());

    expect(zombie.isAlive, isFalse);
    expect(zombie.component<HealthComponent>().current, 0);
  });

  test('blocked movement consumes a turn without moving the player', () {
    final world = playerOnlyWorld(facing: Direction.west);

    final events = const TurnScheduler().advance(
      world,
      const MoveAction(Direction.west),
    );

    expect(world.tick, 1);
    expect(
      world.player.component<PositionComponent>().position,
      const GridPoint(1, 1),
    );
    expect(events.whereType<BlockedEvent>(), hasLength(1));
  });
}
