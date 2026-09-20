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
      image.dispose();
    }
  });
}
