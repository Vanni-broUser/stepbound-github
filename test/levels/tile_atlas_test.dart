import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/tile_atlas.dart';

/// The places the game paints from the tile atlas: every one of them.
Iterable<Place> get convertedPlaces => tutorialPlaces;

void main() {
  final manifest = TileAtlasManifest.parse(
    File(tileAtlasManifestPath).readAsStringSync(),
  );

  test('the atlas is cut to the tile the rest of the game draws with', () {
    expect(manifest.tileWidth, levelTileSize.round());
    expect(manifest.tileHeight, levelTileSize.round());
  });

  test('every place has art to be painted with', () {
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
            '${place.id} has no entry in '
            '$tileAtlasManifestPath: it would be drawn as a bare rectangle. '
            'Run python tools/build_tile_atlas.py',
      );
    }
  });

  test('no glyph of a converted place goes unpainted', () {
    for (final place in convertedPlaces) {
      final art = manifest.places[place.id.name]!;
      expect(
        art.unpainted(art.gridFor(place.rows)),
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

  test('a placed object still lies over the rows it was painted for', () {
    for (final place in convertedPlaces) {
      for (final object in manifest.places[place.id.name]!.objects) {
        final at = object.underCorner;
        if (at == null) {
          continue;
        }
        final under = object.under!;
        expect(
          under,
          isNotEmpty,
          reason:
              '${place.id}: ${object.image} is placed and says nothing '
              'of what it lies over',
        );
        for (var row = 0; row < under.length; row++) {
          final y = at.$2 + row;
          final now = y < place.rows.length
              ? place.rows[y].substring(
                  at.$1,
                  math.min(at.$1 + under[row].length, place.rows[y].length),
                )
              : '';
          expect(
            now,
            under[row],
            reason:
                '${place.id}: ${object.image} was painted over rows that '
                'have since changed (row $y, from column ${at.$1}). Re-run '
                'python tools/build_tile_atlas.py',
          );
        }
      }
    }
  });

  test('an object is painted for the run of glyphs it was drawn for', () {
    for (final place in convertedPlaces) {
      for (final object in manifest.places[place.id.name]!.objects) {
        final tiles = object.tiles;
        final glyph = object.glyph;
        if (tiles == null || glyph == null) {
          continue;
        }
        final cells = place.tilesOf(glyph);
        expect(
          cells,
          isNotEmpty,
          reason: '${place.id} has no "$glyph" for ${object.image}',
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

  test('every place of the atlas is a place of the game', () {
    final ids = <String>{for (final place in tutorialPlaces) place.id.name};
    for (final name in manifest.places.keys) {
      expect(
        ids,
        contains(name),
        reason:
            '$name is painted in the atlas and no place is called that: '
            'dead weight, or a place renamed on one side only',
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
