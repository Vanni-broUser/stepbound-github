import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;
import 'package:stepbound/game/render/asset_image.dart';
import 'package:stepbound/game/render/depth_sorted_world.dart';

/// Someone alive who is not part of the simulation: Luigi behind his
/// shutter, Don Angelo behind his gate. They stand on their tile facing
/// [facing], breathing between their two idle frames, and turn to whoever
/// they speak to (see [turnTowards]), until the story sends them away
/// through [walkAwayThrough]; then they walk the path given and remove
/// themselves once they arrive.
final class NpcComponent extends PositionComponent with StandsOnFloor {
  NpcComponent({
    required this.asset,
    required GridPoint tile,
    this.name,
    this.facing = Direction.south,
    double tileSize = 16,
  }) : _tileSize = tileSize,
       super(
         position: _footPosition(tile, tileSize),
         size: Vector2(16, 24),
         anchor: Anchor.bottomCenter,
         priority: 20,
       );

  static const String luigiAsset = 'assets/characters/npcs/sprites/luigi.png';
  static const String priestAsset = 'assets/characters/npcs/sprites/priest.png';
  static const String cultistAsset =
      'assets/characters/npcs/sprites/cultist.png';
  static const String maranzaRomaAsset =
      'assets/characters/npcs/sprites/maranza_roma.png';
  static const String maranzaLazioAsset =
      'assets/characters/npcs/sprites/maranza_lazio.png';
  static const String chiaraAsset = 'assets/characters/npcs/sprites/chiara.png';
  static const double frameSeconds = 0.55;

  /// Tiles per second while walking away: about the player's own pace.
  static const double walkTilesPerSecond = 2.5;

  /// Rows of the atlas, as in the player's and zombies' own sprite sheets:
  /// south, west, east, north.
  static const Map<Direction, int> _facingRow = <Direction, int>{
    Direction.south: 0,
    Direction.west: 1,
    Direction.east: 2,
    Direction.north: 3,
  };

  static Vector2 _footPosition(GridPoint tile, double tileSize) =>
      Vector2(tile.x * tileSize + tileSize / 2, (tile.y + 1) * tileSize);

  /// The sprite sheet this one is drawn from.
  final String asset;

  /// Who they are, the way the story names them over their lines: a line
  /// of theirs turns them to whoever they are speaking to. Without one
  /// they never speak.
  final String? name;

  /// The way they are turned; speaking turns them to their listener,
  /// walking away turns them along the path.
  Direction facing;

  final double _tileSize;
  final List<Vector2> _walkQueue = <Vector2>[];
  void Function()? _onArrived;
  ui.Image? _atlas;
  double _time = 0;
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _atlas = await loadAssetImage(asset);
  }

  /// The tile they stand on (the one they are walking over, on their way
  /// out).
  GridPoint get tile => GridPoint(
    (position.x / _tileSize).floor(),
    (position.y / _tileSize).ceil() - 1,
  );

  /// Turns to face [target], the way the player does when he speaks to
  /// them: along whichever axis it lies further off, and sideways when it
  /// lies as far along both. Standing on it, they stay as they are.
  void turnTowards(GridPoint target) {
    final dx = target.x - tile.x;
    final dy = target.y - tile.y;
    if (dx == 0 && dy == 0) {
      return;
    }
    facing = dx.abs() >= dy.abs()
        ? (dx < 0 ? Direction.west : Direction.east)
        : (dy < 0 ? Direction.north : Direction.south);
  }

  /// Walks in a straight line through [tiles] in order; once the last one
  /// is reached, calls [onArrived] and leaves for good.
  void walkAwayThrough(List<GridPoint> tiles, {void Function()? onArrived}) {
    _walkQueue
      ..clear()
      ..addAll(tiles.map((tile) => _footPosition(tile, _tileSize)));
    _onArrived = onArrived;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_walkQueue.isEmpty) {
      return;
    }
    final target = _walkQueue.first;
    final delta = target - position;
    final distance = delta.length;
    final step = walkTilesPerSecond * _tileSize * dt;
    if (distance <= step) {
      position.setFrom(target);
      _walkQueue.removeAt(0);
      if (_walkQueue.isEmpty) {
        _onArrived?.call();
        removeFromParent();
      }
      return;
    }
    facing = delta.x.abs() >= delta.y.abs()
        ? (delta.x < 0 ? Direction.west : Direction.east)
        : (delta.y < 0 ? Direction.north : Direction.south);
    position.add(delta * (step / distance));
  }

  @override
  void render(ui.Canvas canvas) {
    final atlas = _atlas;
    if (atlas == null) {
      return;
    }
    final row = _facingRow[facing]!;
    final walking = _walkQueue.isNotEmpty;
    final progress = (_time / frameSeconds) % 1;
    final column = walking
        ? 2 + (progress * 4).floor().clamp(0, 3)
        : (progress * 2).floor().clamp(0, 1);
    canvas.drawImageRect(
      atlas,
      ui.Rect.fromLTWH(column * 16, row * 24, 16, 24),
      size.toRect(),
      _paint,
    );
  }
}
