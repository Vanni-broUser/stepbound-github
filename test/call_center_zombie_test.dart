import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/zombie_lore.dart';

void main() {
  /// An open room, the operator's desk `D` in the middle of its west side
  /// and the operator on the chair east of it, on a cord of [cord] tiles.
  WorldState room({required GridPoint player, int cord = 3}) {
    final factory = EntityFactory(BalanceConfig.standard());
    return WorldState(
      map: TileMap.fromAscii(const <String>[
        '################',
        '#..............#',
        '#..............#',
        '#..............#',
        '#.D............#',
        '#..............#',
        '#..............#',
        '#..............#',
        '################',
      ])..setTile(const GridPoint(2, 4), const Tile(TileKind.obstacle)),
      entities: <Entity>[
        factory.player(id: 'player', position: player),
        factory.zombie(
          id: 'caller',
          kind: EntityKind.callCenter,
          position: const GridPoint(3, 4),
          facing: Direction.east,
          tether: TetherComponent(anchor: const GridPoint(2, 4), length: cord),
        ),
      ],
      playerId: 'player',
      random: SeededRandom(3),
    );
  }

  GridPoint callerAt(WorldState world) =>
      world.entities['caller']!.component<PositionComponent>().position;

  void wait(WorldState world, int turns) {
    for (var i = 0; i < turns; i++) {
      const TurnScheduler().advance(world, const WaitAction());
    }
  }

  test('it goes after Mario as fast as he walks, until the cord is taut, '
      'and then waits there pulling at it', () {
    final world = room(player: const GridPoint(10, 4));
    const TurnScheduler().advance(world, const WaitAction());
    expect(callerAt(world), const GridPoint(4, 4), reason: 'a step a turn');
    wait(world, 10);
    expect(
      callerAt(world),
      const GridPoint(5, 4),
      reason: 'three from the desk',
    );
    expect(
      world.entities['caller']!.component<PositionComponent>().facing,
      Direction.east,
    );
    expect(world.player.component<HealthComponent>().current, 6);
  });

  test('when Mario moves round it, it comes round after him, never past '
      'the reach of its cord', () {
    final world = room(player: const GridPoint(10, 4));
    wait(world, 6);
    expect(callerAt(world), const GridPoint(5, 4));
    world.player.component<PositionComponent>().position = const GridPoint(
      4,
      7,
    );
    wait(world, 6);
    final at = callerAt(world);
    final tether = world.entities['caller']!.component<TetherComponent>();
    expect(tether.reaches(at), isTrue);
    expect(at.manhattanDistanceTo(const GridPoint(4, 7)), 1);
  });

  test('within reach of the cord, it bites like any other', () {
    final world = room(player: const GridPoint(6, 4));
    var bitten = false;
    for (var i = 0; i < 6 && !bitten; i++) {
      bitten = const TurnScheduler()
          .advance(world, const WaitAction())
          .whereType<DamagedEvent>()
          .any((event) => event.sourceEntityId == 'caller');
    }
    expect(bitten, isTrue);
  });

  test('its cord is kept by a save', () {
    final world = room(player: const GridPoint(10, 4));
    final read = WorldState.fromJson(world.toJson());
    final tether = read.entities['caller']!.component<TetherComponent>();
    expect(tether.anchor, const GridPoint(2, 4));
    expect(tether.length, 3);
    expect(tether.reaches(const GridPoint(5, 4)), isTrue);
    expect(tether.reaches(const GridPoint(6, 4)), isFalse);
  });

  test('it is introduced the first time it is seen, and has its card in '
      'the book', () {
    final lore = zombieLore[EntityKind.callCenter]!;
    expect(lore.introducedOnSight, isTrue);
    expect(
      lore.portrait,
      'assets/characters/zombies/portraits/call_center.png',
    );
    expect(lore.name, 'Call center');
    expect(levelZombieKinds(LevelId.hometown), contains(EntityKind.callCenter));
  });
}
