import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  final floors = <Place>[
    place(PlaceId.hospitalFirstFloor),
    place(PlaceId.hospitalSecondFloor),
    place(PlaceId.hospitalThirdFloor),
  ];
  final roof = place(PlaceId.hospitalRoof);

  GridPoint mario(WorldState world) =>
      world.player.component<PositionComponent>().position;

  /// The level with nobody else in it: the horde on the stairs and the
  /// hospital's wanderers would have Mario before the doors do.
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

  test('the PRONTO SOCCORSO doors at the top of the stairs lead into the '
      'waiting room, and back out onto the stairs', () {
    final world = empty();
    final outside = hospitalDoors.first.step(Direction.south);
    final inside = through(world, outside, hospitalDoors.first);
    expect(inside, hospitalEntrance.first.step(Direction.north));
    expect(placeAt(inside), floors.first);
    expect(through(world, inside, hospitalEntrance.first), outside);
    expect(placeAt(outside), place(PlaceId.northDistrict));
  });

  test('from the waiting room Mario climbs floor after floor up to the '
      'roof, walking across every floor, and comes back down the same way', () {
    final world = empty();
    final above = <Place>[...floors.skip(1), roof];
    var at = hospitalEntrance.first.step(Direction.north);
    for (final (index, (up, landing)) in hospitalFlights.indexed) {
      expect(floors[index].bounds.contains(up), isTrue);
      expect(above[index].bounds.contains(landing), isTrue);
      final front = up.step(Direction.south);
      walk(world, at, front);
      at = through(world, front, up);
      expect(at, landing.step(Direction.north));
      expect(placeAt(at), above[index]);
    }
    expect(placeAt(at), roof);
    for (final (up, landing) in hospitalFlights.reversed) {
      expect(
        through(world, landing.step(Direction.north), landing),
        up.step(Direction.south),
      );
    }
  });

  test('on every floor the way up is straight above the way down, and '
      'from the third floor it goes on up to the roof', () {
    for (final (up, landing) in hospitalFlights.take(2)) {
      expect(
        up.x - placeAt(up)!.origin.x,
        landing.x - placeAt(landing)!.origin.x,
      );
    }
    expect(hospitalFlights.last.$2, roof.tileOf('D'));
  });

  test('on the roof a camp burns, and resting there saves the game', () {
    final world = empty();
    expect(roof.bounds.contains(hospitalRoofCampfireTile), isTrue);
    expect(world.campfires, contains(hospitalRoofCampfireTile));
    expect(campfireNames[hospitalRoofCampfireTile], 'Tetto dell’ospedale');
    expect(
      hometownFireSpots.map((spot) => spot.tile),
      contains(hospitalRoofCampfireTile),
    );
    final reached = world.map.floodFillDistances(
      roof.tileOf('D').step(Direction.north),
      maxDistance: roof.width * roof.height,
    );
    expect(
      reached.containsKey(hospitalRoofCampfireTile.step(Direction.west)),
      isTrue,
    );
  });

  test('across the gap east of the roof stands the next block, its stairs '
      'going down out of reach, and looking over the low stretch of wall '
      'measures the gap for a grappling hook', () {
    final world = empty();
    expect(world.lookouts, contains(hospitalRoofLookoutTile));
    expect(world.map.tileAt(hospitalRoofLookoutTile).isWalkable, isFalse);
    world.player.component<PositionComponent>()
      ..position = hospitalRoofLookoutTile.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(
      events.whereType<LookedOutEvent>().single.at,
      hospitalRoofLookoutTile,
    );
    // The next roof, and the stairs going down into its block, are east
    // of the gap, and nobody gets there from this roof.
    final reached = world.map.floodFillDistances(
      roof.tileOf('D').step(Direction.north),
      maxDistance: roof.width * roof.height,
    );
    final stairs = roof.tilesOf('v');
    expect(stairs, hasLength(4));
    final nextRoof = <GridPoint>[
      for (final (tile, glyph) in roof.glyphs)
        if (glyph == '.' && tile.x > hospitalRoofLookoutTile.x) tile,
    ];
    expect(nextRoof, isNotEmpty);
    for (final tile in <GridPoint>[...stairs, ...nextRoof]) {
      expect(tile.x, greaterThan(hospitalRoofLookoutTile.x));
      expect(reached.containsKey(tile), isFalse);
    }
  });

  test('every room of every floor can be walked into from the stairs', () {
    final world = empty();
    for (final floor in floors) {
      final start = floor.id == PlaceId.hospitalFirstFloor
          ? hospitalEntrance.first.step(Direction.north)
          : floor.tileOf('D').step(Direction.north);
      final reached = world.map.floodFillDistances(
        start,
        maxDistance: floor.width * floor.height,
      );
      for (final doorway in floor.tilesOf('d')) {
        expect(reached.containsKey(doorway), isTrue, reason: '$doorway');
      }
      // Beds and the rest of the furniture never shut a doorway.
      for (final (tile, glyph) in floor.glyphs) {
        if (glyph == '.' || glyph == 'Z') {
          expect(reached.containsKey(tile), isTrue, reason: '$tile');
        }
      }
    }
  });

  test('the first floor is the emergency department, the two above it '
      'wards full of beds, and wanderers are left on every floor', () {
    final first = floors.first;
    expect(first.tilesOf('C'), isNotEmpty, reason: 'the reception counter');
    expect(first.tilesOf('h'), isNotEmpty, reason: 'the waiting room');
    expect(first.tilesOf('L'), hasLength(6), reason: 'three consulting rooms');
    expect(first.tilesOf('B'), isEmpty);
    for (final ward in floors.skip(1)) {
      expect(ward.tilesOf('B').length, greaterThanOrEqualTo(20));
    }
    final world = createGameWorld();
    for (final floor in floors) {
      expect(
        world.entities.values.where(
          (entity) =>
              entity.id.startsWith(hospitalZombiePrefix) &&
              floor.bounds.contains(
                entity.component<PositionComponent>().position,
              ),
        ),
        isNotEmpty,
        reason: '${floor.id}',
      );
    }
  });

  test('the horde on the hospital stairs and in the forecourt faces every '
      'way; the zombies out on the street all still look west', () {
    final world = createGameWorld();
    final north = place(PlaceId.northDistrict);
    final outdoors = world.entities.values.where(
      (entity) =>
          entity.kind != EntityKind.player &&
          north.bounds.contains(entity.component<PositionComponent>().position),
    );
    final milling = <Direction, int>{};
    for (final zombie in outdoors) {
      final position = zombie.component<PositionComponent>();
      if (hospitalForecourt.contains(position.position)) {
        milling.update(position.facing, (n) => n + 1, ifAbsent: () => 1);
      } else if (!zombie.id.startsWith(barracksRoadZombieId)) {
        expect(position.facing, Direction.west, reason: zombie.id);
      }
    }
    expect(milling.keys.toSet(), Direction.values.toSet());
    final total = milling.values.reduce((a, b) => a + b);
    expect(total, greaterThan(20));
    for (final count in milling.values) {
      expect(count, greaterThanOrEqualTo(total ~/ 4 - 1));
    }
  });
}
