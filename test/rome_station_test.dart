import 'dart:math' as math;

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
    final up = travel(world, terminiStairsFoot.first, Direction.south);
    expect(overpass.bounds.contains(up), isTrue);
    final down = travel(world, overpass.tilesOf('D').first, Direction.north);
    expect(down, terminiStairsFoot.first.step(Direction.north));
    expect(
      world.player.component<PositionComponent>().facing,
      Direction.north,
      reason: 'back onto the step above the last, facing down the flight',
    );
  });

  test('both flights up climb through the front wall of the platform and '
      'one cell past it, two cells by two, got onto only from the north', () {
    final world = createGameWorld();
    for (final (flight, foot, platform)
        in <(List<GridPoint>, List<GridPoint>, Place)>[
          (terminiStairsTiles, terminiStairsFoot, termini),
          (terminiFarStairs, terminiFarStairsFoot, farPlatform),
        ]) {
      expect(flight, hasLength(4));
      expect(foot, <GridPoint>[
        flight.first.step(Direction.south),
        flight[1].step(Direction.south),
      ]);
      for (final step in foot) {
        expect(platform.bounds.contains(step), isTrue);
        final wall = platform.rows[step.y - 1 - platform.origin.y];
        expect(
          wall.contains('WWW') || wall.contains('www'),
          isTrue,
          reason: 'the first step is in the front wall, where it always was',
        );
        expect(
          platform.rows[step.y - platform.origin.y].replaceAll('D', ''),
          matches(RegExp(r'^x+$')),
          reason: 'and the last one past it, in the dark',
        );
      }
      for (final step in flight) {
        for (final side in <Direction>[Direction.west, Direction.east]) {
          final beside = step.step(side);
          if (!flight.contains(beside)) {
            expect(world.canStep(beside, step), isFalse, reason: '$step');
          }
        }
      }
      final head = flight.first;
      expect(world.canStep(head.step(Direction.north), head), isTrue);
    }
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

  test('Via Marsala is shut both ways: burning cars west, the palazzi '
      'east; the bank is a wall and the palazzo beside it has its portone '
      'open onto its hall', () {
    final world = createGameWorld();
    expect(workInProgressEnds.keys.where(marsala.bounds.contains), isEmpty);
    final reached = from(
      world,
      world.portals[terminiBreachTiles.first]!.to,
      marsala,
    ).keys;
    int column(GridPoint tile) => tile.x - marsala.origin.x;
    expect(reached.map(column).reduce(math.min), greaterThan(1));
    expect(reached.map(column).reduce(math.max), lessThan(marsala.width - 4));
    // West, the fuel burning in the gap of the pile-up: looked at, it says
    // what it would take.
    expect(world.map.tileAt(marsalaFireTile).kind, TileKind.fire);
    expect(reached, contains(marsalaFireTile.step(Direction.east)));
    expect(world.lookouts, contains(marsalaFireTile));
    // The bank, shut, and the portone just past it.
    final bank = marsala.tilesOf('£');
    expect(bank, isNotEmpty);
    for (final tile in bank) {
      expect(world.map.tileAt(tile).kind, TileKind.wall);
    }
    expect(
      marsalaPortoneTile.x,
      bank.map((tile) => tile.x).reduce(math.max) + 2,
      reason: 'the palazzo right beside the bank',
    );
    expect(reached, contains(marsalaPortoneTile));
    final hall = travel(world, marsalaPortoneTile, Direction.north);
    expect(placeAt(hall)!.id, PlaceId.romePalazzoGround);
  });

  test('Rome ends, for now, where its streets run off the map', () {
    final ends = workInProgressEnds.keys;
    expect(ends.where(piazza.bounds.contains), isNotEmpty);
    // East of Termini, past the roadblock, where the road runs off the map.
    expect(
      workInProgressEnds[GridPoint(piazza.bounds.right, piazza.origin.y + 12)],
      Direction.west,
    );
    // Off Piazza di Santa Maria Maggiore the road runs off the map west,
    // where the map turns the corner of its L, as far as it does east.
    final lines = piazza
        .tilesOf('-')
        .where((tile) => tile.y > piazza.origin.y + 40)
        .toList();
    final square = piazza.tilesOf('°').map((tile) => tile.x);
    final west = lines.where((tile) => tile.x < square.reduce(math.min));
    final east = lines.where((tile) => tile.x > square.reduce(math.max));
    expect(west.length, east.length);
    expect(workInProgressEnds[west.first], Direction.east);
    expect(workInProgressEnds[east.last], Direction.west);
    // West, the road ends against the Baths of Diocletian.
    for (var y = piazza.origin.y; y <= piazza.bounds.bottom; y++) {
      expect(
        workInProgressEnds.containsKey(GridPoint(piazza.origin.x, y)),
        isFalse,
        reason: '$y',
      );
    }
    for (final station in <Place>[termini, overpass, farPlatform, concourse]) {
      expect(ends.where(station.bounds.contains), isEmpty, reason: '$station');
    }
  });

  test('west of Termini the road runs on past more palazzi, up to the '
      'Baths of Diocletian, and ends against them', () {
    final world = createGameWorld();
    final termini = piazza.tilesOf('{').first;
    final baths = piazza.tilesOf('§');
    expect(baths, isNotEmpty);
    // Their front along the north side, from the top of the map down to
    // the pavement, as tall as the station's.
    final front = baths.where((tile) => tile.y == piazza.origin.y);
    expect(front.map((tile) => tile.x).reduce(math.max), lessThan(termini.x));
    // The road, walked west from in front of the station, gets as far as
    // the wing of them across its end.
    final road = GridPoint(termini.x, piazza.origin.y + 13);
    final reached = from(
      world,
      road,
      piazza,
    ).keys.where((tile) => tile.y == road.y);
    final westmost = reached.map((tile) => tile.x).reduce(math.min);
    expect(piazza.tilesOf('§'), contains(GridPoint(westmost - 1, road.y)));
    expect(termini.x - westmost, greaterThan(40), reason: 'a good way on');
  });

  group('the Baths of Diocletian', () {
    final terme = place(PlaceId.termeDiocleziano);

    test('the portal of Santa Maria degli Angeli leads inside, and back '
        'out onto the pavement', () {
      final world = createGameWorld();
      final inside = travel(world, termePortalTile, Direction.north);
      expect(terme.bounds.contains(inside), isTrue);
      expect(world.map.tileAt(inside).isWalkable, isTrue);
      final out = travel(world, terme.tilesOf('E').single, Direction.south);
      expect(out, termePortalTile.step(Direction.south));
      expect(piazza.bounds.contains(out), isTrue);
    });

    test('the vestibule opens onto the great hall, all of it within reach, '
        'with nothing let into its floor that reads as a barrier', () {
      final world = createGameWorld();
      final start = terme.tilesOf('E').single.step(Direction.north);
      final reached = from(world, start, terme).keys.toSet();
      for (final (tile, glyph) in terme.glyphs) {
        if (world.map.tileAt(tile).isWalkable) {
          expect(reached, contains(tile), reason: '$glyph at $tile');
        }
      }
      expect(terme.tilesOf('O'), hasLength(8), reason: 'the eight columns');
      expect(terme.tilesOf('m'), isEmpty, reason: 'no meridian');
      expect(workInProgressEnds.keys.where(terme.bounds.contains), isEmpty);
    });

    test('the dead wander inside too, where they can walk', () {
      final world = createGameWorld();
      final inside = world.entities.values.where(
        (entity) =>
            entity.kind != EntityKind.player &&
            terme.bounds.contains(
              entity.component<PositionComponent>().position,
            ),
      );
      expect(
        inside,
        hasLength(romeZombieSpots[PlaceId.termeDiocleziano]!.length),
      );
      for (final zombie in inside) {
        final at = zombie.component<PositionComponent>().position;
        expect(world.map.tileAt(at).isWalkable, isTrue, reason: '$at');
      }
    });

    test('a brown sign stands on the pavement in front of them, and Mario '
        'walks round it', () {
      final world = createGameWorld();
      final sign = piazza.tileOf('¤');
      expect(world.map.tileAt(sign).isWalkable, isFalse);
      expect(sign.y, termePortalTile.y + 1, reason: 'on the pavement');
    });
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
