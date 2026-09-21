import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

import 'test_world.dart';

void main() {
  group('energy scheduler', () {
    test('zombie archetypes act at their configured speeds', () {
      // Each zombie steps as soon as it spots the player, then keeps its
      // own cadence: sprinter every tick, wanderer every 2, brute every 3.
      expect(_xAfterWaits(EntityKind.sprinter, 1), 4);
      expect(_xAfterWaits(EntityKind.sprinter, 2), 3);

      expect(_xAfterWaits(EntityKind.wanderer, 1), 4);
      expect(_xAfterWaits(EntityKind.wanderer, 2), 4);
      expect(_xAfterWaits(EntityKind.wanderer, 3), 3);

      expect(_xAfterWaits(EntityKind.brute, 1), 4);
      expect(_xAfterWaits(EntityKind.brute, 3), 4);
      expect(_xAfterWaits(EntityKind.brute, 4), 3);
    });

    test('an alert trigger makes a zombie notice the player behind it', () {
      final world = corridorWorld(
        EntityKind.wanderer,
        playerPosition: const GridPoint(2, 1),
      );
      world.entities['zombie']!.component<PositionComponent>().facing =
          Direction.east;
      world.alertTriggers['zombie'] = const GridRect(1, 1, 2, 1);

      final events = const TurnScheduler().advance(world, const WaitAction());

      expect(events.whereType<AlertedEvent>(), hasLength(1));
      expect(
        world.entities['zombie']!.component<PositionComponent>().position,
        const GridPoint(4, 1),
      );
      expect(world.alertTriggers, isEmpty);
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

  WorldState corridor(int width, {required EntityKind kind, int zombieX = 7}) {
    final factory = EntityFactory(BalanceConfig.standard());
    return WorldState(
      map: TileMap.fromAscii(<String>[
        '#' * width,
        '#${'.' * (width - 2)}#',
        '#' * width,
      ]),
      entities: <Entity>[
        factory.player(id: 'player', position: const GridPoint(1, 1)),
        factory.zombie(
          id: 'zombie',
          kind: kind,
          position: GridPoint(zombieX, 1),
        ),
      ],
      playerId: 'player',
      random: SeededRandom(1),
    );
  }

  GridPoint zombieAt(WorldState world) =>
      world.entities['zombie']!.component<PositionComponent>().position;

  test('a hunting zombie turns round when the player doubles back', () {
    final world = corridor(12, kind: EntityKind.wanderer);
    final scheduler = const TurnScheduler()
      ..advance(world, const WaitAction())
      ..advance(world, const WaitAction());
    expect(zombieAt(world), const GridPoint(6, 1));

    // Behind its back, but close: it keeps sensing the player.
    world.player.component<PositionComponent>().position = const GridPoint(
      10,
      1,
    );
    scheduler
      ..advance(world, const WaitAction())
      ..advance(world, const WaitAction());
    expect(zombieAt(world), const GridPoint(7, 1));
  });

  test('a zombie that loses the player heads for where it last saw them', () {
    final world = corridor(30, kind: EntityKind.wanderer);
    final scheduler = const TurnScheduler()
      ..advance(world, const WaitAction())
      ..advance(world, const WaitAction());
    expect(zombieAt(world), const GridPoint(6, 1));

    // Far beyond its senses: it walks to the last known position.
    world.player.component<PositionComponent>().position = const GridPoint(
      28,
      1,
    );
    scheduler
      ..advance(world, const WaitAction())
      ..advance(world, const WaitAction());
    expect(zombieAt(world), const GridPoint(5, 1));
  });

  test('a carabiniere hits the player two tiles away in a straight line', () {
    final world = corridor(12, kind: EntityKind.carabiniere, zombieX: 3);
    world.entities['zombie']!.component<PositionComponent>().facing =
        Direction.west;
    final events = const TurnScheduler().advance(world, const WaitAction());
    expect(events.whereType<DamagedEvent>().single.sourceEntityId, 'zombie');
    expect(zombieAt(world), const GridPoint(3, 1), reason: 'no step needed');
  });

  test('a table between them stops the baton', () {
    final factory = EntityFactory(BalanceConfig.standard());
    final world = WorldState(
      map: TileMap.fromAscii(const <String>[
        '########',
        '#.o....#',
        '#......#',
        '########',
      ]),
      entities: <Entity>[
        factory.player(id: 'player', position: const GridPoint(1, 1)),
        factory.zombie(
          id: 'zombie',
          kind: EntityKind.carabiniere,
          position: const GridPoint(3, 1),
        ),
      ],
      playerId: 'player',
      random: SeededRandom(1),
    );
    final events = const TurnScheduler().advance(world, const WaitAction());
    expect(events.whereType<DamagedEvent>(), isEmpty);
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

  test('a zombie raises the alert once when it first spots the player', () {
    final world = corridorWorld(EntityKind.sprinter);
    world.entities['zombie']!.component<PositionComponent>().facing =
        Direction.west;

    final firstTurn = const TurnScheduler().advance(world, const WaitAction());
    expect(firstTurn.whereType<AlertedEvent>(), hasLength(1));

    final secondTurn = const TurnScheduler().advance(world, const WaitAction());
    expect(secondTurn.whereType<AlertedEvent>(), isEmpty);
  });

  test('an adjacent zombie turns to face the player before biting', () {
    final world = corridorWorld(
      EntityKind.sprinter,
      zombiePosition: const GridPoint(2, 1),
    );
    world.entities['zombie']!.component<PositionComponent>().facing =
        Direction.north;

    const TurnScheduler().advance(world, const WaitAction());

    expect(
      world.entities['zombie']!.component<PositionComponent>().facing,
      Direction.west,
    );
    expect(
      world.player.component<HealthComponent>().current,
      lessThan(world.player.component<HealthComponent>().maximum),
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
