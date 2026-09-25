import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/tile_atlas.dart';
import 'package:stepbound/game/render/tile_place_component.dart';

/// The front layer of [place], as the game draws it over the characters.
Future<(ByteData, int)> _front(Place place) async {
  final component = TilePlaceComponent(place: place);
  await component.onLoad();
  final recorder = ui.PictureRecorder();
  component.front.render(ui.Canvas(recorder));
  final width = place.width * levelTileSize.round();
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    width,
    place.height * levelTileSize.round(),
  );
  picture.dispose();
  return ((await image.toByteData())!, width);
}

/// How many pixels of the cell [x], [y] (the place's own) the front covers.
int _covered(ByteData front, int width, int x, int y) {
  final size = levelTileSize.round();
  var count = 0;
  for (var py = y * size; py < (y + 1) * size; py++) {
    for (var px = x * size; px < (x + 1) * size; px++) {
      if (front.getUint8((py * width + px) * 4 + 3) > 0) {
        count++;
      }
    }
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('what stands taller than its cell is in front of whoever is behind '
      'it, and only where someone can stand', () async {
    resetTileAtlasCache();
    final street = place(PlaceId.mallNorthStreet);
    final (front, width) = await _front(street);
    final rows = street.rows;
    bool walkable(int x, int y) => Tile(street.kindOf(rows[y][x])).isWalkable;

    var behindHull = 0;
    var behindSigns = 0;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final covered = _covered(front, width, x, y);
        if (!walkable(x, y)) {
          expect(covered, 0, reason: 'nobody stands on ($x, $y)');
          continue;
        }
        final below = y + 1 < rows.length ? rows[y + 1][x] : '';
        if (below == '_' && covered > 0) {
          behindHull++;
          // The feet line is hidden edge to edge: no shoe pokes out where
          // the hull's edge runs down to it.
          final size = levelTileSize.round();
          final feet = (y + 1) * size - 1;
          for (var px = x * size; px < (x + 1) * size; px++) {
            expect(
              front.getUint8((feet * width + px) * 4 + 3),
              greaterThan(0),
              reason: 'feet behind the hull at ($x, $y)',
            );
          }
        }
        if ((below == '/' || below == 'T') && covered > 0) {
          behindSigns++;
        }
      }
    }
    expect(behindHull, greaterThan(0), reason: 'the top of the airliner');
    expect(behindSigns, greaterThan(0), reason: 'road signs, traffic lights');
  });
}
