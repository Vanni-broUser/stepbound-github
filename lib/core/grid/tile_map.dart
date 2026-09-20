import 'dart:collection';

import 'package:stepbound/core/grid/grid_point.dart';
import 'package:stepbound/core/grid/tile.dart';

final class TileMap {
  TileMap({
    required this.width,
    required this.height,
    required List<Tile> tiles,
  }) : _tiles = List<Tile>.of(tiles) {
    if (width <= 0 || height <= 0 || _tiles.length != width * height) {
      throw ArgumentError('Tile data must match a positive width and height.');
    }
  }

  factory TileMap.fromAscii(List<String> rows) {
    if (rows.isEmpty || rows.first.isEmpty) {
      throw ArgumentError('An ASCII map needs at least one tile.');
    }
    final width = rows.first.length;
    if (rows.any((row) => row.length != width)) {
      throw ArgumentError('Every ASCII row must have the same width.');
    }

    final tiles = <Tile>[];
    for (final row in rows) {
      for (final glyph in row.split('')) {
        tiles.add(
          Tile(switch (glyph) {
            '#' => TileKind.wall,
            '+' => TileKind.closedDoor,
            '/' => TileKind.openDoor,
            ':' => TileKind.debris,
            _ => TileKind.floor,
          }),
        );
      }
    }
    return TileMap(width: width, height: rows.length, tiles: tiles);
  }

  factory TileMap.fromJson(Map<String, Object?> json) {
    final encodedTiles = json['tiles']! as List<Object?>;
    return TileMap(
      width: json['width']! as int,
      height: json['height']! as int,
      tiles: encodedTiles
          .map((tile) => Tile.fromJson(tile! as Map<String, Object?>))
          .toList(),
    );
  }

  final int width;
  final int height;
  final List<Tile> _tiles;

  bool contains(GridPoint point) {
    return point.x >= 0 && point.y >= 0 && point.x < width && point.y < height;
  }

  Tile tileAt(GridPoint point) {
    if (!contains(point)) {
      throw RangeError('Point $point is outside the map.');
    }
    return _tiles[_indexOf(point)];
  }

  void setTile(GridPoint point, Tile tile) {
    if (!contains(point)) {
      throw RangeError('Point $point is outside the map.');
    }
    _tiles[_indexOf(point)] = tile;
  }

  Iterable<GridPoint> walkableNeighbors(GridPoint point) sync* {
    for (final direction in Direction.values) {
      final neighbor = point.step(direction);
      if (contains(neighbor) && tileAt(neighbor).isWalkable) {
        yield neighbor;
      }
    }
  }

  List<GridPoint> line(GridPoint start, GridPoint end) {
    final points = <GridPoint>[];
    var x0 = start.x;
    var y0 = start.y;
    final x1 = end.x;
    final y1 = end.y;
    final dx = (x1 - x0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final dy = -(y1 - y0).abs();
    final sy = y0 < y1 ? 1 : -1;
    var error = dx + dy;

    while (true) {
      points.add(GridPoint(x0, y0));
      if (x0 == x1 && y0 == y1) {
        break;
      }
      final doubledError = 2 * error;
      if (doubledError >= dy) {
        error += dy;
        x0 += sx;
      }
      if (doubledError <= dx) {
        error += dx;
        y0 += sy;
      }
    }
    return points;
  }

  bool hasLineOfSight(GridPoint start, GridPoint end) {
    final points = line(start, end);
    if (points.length <= 2) {
      return true;
    }
    for (final point in points.skip(1).take(points.length - 2)) {
      if (tileAt(point).blocksSight) {
        return false;
      }
    }
    return true;
  }

  Map<GridPoint, int> floodFillDistances(
    GridPoint origin, {
    required int maxDistance,
  }) {
    final distances = <GridPoint, int>{origin: 0};
    final frontier = ListQueue<GridPoint>()..add(origin);

    while (frontier.isNotEmpty) {
      final current = frontier.removeFirst();
      final distance = distances[current]!;
      if (distance >= maxDistance) {
        continue;
      }
      for (final neighbor in walkableNeighbors(current)) {
        if (distances.containsKey(neighbor)) {
          continue;
        }
        distances[neighbor] = distance + 1;
        frontier.add(neighbor);
      }
    }
    return distances;
  }

  GridPoint? shortestNextStep({
    required GridPoint start,
    required GridPoint target,
    Set<GridPoint> blocked = const <GridPoint>{},
  }) {
    if (start == target) {
      return start;
    }

    final frontier = ListQueue<GridPoint>()..add(start);
    final cameFrom = <GridPoint, GridPoint?>{start: null};

    while (frontier.isNotEmpty && !cameFrom.containsKey(target)) {
      final current = frontier.removeFirst();
      for (final neighbor in walkableNeighbors(current)) {
        if (cameFrom.containsKey(neighbor) ||
            (blocked.contains(neighbor) && neighbor != target)) {
          continue;
        }
        cameFrom[neighbor] = current;
        frontier.add(neighbor);
      }
    }

    if (!cameFrom.containsKey(target)) {
      return null;
    }

    var current = target;
    while (cameFrom[current] != start) {
      final previous = cameFrom[current];
      if (previous == null) {
        return null;
      }
      current = previous;
    }
    return current;
  }

  List<String> toAsciiRows() {
    return List<String>.generate(
      height,
      (y) => List<String>.generate(
        width,
        (x) => tileAt(GridPoint(x, y)).glyph,
      ).join(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'width': width,
      'height': height,
      'tiles': _tiles.map((tile) => tile.toJson()).toList(),
    };
  }

  int _indexOf(GridPoint point) => point.y * width + point.x;
}
