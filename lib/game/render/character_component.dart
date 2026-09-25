import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;
import 'package:stepbound/core/entities/components.dart' as simulation;
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/pixel_palette.dart';

enum CharacterAction { none, fire, hit, bite, death, pickup, rest }

final class CharacterComponent extends PositionComponent {
  CharacterComponent({
    required this.entity,
    this.playerOutfit = PlayerOutfit.base,
  }) : super(size: Vector2(16, 24), anchor: Anchor.bottomCenter, priority: 20);

  static const double fireDuration = 0.21;
  static const double hitDuration = 0.18;
  static const double biteDuration = 0.28;
  static const double deathDuration = 0.45;
  static const double alertDuration = 1.2;
  static const double pickupDuration = 0.6;
  static const double emergeDuration = 0.9;
  static const double restDuration = 1.5;

  final Entity entity;
  ui.Image? _atlas;
  ui.Image? _gunAtlas;
  ui.Image? _pickupAtlas;
  ui.Image? _hitAtlas;
  ui.Image? _biteAtlas;
  ui.Image? _deathAtlas;
  final Map<PlayerOutfit, ui.Image?> _outfitAtlases =
      <PlayerOutfit, ui.Image?>{};
  final Map<PlayerOutfit, ui.Image?> _outfitGunAtlases =
      <PlayerOutfit, ui.Image?>{};
  final Map<PlayerOutfit, ui.Image?> _outfitPickupAtlases =
      <PlayerOutfit, ui.Image?>{};
  PlayerOutfit playerOutfit;
  double animationProgress = 1;
  double _breathElapsed = 0;
  double _alertElapsed = alertDuration;
  double _emergeElapsed = emergeDuration;
  bool isMoving = false;

  /// Cleared by the game while this character stands away from the
  /// camera, so a crowd spread over the map is not drawn every frame
  /// for nothing. Its timers keep running: they cost almost nothing and
  /// an animation started off screen should be over by the time it
  /// walks back in.
  bool onScreen = true;

  CharacterAction _action = CharacterAction.none;
  double _actionElapsed = 0;
  double actionDuration = 0;
  int _actionRow = 0;

  /// True while the player should hold the drawn-pistol stance.
  bool aiming = false;

  bool get isDying => _action == CharacterAction.death;

