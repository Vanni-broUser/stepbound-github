import 'package:stepbound/core/core.dart';

WorldState createF2World({int seed = 20260920}) {
  const width = 48;
  const height = 18;
  final cells = List<List<String>>.generate(
    height,
    (y) => List<String>.generate(
      width,
      (x) => x == 0 || y == 0 || x == width - 1 || y == height - 1 ? '#' : '.',
    ),
  );
  for (var y = 2; y < height - 2; y++) {
    cells[y][15] = y == 9 ? '+' : '#';
    cells[y][32] = y == 6 || y == 13 ? '+' : '#';
  }
  for (var x = 3; x < 14; x += 2) {
    cells[5][x] = ':';
  }
  for (var x = 34; x < 45; x += 2) {
    cells[12][x] = ':';
  }

  final rows = cells.map((row) => row.join()).toList(growable: false);
  final factory = EntityFactory(BalanceConfig.standard());
  return WorldState(
    map: TileMap.fromAscii(rows),
    entities: <Entity>[
      factory.player(id: 'player', position: const GridPoint(4, 9)),
      factory.zombie(
        id: 'wanderer',
        kind: EntityKind.wanderer,
        position: const GridPoint(10, 9),
      ),
      factory.zombie(
        id: 'sprinter',
        kind: EntityKind.sprinter,
        position: const GridPoint(25, 6),
      ),
      factory.zombie(
        id: 'brute',
        kind: EntityKind.brute,
        position: const GridPoint(29, 13),
      ),
      factory.zombie(
        id: 'blind',
        kind: EntityKind.blind,
        position: const GridPoint(40, 9),
      ),
    ],
    playerId: 'player',
    random: SeededRandom(seed),
  );
}
