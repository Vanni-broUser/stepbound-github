import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/entities/entity_factory.dart';
import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile_map.dart';
import 'package:stepbound/core/seeded_random.dart';
import 'package:stepbound/core/world.dart';

WorldState createDemoWorld({int seed = 20260920}) {
  const rows = <String>[
    '#################',
    '#@....:.........#',
    '#.....#....w....#',
    '#.....+.........#',
    '#.....#..s...b..#',
    '#.............c.#',
    '#################',
  ];
  final balance = BalanceConfig.standard();
  final factory = EntityFactory(balance);
  final entities = <Entity>[];
  var zombieIndex = 0;

  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final point = GridPoint(x, y);
      switch (rows[y][x]) {
        case '@':
          entities.add(factory.player(id: 'player', position: point));
        case 'w':
          entities.add(
            factory.zombie(
              id: 'wanderer-${zombieIndex++}',
              kind: EntityKind.wanderer,
              position: point,
            ),
          );
        case 's':
          entities.add(
            factory.zombie(
              id: 'sprinter-${zombieIndex++}',
              kind: EntityKind.sprinter,
              position: point,
            ),
          );
        case 'b':
          entities.add(
            factory.zombie(
              id: 'brute-${zombieIndex++}',
              kind: EntityKind.brute,
              position: point,
            ),
          );
        case 'c':
          entities.add(
            factory.zombie(
              id: 'blind-${zombieIndex++}',
              kind: EntityKind.blind,
              position: point,
            ),
          );
      }
    }
  }

  return WorldState(
    map: TileMap.fromAscii(rows),
    entities: entities,
    playerId: 'player',
    random: SeededRandom(seed),
  );
}