  static int rowFor(Direction direction) => switch (direction) {
    Direction.south => 0,
    Direction.west => 1,
    Direction.east => 2,
    Direction.north => 3,
  };

  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    if (entity.kind == EntityKind.player) {
      for (final outfit in PlayerOutfit.values) {
        final stem = outfit.spriteStem;
        _outfitAtlases[outfit] = await _loadImage(
          assets,
          'assets/sprites/$stem.png',
        );
        _outfitGunAtlases[outfit] = await _loadImage(
          assets,
          'assets/sprites/${stem}_gun.png',
        );
        _outfitPickupAtlases[outfit] = await _loadImage(
          assets,
          'assets/sprites/${stem}_pickup.png',
        );
      }
      wearOutfit(playerOutfit);
    } else {
      final name = _atlasName(entity.kind);
      _atlas = await _loadImage(assets, 'assets/sprites/$name.png');
      _hitAtlas = await _loadImage(assets, 'assets/sprites/${name}_hit.png');
      _biteAtlas = await _loadImage(assets, 'assets/sprites/${name}_bite.png');
      _deathAtlas = await _loadImage(
        assets,
        'assets/sprites/${name}_death.png',
      );
    }
  }

  /// Swaps the three player sheets together, including gun and pickup/rest
  /// actions. They are preloaded, so the change can happen while black.
  void wearOutfit(PlayerOutfit outfit) {
    if (entity.kind != EntityKind.player) {
      return;
    }
    playerOutfit = outfit;
    _atlas = _outfitAtlases[outfit];
    _gunAtlas = _outfitGunAtlases[outfit];
    _pickupAtlas = _outfitPickupAtlases[outfit];
  }

  Future<ui.Image?> _loadImage(
    Iterable<String> assets,
    String assetPath,
  ) async {
    if (!assets.contains(assetPath)) {
      return null;
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
    if (loaded.width < 96 || loaded.height < 96) {
      return null;
    }
    return loaded;
  }

  void playFire(Direction facing) {
    if (_gunAtlas == null || _action == CharacterAction.death) {
      return;
    }
    _startAction(CharacterAction.fire, rowFor(facing), fireDuration);
  }

  /// Crouch, grab the backpack in front and stand up again.
  void playPickup(Direction facing) {
    if (_pickupAtlas == null || _action == CharacterAction.death) {
      return;
    }
    _startAction(CharacterAction.pickup, rowFor(facing), pickupDuration);
  }

  /// Kneel by a campfire to warm up, then stand again.
  void playRest(Direction facing) {
    if (_pickupAtlas == null || _action == CharacterAction.death) {
      return;
    }
    _startAction(CharacterAction.rest, rowFor(facing), restDuration);
  }

  void playHit(Direction facing) {
    if (_hitAtlas == null || _action == CharacterAction.death) {
      return;
    }
    _startAction(CharacterAction.hit, rowFor(facing), hitDuration);
  }

  void playBite(Direction facing) {
    if (_biteAtlas == null || _action == CharacterAction.death) {
      return;
    }
    _startAction(CharacterAction.bite, rowFor(facing), biteDuration);
  }

  void playDeath(Direction facing) {
    if (_deathAtlas == null) {
      return;
    }
    _startAction(CharacterAction.death, rowFor(facing), deathDuration);
  }

  void _startAction(CharacterAction action, int row, double duration) {
    _action = action;
    _actionRow = row;
    _actionElapsed = 0;
    actionDuration = duration;
  }

  /// Fades the character in out of the dark, rising from a crouch.
  void playEmerge() {
    _emergeElapsed = 0;
  }

  /// Shows the comic-style "!" balloon above the head.
  void playAlert() {
    _alertElapsed = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _breathElapsed += dt;
    if (_alertElapsed < alertDuration) {
      _alertElapsed += dt;
    }
    if (_emergeElapsed < emergeDuration) {
      _emergeElapsed += dt;
    }
    if (_action == CharacterAction.none) {
      return;
    }
    _actionElapsed += dt;
    if (_actionElapsed >= actionDuration && _action != CharacterAction.death) {
      _action = CharacterAction.none;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (!onScreen) {
      return;
    }
    if (_emergeElapsed >= emergeDuration) {
      _renderCharacter(canvas);
      return;
    }
    final progress = _emergeElapsed / emergeDuration;
    canvas
      ..saveLayer(
        const ui.Rect.fromLTWH(-16, -16, 48, 48),
        ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, progress),
      )
      ..translate(0, ((1 - progress) * 4).roundToDouble());
    _renderCharacter(canvas);
    canvas.restore();
  }

  void _renderCharacter(ui.Canvas canvas) {
    if (_action == CharacterAction.death) {
      final atlas = _deathAtlas;
      if (atlas == null) {
        return;
      }
      if (_actionElapsed >= actionDuration) {
        return;
      }
      final progress = _actionElapsed / actionDuration;
      final column = (progress * 6).floor().clamp(0, 5);
      _drawCell(canvas, atlas, _actionRow, column);
      return;
    }
    if (!entity.isAlive) {
      return;
    }
    final facing = entity.component<simulation.PositionComponent>().facing;
    final row = rowFor(facing);
    switch (_action) {
      case CharacterAction.fire when _gunAtlas != null:
        final progress = (_actionElapsed / actionDuration).clamp(0, 1);
        _drawCell(canvas, _gunAtlas!, _actionRow, 3 + (progress * 3).floor());
      case CharacterAction.pickup when _pickupAtlas != null:
        final progress = (_actionElapsed / actionDuration).clamp(0, 1);
        _drawCell(
          canvas,
          _pickupAtlas!,
          _actionRow,
          (progress * 6).floor().clamp(0, 5),
        );
      case CharacterAction.rest when _pickupAtlas != null:
        // Kneel (pick_0, pick_1), stay down warming up, rise (pick_0, idle).
        final progress = (_actionElapsed / actionDuration).clamp(0, 1);
        final column = switch (progress) {
          < 0.12 => 0,
          < 0.82 => 1,
          < 0.92 => 0,
          _ => 5,
        };
        _drawCell(canvas, _pickupAtlas!, _actionRow, column);
      case CharacterAction.hit when _hitAtlas != null:
        final progress = (_actionElapsed / actionDuration).clamp(0, 1);
        _drawCell(canvas, _hitAtlas!, _actionRow, (progress * 3).floor());
      case CharacterAction.bite when _biteAtlas != null:
        final progress = (_actionElapsed / actionDuration).clamp(0, 1);
        _drawCell(canvas, _biteAtlas!, _actionRow, (progress * 4).floor());
        final reach = entity.component<simulation.ActorComponent>().attackReach;
        if (reach > 1 && progress >= 0.45 && progress < 0.8) {
          _drawBatonSwoosh(canvas, _actionRow, reach);
        }
      case _:
        _renderBase(canvas, row);
    }
    if (_alertElapsed < alertDuration) {
      _drawAlertBalloon(canvas);
    }
  }

  /// The baton's arc sweeping across the tile between the attacker and a
  /// player standing further than one tile away.
  void _drawBatonSwoosh(ui.Canvas canvas, int row, int reach) {
    final length = (reach - 1) * 16.0;
    _paint.color = const ui.Color(0xccf4f4f4);
    final rect = switch (row) {
      0 => ui.Rect.fromLTWH(5, 22, 6, length),
      1 => ui.Rect.fromLTWH(-length, 11, length, 2),
      2 => ui.Rect.fromLTWH(16, 11, length, 2),
      _ => ui.Rect.fromLTWH(5, -length, 6, length),
    };
    canvas.drawRect(rect, _paint);
    _paint.color = const ui.Color(0x66f4f4f4);
    canvas.drawRect(rect.inflate(1), _paint);
  }

  void _drawAlertBalloon(ui.Canvas canvas) {
    final rise = (_alertElapsed / alertDuration * 2).floorToDouble();
    canvas
      ..save()
      ..translate(0, rise);
    _paint.color = const ui.Color(0xff100c0c);
    canvas
      ..drawRect(const ui.Rect.fromLTWH(8, -9, 8, 8), _paint)
      ..drawRect(const ui.Rect.fromLTWH(10, -1, 1, 2), _paint);
    _paint.color = PixelPalette.bone;
    canvas.drawRect(const ui.Rect.fromLTWH(9, -8, 6, 6), _paint);
    _paint.color = PixelPalette.brickRed;
    canvas
      ..drawRect(const ui.Rect.fromLTWH(11, -7, 2, 2), _paint)
      ..drawRect(const ui.Rect.fromLTWH(11, -4, 2, 1), _paint)
      ..restore();
  }

  void _renderBase(ui.Canvas canvas, int row) {
    final gunAtlas = _gunAtlas;
    if (aiming && gunAtlas != null) {
      final breathe = (_breathElapsed * 1.6).floor() % 2;
      _drawCell(canvas, gunAtlas, row, breathe);
      return;
    }
    final atlas = _atlas;
    if (atlas != null) {
      final column = isMoving
          ? 2 + (animationProgress * 4).floor().clamp(0, 3)
          : (animationProgress * 2).floor().clamp(0, 1);
      _drawCell(canvas, atlas, row, column);
    } else {
      _renderPrototype(canvas);
    }
  }

  void _drawCell(ui.Canvas canvas, ui.Image atlas, int row, int column) {
    // The supplied occultist sheets leave two transparent pixels under
    // every frame. Compensate at draw time so Mario keeps the same foot
    // anchor when changing clothes.
    final outfitOffset =
        entity.kind == EntityKind.player && playerOutfit == PlayerOutfit.cultist
        ? 2.0
        : 0.0;
    canvas.drawImageRect(
      atlas,
      ui.Rect.fromLTWH(column * 16, row * 24, 16, 24),
      ui.Rect.fromLTWH(0, outfitOffset, 16, 24),
      _paint,
    );
  }

  void _renderPrototype(ui.Canvas canvas) {
    final colors = _colorsFor(entity.kind);
    final facing = entity.component<simulation.PositionComponent>().facing;
    _paint.color = const ui.Color(0x55000000);
    canvas.drawRect(const ui.Rect.fromLTWH(3, 21, 10, 2), _paint);
    // No legs: the head and the chest lie on the floor, the stumps bloody.
    final legless = entity.kind == EntityKind.mutilated;
    if (legless) {
      canvas
        ..save()
        ..translate(0, 6);
    }
    _paint.color = colors.$1;
    canvas.drawRect(const ui.Rect.fromLTWH(4, 3, 8, 7), _paint);
    _paint.color = colors.$2;
    canvas.drawRect(const ui.Rect.fromLTWH(4, 2, 8, 3), _paint);
    _paint.color = colors.$3;
    canvas.drawRect(const ui.Rect.fromLTWH(3, 10, 10, 8), _paint);
    _paint.color = colors.$4;
    if (legless) {
      canvas.drawRect(const ui.Rect.fromLTWH(3, 16, 10, 2), _paint);
    } else {
      canvas
        ..drawRect(const ui.Rect.fromLTWH(4, 18, 3, 4), _paint)
        ..drawRect(const ui.Rect.fromLTWH(9, 18, 3, 4), _paint);
    }
    _paint.color = PixelPalette.voidBlack;
    final eyeY = facing == Direction.north ? 5.0 : 6.0;
    if (facing != Direction.west) {
      canvas.drawRect(ui.Rect.fromLTWH(9, eyeY, 1, 1), _paint);
    }
    if (facing != Direction.east) {
      canvas.drawRect(ui.Rect.fromLTWH(6, eyeY, 1, 1), _paint);
    }
    if (legless) {
      canvas.restore();
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
        EntityKind.carabiniere => (
          PixelPalette.zombie,
          PixelPalette.voidBlack,
          PixelPalette.jacket,
          PixelPalette.brickRed,
        ),
        EntityKind.mutilated => (
          PixelPalette.zombie,
          PixelPalette.zombieDark,
          PixelPalette.wall,
          PixelPalette.brickRed,
        ),
        EntityKind.burning => (
          PixelPalette.hair,
          PixelPalette.blood,
          PixelPalette.brickRed,
          PixelPalette.voidBlack,
        ),
        EntityKind.drunk => (
          PixelPalette.zombie,
          PixelPalette.hair,
          PixelPalette.sprinter,
          PixelPalette.zombieDark,
        ),
        EntityKind.cultist => (
          PixelPalette.zombie,
          PixelPalette.hair,
          PixelPalette.cultistRobe,
          PixelPalette.cultistVein,
        ),
      };

  String _atlasName(EntityKind kind) => switch (kind) {
    EntityKind.player => 'protagonist',
    EntityKind.wanderer => 'zombie_wanderer',
    EntityKind.sprinter => 'zombie_sprinter',
    EntityKind.brute => 'zombie_brute',
    EntityKind.blind => 'zombie_blind',
    EntityKind.carabiniere => 'zombie_carabiniere',
    EntityKind.mutilated => 'zombie_mutilated',
    EntityKind.burning => 'zombie_burning',
    EntityKind.drunk => 'zombie_drunk',
    EntityKind.cultist => 'zombie_cultist',
  };
}
