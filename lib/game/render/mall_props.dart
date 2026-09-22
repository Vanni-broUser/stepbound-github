import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;
import 'package:stepbound/game/render/asset_image.dart';

/// Luigi, stuck in his shop: he stands facing the shutter, breathing
/// between his two idle frames. He is scenery, not part of the simulation.
final class LuigiComponent extends PositionComponent {
  LuigiComponent({required GridPoint tile, double tileSize = 16})
    : super(
        position: Vector2(
          tile.x * tileSize + tileSize / 2,
          (tile.y + 1) * tileSize,
        ),
        size: Vector2(16, 24),
        anchor: Anchor.bottomCenter,
        priority: 20,
      );

  static const String assetPath = 'assets/sprites/luigi.png';
  static const double frameSeconds = 0.55;

  ui.Image? _atlas;
  double _time = 0;
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _atlas = await loadAssetImage(assetPath);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(ui.Canvas canvas) {
    final atlas = _atlas;
    if (atlas == null) {
      return;
    }
    // Row 0 faces south; columns 0 and 1 are the idle frames.
    final frame = (_time / frameSeconds).floor() % 2;
    canvas.drawImageRect(
      atlas,
      ui.Rect.fromLTWH(frame * 16, 0, 16, 24),
      size.toRect(),
      _paint,
    );
  }
}

/// The steel shutter of Luigi's shop: a grid of bars standing on [bars],
/// taller than the tiles so it covers Luigi's legs. When the tiles turn to
/// floor (the panel was used) it rolls up and vanishes.
final class ShutterComponent extends PositionComponent {
  ShutterComponent({
    required this.bars,
    required this.map,
    double tileSize = 16,
  }) : super(
         position: Vector2(bars.left * tileSize, (bars.top + 1) * tileSize),
         size: Vector2((bars.right - bars.left + 1) * tileSize, shutterHeight),
         anchor: Anchor.bottomLeft,
         priority: 21,
       );

  static const double shutterHeight = 26;
  static const double liftSeconds = 1.1;

  final GridRect bars;
  final TileMap map;
  double _lift = 0;

  final ui.Paint _bar = ui.Paint()
    ..color = const ui.Color(0xff6c7078)
    ..isAntiAlias = false;
  final ui.Paint _shine = ui.Paint()
    ..color = const ui.Color(0xffa4a8b0)
    ..isAntiAlias = false;
  final ui.Paint _rust = ui.Paint()
    ..color = const ui.Color(0xff7a4a30)
    ..isAntiAlias = false;

  bool get _closed =>
      map.tileAt(GridPoint(bars.left, bars.top)).kind == TileKind.obstacle;

  @override
  void update(double dt) {
    super.update(dt);
    if (!_closed && _lift < 1) {
      _lift = (_lift + dt / liftSeconds).clamp(0, 1);
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_lift >= 1) {
      return;
    }
    final w = size.x;
    // Rolling up: the grid shortens from the bottom into its top box.
    final visible = shutterHeight * (1 - _lift);
    canvas
      ..save()
      ..clipRect(ui.Rect.fromLTWH(0, 0, w, visible));
    for (var x = 1.0; x < w; x += 4) {
      canvas
        ..drawRect(ui.Rect.fromLTWH(x, 3, 1, shutterHeight - 3), _bar)
        ..drawRect(ui.Rect.fromLTWH(x + 1, 3, 1, shutterHeight - 3), _shine);
    }
    for (var y = 6.0; y < shutterHeight; y += 5) {
      canvas.drawRect(ui.Rect.fromLTWH(0, y, w, 1), _bar);
    }
    canvas
      ..drawRect(const ui.Rect.fromLTWH(7, 14, 3, 2), _rust)
      ..drawRect(ui.Rect.fromLTWH(w - 12, 9, 2, 3), _rust)
      ..restore()
      // The box the shutter rolls into, always on top.
      ..drawRect(ui.Rect.fromLTWH(0, 0, w, 3), _bar)
      ..drawRect(ui.Rect.fromLTWH(0, 0, w, 1), _shine);
  }
}

/// The same white glint the backpacks give off, on the control panel, for
/// as long as the panel has not been used.
final class PanelGlintComponent extends PositionComponent {
  PanelGlintComponent({
    required this.panel,
    required this.world,
    double tileSize = 16,
  }) : super(
         position: Vector2(panel.x * tileSize, panel.y * tileSize),
         size: Vector2.all(tileSize),
         // Above the indoor darkness, so it catches the eye like a lamp.
         priority: 30,
       );

  final GridPoint panel;
  final WorldState world;
  double _time = 0;
  final ui.Paint _paint = ui.Paint()
    ..color = const ui.Color(0xfffff6d8)
    ..isAntiAlias = false;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(ui.Canvas canvas) {
    if (!world.controls.containsKey(panel)) {
      return;
    }
    final phase = (_time * 0.6) % 1;
    if (phase < 0.12) {
      canvas
        ..drawRect(const ui.Rect.fromLTWH(11, 5, 1, 3), _paint)
        ..drawRect(const ui.Rect.fromLTWH(10, 6, 3, 1), _paint);
    }
  }
}
