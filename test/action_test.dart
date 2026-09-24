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
