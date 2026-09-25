import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

import 'test_world.dart';

void main() {
  test('a blind zombie follows the last audible player position', () {
    final world = corridorWorld(
      EntityKind.blind,
      zombiePosition: const GridPoint(4, 1),
    );

    const TurnScheduler().advance(world, const MoveAction(Direction.east));
    expect(
      world.entities['zombie']!.component<HearingComponent>().lastHeard,
      const GridPoint(2, 1),
    );

    const TurnScheduler().advance(world, const WaitAction());
    expect(
      world.entities['zombie']!.component<PositionComponent>().position,
      const GridPoint(3, 1),
    );
  });
}
