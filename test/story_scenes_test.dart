import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The story's pictures are drawn by hand and dropped into
/// assets/story/scenes as they are (docs/art_direction.md): nothing
/// generates them, so nothing can check their pixels. What can be checked
/// is that each is the size the screens draw it at, which is what
/// putting them in place used to guarantee.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every story scene is the size the screens draw it at', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final scenes =
        manifest
            .listAssets()
            .where((path) => path.startsWith('assets/story/scenes/'))
            .toList()
          ..sort();
    expect(scenes, isNotEmpty);
    for (final path in scenes) {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final image = (await codec.getNextFrame()).image;
      if (path.endsWith('.png')) {
        // The intro frames: the virtual 16:9 resolution doubled.
        expect(image.width, 768, reason: path);
        expect(image.height, 432, reason: path);
      } else {
        // The scenes played during the game keep the frame they were
        // drawn at, a pixel either way in width from the tool that made
        // them.
        expect(image.height, 768, reason: path);
        expect(image.width, inInclusiveRange(1375, 1377), reason: path);
      }
      image.dispose();
      codec.dispose();
    }
  });
}
