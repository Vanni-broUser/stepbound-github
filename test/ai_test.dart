import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

import 'test_world.dart';

void main() {
  group('energy scheduler', () {
    test('zombie archetypes act at their configured speeds', () {
      expect(_xAfterWaits(EntityKind.sprinter, 1), 4);
      expect(_xAfterWaits(EntityKind.sprinter, 2), 3);

      expect(_xAfterWaits(EntityKind.wanderer, 1), 5);
      expect(_xAfterWaits(EntityKind.wanderer, 2), 4);

      expect(_xAfterWaits(EntityKind.brute, 2), 5);
      expect(_xAfterWaits(EntityKind.brute, 3), 4);
    });

    test('actors outside forty tiles are not simulated', () {
      final factory = EntityFactory(BalanceConfig.standard());
      final world = WorldState(
        map: TileMap.fromAscii(const <String>[
          '#############################################',
          '#...........................................#',
          '#############################################',
        ]),
        entities: <Entity>[
          factory.player(id: 'player', position: const GridPoint(1, 1)),
          factory.zombie(
            id: 'zombie',
            kind: EntityKind.sprinter,
            position: const GridPoint(42, 1),
          ),
        ],
        playerId: 'player',
        random: SeededRandom(1),
      );

      const TurnScheduler().advance(world, const WaitAction());

      expect(
        world.entities['zombie']!.component<PositionComponent>().position,
        const GridPoint(42, 1),
      );
    });
  });
}

int _xAfterWaits(EntityKind kind, int waits) {
  final world = corridorWorld(kind);
  for (var index = 0; index < waits; index++) {
    const TurnScheduler().advance(world, const WaitAction());
  }
  return world.entities['zombie']!.component<PositionComponent>().position.x;
}
