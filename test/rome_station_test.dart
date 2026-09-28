import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

/// Roma Termini past its first platform, and the two streets round it.
void main() {
  final termini = place(PlaceId.romeTermini);
  final overpass = place(PlaceId.terminiOverpass);
  final farPlatform = place(PlaceId.terminiFarPlatform);
  final concourse = place(PlaceId.terminiConcourse);
  final piazza = place(PlaceId.piazzaCinquecento);
  final marsala = place(PlaceId.viaMarsala);

  /// Everywhere reachable from [start] without going through a door.
  Map<GridPoint, int> from(WorldState world, GridPoint start, Place place) =>
      world.map.floodFillDistances(
        start,
        maxDistance: place.width * place.height,
      );

  /// Steps onto [threshold] from beside it, going [facing], and says where
  /// Mario comes out.
  GridPoint travel(WorldState world, GridPoint threshold, Direction facing) {
    world.player.component<PositionComponent>().position = threshold.step(
      facing.opposite,
    );
    final events = const TurnScheduler().advance(world, MoveAction(facing));
    expect(events.whereType<TeleportedEvent>(), hasLength(1));
    return world.player.component<PositionComponent>().position;
  }

  test('the stairs up from the train go to the overpass, and back', () {
    final world = createGameWorld();
    final up = travel(world, terminiStairsTiles.first, Direction.south);
    expect(overpass.bounds.contains(up), isTrue);
    final down = travel(world, overpass.tilesOf('D').first, Direction.north);
    expect(termini.bounds.contains(down), isTrue);
    expect(world.map.tileAt(down).isWalkable, isTrue);
  });

  test('of the eight flights down from the overpass, only two go anywhere', () {
    final world = createGameWorld();
    final backWall = overpass.bounds.top + 2;
    final openings = <GridPoint>[
      for (var x = overpass.bounds.left; x <= overpass.bounds.right; x++)
        if (world.map.tileAt(GridPoint(x, backWall)).isWalkable)
          GridPoint(x, backWall),
    ];
    expect(
      openings,
      unorderedEquals(<GridPoint>[
        ...overpass.tilesOf('D'),
        ...overpass.tilesOf('U'),
      ]),
    );
    expect(overpass.tilesOf('#').where((t) => t.y == backWall), isNotEmpty);
    expect(overpass.tilesOf('H'), isNotEmpty);
    // The overpass is wider than Molfetta's underpass.
    final underpass = place(PlaceId.stationUnderpass);
    int floorRows(Place place) => <int>{
      for (final (tile, glyph) in place.glyphs)
        if (glyph == '.') tile.y,
    }.length;
    expect(floorRows(overpass), greaterThan(floorRows(underpass)));
  });

  test('the far platform is shut west by the rubbish and east by the '
      'derailed train, and the breach is the way on', () {
    final world = createGameWorld();
    final landing = travel(world, terminiFarFlightTiles.first, Direction.north);
    expect(farPlatform.bounds.contains(landing), isTrue);
    final reached = from(world, landing, farPlatform);
    final xs = reached.keys.map((tile) => tile.x);
    expect(xs.reduce((a, b) => a < b ? a : b), greaterThan(farPlatform.left));
    expect(xs.reduce((a, b) => a > b ? a : b), lessThan(farPlatform.right));
    // Both the rubbish and the train are a long walk from the platform.
    final platformEdge = farPlatform.tilesOf('=');
    final west = platformEdge.map((t) => t.x).reduce((a, b) => a < b ? a : b);
    final east = platformEdge.map((t) => t.x).reduce((a, b) => a > b ? a : b);
    expect(west - xs.reduce((a, b) => a < b ? a : b), greaterThan(10));
    expect(xs.reduce((a, b) => a > b ? a : b) - east, greaterThan(10));
    expect(
      terminiBreachTiles.any(
        (tile) => reached.containsKey(tile.step(Direction.south)),
      ),
      isTrue,
    );
    // In a hollow of the rubbish, a backpack with two rounds.
    final backpack = world.pickups[terminiRubbishBackpackId]!;
    expect(backpack.ammo, 2);
    expect(reached.containsKey(backpack.position), isTrue);
    expect(
      Direction.values
          .map(backpack.position.step)
          .where((tile) => farPlatform.kindOf(_glyph(tile)) == TileKind.wall),
      isNotEmpty,
      reason: 'it lies up against the heap',
    );
    final street = travel(world, terminiBreachTiles.first, Direction.north);
    expect(marsala.bounds.contains(street), isTrue);
    expect(world.map.tileAt(street).isWalkable, isTrue);
  });

  test('the overpass goes on to the concourse, and its doorways out onto '
      'the piazza in front of the station', () {
    final world = createGameWorld();
    final hall = travel(world, overpass.tilesOf('E').first, Direction.south);
    expect(concourse.bounds.contains(hall), isTrue);
    final reached = from(world, hall, concourse);
    for (final door in concourse.tilesOf('O')) {
      expect(reached.containsKey(door.step(Direction.north)), isTrue);
      final out = travel(world, door, Direction.south);
      expect(piazza.bounds.contains(out), isTrue);
      expect(world.map.tileAt(out).isWalkable, isTrue);
    }
    // The station's front, and its three doorways in it.
    expect(piazza.tilesOf(']'), isNotEmpty);
    expect(piazza.tilesOf('{'), hasLength(concourse.tilesOf('O').length));
  });

  test('every door of Rome leads both ways onto walkable ground', () {
    final world = createGameWorld();
    final rome = gamePlaces.where((place) => place.level == LevelId.rome);
    for (final MapEntry(key: door, value: portal) in world.portals.entries) {
      final there = placeAt(door);
      // The train's door leads aboard wherever the train is parked.
      if (there == null ||
          !rome.contains(there) ||
          door == terminiTrainDoorTile) {
        continue;
      }
      expect(world.map.tileAt(door).isWalkable, isTrue, reason: '$door');
      expect(world.map.tileAt(portal.to).isWalkable, isTrue, reason: '$door');
      final back = world.portals.entries.where(
        (entry) => placeAt(entry.key) == placeAt(portal.to),
      );
      expect(
        back.any((entry) => placeAt(entry.value.to) == there),
        isTrue,
        reason: 'no way back from ${placeAt(portal.to)!.id} to ${there.id}',
      );
    }
  });

  test('Rome ends, for now, where its streets run off the map', () {
    final ends = workInProgressEnds.keys;
    expect(ends.where(piazza.bounds.contains), isNotEmpty);
    expect(ends.where(marsala.bounds.contains), isNotEmpty);
    // West of Termini, where the piazza runs off the map.
    expect(
      workInProgressEnds[GridPoint(piazza.origin.x, piazza.origin.y + 8)],
      Direction.east,
    );
    for (final station in <Place>[termini, overpass, farPlatform, concourse]) {
      expect(ends.where(station.bounds.contains), isEmpty, reason: '$station');
    }
  });

  test('fires burn in the streets of Rome too', () {
    final rome = gamePlaces.where((place) => place.level == LevelId.rome);
    final fires = outdoorFireSpots.where(
      (spot) => rome.any((place) => place.bounds.contains(spot.tile)),
    );
    expect(fires, hasLength(romeFireSpots.length));
    expect(romeFireSpots, isNotEmpty);
  });

  test("Rome's dead stand where they can walk", () {
    final world = createGameWorld();
    for (final MapEntry(key: id, value: spots) in romeZombieSpots.entries) {
      final there = place(id);
      for (final spot in spots) {
        final tile = GridPoint(
          there.origin.x + spot.x,
          there.origin.y + spot.y,
        );
        expect(world.map.tileAt(tile).isWalkable, isTrue, reason: '$id $spot');
      }
    }
  });
}

/// The glyph of the far platform's rows at [tile], on the shared grid.
String _glyph(GridPoint tile) {
  final far = place(PlaceId.terminiFarPlatform);
  return far.rows[tile.y - far.origin.y][tile.x - far.origin.x];
}

extension on Place {
  int get left => bounds.left;
  int get right => bounds.right;
}
