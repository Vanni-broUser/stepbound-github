import 'package:meta/meta.dart';

enum Direction {
  north(0, -1, '^'),
  east(1, 0, '>'),
  south(0, 1, 'v'),
  west(-1, 0, '<');

  const Direction(this.dx, this.dy, this.glyph);

  final int dx;
  final int dy;
  final String glyph;

  Direction get opposite =>
      Direction.values[(index + 2) % Direction.values.length];
}

@immutable
final class GridPoint {
  const GridPoint(this.x, this.y);

  factory GridPoint.fromJson(Map<String, Object?> json) {
    return GridPoint(json['x']! as int, json['y']! as int);
  }

  final int x;
  final int y;

  GridPoint step(Direction direction) {
    return GridPoint(x + direction.dx, y + direction.dy);
  }

  int manhattanDistanceTo(GridPoint other) {
    return (x - other.x).abs() + (y - other.y).abs();
  }

  Map<String, Object?> toJson() => <String, Object?>{'x': x, 'y': y};

  @override
  bool operator ==(Object other) {
    return other is GridPoint && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}
