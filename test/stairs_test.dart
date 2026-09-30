import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

/// Every flight of stairs is climbed only along it: onto its first step
/// from the floor in front, step by step to the last, which is the door,
/// and off it the same way (docs/level_pipeline.md, "Le scale").
void main() {
  late WorldState world;

  setUp(() => world = createGameWorld());

  GridPoint mario() => world.player.component<PositionComponent>().position;

  /// Mario at [from] takes a step [way]; the events of the turn.
  List<WorldEvent> step(GridPoint from, Direction way) {
    world.player.component<PositionComponent>()
      ..position = from
      ..facing = way;
    return const TurnScheduler().advance(world, MoveAction(way));
  }

  group('the stairwell past the airliner, down eastward', () {
    late GridPoint head;
    late GridPoint middle;

    setUp(() {
      head = _topLeft(rooftopFarStairs);
      middle = head.step(Direction.east);
    });

    test('is got onto from the floor in front of its head, and climbed '
        'down to the last step, the door into the palazzo', () {
      step(head.step(Direction.west), Direction.east);
      expect(mario(), head);
      step(head, Direction.east);
      expect(mario(), middle);
      final events = step(middle, Direction.east);
      expect(events.whereType<MovedEvent>().single.from, middle);
      expect(
        rooftopFarStairsFoot,
        contains(events.whereType<MovedEvent>().single.to),
      );
      expect(mario(), palazzoRoofStairs.step(Direction.south));
    });

    test('is shut along its sides and its far end, where its rails are', () {
      for (final (from, way) in <(GridPoint, Direction)>[
        (head.step(Direction.north), Direction.south),
        (middle.step(Direction.north), Direction.south),
        (rooftopFarStairsFoot.first.step(Direction.east), Direction.west),
      ]) {
        if (world.stairs.containsKey(from) ||
            !world.map.tileAt(from).isWalkable) {
          continue;
        }
        final events = step(from, way);
        expect(mario(), from, reason: '$from $way');
        expect(events.whereType<BlockedEvent>().single.reason, 'stairs');
      }
    });

    test('can be crossed sideways on a step, and is left only back the way '
        'it was got onto', () {
      final beside = rooftopFarStairs.firstWhere(
        (step) => step.x == head.x && step != head,
      );
      final way = beside.y > head.y ? Direction.south : Direction.north;
      step(head, way);
      expect(mario(), beside);

      final off = beside.step(way);
      if (world.map.tileAt(off).isWalkable) {
        step(beside, way);
        expect(mario(), beside, reason: 'over the rail');
      }
      step(beside, Direction.west);
      expect(mario(), beside.step(Direction.west));
    });
  });

  test('the stairwell by the hospital roof is climbed down southward: its '
      'first step walked on, its last the door', () {
    final head = _topLeft(hospitalNextRoofStairs);
    step(head.step(Direction.north), Direction.south);
    expect(mario(), head);
    expect(workInProgressDoors.contains(head), isFalse);
    step(head, Direction.south);
    expect(hospitalNextRoofStairsFoot, contains(mario()));
    // Not from the side of the first step.
    final side = head.step(Direction.west);
    if (!world.stairs.containsKey(side) && world.map.tileAt(side).isWalkable) {
      step(side, Direction.east);
      expect(mario(), side);
    }
  });

  test("the hypermarket's stairs: the first step is walked on, the last "
      'is the door upstairs', () {
    final flight = place(PlaceId.mallGround).tilesOf('U');
    final first = flight.reduce((a, b) => a.y > b.y ? a : b);
    step(first.step(Direction.south), Direction.north);
    expect(mario(), first);
    final events = step(first, Direction.north);
    expect(events.whereType<TeleportedEvent>(), hasLength(1));
    expect(placeAt(mario())?.id, PlaceId.mallFirst);
  });

  test('a zombie takes the stairs the same way: never over their rails', () {
    final head = _topLeft(rooftopFarStairs);
    final beside = head.step(Direction.north);
    final target = head.step(Direction.east);
    final next = world.map.shortestNextStep(
      start: beside,
      target: target,
      canStep: world.canStep,
      maxDistance: 20,
    );
    expect(next, isNot(head), reason: 'onto the first step from its side');
    expect(world.canStep(beside, head), isFalse);
    expect(world.canStep(head.step(Direction.west), head), isTrue);
  });

  test('every other stairway, one cell wide in its wall, can only be got '
      'onto from the floor in front of it', () {
    for (final place in gamePlaces) {
      for (final (tile, glyph) in place.glyphs) {
        // The hatches in the roofs, and the tail torn open, are holes in
        // the floor: they are got into from any side.
        if (!'UD'.contains(glyph) ||
            _roofs.contains(place.id) ||
            !world.portals.containsKey(tile) ||
            world.stairs.containsKey(tile)) {
          continue;
        }
        final ways = <GridPoint>[
          for (final way in Direction.values)
            if (placeAt(tile.step(way)) == place &&
                world.map.tileAt(tile.step(way)).isWalkable &&
                !world.portals.containsKey(tile.step(way)))
              tile.step(way),
        ];
        expect(
          ways.length,
          lessThanOrEqualTo(1),
          reason: '${place.id} $glyph $tile can be got onto from $ways',
        );
      }
    }
  });

  test('the stairs survive a save', () {
    final restored = restoreGameWorld(saveGameWorld(world));
    expect(restored.stairs, world.stairs);
    expect(restored.stairs, <GridPoint, Direction>{
      ...hometownStairs,
      ...romeStairs,
    });
  });
}

const Set<PlaceId> _roofs = <PlaceId>{
  PlaceId.duomoTowerRoof,
  PlaceId.hospitalRoof,
  PlaceId.airlinerRoofs,
};

/// The step of [flight] furthest west, and of those the northernmost.
GridPoint _topLeft(List<GridPoint> flight) =>
    flight.reduce((a, b) => a.x < b.x || (a.x == b.x && a.y < b.y) ? a : b);
