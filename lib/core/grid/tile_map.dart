import 'dart:collection';
import 'dart:typed_data';

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
            'o' => TileKind.obstacle,
            '*' => TileKind.fire,
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

  /// Scratch for [shortestNextStep], kept between calls and grown only
  /// once: a search stamps its own number on the tiles it reaches instead
  /// of clearing arrays the size of the map before every query.
  late final Int32List _reachedBy = Int32List(width * height);
  late final Int32List _cameFrom = Int32List(width * height);
  late final Int32List _queue = Int32List(width * height);
  int _searches = 0;

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

  /// The first step of a shortest path from [start] to [target], or null
  /// when there is no way there. [isBlocked] marks the tiles somebody or
  /// something else is standing on; the target tile itself is never
  /// blocked, so a zombie still walks into whoever is on it.
  ///
  /// [maxDistance] caps how far the search spreads. Without it a target
  /// that cannot be reached — the player behind a wall two tiles away, or
  /// a way out walled off by the crowd — costs the whole walkable area
  /// before the search admits defeat, and that happens per zombie, per
  /// tick.
  ///
  /// Neighbours are visited in [Direction] order, so of two paths of the
  /// same length the same one comes back every time.
  GridPoint? shortestNextStep({
    required GridPoint start,
    required GridPoint target,
    bool Function(GridPoint point)? isBlocked,
    int? maxDistance,
  }) {
    if (start == target) {
      return start;
    }
    if (!contains(start) || !contains(target)) {
      return null;
    }

    final targetIndex = _indexOf(target);
    final startIndex = _indexOf(start);
    final search = ++_searches;
    _reachedBy[startIndex] = search;
    _cameFrom[startIndex] = -1;
    _queue[0] = startIndex;

    var head = 0;
    var tail = 1;
    var levelEnd = 1;
    var distance = 0;
    var found = false;

    while (head < tail && !found) {
      if (head == levelEnd) {
        distance += 1;
        levelEnd = tail;
        // A queue in level order never goes back: past the cap, nothing
        // still waiting in it can reach the target either.
        if (maxDistance != null && distance >= maxDistance) {
          break;
        }
      }
      final current = _queue[head++];
      final x = current % width;
      final y = current ~/ width;
      for (final direction in Direction.values) {
        final nextX = x + direction.dx;
        final nextY = y + direction.dy;
        if (nextX < 0 || nextY < 0 || nextX >= width || nextY >= height) {
          continue;
        }
        final neighbor = nextY * width + nextX;
        if (_reachedBy[neighbor] == search || !_tiles[neighbor].isWalkable) {
          continue;
        }
        if (neighbor != targetIndex &&
            (isBlocked?.call(GridPoint(nextX, nextY)) ?? false)) {
          continue;
        }
        _reachedBy[neighbor] = search;
        _cameFrom[neighbor] = current;
        if (neighbor == targetIndex) {
          found = true;
          break;
        }
        _queue[tail++] = neighbor;
      }
    }

    if (!found) {
      return null;
    }

    var step = targetIndex;
    while (true) {
      final previous = _cameFrom[step];
      if (previous == startIndex) {
        return GridPoint(step % width, step ~/ width);
      }
      if (previous < 0) {
        return null;
      }
      step = previous;
    }
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
