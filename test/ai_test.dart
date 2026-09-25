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

      expect(_xAfterWaits(EntityKind.cultist, 1), 4);
      expect(_xAfterWaits(EntityKind.cultist, 2), 4);
      expect(_xAfterWaits(EntityKind.cultist, 3), 3);

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

  test('a mutilated zombie never leaves its tile, but turns to the player', () {
    final world = corridor(12, kind: EntityKind.mutilated, zombieX: 4);
    world.entities['zombie']!.component<PositionComponent>().facing =
        Direction.west;
    const scheduler = TurnScheduler();
    final alerted = scheduler.advance(world, const WaitAction());
    expect(alerted.whereType<AlertedEvent>(), hasLength(1));
    for (var i = 0; i < 6; i++) {
      final events = scheduler.advance(world, const WaitAction());
      expect(events.whereType<MovedEvent>(), isEmpty);
    }
    expect(zombieAt(world), const GridPoint(4, 1));

    // Behind it now: it cannot follow, it only turns round.
    world.player.component<PositionComponent>().position = const GridPoint(
      6,
      1,
    );
    scheduler.advance(world, const WaitAction());
    expect(zombieAt(world), const GridPoint(4, 1));
    expect(
      world.entities['zombie']!.component<PositionComponent>().facing,
      Direction.east,
    );
  });

  test('a mutilated zombie bites on every turn Mario stays next to it', () {
    final world = corridor(12, kind: EntityKind.mutilated, zombieX: 2);
    const scheduler = TurnScheduler();
    var bites = 0;
    for (var i = 0; i < 3; i++) {
      bites += scheduler
          .advance(world, const WaitAction())
          .whereType<DamagedEvent>()
          .where((event) => event.sourceEntityId == 'zombie')
          .length;
      world.player.component<HealthComponent>().current = 6;
    }
    expect(bites, 3, reason: 'no idle turns, like the sprinter');
  });

  test('two tiles away a mutilated zombie cannot touch Mario', () {
    final world = corridor(12, kind: EntityKind.mutilated, zombieX: 3);
    const scheduler = TurnScheduler();
    for (var i = 0; i < 4; i++) {
      expect(
        scheduler.advance(world, const WaitAction()).whereType<DamagedEvent>(),
        isEmpty,
      );
    }
  });

  test('a mutilated zombie turns to a noise, then lets it go', () {
    final world = corridor(30, kind: EntityKind.mutilated, zombieX: 10);
    final zombie = world.entities['zombie']!;
    zombie.component<PositionComponent>().facing = Direction.east;
    zombie.component<HearingComponent>().lastHeard = const GridPoint(1, 1);
    // Far beyond its senses: it turns towards the sound and forgets it.
    world.player.component<PositionComponent>().position = const GridPoint(
      28,
      1,
    );
    const TurnScheduler().advance(world, const WaitAction());
    expect(zombieAt(world), const GridPoint(10, 1));
    expect(zombie.component<PositionComponent>().facing, Direction.west);
    expect(zombie.component<HearingComponent>().lastHeard, isNull);
  });

  group('the burning zombie', () {
    test('walks like a wanderer and sets alight every tile it leaves', () {
      final world = corridor(12, kind: EntityKind.burning);
      const scheduler = TurnScheduler();
      final fires = <GridPoint>[];
      for (var i = 0; i < 4; i++) {
        fires.addAll(
          scheduler
              .advance(world, const WaitAction())
              .whereType<FireStartedEvent>()
              .map((event) => event.at),
        );
      }
      // As slow as a wanderer: from 7 it reached 5 in four turns.
      expect(zombieAt(world), const GridPoint(5, 1));
      expect(fires, const <GridPoint>[GridPoint(7, 1), GridPoint(6, 1)]);
      for (final tile in fires) {
        expect(world.map.tileAt(tile).kind, TileKind.fire);
      }
      expect(
        world.map.tileAt(zombieAt(world)).kind,
        TileKind.floor,
        reason: 'only the tiles it left',
      );
    });

    test('Mario cannot walk into the fire it leaves', () {
      final world = corridor(12, kind: EntityKind.burning, zombieX: 5);
      world.map.setTile(const GridPoint(2, 1), const Tile(TileKind.fire));
      final events = const TurnScheduler().advance(
        world,
        const MoveAction(Direction.east),
      );
      expect(events.whereType<BlockedEvent>().single.reason, 'terrain');
      expect(
        world.player.component<PositionComponent>().position,
        const GridPoint(1, 1),
      );
    });

    test('nor can the zombies: fire in the corridor stops them', () {
      final world = corridor(12, kind: EntityKind.wanderer);
      world.map.setTile(const GridPoint(4, 1), const Tile(TileKind.fire));
      const scheduler = TurnScheduler();
      for (var i = 0; i < 8; i++) {
        scheduler.advance(world, const WaitAction());
      }
      // No way through to Mario: it waits where it stands.
      expect(zombieAt(world), const GridPoint(7, 1));
    });

    test('a shot still goes through the flames', () {
      final world = corridor(12, kind: EntityKind.burning, zombieX: 4);
      world.map.setTile(const GridPoint(3, 1), const Tile(TileKind.fire));
      final events = const TurnScheduler().advance(world, const ShootAction());
      expect(events.whereType<DiedEvent>().single.entityId, 'zombie');
    });

    test('never sets a doorway, or the tile in front of it, alight', () {
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
            kind: EntityKind.burning,
            position: const GridPoint(7, 1),
          ),
        ],
        portals: <GridPoint, Portal>{
          const GridPoint(7, 0): const Portal(
            to: GridPoint(1, 1),
            facing: Direction.south,
          ),
        },
        playerId: 'player',
        random: SeededRandom(1),
      );
      const scheduler = TurnScheduler();
      for (var i = 0; i < 4; i++) {
        scheduler.advance(world, const WaitAction());
      }
      expect(zombieAt(world), const GridPoint(5, 1));
      expect(world.map.tileAt(const GridPoint(7, 1)).kind, TileKind.floor);
      expect(world.map.tileAt(const GridPoint(6, 1)).kind, TileKind.fire);
    });
  });

  group('the drunk zombie', () {
    /// An empty room, Mario at [player], the drunk in the middle.
    WorldState room({
      GridPoint player = const GridPoint(1, 1),
      int seed = 1,
      Map<GridPoint, Portal> portals = const <GridPoint, Portal>{},
    }) {
      final factory = EntityFactory(BalanceConfig.standard());
      return WorldState(
        map: TileMap.fromAscii(<String>[
          '#' * 21,
          for (var y = 0; y < 11; y++) '#${'.' * 19}#',
          '#' * 21,
        ]),
        entities: <Entity>[
          factory.player(id: 'player', position: player),
          factory.zombie(
            id: 'zombie',
            kind: EntityKind.drunk,
            position: const GridPoint(10, 6),
          ),
        ],
        portals: portals,
        playerId: 'player',
        random: SeededRandom(seed),
      );
    }

    List<MovedEvent> movesOver(WorldState world, int turns) {
      const scheduler = TurnScheduler();
      return <MovedEvent>[
        for (var i = 0; i < turns; i++)
          ...scheduler
              .advance(world, const WaitAction())
              .whereType<MovedEvent>()
              .where((event) => event.entityId == 'zombie'),
      ];
    }

    test('staggers about all the time, even with Mario nowhere near', () {
      // Behind it and out of its sight: a wanderer would stand still.
      final world = room();
      world.entities['zombie']!.component<PositionComponent>().facing =
          Direction.east;
      final moves = movesOver(world, 40);
      expect(moves, hasLength(20), reason: 'a step every other turn');
      final directions = <(int, int)>{
        for (final move in moves)
          (move.to.x - move.from.x, move.to.y - move.from.y),
      };
      expect(directions.length, greaterThanOrEqualTo(3), reason: 'at random');
    });

    test('having seen Mario does not make it go after him', () {
      final world = room(player: const GridPoint(6, 6));
      final zombie = world.entities['zombie']!;
      zombie.component<PositionComponent>().facing = Direction.west;
      final player = world.player.component<PositionComponent>().position;
      final moves = movesOver(world, 30);
      expect(
        moves.where(
          (move) =>
              move.to.manhattanDistanceTo(player) >
              move.from.manhattanDistanceTo(player),
        ),
        isNotEmpty,
        reason: 'some of its lurches take it away from Mario',
      );
    });

    test('bites Mario, straight at him, when he is next to it', () {
      final world = room(player: const GridPoint(9, 6));
      final events = const TurnScheduler().advance(world, const WaitAction());
      expect(events.whereType<DamagedEvent>().single.sourceEntityId, 'zombie');
      expect(events.whereType<MovedEvent>(), isEmpty);
      expect(
        world.entities['zombie']!.component<PositionComponent>().facing,
        Direction.west,
      );
    });

    test('never stumbles onto a doorway', () {
      final factory = EntityFactory(BalanceConfig.standard());
      final world = WorldState(
        map: TileMap.fromAscii(const <String>['#####', '#.#.#', '#####']),
        entities: <Entity>[
          factory.player(id: 'player', position: const GridPoint(1, 1)),
          factory.zombie(
            id: 'zombie',
            kind: EntityKind.drunk,
            position: const GridPoint(3, 1),
          ),
        ],
        portals: <GridPoint, Portal>{
          const GridPoint(3, 1).step(Direction.north): const Portal(
            to: GridPoint(1, 1),
            facing: Direction.south,
          ),
        },
        playerId: 'player',
        random: SeededRandom(1),
      );
      // The wall above it is a doorway: walkable or not, it stays put.
      world.map.setTile(const GridPoint(3, 0), const Tile(TileKind.floor));
      expect(movesOver(world, 10), isEmpty);
    });

    test('staggers the same way from the same seed, so saves replay it', () {
      List<GridPoint> path(int seed) => <GridPoint>[
        for (final move in movesOver(room(seed: seed), 20)) move.to,
      ];
      expect(path(7), path(7));
      expect(path(7), isNot(path(8)));
    });
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

  test('a zombie that lost the player raises the alert again when it finds '
      'him', () {
    final world = corridor(34, kind: EntityKind.wanderer, zombieX: 5);
    final zombie = world.entities['zombie']!;
    zombie.component<PositionComponent>().facing = Direction.west;
    final player = world.player.component<PositionComponent>();
    final start = player.position;

    var events = const TurnScheduler().advance(world, const WaitAction());
    expect(events.whereType<AlertedEvent>(), hasLength(1));

    // Mario gets far down the corridor: the zombie loses him, though it
    // still heads to where it saw him last.
    player.position = const GridPoint(32, 1);
    const TurnScheduler().advance(world, const WaitAction());
    final hearing = zombie.component<HearingComponent>();
    expect(hearing.hunting, isFalse);
    expect(hearing.lastHeard, isNotNull);

    // He comes back in sight: a new alert.
    player.position = start;
    events = const TurnScheduler().advance(world, const WaitAction());
    expect(events.whereType<AlertedEvent>(), hasLength(1));
    expect(hearing.hunting, isTrue);
  });

  test('a zombie drawn by a noise still raises the alert when it sees the '
      'player', () {
    final world = corridorWorld(EntityKind.wanderer);
    final zombie = world.entities['zombie']!;
    // A shot somewhere: it heads there, aware but not after Mario yet.
    zombie.component<HearingComponent>().lastHeard = const GridPoint(1, 1);
    zombie.component<PositionComponent>().facing = Direction.west;

    final events = const TurnScheduler().advance(world, const WaitAction());
    expect(events.whereType<AlertedEvent>(), hasLength(1));
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
