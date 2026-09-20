// Canvas draw calls intentionally share one receiver between paint changes.
// ignore_for_file: cascade_invocations

import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/pixel_palette.dart';

enum TileLayer { ground, structures, foreground }

final class TileMapComponent extends Component {
  TileMapComponent({required this.map, required this.layer, this.tileSize = 16})
    : super(
        priority: switch (layer) {
          TileLayer.ground => 0,
          TileLayer.structures => 10,
          TileLayer.foreground => 30,
        },
      );

  final TileMap map;
  final TileLayer layer;
  final double tileSize;
  final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  @override
  void render(Canvas canvas) {
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        final tile = map.tileAt(GridPoint(x, y));
        final left = x * tileSize;
        final top = y * tileSize;
        switch (layer) {
          case TileLayer.ground:
            _drawGround(canvas, left, top, x, y);
          case TileLayer.structures:
            _drawStructure(canvas, tile, left, top);
          case TileLayer.foreground:
            _drawForeground(canvas, tile, left, top);
        }
      }
    }
  }

  void _drawGround(Canvas canvas, double left, double top, int x, int y) {
    _paint.color = (x + y).isEven
        ? PixelPalette.asphalt
        : PixelPalette.asphaltLight;
    canvas.drawRect(Rect.fromLTWH(left, top, tileSize, tileSize), _paint);
    _paint.color = const Color(0xff263032);
    canvas.drawRect(Rect.fromLTWH(left + 2, top + 4, 2, 1), _paint);
    canvas.drawRect(Rect.fromLTWH(left + 11, top + 12, 3, 1), _paint);
  }

  void _drawStructure(Canvas canvas, Tile tile, double left, double top) {
    switch (tile.kind) {
      case TileKind.wall:
        _paint.color = PixelPalette.wallShadow;
        canvas.drawRect(Rect.fromLTWH(left, top, tileSize, tileSize), _paint);
        _paint.color = PixelPalette.wall;
        canvas.drawRect(Rect.fromLTWH(left, top, tileSize, 12), _paint);
        _paint.color = PixelPalette.mortar;
        canvas.drawRect(Rect.fromLTWH(left, top + 5, tileSize, 1), _paint);
        canvas.drawRect(Rect.fromLTWH(left + 7, top, 1, 5), _paint);
      case TileKind.closedDoor:
        _paint.color = PixelPalette.door;
        canvas.drawRect(Rect.fromLTWH(left + 1, top, 14, 16), _paint);
        _paint.color = PixelPalette.doorLight;
        canvas.drawRect(Rect.fromLTWH(left + 3, top + 2, 10, 2), _paint);
        canvas.drawRect(Rect.fromLTWH(left + 11, top + 8, 2, 2), _paint);
      case TileKind.openDoor:
        _paint.color = PixelPalette.door;
        canvas.drawRect(Rect.fromLTWH(left, top, 2, 16), _paint);
        canvas.drawRect(Rect.fromLTWH(left + 14, top, 2, 16), _paint);
      case TileKind.debris || TileKind.floor:
        break;
    }
  }

  void _drawForeground(Canvas canvas, Tile tile, double left, double top) {
    if (tile.kind != TileKind.debris) {
      return;
    }
    _paint.color = PixelPalette.debris;
    canvas.drawRect(Rect.fromLTWH(left + 2, top + 10, 4, 3), _paint);
    canvas.drawRect(Rect.fromLTWH(left + 9, top + 5, 5, 2), _paint);
    canvas.drawRect(Rect.fromLTWH(left + 8, top + 13, 3, 2), _paint);
  }
}
