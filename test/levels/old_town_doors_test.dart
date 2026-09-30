import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('the damaged doors of the old town stay shut, and facing one from '
      'the alley in front of it looks at it', () {
    expect(oldTownDamagedDoorTiles, hasLength(3));
    for (final door in oldTownDamagedDoorTiles) {
      final world = createGameWorld();
      for (final entity in world.entities.values) {
        if (entity.kind != EntityKind.player) {
          entity.component<HealthComponent>().current = 0;
        }
      }
      final front = door.step(Direction.south);
      expect(world.map.tileAt(door).isWalkable, isFalse, reason: '$door');
      expect(world.map.tileAt(front).isWalkable, isTrue, reason: '$front');
      expect(world.lookouts, contains(door));

      world.player.component<PositionComponent>()
        ..position = front
        ..facing = Direction.north;
      final events = const TurnScheduler().advance(
        world,
        const InteractAction(),
      );

      expect(events.whereType<LookedOutEvent>().single.at, door);
      expect(world.map.tileAt(door).isWalkable, isFalse);
    }
  });
}
