import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> loadAsset(String path) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<ui.Image> loadSheet(String name) =>
      loadAsset('assets/characters/$name.png');

  test('production sprite atlases match the 4x6 runtime contract', () async {
    const names = <String>[
      'mario/sprites/base',
      'mario/sprites/cultist',
      'mario/sprites/roma',
      'mario/sprites/lazio',
      'zombies/sprites/wanderer',
      'zombies/sprites/sprinter',
      'zombies/sprites/brute',
      'zombies/sprites/blind',
      'zombies/sprites/carabiniere',
      'zombies/sprites/mutilated',
      'zombies/sprites/burning',
      'zombies/sprites/drunk',
      'zombies/sprites/cultist',
      'npcs/sprites/maranza_roma',
      'npcs/sprites/maranza_lazio',
    ];
    for (final name in names) {
      final image = await loadSheet(name);
      expect(image.width, 96, reason: name);
      expect(image.height, 96, reason: name);
      final rgba = await pixelsOf(image);
      var hasTransparentPixel = false;
      var hasOpaquePixel = false;
      for (var index = 3; index < rgba.length; index += 4) {
        hasTransparentPixel |= rgba[index] == 0;
        hasOpaquePixel |= rgba[index] == 255;
      }
      expect(hasTransparentPixel, isTrue, reason: '$name needs alpha');
      expect(hasOpaquePixel, isTrue, reason: '$name needs visible pixels');
      for (var row = 0; row < 4; row++) {
        for (var column = 0; column < 6; column++) {
          var minX = 16;
          var maxX = -1;
          var maxY = -1;
          for (var y = 0; y < 24; y++) {
            for (var x = 0; x < 16; x++) {
              final pixel = ((row * 24 + y) * 96 + column * 16 + x) * 4;
              if (rgba[pixel + 3] == 0) {
                continue;
              }
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y > maxY) maxY = y;
            }
          }
          final frameName = '$name row $row column $column';
          expect(minX, greaterThanOrEqualTo(1), reason: frameName);
          expect(maxX, lessThanOrEqualTo(14), reason: frameName);
          final cultistOutfit = name == 'mario/sprites/cultist';
          final runtimeOffset = cultistOutfit ? 2 : 0;
          if (cultistOutfit) {
            expect(
              maxY + runtimeOffset,
              inInclusiveRange(22, 23),
              reason: '$frameName runtime foot anchor',
            );
          } else {
            expect(maxY, 23, reason: '$frameName foot anchor');
          }
          expect((minX + maxX) / 2, closeTo(7.5, 1), reason: frameName);
        }
      }
      image.dispose();
    }
  });

  test('zombie portraits match the story portrait contract', () async {
    for (final name in <String>[
      'assets/characters/zombies/portraits/sprinter.png',
      'assets/characters/zombies/portraits/mutilated.png',
      'assets/characters/zombies/portraits/burning.png',
      'assets/characters/zombies/portraits/drunk.png',
      'assets/characters/zombies/portraits/cultist.png',
    ]) {
      final image = await loadAsset(name);
      expect(image.width, 1048, reason: name);
      expect(image.height, 1501, reason: name);
      final rgba = await pixelsOf(image);
      var hasTransparentPixel = false;
      var hasOpaquePixel = false;
      for (var index = 3; index < rgba.length; index += 4) {
        hasTransparentPixel |= rgba[index] == 0;
        hasOpaquePixel |= rgba[index] == 255;
        if (hasTransparentPixel && hasOpaquePixel) {
          break;
        }
      }
      expect(hasTransparentPixel, isTrue, reason: '$name needs alpha');
      expect(hasOpaquePixel, isTrue, reason: '$name needs visible pixels');
      image.dispose();
    }
  });

  test('new portraits match the story portrait contract', () async {
    for (final name in <String>[
      'assets/characters/npcs/portraits/maranza_roma.png',
      'assets/characters/npcs/portraits/maranza_lazio.png',
      'assets/characters/mario/portraits/roma.png',
      'assets/characters/mario/portraits/lazio.png',
    ]) {
      final image = await loadAsset(name);
      expect(image.width, 1048, reason: name);
      expect(image.height, 1501, reason: name);
      final rgba = await pixelsOf(image);
      var hasTransparentPixel = false;
      var hasOpaquePixel = false;
      for (var index = 3; index < rgba.length; index += 4) {
        hasTransparentPixel |= rgba[index] == 0;
        hasOpaquePixel |= rgba[index] == 255;
        if (hasTransparentPixel && hasOpaquePixel) {
          break;
        }
      }
      expect(hasTransparentPixel, isTrue, reason: '$name needs alpha');
      expect(hasOpaquePixel, isTrue, reason: '$name needs visible pixels');
      image.dispose();
    }
  });

  test(
    'action sheets follow the manifest contract on the shared grid',
    () async {
      final manifestJson = await rootBundle.loadString(
        'assets/characters/atlas_manifest.json',
      );
      final manifest = jsonDecode(manifestJson) as Map<String, Object?>;
      final sheets = (manifest['actionSheets']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(sheets, isNotEmpty);
      for (final sheet in sheets) {
        final name = sheet['file']! as String;
        final columns = (sheet['columns']! as List<Object?>).cast<String>();
        expect(
          columns.length,
          lessThanOrEqualTo(6),
          reason: '$name declares more columns than the grid provides',
        );
        final image = await loadSheet(name.replaceAll('.png', ''));
        expect(image.width, 96, reason: name);
        expect(image.height, 96, reason: name);
        final rgba = await pixelsOf(image);
        for (var row = 0; row < 4; row++) {
          for (var column = 0; column < columns.length; column++) {
            var opaquePixels = 0;
            var maxY = -1;
            for (var y = 0; y < 24; y++) {
              for (var x = 0; x < 16; x++) {
                final pixel = ((row * 24 + y) * 96 + column * 16 + x) * 4;
                if (rgba[pixel + 3] == 0) {
                  continue;
                }
                opaquePixels += 1;
                if (y > maxY) maxY = y;
              }
            }
            final frameName =
                '$name row $row column $column (${columns[column]})';
            expect(opaquePixels, greaterThan(0), reason: '$frameName is empty');
            expect(
              maxY,
              greaterThanOrEqualTo(18),
              reason: '$frameName floats above the ground line',
            );
          }
        }
        image.dispose();
      }
    },
  );

  test('held molotov is a shared transparent weapon layer', () async {
    final image = await loadAsset('assets/objects/molotov_held.png');
    expect(image.width, 8);
    expect(image.height, 8);
    final rgba = await pixelsOf(image);
    var transparentPixels = 0;
    var opaquePixels = 0;
    for (var index = 3; index < rgba.length; index += 4) {
      if (rgba[index] == 0) {
        transparentPixels += 1;
      } else if (rgba[index] == 255) {
        opaquePixels += 1;
      }
    }
    expect(transparentPixels, greaterThan(0));
    expect(opaquePixels, greaterThan(0));
    image.dispose();
  });
}

Future<Uint8List> pixelsOf(ui.Image image) async {
  final pixels = await image.toByteData();
  return pixels!.buffer.asUint8List();
}
