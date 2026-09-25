// Deterministic scaling benchmark for the simulation.
//
// Two measurements, both on the real tutorial map:
//
//   turns  the cost of a turn with 100, 500 and 1,000 entities spread over
//          the walkable tiles, everybody pointed at the player every turn
//          so nobody takes the cheap "nothing to do" exit;
//   paths  the cost of one path query, with the target reachable, then
//          walled off with and without a cap on how far the search spreads.
//
// The work is the same on every run; only the timings move with the
// machine, so each figure is the best of several rounds.
//
//   dart run tools/benchmark_world.dart [turns]
import 'dart:io';

import 'package:stepbound/core/core.dart';
import 'package:stepbound/core/systems/zombie_ai.dart';

const List<int> _populations = <int>[100, 500, 1000];
const int _rounds = 5;

void main(List<String> arguments) {
  final turns = arguments.isEmpty ? 200 : int.parse(arguments.single);
  _benchmarkTurns(turns);
  stdout.writeln();
  _benchmarkPaths();
}

// ----------------------------------------------------------------- turns

void _benchmarkTurns(int turns) {
  stdout
    ..writeln('turns: $turns')
    ..writeln('entities  acting  ms/turn   best ms');
  for (final population in _populations) {
    // A warm-up run keeps the JIT out of the first measured population.
    _run(_populate(population), turns: 50);

    final sample = _populate(population);
    var best = double.infinity;
    for (var round = 0; round < _rounds; round++) {
      final world = _populate(population);
      final stopwatch = Stopwatch()..start();
      _run(world, turns: turns);
      stopwatch.stop();
      final elapsed = stopwatch.elapsedMicroseconds / 1000;
      best = elapsed < best ? elapsed : best;
    }

    stdout.writeln(
      '${sample.entities.length.toString().padLeft(8)}'
      '${sample.actorsInSimulationRadius().length.toString().padLeft(8)}'
      '${(best / turns).toStringAsFixed(3).padLeft(9)}'
      '${best.toStringAsFixed(1).padLeft(10)}',
    );
  }
}

void _run(WorldState world, {required int turns}) {
  const scheduler = TurnScheduler();
  for (var turn = 0; turn < turns; turn++) {
    scheduler.advance(world, const WaitAction());
    world.drainEvents();
    _rearm(world);
  }
}

/// Keeps the crowd at full load: everybody is pointed at the player again,
/// and the player is patched up so a turn does not end early on his death.
/// Left alone, the zombies reach the spot they were walking to within a
/// handful of turns and the benchmark measures a world asleep.
void _rearm(WorldState world) {
  final player = world.player;
  final position = player.component<PositionComponent>().position;
  final health = player.component<HealthComponent>();
  health.current = health.maximum;
  for (final entity in world.entities.values) {
    entity.maybeComponent<HearingComponent>()?.lastHeard = position;
  }
}

/// The tutorial world topped up to [population] entities, spread evenly
/// over the walkable tiles so the crowd has room to walk: packed shoulder
/// to shoulder every path query dies on the first step and measures
/// nothing.
WorldState _populate(int population) {
  final world = createTutorialWorld();
  final factory = EntityFactory(BalanceConfig.standard());
  final taken = world.occupiedPoints();
  final tiles = _walkableTiles(world.map);
  final wanted = population - world.entities.length;
  const kinds = <EntityKind>[
    EntityKind.wanderer,
    EntityKind.sprinter,
    EntityKind.brute,
    EntityKind.blind,
  ];
  if (wanted <= 0) {
    return world;
  }

  var added = 0;
  for (var index = 0; index < tiles.length && added < wanted; index++) {
    // One entity every `tiles.length / wanted` tiles, in map order.
    if (index * wanted ~/ tiles.length != added) {
      continue;
    }
    final point = tiles[index];
    if (taken.contains(point)) {
      continue;
    }
    taken.add(point);
    world.addEntity(
      factory.zombie(
        id: 'bench-$added',
        kind: kinds[added % kinds.length],
        position: point,
      ),
    );
    added++;
  }
  return world;
}

// ----------------------------------------------------------------- paths

