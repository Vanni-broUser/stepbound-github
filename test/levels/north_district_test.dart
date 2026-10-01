import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  final north = place(PlaceId.northDistrict);
  final world = createGameWorld();
  final reached = world.map.floodFillDistances(
    northDistrictBackExitTile.step(Direction.north),
    maxDistance: north.width * north.height,
  );

  GridPoint local(GridPoint tile) =>
      GridPoint(tile.x - north.origin.x, tile.y - north.origin.y);
  String glyph(GridPoint tile) =>
      north.rows[tile.y - north.origin.y][tile.x - north.origin.x];

  // Where the branch off the road north comes in, and where the side road
  // down from its crossroads comes out on the road west of the square.
  // (The crossroads has zebras of its own, further west and north.)
  final zebras = north.tilesOf('Z');
  final branchMouth = zebras.where((tile) => tile.x == zebras.last.x).toList();
  final crossings = north.tilesOf('V');
  final sideRoadMouth = crossings
      .where((tile) => tile.y == crossings.last.y)
      .toList();

  test('up the road north, before the car park, a branch turns west to a '
      'crossroads, and its side road south comes out on the road west of '
      'the square', () {
    expect(branchMouth, hasLength(3));
    expect(sideRoadMouth, hasLength(5));
    for (final tile in <GridPoint>[...branchMouth, ...sideRoadMouth]) {
      expect(reached.containsKey(tile), isTrue, reason: '${local(tile)}');
    }
    // Between the square's fountain and the car park.
    final fountain = north.tilesOf('O');
    final parking = north.tilesOf('L');
    for (final tile in branchMouth) {
      expect(tile.y, lessThan(fountain.first.y));
      expect(tile.y, greaterThan(parking.last.y));
    }
    // It comes out west of the square.
    expect(sideRoadMouth.last.x, lessThan(fountain.first.x));
    final crossing = sideRoadMouth[sideRoadMouth.length ~/ 2];
    expect(
      glyph(crossing.step(Direction.south)),
      '.',
      reason: 'the road west, under the zebra crossing',
    );
  });

  test('north of the crossroads a pile-up closes the road, its one free '
      'lane burning, and looking at the fire says what it would take', () {
    expect(world.map.tileAt(northDistrictFireTile).kind, TileKind.fire);
    expect(world.map.tileAt(northDistrictFireTile).blocksSight, isFalse);
    expect(world.lookouts, contains(northDistrictFireTile));
    // Wreck to wreck across the road, sidewalks and all.
    final row = local(northDistrictFireTile).y;
    final across = north.rows[row].substring(
      local(northDistrictFireTile).x - 3,
      local(northDistrictFireTile).x + 4,
    );
    expect(across, 'kCC?CCv');
    // Nothing past it can be walked to.
    for (final tile in reached.keys) {
      expect(
        tile.y > northDistrictFireTile.y ||
            (tile.x - northDistrictFireTile.x).abs() > 3,
        isTrue,
        reason: 'reached ${local(tile)}, past the pile-up',
      );
    }
    // Walked up to from the crossroads, and looked at.
    final stand = northDistrictFireTile.step(Direction.south);
    expect(reached.containsKey(stand), isTrue);
    final looking = createGameWorld();
    looking.player.component<PositionComponent>()
      ..position = stand
      ..facing = Direction.north;
    final events = const TurnScheduler().advance(
      looking,
      const InteractAction(),
    );
    expect(events.whereType<LookedOutEvent>().single.at, northDistrictFireTile);
  });

  test('round the crossroads lie the worst of the crashes: overturned cars, '
      'wrecks, the dead and their blood', () {
    final crossroads = GridRect(
      sideRoadMouth.first.x - 1,
      northDistrictFireTile.y + 1,
      branchMouth.first.x,
      sideRoadMouth.first.y - 1,
    );
    final counts = <String, int>{};
    for (final (tile, found) in north.glyphs) {
      if (crossroads.contains(tile)) {
        counts.update(found, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    expect((counts['U'] ?? 0) ~/ 2, greaterThanOrEqualTo(4), reason: 'UU');
    expect((counts['C'] ?? 0) ~/ 2, greaterThanOrEqualTo(3), reason: 'CC');
    expect(counts['d'] ?? 0, greaterThanOrEqualTo(8), reason: 'the dead');
    expect(counts['D'] ?? 0, greaterThanOrEqualTo(2), reason: 'piled up');
    expect(counts['>'] ?? 0, greaterThanOrEqualTo(10), reason: 'blood');
  });

  test('past the side road, the road west runs on between shop fronts to '
      'the hospital, moved out west of it', () {
    final hospital = north.tilesOf('G');
    final crossing = sideRoadMouth.first;
    for (final tile in hospital) {
      expect(tile.x, lessThan(crossing.x - 30), reason: '${local(tile)}');
    }
    expect(hospitalForecourt.left, hospital.first.x);
    // A band of fronts all the way from the forecourt to the side road.
    final forecourtEast = hospital
        .map((tile) => tile.x)
        .reduce((a, b) => a > b ? a : b);
    for (var x = forecourtEast + 1; x < crossing.x - 1; x++) {
      expect(
        'Hf',
        contains(glyph(GridPoint(x, crossing.y - 1))),
        reason: 'column ${x - north.origin.x}',
      );
    }
  });

  test('the crossroads has a zebra crossing across each of its arms and a '
      'traffic light on its corners', () {
    final crossroads = GridRect(
      sideRoadMouth.first.x - 1,
      branchMouth.first.y - 2,
      sideRoadMouth.last.x + 2,
      branchMouth.last.y + 2,
    );
    final zebras = <GridPoint>[
      for (final (tile, found) in north.glyphs)
        if ('VZ'.contains(found) && crossroads.contains(tile)) tile,
    ];
    // Five across each of the side road's arms, three across the branch.
    expect(zebras, hasLength(13));
    final lights = <GridPoint>[
      for (final (tile, found) in north.glyphs)
        if (found == 'T' && crossroads.contains(tile)) tile,
    ];
    expect(lights, hasLength(4));
    for (final tile in <GridPoint>[...zebras]) {
      expect(world.map.tileAt(tile).isWalkable, isTrue);
    }
  });

  test('a few steps short of the burning pile-up, a camp of its own, '
      'reached from the crossroads, where resting saves', () {
    final camp = northDistrictBlazeCampTile;
    expect(world.campfires, contains(camp));
    expect(campfireNames[camp], 'Davanti all’incendio');
    expect(camp.manhattanDistanceTo(northDistrictFireTile), lessThan(6));
    expect(world.map.tileAt(camp).isWalkable, isFalse);
    // The other camp keeps its name, and stays the district's first.
    final barracksCamp = world.campfires.firstWhere(north.bounds.contains);
    expect(barracksCamp, isNot(camp));
    expect(campfireNames[barracksCamp], 'Dietro la caserma');
    // Walked up to from the crossroads, and rested at.
    final beside = Direction.values
        .map(camp.step)
        .firstWhere(reached.containsKey);
    final resting = createGameWorld();
    resting.player.component<PositionComponent>()
      ..position = beside
      ..facing = Direction.values.firstWhere((way) => beside.step(way) == camp);
    final events = const TurnScheduler().advance(
      resting,
      const InteractAction(),
    );
    expect(events.whereType<CampfireUsedEvent>().single.at, camp);
    // Still the way up to the fire, past it.
    expect(
      reached.containsKey(northDistrictFireTile.step(Direction.south)),
      isTrue,
    );
  });
}
