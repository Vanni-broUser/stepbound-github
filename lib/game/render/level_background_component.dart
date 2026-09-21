import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/game/render/asset_image.dart';

/// Draws a region's pre-baked background image, pixel for pixel, with its
/// top-left corner at [offset] in world pixels.
final class LevelBackgroundComponent extends Component {
  LevelBackgroundComponent({
    required this.assetPath,
    this.offset = ui.Offset.zero,
  }) : super(priority: 0);

  final String assetPath;
  final ui.Offset offset;
  ui.Image? _image;
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _image = await loadAssetImage(assetPath);
  }

  @override
  void render(ui.Canvas canvas) {
    final image = _image;
    if (image != null) {
      canvas.drawImage(image, offset, _paint);
    }
  }
}
