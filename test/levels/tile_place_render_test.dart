import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/tile_atlas.dart';
import 'package:stepbound/game/render/tile_place_component.dart';

/// Draws [place] the way the game does, into an image.
Future<ui.Image> _render(Place place) async {
  final component = TilePlaceComponent(place: place);
  await component.onLoad();
  final recorder = ui.PictureRecorder();
  component.render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    place.width * levelTileSize.round(),
    place.height * levelTileSize.round(),
  );
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The renderer is written twice: here, and in tools/build_tile_atlas.py
  // for --preview. This is how they are held to the same picture:
  //
  //   TILE_RENDER_DUMP=some/dir flutter test test/levels/tile_place_render_test.dart
  //   python tools/build_tile_atlas.py --compare some/dir
  test('every converted place is drawn at the size of its rows', () async {
    resetTileAtlasCache();
    final places = tutorialPlaces.where((place) => place.background == null);
    expect(places, isNotEmpty);
    final dump = Platform.environment['TILE_RENDER_DUMP'];
    for (final place in places) {
      final image = await _render(place);
      expect(image.width, place.width * levelTileSize.round());
      expect(image.height, place.height * levelTileSize.round());
      if (dump != null) {
        final bytes = await image.toByteData();
        File(
          '$dump/${place.id.name}.rgba',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    }
  });
}
