import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/tile_atlas.dart';

/// The places the game paints from the tile atlas: the ones that gave up
/// their baked picture.
Iterable<Place> get convertedPlaces =>
    tutorialPlaces.where((place) => place.background == null);

void main() {
  final manifest = TileAtlasManifest.parse(
    File(tileAtlasManifestPath).readAsStringSync(),
  );

  test('the atlas is cut to the tile the rest of the game draws with', () {
    expect(manifest.tileWidth, levelTileSize.round());
    expect(manifest.tileHeight, levelTileSize.round());
  });

  test('every place without a picture has art to be painted with', () {
    expect(
      convertedPlaces,
      isNotEmpty,
      reason: 'this test would pass on an empty list',
    );
    for (final place in convertedPlaces) {
      expect(
        manifest.places,
        contains(place.id.name),
        reason:
            '${place.id} has no background and no entry in '
            '$tileAtlasManifestPath: it would be drawn as a bare rectangle. '
            'Run python tools/build_tile_atlas.py',
      );
    }
  });

  test('no glyph of a converted place goes unpainted', () {
    for (final place in convertedPlaces) {
      final art = manifest.places[place.id.name]!;
      final glyphs = <String>{for (final (_, glyph) in place.glyphs) glyph};
      expect(
        art.unpainted(glyphs),
        isEmpty,
        reason:
            '${place.id}: these glyphs are in its rows but no rule of the '
            'atlas paints them, so they would be holes in the floor. Add '
            'them in tools/build_tile_atlas.py',
      );
    }
  });

  test('every tile a rule asks for is in the atlas', () {
    final tiles = _atlasTileCount(manifest);
    for (final entry in manifest.places.entries) {
      for (final rule in entry.value.rules) {
        for (final bucket in rule.buckets) {
          for (final tile in bucket) {
            expect(
              tile,
              lessThan(tiles),
              reason:
                  '${entry.key}: a rule for "${rule.glyphs}" asks for tile '
                  '$tile, and ${manifest.atlasPath} only holds $tiles',
            );
          }
        }
      }
    }
  });

  test('an object is painted over the glyphs it was drawn for', () {
    for (final place in convertedPlaces) {
      for (final object in manifest.places[place.id.name]!.objects) {
        final tiles = object.tiles;
        if (tiles == null) {
          continue;
        }
        final at = object.at;
        if (at != null) {
          // Placed by hand, as the shopfronts of a wall are: every cell
          // under it must still be one of the glyphs it was drawn over.
          final grid = GlyphGrid(place.rows);
          for (var y = at.$2; y < at.$2 + tiles.$2; y++) {
            for (var x = at.$1; x < at.$1 + tiles.$1; x++) {
              expect(
                object.glyph,
                contains(grid.glyphAt(x, y)),
                reason:
                    '${place.id}: ${object.image} covers $x,$y, which the '
                    'rows now show as "${grid.glyphAt(x, y)}", not one of '
                    '"${object.glyph}". Re-run '
                    'python tools/build_tile_atlas.py after changing them',
              );
            }
          }
          continue;
        }
        final cells = place.tilesOf(object.glyph);
        expect(
          cells,
          isNotEmpty,
          reason: '${place.id} has no "${object.glyph}" for ${object.image}',
        );
        final xs = cells.map((tile) => tile.x);
        final ys = cells.map((tile) => tile.y);
        final width = xs.reduce(math.max) - xs.reduce(math.min) + 1;
        final height = ys.reduce(math.max) - ys.reduce(math.min) + 1;
        expect(
          (width, height),
          tiles,
          reason:
              '${place.id}: ${object.image} was painted for a run of '
              '${tiles.$1}x${tiles.$2} tiles and the rows now make it '
              '${width}x$height. Re-run python tools/build_tile_atlas.py '
              'after changing them',
        );
      }
    }
  });

  test('a place with a picture is not also in the atlas', () {
    for (final place in tutorialPlaces) {
      if (place.background == null) {
        continue;
      }
      expect(
        manifest.places,
        isNot(contains(place.id.name)),
        reason:
            '${place.id} is baked and painted from tiles at once: one of '
            'the two is dead weight',
      );
    }
  });
}

/// How many tiles the atlas image holds, from its PNG header.
int _atlasTileCount(TileAtlasManifest manifest) {
  final bytes = File(manifest.atlasPath).readAsBytesSync();
  final header = ByteData.sublistView(bytes, 16, 24);
  final columns = header.getUint32(0) ~/ manifest.tileWidth;
  final rows = header.getUint32(4) ~/ manifest.tileHeight;
  return columns * rows;
}
