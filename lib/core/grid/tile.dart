/// [obstacle] blocks movement but not sight, like a wrecked car you can
/// see and shoot over.
enum TileKind { floor, wall, closedDoor, openDoor, debris, obstacle }

final class Tile {
  const Tile(this.kind);

  factory Tile.fromJson(Map<String, Object?> json) {
    return Tile(TileKind.values.byName(json['kind']! as String));
  }

  final TileKind kind;

  bool get isWalkable => switch (kind) {
    TileKind.wall || TileKind.closedDoor || TileKind.obstacle => false,
    TileKind.floor || TileKind.openDoor || TileKind.debris => true,
  };

  bool get blocksSight => switch (kind) {
    TileKind.wall || TileKind.closedDoor => true,
    TileKind.floor ||
    TileKind.openDoor ||
    TileKind.debris ||
    TileKind.obstacle => false,
  };

  int get movementNoiseRadius => kind == TileKind.debris ? 7 : 2;

  String get glyph => switch (kind) {
    TileKind.floor => '.',
    TileKind.wall => '#',
    TileKind.closedDoor => '+',
    TileKind.openDoor => '/',
    TileKind.debris => ':',
    TileKind.obstacle => 'o',
  };

  Map<String, Object?> toJson() => <String, Object?>{'kind': kind.name};
}
