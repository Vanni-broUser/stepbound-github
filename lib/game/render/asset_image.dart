import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

final Map<String, Future<ui.Image>> _decoded = <String, Future<ui.Image>>{};

/// Decodes a bundled image asset, once: every component drawing it, in
/// this game and in every game started after it, shares the same image.
/// Decoding it again for each of the eighty characters of a level, and
/// again at every return to a campfire, only piled up copies nobody freed.
Future<ui.Image> loadAssetImage(String assetPath) {
  final cached = _decoded[assetPath];
  if (cached != null) {
    return cached;
  }
  final loading = _decoded[assetPath] = _decode(assetPath);
  // A failed load is not kept, so the next one tries again; the caller
  // still gets the error.
  unawaited(
    loading.then<void>(
      (_) {},
      onError: (Object _) => _decoded.remove(assetPath),
    ),
  );
  return loading;
}

Future<ui.Image> _decode(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
