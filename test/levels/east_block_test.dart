import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  final top = place(PlaceId.eastBlockTopFloor);
  final lower = place(PlaceId.eastBlockLowerFloor);
  final roof = place(PlaceId.hospitalRoof);

  GridPoint mario(WorldState world) =>
      world.player.component<PositionComponent>().position;

  /// The level with nobody else in it: the block's wanderers would have
  /// Mario before the doors do.
  WorldState empty() {
    final world = createGameWorld();
    for (final entity in world.entities.values) {
      if (entity.kind != EntityKind.player) {
        entity.component<HealthComponent>().current = 0;
      }
    }
    return world;
  }

  /// Walks Mario from [from] to [to] inside one place, one step at a time
  /// along the shortest way.
  void walk(WorldState world, GridPoint from, GridPoint to) {
    world.player.component<PositionComponent>().position = from;
    final distances = world.map.floodFillDistances(to, maxDistance: 2000);
    expect(distances.containsKey(from), isTrue, reason: '$to from $from');
    while (mario(world) != to) {
      final here = mario(world);
      final direction = Direction.values.firstWhere((direction) {
        final next = here.step(direction);
        return distances[next] == distances[here]! - 1;
      });
      const TurnScheduler().advance(world, MoveAction(direction));
    }
  }

  /// Steps Mario from [at] onto the door [door] next to it, and returns
  /// where the door takes him.
  GridPoint through(WorldState world, GridPoint at, GridPoint door) {
    world.player.component<PositionComponent>().position = at;
    final direction = Direction.values.firstWhere(
      (direction) => at.step(direction) == door,
    );
    final events = const TurnScheduler().advance(world, MoveAction(direction));
    expect(events.whereType<TeleportedEvent>(), hasLength(1), reason: '$door');
    return mario(world);
  }

  test('down the stairwell on the roof east of the hospital onto the top '
      'floor, down the flight to the floor below, and back up the same '
      'way onto the roof', () {
    final world = empty();
    for (final foot in hospitalNextRoofStairsFoot) {
      final at = through(world, foot.step(Direction.north), foot);
      expect(at, eastBlockRoofStairs.step(Direction.south));
      expect(placeAt(at), top);
    }
    var at = eastBlockRoofStairs.step(Direction.south);
    final (up, down) = eastBlockFlights.single;
    expect(placeAt(up), lower);
    expect(placeAt(down), top);
    walk(world, at, down.step(Direction.north));
    at = through(world, down.step(Direction.north), down);
    expect(at, up.step(Direction.south));
    expect(placeAt(at), lower);

    // And back: up the flight, across the top floor, up onto the roof.
    at = through(world, at, up);
    expect(at, down.step(Direction.north));
    expect(placeAt(at), top);
    walk(world, at, eastBlockRoofStairs.step(Direction.south));
    at = through(
      world,
      eastBlockRoofStairs.step(Direction.south),
      eastBlockRoofStairs,
    );
    expect(placeAt(at), roof);
    expect(hospitalNextRoofStairs, contains(at));
    expect(at, hospitalNextRoofStairsFoot.first.step(Direction.north));
  });

  test('on both floors the way up is straight above the way down, in the '
      'middle of the stairwell, as in the palazzo', () {
    for (final floor in <Place>[top, lower]) {
      expect(floor.tileOf('U').x - floor.origin.x, 22);
      expect(floor.tileOf('D').x - floor.origin.x, 23);
      expect(eastBlockStairwell.contains(const GridPoint(22, 2)), isTrue);
      expect(eastBlockStairwell.contains(const GridPoint(23, 18)), isTrue);
    }
  });

  test('every room of both floors is walked into from the landing; on the '
      'lower floor the stairs on down lie under the heap of the ceiling, '
      'and lead nowhere', () {
    final world = createGameWorld();
    for (final floor in <Place>[top, lower]) {
      final landing = floor.tileOf('U').step(Direction.south);
      final reached = world.map.floodFillDistances(landing, maxDistance: 2000);
      for (final (tile, glyph) in floor.glyphs) {
        if (!world.map.tileAt(tile).isWalkable ||
            world.portals.containsKey(tile)) {
          continue;
        }
        if (tile == eastBlockBuriedStairs) {
          expect(reached.containsKey(tile), isFalse, reason: 'buried');
          continue;
        }
        expect(reached.containsKey(tile), isTrue, reason: '$tile ($glyph)');
      }
    }
    expect(placeAt(eastBlockBuriedStairs), lower);
    expect(world.portals.containsKey(eastBlockBuriedStairs), isFalse);
    expect(workInProgressEnds.containsKey(eastBlockBuriedStairs), isFalse);
    expect(workInProgressDoors.contains(eastBlockBuriedStairs), isFalse);
    // The heap right in front of them, and plaster all round it.
    final before = eastBlockBuriedStairs.step(Direction.north);
    expect(world.map.tileAt(before).isWalkable, isFalse);
    expect(lower.glyphs.firstWhere((cell) => cell.$1 == before).$2, 'r');
    expect(lower.tilesOf('r'), hasLength(3));
  });

  test('the rocket launcher lies in the far corner of the lower floor '
      'offices, on their carpet, the one tile free beside it the way to '
      'pick it up', () {
    final world = createGameWorld();
    final launcher = world.pickups[rocketLauncherPickupId]!;
    expect(launcher.rocketLauncher, isTrue);
    expect(launcher.rockets, 0);
    expect(launcher.ammo, 0);
    expect(launcher.active, isTrue);
    expect(placeAt(launcher.position), lower);
    expect(lower.tilesOf('9').single, launcher.position);
    expect(world.pickups.values.where((p) => p.rocketLauncher), hasLength(1));
    final free = Direction.values
        .map(launcher.position.step)
        .where((tile) => world.map.tileAt(tile).isWalkable)
        .toList();
    expect(free, <GridPoint>[launcher.position.step(Direction.north)]);
    expect(lower.glyphs.firstWhere((cell) => cell.$1 == free.single).$2, '~');
    // The rounds for it are elsewhere: two on the Duomo's other tower.
    expect(world.pickups[duomoFarTowerBackpackId]!.rockets, 2);
    expect(duomoFarTowerBackpackRockets, 2);
  });

  test('the block has its wanderers, its stairwell and corridor lit, its '
      'flats west of the stairwell and its offices east of it dark', () {
    final world = createGameWorld();
    final zombies = world.entities.values.where(
      (entity) => entity.id.startsWith(eastBlockZombiePrefix),
    );
    expect(zombies, hasLength(eastBlockZombieTiles.length));
    expect(zombies.length, greaterThanOrEqualTo(8));
    for (final zombie in zombies) {
      expect(zombie.kind, EntityKind.wanderer);
    }
    for (final floor in <Place>[top, lower]) {
      expect(floor.indoor, isTrue);
      expect(floor.lit, isFalse);
      expect(floor.name, eastBlockName);
      expect(floor.darkness, greaterThan(palazzoFlatDarkness));
      expect(floor.litAreas, hasLength(2));
      final stairwell = floor.litAreas.first;
      final corridor = floor.litAreas.last;
      expect(stairwell.contains(floor.tileOf('U')), isTrue);
      expect(stairwell.contains(floor.tileOf('D')), isTrue);
      expect(corridor.right - corridor.left + 1, floor.width - 2);
      // Every door onto the corridor opens off it, two flats and two
      // offices a floor.
      expect(floor.tilesOf('P'), hasLength(4));
      for (final door in floor.tilesOf('P')) {
        expect(
          corridor.contains(door.step(Direction.north)) ||
              corridor.contains(door.step(Direction.south)),
          isTrue,
          reason: '$door',
        );
      }
      // Parquet, kitchen and bathroom tiles one side, carpet the other.
      for (final (tile, glyph) in floor.glyphs) {
        if (glyph == '~' || glyph == 'o' || glyph == 'y') {
          expect(tile.x, greaterThan(stairwell.right), reason: '$tile');
        }
        if (glyph == '.' || glyph == ',' || glyph == '_') {
          expect(tile.x, lessThan(stairwell.left), reason: '$tile');
        }
      }
      // The lamps left: only flickering ones in the rooms, the steady ones
      // in the stairwell and along the corridor.
      for (final light in floor.lights) {
        if (!light.flickers) {
          expect(
            corridor.contains(light.tile) || stairwell.contains(light.tile),
            isTrue,
            reason: '${light.tile}',
          );
        }
      }
    }
  });
}
