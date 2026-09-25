/// [obstacle] blocks movement but not sight, like a wrecked car you can
/// see and shoot over. [fire] is ground that is burning and will not stop:
/// nobody walks through it, but it is seen and shot across.
enum TileKind { floor, wall, closedDoor, openDoor, debris, obstacle, fire }

final class Tile {
  const Tile(this.kind);

  factory Tile.fromJson(Map<String, Object?> json) {
    return Tile(TileKind.values.byName(json['kind']! as String));
  }

  final TileKind kind;

  bool get isWalkable => switch (kind) {
    TileKind.wall ||
    TileKind.closedDoor ||
    TileKind.obstacle ||
    TileKind.fire => false,
    TileKind.floor || TileKind.openDoor || TileKind.debris => true,
  };

  bool get blocksSight => switch (kind) {
    TileKind.wall || TileKind.closedDoor => true,
    TileKind.floor ||
    TileKind.openDoor ||
    TileKind.debris ||
    TileKind.obstacle ||
    TileKind.fire => false,
  };

  int get movementNoiseRadius => kind == TileKind.debris ? 7 : 2;

  String get glyph => switch (kind) {
    TileKind.floor => '.',
    TileKind.wall => '#',
    TileKind.closedDoor => '+',
    TileKind.openDoor => '/',
    TileKind.debris => ':',
    TileKind.obstacle => 'o',
    TileKind.fire => '*',
  };

  Map<String, Object?> toJson() => <String, Object?>{'kind': kind.name};
}
