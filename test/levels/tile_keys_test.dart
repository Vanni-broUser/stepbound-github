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
}
