import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;
import 'package:stepbound/core/entities/components.dart' as simulation;
import 'package:stepbound/game/render/pixel_palette.dart';

final class CharacterComponent extends PositionComponent {
  CharacterComponent({required this.entity})
    : super(size: Vector2(16, 24), anchor: Anchor.bottomCenter, priority: 20);

  final Entity entity;
  ui.Image? _atlas;
  double animationProgress = 1;
  bool isMoving = false;
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final name = _atlasName(entity.kind);
    final assetPath = 'assets/sprites/$name.png';
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    if (!manifest.listAssets().contains(assetPath)) {
      return;
    }
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final loaded = frame.image;
    if (loaded.width >= 96 && loaded.height >= 96) {
      _atlas = loaded;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final atlas = _atlas;
    if (atlas != null) {
      _renderAtlas(canvas, atlas);
    } else {
      _renderPrototype(canvas);
    }
  }

  void _renderAtlas(ui.Canvas canvas, ui.Image atlas) {
    final facing = entity.component<simulation.PositionComponent>().facing;
    final row = switch (facing) {
      Direction.south => 0,
      Direction.west => 1,
      Direction.east => 2,
      Direction.north => 3,
    };
    final column = isMoving
        ? 2 + (animationProgress * 4).floor().clamp(0, 3)
        : (animationProgress * 2).floor().clamp(0, 1);
    canvas.drawImageRect(
      atlas,
      ui.Rect.fromLTWH(column * 16, row * 24, 16, 24),
      const ui.Rect.fromLTWH(0, 0, 16, 24),
      _paint,
    );
  }

  void _renderPrototype(ui.Canvas canvas) {
    final colors = _colorsFor(entity.kind);
    final facing = entity.component<simulation.PositionComponent>().facing;
    _paint.color = const ui.Color(0x55000000);
    canvas.drawRect(const ui.Rect.fromLTWH(3, 21, 10, 2), _paint);
    _paint.color = colors.$1;
    canvas.drawRect(const ui.Rect.fromLTWH(4, 3, 8, 7), _paint);
    _paint.color = colors.$2;
    canvas.drawRect(const ui.Rect.fromLTWH(4, 2, 8, 3), _paint);
    _paint.color = colors.$3;
    canvas.drawRect(const ui.Rect.fromLTWH(3, 10, 10, 8), _paint);
    _paint.color = colors.$4;
    canvas
      ..drawRect(const ui.Rect.fromLTWH(4, 18, 3, 4), _paint)
      ..drawRect(const ui.Rect.fromLTWH(9, 18, 3, 4), _paint);
    _paint.color = PixelPalette.voidBlack;
    final eyeY = facing == Direction.north ? 5.0 : 6.0;
    if (facing != Direction.west) {
      canvas.drawRect(ui.Rect.fromLTWH(9, eyeY, 1, 1), _paint);
    }
    if (facing != Direction.east) {
      canvas.drawRect(ui.Rect.fromLTWH(6, eyeY, 1, 1), _paint);
    }
    if (entity.kind == EntityKind.player) {
      _paint.color = PixelPalette.brickRed;
      canvas.drawRect(const ui.Rect.fromLTWH(3, 10, 10, 2), _paint);
    }
  }

  (ui.Color, ui.Color, ui.Color, ui.Color) _colorsFor(EntityKind kind) =>
      switch (kind) {
        EntityKind.player => (
          PixelPalette.skin,
          PixelPalette.hair,
          PixelPalette.jacket,
          PixelPalette.bone,
        ),
        EntityKind.wanderer => (
          PixelPalette.zombie,
          PixelPalette.zombieDark,
          PixelPalette.wall,
          PixelPalette.zombieDark,
        ),
        EntityKind.sprinter => (
          PixelPalette.zombie,
          PixelPalette.hair,
          PixelPalette.sprinter,
          PixelPalette.zombieDark,
        ),
        EntityKind.brute => (
          PixelPalette.zombie,
          PixelPalette.zombieDark,
          PixelPalette.brute,
          PixelPalette.wallShadow,
        ),
        EntityKind.blind => (
          PixelPalette.blind,
          PixelPalette.bone,
          PixelPalette.wallShadow,
          PixelPalette.blind,
        ),
      };

  String _atlasName(EntityKind kind) => switch (kind) {
    EntityKind.player => 'protagonist',
    EntityKind.wanderer => 'zombie_wanderer',
    EntityKind.sprinter => 'zombie_sprinter',
    EntityKind.brute => 'zombie_brute',
    EntityKind.blind => 'zombie_blind',
  };
}
