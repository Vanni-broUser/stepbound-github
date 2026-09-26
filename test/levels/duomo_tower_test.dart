import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  final roof = place(PlaceId.duomoTowerRoof);

  GridPoint mario(WorldState world) =>
      world.player.component<PositionComponent>().position;

  /// Walks Mario from [from] to [to] inside one place, one step at a time
  /// along the shortest way, and returns the events of the last step.
  List<WorldEvent> walk(WorldState world, GridPoint from, GridPoint to) {
    world.player.component<PositionComponent>().position = from;
    final distances = world.map.floodFillDistances(to, maxDistance: 400);
    expect(distances.containsKey(from), isTrue, reason: '$to from $from');
    var events = <WorldEvent>[];
    while (mario(world) != to) {
      final here = mario(world);
      final direction = Direction.values.firstWhere((direction) {
        final next = here.step(direction);
        return distances[next] == distances[here]! - 1;
      });
      events = const TurnScheduler().advance(world, MoveAction(direction));
    }
    return events;
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

  test('from the door the key opens, Mario climbs floor after floor to the '
      'top of the tower, and comes back down the same way', () {
    final world = createTutorialWorld();
    world.map.setTile(duomoUpperLockedDoorTile, const Tile(TileKind.floor));

    final climb = <(PlaceId, GridPoint, GridPoint)>[
      (PlaceId.duomoUpper, duomoUpperLockedDoorTile, duomoSecondFloorStairTile),
      (PlaceId.duomoSecondFloor, duomoSecondFloorUpTile, duomoTowerStairTile),
      (PlaceId.duomoTower, duomoTowerUpTile, duomoBellsStairTile),
      (PlaceId.duomoBells, duomoBellsUpTile, duomoRoofHatchTile),
    ];
    var at = duomoUpperLockedDoorTile.step(Direction.south);
    for (final (from, door, landing) in climb) {
      expect(place(from).bounds.contains(door), isTrue);
      final front = door.step(Direction.south);
      // Every floor is walked across, from where the stairs left Mario to
      // the foot of the next way up.
      walk(world, at, front);
      at = through(world, front, door);
      expect(at, landing.step(Direction.north));
      expect(placeAt(at), isNot(place(from)));
    }
    expect(roof.bounds.contains(at), isTrue);

    // And down again: every way back lands in front of the way up.
    for (final (_, door, landing) in climb.reversed) {
      final back = through(world, landing.step(Direction.north), landing);
      expect(back, door.step(Direction.south));
    }
  });

  test('every way up is a doorway in the back wall, walled either side', () {
    final world = createTutorialWorld();
    for (final door in <GridPoint>[
      duomoSecondFloorUpTile,
      duomoTowerUpTile,
      duomoBellsUpTile,
    ]) {
      for (final side in <Direction>[Direction.east, Direction.west]) {
        expect(world.map.tileAt(door.step(side)).isWalkable, isFalse);
      }
      expect(world.map.tileAt(door.step(Direction.south)).isWalkable, isTrue);
    }
  });

  test('both tower floors are climbed by a broad flight of four steps, '
      'three wide, against the east wall, the doorway over its middle', () {
    for (final id in <PlaceId>[PlaceId.duomoTower, PlaceId.duomoBells]) {
      final tower = place(id);
      final steps = tower.tilesOf('s').toSet();
      final xs = steps.map((tile) => tile.x).toSet().toList()..sort();
      final ys = steps.map((tile) => tile.y).toSet();
      expect(xs, hasLength(3), reason: '$id: three wide');
      expect(ys, hasLength(4), reason: '$id: four steps');
      expect(steps, hasLength(12), reason: '$id: a solid block');
      expect(xs.last, tower.bounds.right - 2, reason: 'against the wall');
      final door = tower.tileOf('U');
      expect(door.x, xs[1], reason: '$id: the doorway over its middle');
      expect(steps, contains(door.step(Direction.south)));
      // The railing runs down the open side.
      expect(
        tower.tilesOf('|').every((tile) => tile.x == xs.first - 1),
        isTrue,
      );
    }
  });

  test('on every floor above the nave the way up is straight above the way '
      'down, two columns in from the east wall', () {
    for (final (id, up, down) in <(PlaceId, String, String)>[
      (PlaceId.duomoUpper, 'L', 'D'),
      (PlaceId.duomoSecondFloor, 'U', 'D'),
      (PlaceId.duomoTower, 'U', 'D'),
      (PlaceId.duomoBells, 'U', 'D'),
    ]) {
      final floor = place(id);
      final door = floor.tileOf(up);
      final stairs = floor.tileOf(down);
      expect(door.x, stairs.x, reason: '$id');
      final eastWall = floor.bounds.right - 1;
      expect(eastWall - door.x, 2, reason: '$id: wall, a free cell, door');
      // Beside the way down there is floor: in the towers the flight
      // fills the other end.
      expect(
        floor.rows[stairs.y - 1 - floor.origin.y][eastWall -
            1 -
            floor.origin.x],
        '.',
        reason: '$id: the cell beside the stairs is free',
      );
    }
    // On the roof the hatch keeps the same place, two in from the parapet.
    final hatch = duomoRoofHatchTile;
    expect(
      roof.rows[hatch.y - roof.origin.y][hatch.x - roof.origin.x + 2],
      '^',
    );
  });

  test('from the parapet facing the other tower Mario measures the gap '
      'for a grappling hook', () {
    final world = createTutorialWorld();
    expect(world.lookouts, contains(duomoTowerLookoutTile));
    expect(world.map.tileAt(duomoTowerLookoutTile).isWalkable, isFalse);
    world.player.component<PositionComponent>()
      ..position = duomoTowerLookoutTile.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(events.whereType<LookedOutEvent>().single.at, duomoTowerLookoutTile);
  });

  test('the backpack on the other tower is seen and never reached', () {
    final world = createTutorialWorld();
    final backpack = world.pickups[duomoFarTowerBackpackId]!;
    expect(backpack.active, isTrue);
    expect(roof.bounds.contains(backpack.position), isTrue);
    final reached = world.map.floodFillDistances(
      duomoRoofHatchTile.step(Direction.north),
      maxDistance: roof.width * roof.height,
    );
    for (final side in Direction.values) {
      expect(reached.containsKey(backpack.position.step(side)), isFalse);
    }
    // The other tower stands east, across the nave.
    expect(backpack.position.x, greaterThan(duomoTowerLookoutTile.x));
  });
}
