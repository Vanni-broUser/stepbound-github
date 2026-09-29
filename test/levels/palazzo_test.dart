import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  final third = place(PlaceId.palazzoThirdFloor);
  final second = place(PlaceId.palazzoSecondFloor);
  final first = place(PlaceId.palazzoFirstFloor);
  final hall = place(PlaceId.palazzoGroundFloor);
  final street = place(PlaceId.industryStreet);
  final roofs = place(PlaceId.airlinerRoofs);

  GridPoint mario(WorldState world) =>
      world.player.component<PositionComponent>().position;

  /// The level with nobody else in it: the palazzo's wanderers would have
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

  test('down the stairwell on the roofs past the airliner, down the '
      'palazzo floor by floor, out of the portone onto the street, and '
      'back up the same way', () {
    final world = empty();
    final onStairs = rooftopFarStairsFoot.first.step(Direction.west);
    var at = through(world, onStairs, rooftopFarStairsFoot.first);
    expect(at, palazzoRoofStairs.step(Direction.south));
    expect(placeAt(at), third);

    // Down: the flights of the stairwell, top to bottom.
    final below = <Place>[second, first, hall];
    for (final (index, (up, down)) in palazzoFlights.reversed.indexed) {
      final floor = below[index];
      final front = down.step(Direction.north);
      walk(world, at, front);
      at = through(world, front, down);
      expect(at, up.step(Direction.south));
      expect(placeAt(at), floor);
    }
    expect(placeAt(at), hall);

    final inside = palazzoPortone.step(Direction.north);
    walk(world, at, inside);
    final outside = through(world, inside, palazzoPortone);
    expect(outside, industryStreetPortone.step(Direction.south));
    expect(placeAt(outside), street);

    // And back: in through the portone, up to the top floor, onto the roof.
    at = through(world, outside, industryStreetPortone);
    expect(at, inside);
    for (final (up, down) in palazzoFlights) {
      final front = up.step(Direction.south);
      walk(world, at, front);
      at = through(world, front, up);
      expect(at, down.step(Direction.north));
    }
    expect(placeAt(at), third);
    walk(world, at, palazzoRoofStairs.step(Direction.south));
    at = through(
      world,
      palazzoRoofStairs.step(Direction.south),
      palazzoRoofStairs,
    );
    expect(placeAt(at), roofs);
    expect(rooftopFarStairs, contains(at));
  });

  test('every flat of every floor is walked into from its landing: no room '
      'is shut off, and the one behind the locked door is not drawn', () {
    final world = createGameWorld();
    for (final floor in <Place>[third, second, first, hall]) {
      final landing = floor == hall
          ? palazzoPortone.step(Direction.north)
          : floor.tileOf('D').step(Direction.north);
      final reached = world.map.floodFillDistances(landing, maxDistance: 2000);
      for (final (tile, _) in floor.glyphs) {
        if (!world.map.tileAt(tile).isWalkable ||
            world.portals.containsKey(tile)) {
          continue;
        }
        expect(reached.containsKey(tile), isTrue, reason: '$tile shut off');
      }
    }
    expect(world.map.tileAt(palazzoLockedDoorTile).isWalkable, isFalse);
    // East of the locked door, the dark: the flat is not there at all.
    final behind = palazzoLockedDoorTile.step(Direction.east);
    expect(third.glyphs.firstWhere((cell) => cell.$1 == behind).$2, 'x');
  });

  test('the key is on the first floor, the backpack with two rounds on the '
      'second, and only the portone on the ground floor', () {
    final world = createGameWorld();
    final key = world.pickups[palazzoKeyPickupId]!;
    expect(key.palazzoKey, isTrue);
    expect(placeAt(key.position), first);
    final backpack = world.pickups[palazzoBackpackId]!;
    expect(backpack.ammo, 2);
    expect(placeAt(backpack.position), second);
    expect(
      world.pickups.values.where((p) => placeAt(p.position) == hall),
      isEmpty,
    );
    expect(hall.tilesOf('P'), isEmpty, reason: 'no flats on the ground');
    for (final floor in <Place>[first, second, third]) {
      expect(floor.tilesOf('P'), isNotEmpty, reason: '${floor.id}');
    }
  });

  test('the palazzo has its wanderers, the landings are lit and the flats '
      'dark but for a lamp here and there', () {
    final world = createGameWorld();
    final zombies = world.entities.values.where(
      (entity) => entity.id.startsWith(palazzoZombiePrefix),
    );
    expect(zombies, hasLength(greaterThan(10)));
    for (final floor in <Place>[third, second, first]) {
      expect(floor.indoor, isTrue);
      expect(floor.lit, isFalse);
      final landingLamps = floor.lights.where(
        (light) => floor.glyphs.any(
          (cell) =>
              cell.$1.x == light.tile.x &&
              (cell.$1.y - light.tile.y).abs() <= 1 &&
              cell.$2 == '=',
        ),
      );
      expect(landingLamps.length, greaterThanOrEqualTo(4));
      expect(floor.lights.length, greaterThan(landingLamps.length));
    }
    expect(hall.lit, isTrue);
  });

  test('out on the street: the camp by the company is a fire to rest at, '
      'and the ways off it end at the work-in-progress screen', () {
    expect(campfireNames[industryStreetCampfireTile], 'Davanti all’azienda');
    final ends = workInProgressEnds.keys.where(
      (tile) => placeAt(tile) == street,
    );
    // The street going on east, and the road going down south.
    expect(ends.where((tile) => tile.x == street.bounds.right), isNotEmpty);
    expect(ends.where((tile) => tile.y == street.bounds.bottom), isNotEmpty);
    expect(ends.where((tile) => tile.x == street.bounds.left), isEmpty);
  });
}
