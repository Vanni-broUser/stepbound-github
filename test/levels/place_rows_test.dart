import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('every place is a rectangle of glyphs', () {
    for (final place in tutorialPlaces) {
      for (final (index, row) in place.rows.indexed) {
        expect(
          row.length,
          place.width,
          reason:
              '${place.id}: row $index is ${row.length} glyphs wide, the '
              'place is ${place.width}. Place.width reads the first row '
              'only, so a row out of line silently shifts everything '
              'painted after it',
        );
      }
    }
  });
}
