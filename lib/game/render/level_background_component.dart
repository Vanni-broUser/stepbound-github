import 'dart:ui' as ui;

import 'package:stepbound/game/render/asset_image.dart';
import 'package:stepbound/game/render/place_background.dart';

/// Draws a region's pre-baked background image, pixel for pixel, with its
/// top-left corner at [offset] in world pixels.
final class LevelBackgroundComponent extends PlaceBackground {
  LevelBackgroundComponent({
    required this.assetPath,
    this.offset = ui.Offset.zero,
    this.alternateAssetPath,
    this.useAlternate,
  }) : super(priority: 0);

  final String assetPath;
  final ui.Offset offset;
  final String? alternateAssetPath;
  final bool Function()? useAlternate;

  ui.Image? _image;
  ui.Image? _alternateImage;
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _image = await loadAssetImage(assetPath);
    final alternate = alternateAssetPath;
    if (alternate != null) {
      _alternateImage = await loadAssetImage(alternate);
    }
  }

  @override
  String get activeAssetPath =>
      useAlternate?.call() == true && alternateAssetPath != null
      ? alternateAssetPath!
      : assetPath;

  @override
  void render(ui.Canvas canvas) {
    final image = useAlternate?.call() == true
        ? _alternateImage ?? _image
        : _image;
    if (image != null && onScreen) {
      canvas.drawImage(image, offset, _paint);
    }
  }
}
