import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:flutter/foundation.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/pixel_palette.dart';

/// While a molotov is aimed: the 3x3 square it would burst over, in red,
/// and the arc it would fly along, from Mario's hand down onto the middle
/// of the square. Pixel art, on the world's own grid, over the dark.
final class ThrowPreviewComponent extends Component {
  ThrowPreviewComponent({
    required this.simulation,
    required this.target,
    this.tileSize = 16,
  }) : super(priority: 30);

  final WorldState simulation;

  /// The centre of the square, null while no molotov is aimed.
  final ValueListenable<GridPoint?> target;
  final double tileSize;

  /// Pixels between two dots of the arc.
  static const double dotSpacing = 5;

  /// How high the arc rises over its middle, per tile it spans.
  static const double risePerTile = 5;

  double _elapsed = 0;

  final Paint _paint = Paint()..isAntiAlias = false;

  /// Where on its way the arc is at [t], from 0 at [from] to 1 at [to]:
  /// a parabola [rise] pixels over the straight line at its middle.
  static Offset arcPoint(Offset from, Offset to, double rise, double t) =>
      Offset.lerp(from, to, t)! - Offset(0, 4 * rise * t * (1 - t));

  /// How high the arc from [from] to [to] rises.
  static double riseOf(Offset from, Offset to, double tileSize) =>
      8 + (to - from).distance / tileSize * risePerTile;

  @override
  void update(double dt) {
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    final centre = target.value;
    if (centre == null || !simulation.player.isAlive) {
      return;
    }
    final pulse = 0.5 + 0.5 * math.sin(_elapsed * 6);
    _renderSquare(canvas, centre, pulse);
    _renderArc(canvas, centre, pulse);
  }

  void _renderSquare(Canvas canvas, GridPoint centre, double pulse) {
    const radius = ThrowMolotovAction.blastRadius;
    final area = Rect.fromLTWH(
      (centre.x - radius) * tileSize,
      (centre.y - radius) * tileSize,
      (2 * radius + 1) * tileSize,
      (2 * radius + 1) * tileSize,
    );
    _paint
      ..style = PaintingStyle.fill
      ..color = PixelPalette.blood.withValues(alpha: 0.22 + 0.08 * pulse);
    canvas.drawRect(area, _paint);
    // The middle tile, where the bottle lands, a shade stronger.
    final middle = Rect.fromLTWH(
      centre.x * tileSize,
      centre.y * tileSize,
      tileSize,
      tileSize,
    );
    _paint.color = PixelPalette.blood.withValues(alpha: 0.25 + 0.1 * pulse);
    canvas.drawRect(middle, _paint);
    // The grid of the nine tiles, and the square's rim over it.
    _paint.color = PixelPalette.blood.withValues(alpha: 0.45);
    for (var i = 1; i < 2 * radius + 1; i++) {
      canvas
        ..drawRect(
          Rect.fromLTWH(area.left + i * tileSize, area.top, 1, area.height),
          _paint,
        )
        ..drawRect(
          Rect.fromLTWH(area.left, area.top + i * tileSize, area.width, 1),
          _paint,
        );
    }
    _paint.color = PixelPalette.blood.withValues(alpha: 0.75 + 0.25 * pulse);
    canvas
      ..drawRect(Rect.fromLTWH(area.left, area.top, area.width, 1), _paint)
      ..drawRect(
        Rect.fromLTWH(area.left, area.bottom - 1, area.width, 1),
        _paint,
      )
      ..drawRect(Rect.fromLTWH(area.left, area.top, 1, area.height), _paint)
      ..drawRect(
        Rect.fromLTWH(area.right - 1, area.top, 1, area.height),
        _paint,
      );
    // A cross in the middle tile.
    final mid = middle.center;
    canvas
      ..drawRect(Rect.fromLTWH(mid.dx - 3, mid.dy - 0.5, 6, 1), _paint)
      ..drawRect(Rect.fromLTWH(mid.dx - 0.5, mid.dy - 3, 1, 6), _paint);
  }

  void _renderArc(Canvas canvas, GridPoint centre, double pulse) {
    final mario = simulation.player.component<PositionComponent>().position;
    final from = handOf(mario, tileSize);
    final to = Offset(
      centre.x * tileSize + tileSize / 2,
      centre.y * tileSize + tileSize / 2,
    );
    final rise = riseOf(from, to, tileSize);
    // Measure the arc, so the dots lie evenly along it.
    const samples = 48;
    var length = 0.0;
    var previous = from;
    final points = <Offset>[from];
    for (var i = 1; i <= samples; i++) {
      final point = arcPoint(from, to, rise, i / samples);
      length += (point - previous).distance;
      points.add(point);
      previous = point;
    }
    _paint.color = PixelPalette.blood;
    // The dots creep toward the square, as if already on their way.
    final creep = (_elapsed * 12) % dotSpacing;
    var walked = 0.0;
    var next = 4 + creep;
    for (var i = 1; i < points.length; i++) {
      final step = (points[i] - points[i - 1]).distance;
      while (next <= walked + step && next < length - 3) {
        final along = (next - walked) / step;
        final dot = Offset.lerp(points[i - 1], points[i], along)!;
        canvas.drawRect(
          Rect.fromLTWH(dot.dx.floorToDouble(), dot.dy.floorToDouble(), 2, 2),
          _paint,
        );
        next += dotSpacing;
      }
      walked += step;
    }
  }

  /// Where the bottle leaves Mario standing on [tile]: at shoulder height.
  static Offset handOf(GridPoint tile, double tileSize) =>
      Offset(tile.x * tileSize + tileSize / 2, tile.y * tileSize + 2);
}
