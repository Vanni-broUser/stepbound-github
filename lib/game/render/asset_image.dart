import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Decodes a bundled image asset.
Future<ui.Image> loadAssetImage(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
