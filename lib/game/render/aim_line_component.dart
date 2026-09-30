import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:flutter/foundation.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/pixel_palette.dart';

final class AimLineComponent extends Component {
  AimLineComponent({
    required this.simulation,
    required this.aiming,
    this.hidden,
    this.throughEntities,
    this.tileSize = 16,
  }) : super(priority: 30);

  final WorldState simulation;
  final ValueListenable<bool> aiming;

  /// True while what is aimed is not the pistol: a molotov draws its own.
  final bool Function()? hidden;

  /// True while what is aimed goes through whoever stands in its way, on
  /// to the wall: the rocket launcher. The pistol's line stops in the
  /// first one, as its round does.
  final bool Function()? throughEntities;
  final double tileSize;
  final Paint _paint = Paint()
    ..color = PixelPalette.blood
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;

  @override
  void render(Canvas canvas) {
    if (!aiming.value ||
        (hidden?.call() ?? false) ||
        !simulation.player.isAlive) {
      return;
    }

    final playerPosition = simulation.player.component<PositionComponent>();
    // The very path the round will take (see `traceShot`).
    final (impact: end, hit: _) = traceShot(
      simulation,
      playerPosition.position,
      playerPosition.facing,
      throughEntities: throughEntities?.call() ?? false,
    );

    final startOffset = Offset(
      playerPosition.position.x * tileSize + tileSize / 2,
      playerPosition.position.y * tileSize + tileSize / 2,
    );
    final endOffset = Offset(
      end.x * tileSize + tileSize / 2,
      end.y * tileSize + tileSize / 2,
    );
    final delta = endOffset - startOffset;
    final length = delta.distance;
    if (length == 0) {
      return;
    }
    final unit = delta / length;
    final horizontal =
        playerPosition.facing == Direction.east ||
        playerPosition.facing == Direction.west;
    for (var distance = 7.0; distance < length; distance += 7) {
      final point = startOffset + unit * distance;
      canvas.drawRect(
        Rect.fromCenter(
          center: point,
          width: horizontal ? 3 : 1,
          height: horizontal ? 1 : 3,
        ),
        _paint,
      );
    }
  }
}