void _benchmarkPaths() {
  final world = createTutorialWorld();
  final map = world.map;
  const cap = ZombieAi.pathfindingRange;
  const unreachable = 1 << 30;

  final player = world.player.component<PositionComponent>().position;
  final camp = map.floodFillDistances(player, maxDistance: unreachable);
  final near = camp.entries.firstWhere((entry) => entry.value == 12).key;
  // Somewhere the player cannot walk to: another building, another street.
  final walledOff = _walkableTiles(
    map,
  ).firstWhere((point) => !camp.containsKey(point));
  // The widest stretch of the map, where giving up costs the most.
  final street = _largestArea(map);
  // Mario boxed in by the crowd with a zombie two tiles off: the path it
  // asks for is not there, and this is the busiest moment of a game.
  final hemmedIn = _openTile(map);
  final crowd = map.walkableNeighbors(hemmedIn).toSet();
  final nearby = GridPoint(hemmedIn.x + 2, hemmedIn.y);

  final rows = <String, String>{
    'reachable, 12 tiles away': _time(
      () => map.shortestNextStep(start: player, target: near),
    ),
    'walled off, from the camp (${camp.length} tiles)': _time(
      () => map.shortestNextStep(start: player, target: walledOff),
    ),
    'the same, capped at $cap': _time(
      () => map.shortestNextStep(
        start: player,
        target: walledOff,
        maxDistance: cap,
      ),
    ),
    'walled off, from the street (${_areaOf(map, street)} tiles)': _time(
      () => map.shortestNextStep(start: street, target: player),
    ),
    'the same, capped at $cap ': _time(
      () =>
          map.shortestNextStep(start: street, target: player, maxDistance: cap),
    ),
    'hemmed in by the crowd, two tiles off, cap $cap': _time(
      () => map.shortestNextStep(
        start: nearby,
        target: hemmedIn,
        isBlocked: crowd.contains,
        maxDistance: cap,
      ),
    ),
    'the same, on the leash for two tiles (${ZombieAi.detourFor(2)})': _time(
      () => map.shortestNextStep(
        start: nearby,
        target: hemmedIn,
        isBlocked: crowd.contains,
        maxDistance: ZombieAi.detourFor(2),
      ),
    ),
  };

  stdout.writeln('paths (one shortestNextStep, us)');
  for (final row in rows.entries) {
    stdout.writeln('  ${row.key.padRight(44)}${row.value}');
  }
}

/// An open tile in a wide stretch, with room on all four sides and
/// another walkable tile two steps east of it.
GridPoint _openTile(TileMap map) {
  const unreachable = 1 << 30;
  for (final tile in _walkableTiles(map)) {
    final east = GridPoint(tile.x + 2, tile.y);
    if (map.walkableNeighbors(tile).length < 4 ||
        !map.contains(east) ||
        !map.tileAt(east).isWalkable) {
      continue;
    }
    if (map.floodFillDistances(tile, maxDistance: unreachable).length > 1000) {
      return tile;
    }
  }
  throw StateError('The map has nowhere open enough to crowd.');
}

/// A tile in the widest walkable stretch of [map].
GridPoint _largestArea(TileMap map) {
  const unreachable = 1 << 30;
  final seen = <GridPoint>{};
  var best = const GridPoint(0, 0);
  var bestSize = 0;
  for (final tile in _walkableTiles(map)) {
    if (seen.contains(tile)) {
      continue;
    }
    final area = map.floodFillDistances(tile, maxDistance: unreachable);
    seen.addAll(area.keys);
    if (area.length > bestSize) {
      bestSize = area.length;
      best = tile;
    }
  }
  return best;
}

int _areaOf(TileMap map, GridPoint tile) =>
    map.floodFillDistances(tile, maxDistance: 1 << 30).length;

String _time(void Function() query) {
  const iterations = 200;
  for (var warmUp = 0; warmUp < 50; warmUp++) {
    query();
  }
  var best = double.infinity;
  for (var round = 0; round < _rounds; round++) {
    final stopwatch = Stopwatch()..start();
    for (var index = 0; index < iterations; index++) {
      query();
    }
    stopwatch.stop();
    final each = stopwatch.elapsedMicroseconds / iterations;
    best = each < best ? each : best;
  }
  return best.toStringAsFixed(1).padLeft(8);
}

/// Every walkable tile, row by row: the same list on every run.
List<GridPoint> _walkableTiles(TileMap map) => <GridPoint>[
  for (var y = 0; y < map.height; y++)
    for (var x = 0; x < map.width; x++)
      if (map.tileAt(GridPoint(x, y)).isWalkable) GridPoint(x, y),
];
