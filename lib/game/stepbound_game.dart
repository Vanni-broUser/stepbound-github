import 'package:flame/camera.dart';
import 'package:flame/components.dart' hide PositionComponent;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/anim/turn_presentation_controller.dart';
import 'package:stepbound/game/f2_world.dart';
import 'package:stepbound/game/render/aim_line_component.dart';
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
      ) {
    final ammo = simulation.player.component<AmmoComponent>();
    ammoLoaded = ValueNotifier<int>(ammo.loaded);
  }

  static const double tileSize = 16;
  static const double holdRepeatSeconds = 0.18;

  final WorldState simulation;
  late final TurnPresentationController presentation;
  late final DebugWorldOverlay debugOverlay;
  late final TextComponent statusText;
  final Map<String, CharacterComponent> _characters =
      <String, CharacterComponent>{};
  final ValueNotifier<bool> aiming = ValueNotifier<bool>(false);
  final ValueNotifier<bool> gameOver = ValueNotifier<bool>(false);
  late final ValueNotifier<int> ammoLoaded;
  Direction? _heldDirection;
  double _holdElapsed = 0;
  bool _acceptsInput = false;
  int _processedTurn = 0;
  double _gameOverCountdown = 0;

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
    await world.addAll(<Component>[
      debugOverlay,
      AimLineComponent(simulation: simulation, aiming: aiming),
    ]);

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
    _acceptsInput = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    presentation.update(dt);
    _routeNewEvents();
    _updateGameOverCountdown(dt);
    _updateHeldDirection(dt);
    _syncPresentation();
    _updateCamera();
    final ammo = simulation.player.component<AmmoComponent>();
    if (ammoLoaded.value != ammo.loaded) {
      ammoLoaded.value = ammo.loaded;
    }
    final health = simulation.player.component<HealthComponent>();
    statusText.text =
        'TICK ${simulation.tick}  HP ${health.current}/${health.maximum}  '
        'AMMO ${ammo.loaded}/${ammo.reserve}  '
        '${aiming.value ? 'MIRA  ' : ''}G DEBUG';
  }

  void _routeNewEvents() {
    if (presentation.turnCount == _processedTurn) {
      return;
    }
    _processedTurn = presentation.turnCount;
    for (final event in presentation.lastEvents) {
      switch (event) {
        case AlertedEvent(entityId: final spotter):
          _characters[spotter]?.playAlert();
        case ShotEvent(entityId: final shooter) when shooter == playerId:
          _characters[playerId]?.playFire(_playerFacing());
        case DamagedEvent(entityId: final target, sourceEntityId: final source)
            when target == playerId:
          _characters[source]?.playBite(_facingOf(source));
        case DamagedEvent(entityId: final target, sourceEntityId: _):
          _characters[target]?.playHit(_facingOf(target));
        case DiedEvent(entityId: final victim) when victim == playerId:
          _acceptsInput = false;
          aiming.value = false;
          _heldDirection = null;
          _gameOverCountdown = CharacterComponent.deathDuration + 0.45;
        case DiedEvent(entityId: final victim):
          _characters[victim]?.playDeath(_facingOf(victim));
        case _:
          break;
      }
    }
  }

  String get playerId => simulation.playerId;

  Direction _playerFacing() =>
      simulation.player.component<PositionComponent>().facing;

  Direction _facingOf(String entityId) {
    final entity = simulation.entities[entityId];
    if (entity == null) {
      return Direction.south;
    }
    return entity.component<PositionComponent>().facing;
  }

  void _updateGameOverCountdown(double dt) {
    if (_gameOverCountdown <= 0 || gameOver.value) {
      return;
    }
    _gameOverCountdown -= dt;
    if (_gameOverCountdown <= 0) {
      gameOver.value = true;
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final direction = _directionFor(event.logicalKey);
    if (event is KeyDownEvent) {
      if (direction != null) {
        pressDirection(direction);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyB) {
        pressShoot();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyE) {
        pressInteract();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.keyX) {
        pressWait();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyG) {
        debugOverlay.enabled = !debugOverlay.enabled;
        return KeyEventResult.handled;
      }
    }
    if (event is KeyUpEvent && direction != null) {
      releaseDirection(direction);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void pressDirection(Direction direction) {
    if (!_acceptsInput) {
      return;
    }
    if (aiming.value) {
      simulation.player.component<PositionComponent>().facing = direction;
      return;
    }
    if (_heldDirection == direction) {
      return;
    }
    _heldDirection = direction;
    _holdElapsed = 0;
    presentation.submit(MoveAction(direction));
  }

  void releaseDirection(Direction direction) {
    if (_heldDirection != direction) {
      return;
    }
    _heldDirection = null;
    _holdElapsed = 0;
  }

  void pressShoot() {
    if (!_acceptsInput) {
      return;
    }
    if (!aiming.value) {
      final ammo = simulation.player.component<AmmoComponent>();
      if (ammo.loaded == 0) {
        return;
      }
      _heldDirection = null;
      _holdElapsed = 0;
      aiming.value = true;
      return;
    }
    presentation.submit(const ShootAction());
    aiming.value = false;
  }

  void pressInteract() {
    if (!_acceptsInput) {
      return;
    }
    if (aiming.value) {
      aiming.value = false;
      return;
    }
    presentation.submit(const InteractAction());
  }

  void pressWait() {
    if (!_acceptsInput || aiming.value) {
      return;
    }
    presentation.submit(const WaitAction());
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
        ..animationProgress = animationProgress
        ..aiming = entry.key == playerId && aiming.value;
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
