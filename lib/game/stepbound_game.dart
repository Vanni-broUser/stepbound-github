import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/anim/turn_presentation_controller.dart';
import 'package:stepbound/game/f2_world.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/render/debug_overlay.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/game/render/tile_map_component.dart';

final class StepboundGame extends FlameGame with KeyboardEvents {
  StepboundGame({int seed = 20260920})
    : simulation = createF2World(seed: seed),
      super(
        camera: CameraComponent(
          viewport: FixedResolutionViewport(
            resolution: Vector2(
              IntegerResolutionViewport.virtualWidth,
              IntegerResolutionViewport.virtualHeight,
            ),
          ),
        ),
      );

  static const double tileSize = 16;
  static const double holdRepeatSeconds = 0.18;

  final WorldState simulation;
  late final TurnPresentationController presentation;
  late final DebugWorldOverlay debugOverlay;
  late final TextComponent statusText;
  final Map<String, CharacterComponent> _characters =
      <String, CharacterComponent>{};
  Direction? _heldDirection;
  double _holdElapsed = 0;

  @override
  Color backgroundColor() => PixelPalette.voidBlack;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    presentation = TurnPresentationController(world: simulation);
    await world.addAll(<Component>[
      TileMapComponent(map: simulation.map, layer: TileLayer.ground),
      TileMapComponent(map: simulation.map, layer: TileLayer.structures),
      TileMapComponent(map: simulation.map, layer: TileLayer.foreground),
    ]);
    for (final entity in simulation.entities.values) {
      final component = CharacterComponent(entity: entity);
      _characters[entity.id] = component;
      await world.add(component);
    }
    debugOverlay = DebugWorldOverlay(simulation: simulation);
    await world.add(debugOverlay);

    final textPaint = TextPaint(
      style: const TextStyle(
        color: PixelPalette.bone,
        fontSize: 8,
        fontFamily: 'monospace',
      ),
    );
    await camera.viewport.add(
      FpsTextComponent<TextPaint>(
        position: Vector2(4, 4),
        textRenderer: textPaint,
      ),
    );
    statusText = TextComponent(
      position: Vector2(4, 14),
      textRenderer: textPaint,
      priority: double.maxFinite.toInt(),
    );
    await camera.viewport.add(statusText);
    _syncPresentation();
    _snapCameraToPlayer();
  }

  @override
  void update(double dt) {
    super.update(dt);
    presentation.update(dt);
    _updateHeldDirection(dt);
    _syncPresentation();
    _updateCamera();
    statusText.text =
        'TICK ${simulation.tick}  QUEUE ${presentation.bufferedActionCount}  '
        'G DEBUG';
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final direction = _directionFor(event.logicalKey);
    if (event is KeyDownEvent) {
      if (direction != null) {
        if (_heldDirection != direction) {
          _heldDirection = direction;
          _holdElapsed = 0;
          presentation.submit(MoveAction(direction));
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.keyX) {
        presentation.submit(const WaitAction());
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyE) {
        presentation.submit(const InteractAction());
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyG) {
        debugOverlay.enabled = !debugOverlay.enabled;
        return KeyEventResult.handled;
      }
    }
    if (event is KeyUpEvent && direction == _heldDirection) {
      _heldDirection = null;
      _holdElapsed = 0;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _updateHeldDirection(double dt) {
    final direction = _heldDirection;
    if (direction == null) {
      return;
    }
    _holdElapsed += dt;
    while (_holdElapsed >= holdRepeatSeconds) {
      _holdElapsed -= holdRepeatSeconds;
      presentation.submit(MoveAction(direction));
    }
  }

  void _syncPresentation() {
    for (final entry in _characters.entries) {
      final visual = presentation.visualPositionFor(entry.key);
      final moving = presentation.isEntityMoving(entry.key);
      final animationProgress = presentation.progress;
      entry.value
        ..position.setValues(
          visual.x * tileSize + tileSize / 2,
          visual.y * tileSize + tileSize,
        )
        ..isMoving = moving
        ..animationProgress = animationProgress;
    }
  }

  void _snapCameraToPlayer() {
    final player = _characters[simulation.playerId]!;
    camera.viewfinder.position = Vector2(
      player.position.x.roundToDouble(),
      player.position.y.roundToDouble(),
    );
    _clampCamera();
  }

  void _updateCamera() {
    final player = _characters[simulation.playerId]!;
    final cameraPosition = camera.viewfinder.position.clone();
    const deadZoneHalfWidth = 48.0;
    const deadZoneHalfHeight = 32.0;
    final differenceX = player.position.x - cameraPosition.x;
    final differenceY = player.position.y - cameraPosition.y;
    if (differenceX.abs() > deadZoneHalfWidth) {
      cameraPosition.x =
          player.position.x - differenceX.sign * deadZoneHalfWidth;
    }
    if (differenceY.abs() > deadZoneHalfHeight) {
      cameraPosition.y =
          player.position.y - differenceY.sign * deadZoneHalfHeight;
    }
    cameraPosition
      ..x = cameraPosition.x.roundToDouble()
      ..y = cameraPosition.y.roundToDouble();
    camera.viewfinder.position = cameraPosition;
    _clampCamera();
  }

  void _clampCamera() {
    final position = camera.viewfinder.position;
    final worldWidth = simulation.map.width * tileSize;
    final worldHeight = simulation.map.height * tileSize;
    const halfWidth = 192.0;
    const halfHeight = 108.0;
    final x = worldWidth <= halfWidth * 2
        ? worldWidth / 2
        : position.x.clamp(halfWidth, worldWidth - halfWidth);
    final y = worldHeight <= halfHeight * 2
        ? worldHeight / 2
        : position.y.clamp(halfHeight, worldHeight - halfHeight);
    camera.viewfinder.position = Vector2(x, y);
  }

  Direction? _directionFor(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      return Direction.north;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      return Direction.east;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      return Direction.south;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      return Direction.west;
    }
    return null;
  }
}
