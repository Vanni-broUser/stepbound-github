import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/render/tile_atlas.dart';

void main() {
  group('rowHas', () {
    // The aisle of a cabin is every row with no seat in it.
    final grid = GlyphGrid(<String>['.T.', '...', 'TTT']);
    const here = RowHasKey(dy: 0, glyph: 'T');
    const above = RowHasKey(dy: -1, glyph: 'T');
    const below = RowHasKey(dy: 1, glyph: 'T');

    test('asks about the whole row, whatever the column', () {
      expect(here.holds(grid, 0, 0), isTrue);
      expect(here.holds(grid, 2, 0), isTrue);
      expect(here.holds(grid, 1, 1), isFalse);
    });

    test('looks at the rows beside it, and none outside the place', () {
      expect(above.holds(grid, 0, 1), isTrue);
      expect(below.holds(grid, 0, 1), isTrue);
      expect(above.holds(grid, 0, 0), isFalse);
      expect(below.holds(grid, 0, 2), isFalse);
    });

    test('is read from the manifest', () {
      final key = TileKey.fromJson(<String, Object?>{
        'kind': 'rowHas',
        'dy': -1,
        'glyph': 'T',
      });
      expect(key, isA<RowHasKey>());
      expect(key.holds(grid, 0, 1), isTrue);
    });
  });

  group('a rule that leans out over the cell above', () {
    Map<String, Object?> rule({required List<List<int>> up}) =>
        <String, Object?>{
          'layer': 'structures',
          'glyphs': 'T',
          'keys': <Object?>[],
          'buckets': <Object?>[
            <int>[1, 2, 3],
          ],
          'up': up,
        };

    test('pairs each tile with the one that falls above it', () {
      final parsed = TileRule.fromJson(
        rule(
          up: <List<int>>[
            <int>[4, 5, 6],
          ],
        ),
      );
      expect(parsed.up, <List<int>>[
        <int>[4, 5, 6],
      ]);
    });

    test('may leave a bucket without overhang', () {
      final parsed = TileRule.fromJson(rule(up: <List<int>>[<int>[]]));
      expect(parsed.up!.single, isEmpty);
    });

    test('refuses an overhang that could part from its tile', () {
      // Three tiles below and two above: the variant that picks the third
      // would have nothing to lean on, and the picture would tear.
      expect(
        () => TileRule.fromJson(
          rule(
            up: <List<int>>[
              <int>[4, 5],
            ],
          ),
        ),
        throwsFormatException,
      );
    });
  });

  group('beforeRun', () {
    // Camp beds three tiles long, one against the wall on the left and one
    // with the wall on its right: the pillow goes at the end by a wall.
    final grid = GlyphGrid(<String>['WBBB...', '...BBBW']);
    const key = BeforeRunKey(glyphs: 'xW');

    test('is the same for every tile of a run', () {
      for (var x = 1; x <= 3; x++) {
        expect(key.holds(grid, x, 0), isTrue, reason: 'tile $x');
      }
      for (var x = 3; x <= 5; x++) {
        expect(key.holds(grid, x, 1), isFalse, reason: 'tile $x');
      }
    });

    test('is read from the manifest', () {
      final parsed = TileKey.fromJson(<String, Object?>{
        'kind': 'beforeRun',
        'glyphs': 'xW',
      });
      expect(parsed, isA<BeforeRunKey>());
      expect(parsed.holds(grid, 2, 0), isTrue);
    });
  });

  group('between', () {
    // Two roofs with a dark gap between them, and darkness off the edge.
    final grid = GlyphGrid(<String>['x#x', 'x#x', 'xxx', 'x#x', 'xxx']);
    const key = BetweenKey(glyph: 'x');

    test('is the gap, not the edge of the map', () {
      expect(key.holds(grid, 1, 2), isTrue);
      expect(key.holds(grid, 1, 4), isFalse, reason: 'nothing below it');
      expect(key.holds(grid, 0, 2), isFalse, reason: 'a column of nothing');
    });

    test('is read from the manifest', () {
      final parsed = TileKey.fromJson(<String, Object?>{
        'kind': 'between',
        'glyph': 'x',
      });
      expect(parsed, isA<BetweenKey>());
      expect(parsed.holds(grid, 1, 2), isTrue);
    });
  });
}
