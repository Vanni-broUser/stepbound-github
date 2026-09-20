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

  test('a zombie keeps pursuing the last player position it saw', () {
    final factory = EntityFactory(BalanceConfig.standard());
    final world = WorldState(
      map: TileMap.fromAscii(const <String>[
        '############',
        '#..........#',
        '############',
      ]),
      entities: <Entity>[
        factory.player(id: 'player', position: const GridPoint(1, 1)),
        factory.zombie(
          id: 'zombie',
          kind: EntityKind.wanderer,
          position: const GridPoint(7, 1),
        ),
      ],
      playerId: 'player',
      random: SeededRandom(1),
    );

    final scheduler = const TurnScheduler()
      ..advance(world, const WaitAction())
      ..advance(world, const WaitAction());
    expect(
      world.entities['zombie']!.component<PositionComponent>().position,
      const GridPoint(6, 1),
    );

    world.player.component<PositionComponent>().position = const GridPoint(
      10,
      1,
    );
    scheduler
      ..advance(world, const WaitAction())
      ..advance(world, const WaitAction());

    expect(
      world.entities['zombie']!.component<PositionComponent>().position,
      const GridPoint(5, 1),
    );
  });

  test('a newly heard noise affects the same world reaction', () {
    final world = corridorWorld(
      EntityKind.sprinter,
      zombiePosition: const GridPoint(4, 1),
    );
    world.entities['zombie']!.component<PositionComponent>().facing =
        Direction.east;

    const TurnScheduler().advance(world, const MoveAction(Direction.east));

    expect(
      world.entities['zombie']!.component<PositionComponent>().position,
      const GridPoint(3, 1),
    );
  });
}

int _xAfterWaits(EntityKind kind, int waits) {
  final world = corridorWorld(kind);
  for (var index = 0; index < waits; index++) {
    const TurnScheduler().advance(world, const WaitAction());
  }
  return world.entities['zombie']!.component<PositionComponent>().position.x;
}
