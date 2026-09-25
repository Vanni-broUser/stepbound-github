import 'package:stepbound/core/core.dart';

WorldState corridorWorld(
  EntityKind zombieKind, {
  GridPoint playerPosition = const GridPoint(1, 1),
  GridPoint zombiePosition = const GridPoint(5, 1),
  int seed = 7,
}) {
  final factory = EntityFactory(BalanceConfig.standard());
  return WorldState(
    map: TileMap.fromAscii(const <String>['########', '#......#', '########']),
    entities: <Entity>[
      factory.player(id: 'player', position: playerPosition),
      factory.zombie(id: 'zombie', kind: zombieKind, position: zombiePosition),
    ],
    playerId: 'player',
    random: SeededRandom(seed),
  );
}

WorldState playerOnlyWorld({
  List<String> rows = const <String>['#####', '#...#', '#####'],
  GridPoint position = const GridPoint(1, 1),
  Direction facing = Direction.east,
  int seed = 7,
  Iterable<GridPoint> travelMaps = const <GridPoint>[],
  Iterable<GridPoint> lookouts = const <GridPoint>[],
}) {
  final factory = EntityFactory(BalanceConfig.standard());
  return WorldState(
    map: TileMap.fromAscii(rows),
    entities: <Entity>[
      factory.player(id: 'player', position: position, facing: facing),
    ],
    playerId: 'player',
    random: SeededRandom(seed),
    travelMaps: travelMaps,
    lookouts: lookouts,
  );
}
