import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/pixel_palette.dart';

final class DebugWorldOverlay extends Component {
  DebugWorldOverlay({required this.simulation, this.tileSize = 16})
    : super(priority: 100);

  final WorldState simulation;
  final double tileSize;
  bool enabled = false;
  final Paint _gridPaint = Paint()
    ..color = PixelPalette.debugGrid
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5
    ..isAntiAlias = false;
  final Paint _collisionPaint = Paint()
    ..color = PixelPalette.debugCollision
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;
  final Paint _visionPaint = Paint()
    ..color = PixelPalette.debugVision
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..isAntiAlias = false;

  @override
  void render(Canvas canvas) {
    if (!enabled) {
      return;
    }
    for (var y = 0; y < simulation.map.height; y++) {
      for (var x = 0; x < simulation.map.width; x++) {
        final point = GridPoint(x, y);
        final rect = Rect.fromLTWH(
          x * tileSize,
          y * tileSize,
          tileSize,
          tileSize,
        );
        canvas.drawRect(rect, _gridPaint);
        if (!simulation.map.tileAt(point).isWalkable) {
          canvas.drawRect(rect, _collisionPaint);
        }
      }
    }
    for (final entity in simulation.entities.values) {
      final vision = entity.maybeComponent<VisionComponent>();
      if (vision == null || vision.range == 0) {
        continue;
      }
      final point = entity.component<PositionComponent>().position;
      canvas.drawCircle(
        Offset(
          point.x * tileSize + tileSize / 2,
          point.y * tileSize + tileSize / 2,
        ),
        vision.range * tileSize,
        _visionPaint,
      );
    }
  }
}
