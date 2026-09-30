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
      'mario/sprites/ghost',
      'mario/sprites/vampire',
      'mario/sprites/jack_o_lantern',
      'mario/sprites/zombie',
      'mario/sprites/roma',
      'mario/sprites/lazio',
      'zombies/sprites/wanderer',
      'zombies/sprites/sprinter',
      'zombies/sprites/call_center',
      'zombies/sprites/brute',
      'zombies/sprites/blind',
      'zombies/sprites/carabiniere',
      'zombies/sprites/mutilated',
      'zombies/sprites/burning',
      'zombies/sprites/drunk',
      'zombies/sprites/cultist',
      'npcs/sprites/chiara',
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
      'assets/characters/zombies/portraits/call_center.png',
      'assets/characters/zombies/portraits/mutilated.png',
      'assets/characters/zombies/portraits/burning.png',
      'assets/characters/zombies/portraits/drunk.png',
      'assets/characters/zombies/portraits/cultist.png',
    ]) {
      final image = await loadAsset(name);
      expect(image.width, 698, reason: name);
      expect(image.height, 1000, reason: name);
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
      'assets/characters/npcs/portraits/chiara.png',
      'assets/characters/npcs/portraits/maranza_roma.png',
      'assets/characters/npcs/portraits/maranza_lazio.png',
      'assets/characters/mario/portraits/roma.png',
      'assets/characters/mario/portraits/lazio.png',
      'assets/characters/mario/portraits/ghost.png',
      'assets/characters/mario/portraits/vampire.png',
      'assets/characters/mario/portraits/jack_o_lantern.png',
      'assets/characters/mario/portraits/zombie.png',
    ]) {
      final image = await loadAsset(name);
      expect(image.width, 698, reason: name);
      expect(image.height, 1000, reason: name);
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

  test('Halloween art has no stray pure-white pixels', () async {
    const outfits = <String>['ghost', 'vampire', 'jack_o_lantern', 'zombie'];
    final paths = <String>[
      for (final outfit in outfits)
        'assets/characters/mario/portraits/$outfit.png',
      for (final outfit in outfits)
        for (final suffix in <String>['', '_gun', '_pickup', '_throwable'])
          'assets/characters/mario/sprites/$outfit$suffix.png',
    ];
    for (final path in paths) {
      final image = await loadAsset(path);
      final rgba = await pixelsOf(image);
      var pureWhite = 0;
      var partialAlpha = 0;
      for (var index = 0; index < rgba.length; index += 4) {
        if (rgba[index + 3] != 0 && rgba[index + 3] != 255) {
          partialAlpha += 1;
        }
        if (rgba[index + 3] > 0 &&
            rgba[index] == 255 &&
            rgba[index + 1] == 255 &&
            rgba[index + 2] == 255) {
          pureWhite += 1;
        }
      }
      expect(pureWhite, 0, reason: path);
      expect(
        partialAlpha,
        0,
        reason: '$path needs hard pixel-art edges without a pale alpha halo',
      );
      image.dispose();
    }
  });

  test(
    'Halloween headwear fully covers the face and follows pose bobbing',
    () async {
      const poseShifts = <String, List<int>>{
        '': [0, 0, 0, 0, 0, 0],
        '_gun': [0, 0, 0, 0, 0, 0],
        '_pickup': [2, 4, 4, 4, 2, 0],
        '_throwable': [0, 0, 0, 0, 0, 0],
      };
      const pumpkinColors = <(int, int, int)>[
        (224, 91, 20),
        (255, 139, 27),
        (139, 47, 16),
        (255, 223, 99),
      ];
      const ghostColors = <(int, int, int)>[
        (244, 239, 220),
        (211, 215, 211),
        (160, 169, 171),
        (37, 31, 42),
        (20, 15, 19),
      ];
      const pumpkinBounds = <(int, int)>[(4, 12), (3, 12), (4, 13), (4, 12)];

      bool matches(Uint8List rgba, int pixel, (int, int, int) color) =>
          rgba[pixel] == color.$1 &&
          rgba[pixel + 1] == color.$2 &&
          rgba[pixel + 2] == color.$3;

      bool isExposedSkin(
        Uint8List rgba,
        int pixel,
        List<(int, int, int)> costumeColors,
      ) {
        if (rgba[pixel + 3] <= 200 ||
            rgba[pixel] <= 145 ||
            rgba[pixel + 1] <= 80 ||
            rgba[pixel + 2] <= 45 ||
            rgba[pixel] <= rgba[pixel + 1] ||
            rgba[pixel + 1] <= rgba[pixel + 2]) {
          return false;
        }
        return !costumeColors.any((color) => matches(rgba, pixel, color));
      }

      for (final entry in poseShifts.entries) {
        final suffix = entry.key;
        final jack = await loadAsset(
          'assets/characters/mario/sprites/jack_o_lantern$suffix.png',
        );
        final ghost = await loadAsset(
          'assets/characters/mario/sprites/ghost$suffix.png',
        );
        final jackPixels = await pixelsOf(jack);
        final ghostPixels = await pixelsOf(ghost);
        for (var row = 0; row < 4; row++) {
          for (var column = 0; column < 6; column++) {
            final shift = entry.value[column];
            final frameName =
                '${suffix.isEmpty ? 'base' : suffix} row $row column $column';
            var pumpkinMinX = 16;
            var pumpkinMaxX = -1;
            var pumpkinMinY = 24;
            for (var y = 0; y < 24; y++) {
              for (var x = 0; x < 16; x++) {
                final pixel = ((row * 24 + y) * 96 + column * 16 + x) * 4;
                if (pumpkinColors.any(
                  (color) => matches(jackPixels, pixel, color),
                )) {
                  if (x < pumpkinMinX) pumpkinMinX = x;
                  if (x > pumpkinMaxX) pumpkinMaxX = x;
                  if (y < pumpkinMinY) pumpkinMinY = y;
                }
              }
            }
            expect(
              (pumpkinMinX, pumpkinMaxX),
              pumpkinBounds[row],
              reason: '$frameName pumpkin alignment',
            );
            if (suffix == '_pickup') {
              expect(
                pumpkinMinY,
                2 + shift,
                reason: '$frameName pumpkin vertical anchor',
              );
            }

            for (var y = 12 + shift; y < 14 + shift; y++) {
              for (var x = 6; x < 10; x++) {
                final pixel = ((row * 24 + y) * 96 + column * 16 + x) * 4;
                expect(
                  isExposedSkin(jackPixels, pixel, pumpkinColors),
                  isFalse,
                  reason: '$frameName exposes skin below the pumpkin at $x,$y',
                );
              }
            }
            for (var y = 2 + shift; y < 15 + shift; y++) {
              for (var x = 5; x < 11; x++) {
                final pixel = ((row * 24 + y) * 96 + column * 16 + x) * 4;
                expect(
                  isExposedSkin(ghostPixels, pixel, ghostColors),
                  isFalse,
                  reason:
                      '$frameName exposes a face through the ghost hood '
                      'at $x,$y',
                );
              }
            }
          }
        }
        jack.dispose();
        ghost.dispose();
      }
    },
  );

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

  for (final held in <String>['molotov_held', 'grappling_hook_held']) {
    test(
      '$held is a shared transparent layer for the throwable pose',
      () async {
        final image = await loadAsset('assets/objects/$held.png');
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
      },
    );
  }

  test('the rocket launcher is a shared layer on the gun poses grid, with '
      'something of it in every frame', () async {
    final image = await loadAsset('assets/objects/rocket_launcher_held.png');
    expect(image.width, 96);
    expect(image.height, 96);
    final rgba = await pixelsOf(image);
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 6; column++) {
        var opaque = 0;
        for (var y = row * 24; y < row * 24 + 24; y++) {
          for (var x = column * 16; x < column * 16 + 16; x++) {
            if (rgba[(y * 96 + x) * 4 + 3] == 255) {
              opaque += 1;
            }
          }
        }
        expect(opaque, greaterThan(8), reason: 'frame $row,$column');
      }
    }
    image.dispose();
  });

  test('the pistols are shared layers on the gun poses grid, and no '
      'outfit holds one of its own', () async {
    final pistol = await pixelsOf(
      await loadAsset('assets/objects/pistol_held.png'),
    );
    final golden = await pixelsOf(
      await loadAsset('assets/objects/pistol_gold_held.png'),
    );
    expect(pistol.length, 96 * 96 * 4);
    expect(golden.length, pistol.length);
    // The same pistol, pixel for pixel, only in gold.
    for (var index = 3; index < pistol.length; index += 4) {
      expect(golden[index] > 0, pistol[index] > 0);
    }
    const steel = <List<int>>[
      <int>[38, 40, 46],
      <int>[74, 78, 88],
      <int>[136, 142, 152],
    ];
    for (final outfit in <String>[
      'base',
      'cultist',
      'ghost',
      'vampire',
      'jack_o_lantern',
      'zombie',
      'lazio',
    ]) {
      final rgba = await pixelsOf(
        await loadAsset('assets/characters/mario/sprites/${outfit}_gun.png'),
      );
      for (var index = 0; index < rgba.length; index += 4) {
        final colour = <int>[rgba[index], rgba[index + 1], rgba[index + 2]];
        expect(
          rgba[index + 3] > 0 &&
              steel.any((metal) => metal.join() == colour.join()),
          isFalse,
          reason: '${outfit}_gun.png still paints a pistol',
        );
      }
    }
  });
}

Future<Uint8List> pixelsOf(ui.Image image) async {
  final pixels = await image.toByteData();
  return pixels!.buffer.asUint8List();
}
