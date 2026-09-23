import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/core/systems/zombie_ai.dart';

import 'test_world.dart';

/// What [WorldState.entityAt] did before it had an index: every query in
/// these tests is checked against it, because the index is only worth
/// having as long as it answers the same.
Entity? scanFor(WorldState world, GridPoint point, {String? excluding}) {
  for (final entity in world.entities.values) {
    if (entity.id == excluding || !entity.isAlive) {
      continue;
    }
    if (entity.component<PositionComponent>().position == point) {
      return entity;
    }
  }
  return null;
}

void main() {
  final factory = EntityFactory(BalanceConfig.standard());

  group('the tile index', () {
    test('follows a position written straight into the component', () {
      final world = corridorWorld(EntityKind.wanderer);
      final zombie = world.entities['zombie']!;
      const from = GridPoint(5, 1);
      const to = GridPoint(3, 1);

      expect(world.entityAt(from), zombie);
      zombie.component<PositionComponent>().position = to;

      expect(world.entityAt(from), isNull);
      expect(world.entityAt(to), zombie);
      expect(world.entityAt(to), scanFor(world, to));
    });

    test('agrees with a full scan while everybody shuffles about', () {
      final world = corridorWorld(EntityKind.wanderer);
      for (var index = 0; index < 4; index++) {
        world.addEntity(
          factory.zombie(
            id: 'extra-$index',
            kind: EntityKind.wanderer,
            position: GridPoint(index + 2, 1),
          ),
        );
      }

      // A fixed shuffle, so a failure is the same failure every run.
      var step = 0;
      for (var round = 0; round < 12; round++) {
        for (final entity in world.entities.values) {
          entity.component<PositionComponent>().position = GridPoint(
            1 + (step++ % 6),
            1,
          );
        }
        for (var x = 0; x < 8; x++) {
          final point = GridPoint(x, 1);
          expect(
            world.entityAt(point),
            scanFor(world, point),
            reason: '$point',
          );
        }
      }
    });

    test('drops the dead out of the answers but not out of the world', () {
      final world = corridorWorld(EntityKind.wanderer);
      const point = GridPoint(5, 1);
      final zombie = world.entities['zombie']!;

      zombie.component<HealthComponent>().current = 0;

      expect(world.entityAt(point), isNull);
      expect(world.isBlocked(point), isFalse);
      expect(world.entities['zombie'], zombie);
    });

    test('leaves a corpse behind and still finds who walks over it', () {
      final world = corridorWorld(EntityKind.wanderer);
      const point = GridPoint(5, 1);
      world.entities['zombie']!.component<HealthComponent>().current = 0;
      world.player.component<PositionComponent>().position = point;

      expect(world.entityAt(point), world.player);
    });

    test('forgets whoever is replaced under the same id', () {
      final world = corridorWorld(EntityKind.wanderer);
      const old = GridPoint(5, 1);
      const fresh = GridPoint(2, 1);

      world.addEntity(
        factory.zombie(id: 'zombie', kind: EntityKind.brute, position: fresh),
      );

      expect(world.entityAt(old), isNull);
      expect(world.entityAt(fresh)!.kind, EntityKind.brute);
      expect(world.entities.length, 2);
    });

    test('will not let anyone join behind its back', () {
      final world = corridorWorld(EntityKind.wanderer);
      final stray = factory.zombie(
        id: 'stray',
        kind: EntityKind.blind,
        position: const GridPoint(3, 1),
      );

      expect(() => world.entities['stray'] = stray, throwsUnsupportedError);
    });
  });

  group('isBlocked', () {
    test('ignores the one asking and sees the backpacks', () {
      final world = WorldState(
        map: TileMap.fromAscii(const <String>[
          '########',
          '#......#',
          '########',
        ]),
        entities: <Entity>[
          factory.player(id: 'player', position: const GridPoint(1, 1)),
        ],
        playerId: 'player',
        random: SeededRandom(7),
        pickups: <Pickup>[
          Pickup(id: 'bag', position: const GridPoint(4, 1)),
          Pickup(id: 'hidden', position: const GridPoint(5, 1), active: false),
        ],
      );

      expect(world.isBlocked(const GridPoint(1, 1)), isTrue);
      expect(
        world.isBlocked(const GridPoint(1, 1), excluding: 'player'),
        isFalse,
      );
      expect(world.isBlocked(const GridPoint(4, 1)), isTrue);
      expect(world.isBlocked(const GridPoint(5, 1)), isFalse);
      expect(world.pickupAt(const GridPoint(5, 1)), isNull);
    });
  });

  group('shortestNextStep', () {
    final map = TileMap.fromAscii(const <String>[
      '#########',
      '#.......#',
      '#.#####.#',
      '#.......#',
      '#########',
    ]);

    test('walks the long way round when the short one is blocked', () {
      const start = GridPoint(1, 1);
      const target = GridPoint(7, 1);

      expect(
        map.shortestNextStep(
          start: start,
          target: target,
          isBlocked: (point) => point == const GridPoint(2, 1),
        ),
        const GridPoint(1, 2),
      );
    });

    test('the target tile itself is never in the way', () {
      expect(
        map.shortestNextStep(
          start: const GridPoint(1, 1),
          target: const GridPoint(2, 1),
          isBlocked: (point) => true,
        ),
        const GridPoint(2, 1),
      );
    });

    test('gives up past the cap instead of combing the whole map', () {
      const start = GridPoint(1, 1);
      const target = GridPoint(7, 3);
      final uncapped = map.shortestNextStep(start: start, target: target);

      expect(uncapped, isNotNull);
      expect(
        map.shortestNextStep(start: start, target: target, maxDistance: 100),
        uncapped,
      );
      expect(
        map.shortestNextStep(start: start, target: target, maxDistance: 3),
        isNull,
      );
    });

    test('answers the same with a cap wider than the walk', () {
      for (var y = 1; y <= 3; y += 2) {
        for (var x = 1; x <= 7; x++) {
          final target = GridPoint(x, y);
          expect(
            map.shortestNextStep(
              start: const GridPoint(1, 1),
              target: target,
              maxDistance: 64,
            ),
            map.shortestNextStep(start: const GridPoint(1, 1), target: target),
            reason: '$target',
          );
        }
      }
    });
  });

  group('the leash on a zombie looking for a way round', () {
    test('is short for a short hop and never longer than the flat cap', () {
      expect(ZombieAi.detourFor(2), 10);
      expect(
        ZombieAi.detourFor(20),
        ZombieAi.pathfindingRange,
        reason: 'as far as it can hear: it gets the whole allowance',
      );
      for (final distance in <int>[0, 1, 2, 8, 20, 100]) {
        expect(
          ZombieAi.detourFor(distance),
          lessThanOrEqualTo(ZombieAi.pathfindingRange),
          reason: '$distance',
        );
      }
    });

    test('a way round worth walking is still walked', () {
      // Mario two tiles away through the wall, the way round eight steps.
      final map = TileMap.fromAscii(const <String>[
        '######',
        '#....#',
        '####.#',
        '#....#',
        '######',
      ]);

      expect(
        map.shortestNextStep(
          start: const GridPoint(1, 3),
          target: const GridPoint(1, 1),
          maxDistance: ZombieAi.detourFor(2),
        ),
        const GridPoint(2, 3),
      );
    });

    test('a way round the whole block, for two tiles, is not', () {
      // The same two tiles apart, but the corridors meet far to the east:
      // twenty steps to walk two. The zombie waits instead.
      final map = TileMap.fromAscii(const <String>[
        '############',
        '#..........#',
        '##########.#',
        '#..........#',
        '############',
      ]);
      const zombie = GridPoint(1, 3);
      const player = GridPoint(1, 1);

      expect(
        map.shortestNextStep(start: zombie, target: player),
        isNotNull,
        reason: 'there is a way: it is just a silly one',
      );
      expect(
        map.shortestNextStep(
          start: zombie,
          target: player,
          maxDistance: ZombieAi.detourFor(2),
        ),
        isNull,
      );
    });
  });
}
