import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  final piazza = place(PlaceId.piazzaCinquecento);

  GridPoint onPiazza(int x, int y) =>
      GridPoint(piazza.origin.x + x, piazza.origin.y + y);

  test('the road east of Termini runs on to a roadblock of burning '
      'carabinieri and police cars, pavement to pavement, that nobody '
      'gets past', () {
    final world = createGameWorld();
    final cars = <GridPoint>[
      for (final glyph in roadblockCarGlyphs.split(''))
        ...piazza.tilesOf(glyph),
    ];
    // Carabinieri and police, some on their roofs, some on their wheels.
    for (final glyph in roadblockCarGlyphs.split('')) {
      expect(piazza.tilesOf(glyph), isNotEmpty, reason: glyph);
    }
    for (final car in cars) {
      expect(world.map.tileAt(car).kind, TileKind.obstacle);
    }
    // Every car is burning: one flame on its first cell.
    expect(roadblockFireSpots, hasLength(cars.length ~/ 2));
    expect(
      roadblockFireSpots.every((spot) => spot.kind == FireKind.car),
      isTrue,
    );
    expect(romeFireSpots, containsAll(roadblockFireSpots));
    // From in front of Termini, the road past the roadblock is never
    // reached.
    final reached = world.map.floodFillDistances(
      onPiazza(40, 12),
      maxDistance: piazza.width * piazza.height,
    );
    final east = cars.map((tile) => tile.x).reduce((a, b) => a > b ? a : b);
    // The road and its two pavements, rows 10 to 16 of the piazza.
    final road = <int>{for (var y = 10; y <= 16; y++) piazza.origin.y + y};
    for (final (tile, _) in piazza.glyphs) {
      if (tile.x > east &&
          road.contains(tile.y) &&
          world.map.tileAt(tile).isWalkable) {
        expect(reached.containsKey(tile), isFalse, reason: '$tile');
      }
    }
    expect(reached.containsKey(roadblockFireTile.step(Direction.west)), isTrue);
  });

  test('the gap in the middle lane is fuel on fire, and looking at it says '
      'what it would take', () {
    final world = createGameWorld();
    for (final tile in piazza.tilesOf('?')) {
      expect(world.map.tileAt(tile).kind, TileKind.fire);
    }
    expect(world.lookouts, contains(roadblockFireTile));
    world.player.component<PositionComponent>()
      ..position = roadblockFireTile.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(events.whereType<LookedOutEvent>().single.at, roadblockFireTile);
  });

  test('the tank stands in front of it, the carabinieri are back as the '
      'dead round it, and one of them left a backpack', () {
    final world = createGameWorld();
    expect(piazza.tilesOf('t'), hasLength(8));
    for (final tile in piazza.tilesOf('t')) {
      expect(world.map.tileAt(tile).kind, TileKind.obstacle);
    }
    final carabinieri = world.entities.values
        .where((entity) => entity.id.startsWith(roadblockCarabinierePrefix))
        .toList();
    expect(carabinieri, hasLength(roadblockCarabiniereTiles.length));
    expect(carabinieri, hasLength(5));
    expect(
      carabinieri.every((entity) => entity.kind == EntityKind.carabiniere),
      isTrue,
    );
    final backpack = world.pickups[roadblockBackpackId]!;
    expect(backpack.position, roadblockBackpackTile);
    expect(backpack.ammo, 2);
  });
}
