import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

/// Every way that runs off a map with no next map ends on the
/// work-in-progress screen, in every level (docs/level_pipeline.md,
/// "Strade incomplete").
void main() {
  test('every walkable edge of every place is a door or a way that goes '
      'nowhere yet', () {
    final world = createGameWorld();
    for (final place in gamePlaces) {
      final bounds = place.bounds;
      for (final (tile, _) in place.glyphs) {
        final onEdge =
            tile.x == bounds.left ||
            tile.x == bounds.right ||
            tile.y == bounds.top ||
            tile.y == bounds.bottom;
        if (!onEdge || !world.map.tileAt(tile).isWalkable) {
          continue;
        }
        // Shut in by wrecks or fire, with nothing but the edge round it:
        // only reached along the edge, through a tile that is an end.
        final shutIn = Direction.values.every((way) {
          final next = tile.step(way);
          final inside =
              next.x > bounds.left &&
              next.x < bounds.right &&
              next.y > bounds.top &&
              next.y < bounds.bottom;
          return !inside || !world.map.tileAt(next).isWalkable;
        });
        expect(
          world.portals.containsKey(tile) ||
              workInProgressEnds.containsKey(tile) ||
              shutIn,
          isTrue,
          reason: '${place.id} $tile leads off the map to nothing',
        );
      }
    }
  });

  test('the step back from an end is inside its place, and not an end', () {
    final world = createGameWorld();
    for (final MapEntry(key: end, value: back) in workInProgressEnds.entries) {
      final inside = end.step(back);
      expect(world.map.tileAt(end).isWalkable, isTrue, reason: '$end');
      expect(world.map.tileAt(inside).isWalkable, isTrue, reason: '$end');
      expect(placeAt(inside), placeAt(end), reason: '$end');
      expect(workInProgressEnds.containsKey(inside), isFalse, reason: '$end');
      expect(world.portals.containsKey(end), isFalse, reason: '$end');
    }
  });

  test('the doors to buildings with no map yet are the last steps of '
      'walkable stairs inside their place, and none is a real door', () {
    final world = createGameWorld();
    expect(workInProgressDoors, <GridPoint>{
      ...hospitalNextRoofStairsFoot,
      ...companyStairs,
    });
    expect(rooftopFarStairs, hasLength(6));
    expect(rooftopFarStairsFoot, hasLength(2));
    expect(hospitalNextRoofStairs, hasLength(4));
    expect(hospitalNextRoofStairsFoot, hasLength(2));
    // The company's flights are one cell in the back wall, like the
    // palazzo's: the wall either side is their railing.
    for (final door in companyStairs) {
      expect(world.map.tileAt(door).isWalkable, isTrue, reason: '$door');
      expect(world.portals.containsKey(door), isFalse, reason: '$door');
      for (final side in <Direction>[Direction.east, Direction.west]) {
        expect(world.map.tileAt(door.step(side)).isWalkable, isFalse);
      }
      expect(world.map.tileAt(door.step(Direction.south)).isWalkable, isTrue);
    }
    for (final door in hospitalNextRoofStairsFoot) {
      expect(world.map.tileAt(door).isWalkable, isTrue, reason: '$door');
      expect(world.portals.containsKey(door), isFalse, reason: '$door');
      expect(workInProgressEnds.containsKey(door), isFalse, reason: '$door');
      // The step before it on its flight, to come down it from.
      final up = world.stairs[door]!;
      expect(world.stairs[door.step(up.opposite)], up, reason: '$door');
    }
  });
}
