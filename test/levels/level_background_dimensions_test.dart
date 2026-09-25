import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

/// The eight bytes every PNG file opens with.
const List<int> _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

/// The size a PNG declares in its IHDR chunk: two big-endian unsigned
/// 32-bit numbers at bytes 16..24, right after the eight signature bytes
/// and the chunk's length and type. Big-endian is what getUint32 reads by
/// default. The pixels are never decoded: the header is all this test
/// needs.
({int width, int height}) _pngSize(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'missing background $path');
  final bytes = file.readAsBytesSync();
  expect(
    bytes.length,
    greaterThanOrEqualTo(24),
    reason: '$path is too short to hold a PNG header',
  );
  expect(bytes.sublist(0, 8), _pngSignature, reason: '$path is not a PNG');
  expect(
    String.fromCharCodes(bytes.sublist(12, 16)),
    'IHDR',
    reason: '$path does not open with its header chunk',
  );
  final header = ByteData.sublistView(bytes, 16, 24);
  return (width: header.getUint32(0), height: header.getUint32(4));
}

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

  test('every baked background measures its place, tile for tile', () {
    final tile = levelTileSize.round();
    for (final place in tutorialPlaces) {
      final expected = (width: place.width * tile, height: place.height * tile);
      expect(
        _pngSize(place.background),
        expected,
        reason:
            '${place.id}: ${place.background} should be '
            '${place.width}x${place.height} tiles of $tile px. Re-run the '
            'baker of this place (python tools/build_levels.py) after '
            'changing its rows',
      );
      final alternate = place.alternateBackground;
      if (alternate != null) {
        expect(
          _pngSize(alternate),
          expected,
          reason:
              '${place.id}: $alternate is the same place seen again, so '
              'it measures like ${place.background}',
        );
      }
    }
  });
}
