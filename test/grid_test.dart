import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  group('TileMap', () {
    test('finds a shortest first step around walls', () {
      final map = TileMap.fromAscii(const <String>[
        '#####',
        '#.#.#',
        '#...#',
        '#####',
      ]);

      final step = map.shortestNextStep(
        start: const GridPoint(1, 1),
        target: const GridPoint(3, 1),
      );

      expect(step, const GridPoint(1, 2));
    });

    test('closed doors block sight and movement', () {
      final map = TileMap.fromAscii(const <String>['#####', '#.+.#', '#####']);

      expect(map.tileAt(const GridPoint(2, 1)).isWalkable, isFalse);
      expect(
        map.hasLineOfSight(const GridPoint(1, 1), const GridPoint(3, 1)),
        isFalse,
      );
    });

    test('flood fill respects walls and maximum distance', () {
      final map = TileMap.fromAscii(const <String>[
        '#######',
        '#.....#',
        '#######',
      ]);

      final distances = map.floodFillDistances(
        const GridPoint(1, 1),
        maxDistance: 2,
      );

      expect(distances[const GridPoint(3, 1)], 2);
      expect(distances, isNot(contains(const GridPoint(4, 1))));
    });
  });
}
