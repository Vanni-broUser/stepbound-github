import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production sprite atlases match the 4x6 runtime contract', () async {
    const names = <String>[
      'protagonist',
      'zombie_wanderer',
      'zombie_sprinter',
      'zombie_brute',
      'zombie_blind',
    ];
    for (final name in names) {
      final data = await rootBundle.load('assets/sprites/$name.png');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      expect(image.width, 96, reason: name);
      expect(image.height, 96, reason: name);
      final pixels = await image.toByteData();
      final rgba = pixels!.buffer.asUint8List();
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
          expect(maxY, 23, reason: '$frameName foot anchor');
          expect((minX + maxX) / 2, closeTo(7.5, 1), reason: frameName);
        }
      }
      image.dispose();
    }
  });
}
