import 'dart:async';

import 'package:flame/camera.dart';
import 'package:flame/components.dart' hide PositionComponent;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/anim/turn_presentation_controller.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/audio/soundscape.dart';
import 'package:stepbound/game/render/aim_line_component.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/render/debug_overlay.dart';
import 'package:stepbound/game/render/fire_component.dart';
import 'package:stepbound/game/render/flag_component.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/render/level_background_component.dart';
import 'package:stepbound/game/render/lighting_component.dart';
import 'package:stepbound/game/render/pickup_component.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/game/render/screen_fade_component.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// What a campfire save stores: the simulation, the tutorial's progress,
/// the unlocked controls and the name of the place.
typedef GameSnapshot = ({
  Map<String, Object?> world,
  Map<String, Object?> tutorial,
  List<String> hud,
  String place,
});

final class StepboundGame extends FlameGame
    with KeyboardEvents
    implements TutorialHost {
  /// A new game, or one resumed from a save: [world] and `tutorialState`
  /// come from `SaveGame`, [unlocked] lists the touch controls already
  /// earned. [onRest] stores the snapshot taken at a campfire. Without
  /// [audio] the game is silent.
  StepboundGame({
    int seed = 20260920,
    WorldState? world,
    this._tutorialState,
    Set<HudElement> unlocked = const <HudElement>{},
    this.onRest,
    GameAudio? audio,
  }) : simulation = world ?? createStreetWorld(seed: seed),
       audio = audio ?? SilentAudio(),
       hud = ValueNotifier<Set<HudElement>>(Set<HudElement>.of(unlocked)),
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

  /// How long Mario stands still on the threshold of a building, so the
  /// place he has just walked into can sink in.
  static const double entranceHoldSeconds = 2.2;

  final WorldState simulation;
  final GameAudio audio;
  late final Soundscape soundscape = Soundscape(world: simulation);
  late final TurnPresentationController presentation;
  late final DebugWorldOverlay debugOverlay;
  final Map<String, CharacterComponent> _characters =
      <String, CharacterComponent>{};
  final ValueNotifier<bool> aiming = ValueNotifier<bool>(false);
  final ValueNotifier<bool> gameOver = ValueNotifier<bool>(false);

  /// Ignores the keyboard while a dialogue covers the game.
  bool inputLocked = false;

  /// Touch controls unlocked so far by the tutorial (the arrows are always
  /// available).
  final ValueNotifier<Set<HudElement>> hud;

  /// Saves the progress when the player rests at a campfire.
  final Future<void> Function(GameSnapshot snapshot)? onRest;
  final Map<String, Object?>? _tutorialState;
  final Map<GridPoint, FireComponent> _campfires = <GridPoint, FireComponent>{};

  /// Counts down Mario's rest by the fire before the game is saved.
  double _restLeft = 0;
  GridPoint? _restingAt;

  /// Counts down the pause after walking into a building.
  double _entranceHoldLeft = 0;

  /// Tutorial text currently shown over the game, if any.
  final ValueNotifier<List<TutorialLine>?> prompt =
      ValueNotifier<List<TutorialLine>?>(null);
  void Function()? _onPromptDismissed;
  late final TutorialDirector tutorial;
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
    for (final region in levelRegions) {
      await world.add(
        LevelBackgroundComponent(
          assetPath: region.background,
          offset: Offset(
            region.bounds.left * tileSize,
            region.bounds.top * tileSize,
          ),
        ),
      );
      if (region.indoor) {
        await world.add(
          LightingComponent(
            area: _regionRect(region),
            lights: barracksLights(),
            playerPosition: () => _characters[playerId]!.position,
          ),
        );
      }
    }
    await world.addAll(_fires());
    final pole = flagpoleTile();
    await world.add(
      FlagComponent(
        foot: Vector2(
          pole.x * tileSize + tileSize / 2,
          pole.y * tileSize + tileSize - 2,
        ),
      ),
    );
    await world.addAll(<Component>[
      for (final pickup in simulation.pickups.values)
        PickupComponent(pickup: pickup),
    ]);
    tutorial = TutorialDirector(world: simulation, host: this);
    final tutorialState = _tutorialState;
    if (tutorialState != null) {
      tutorial.restore(tutorialState);
    }
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
    tutorial.update(dt, turnAnimating: presentation.isAnimating);
    _updateRest(dt);
    _updateEntranceHold(dt);
    _updateHeldDirection(dt);
    _syncPresentation();
    _updateCamera(dt);
    Soundscape.apply(
      audio,
      soundscape.update(
        dt,
        indoor: _currentRegion().indoor,
        resting: _restingAt != null,
        gameOver: gameOver.value,
      ),
    );
    final ammo = simulation.player.component<AmmoComponent>();
    if (ammoLoaded.value != ammo.loaded) {
      ammoLoaded.value = ammo.loaded;
    }
  }

  List<FireComponent> _fires() {
    var seed = 0;
    return <FireComponent>[
      for (final spot in outdoorFireSpots())
        switch (spot.kind) {
          // A car parked north-south burns on its roof, mid-way down.
          FireKind.car when spot.vertical => FireComponent(
            base: Vector2(
              spot.tile.x * tileSize + tileSize / 2,
              spot.tile.y * tileSize + 12,
            ),
            halfWidth: 4,
            flameHeight: 13,
            seed: seed++,
          ),
          // Burning car: wide fire centred on the two-tile wreck's roof.
          FireKind.car => FireComponent(
            base: Vector2(
              spot.tile.x * tileSize + tileSize,
              spot.tile.y * tileSize + 4,
            ),
            halfWidth: 6,
            flameHeight: 14,
            seed: seed++,
          ),
          FireKind.bin => FireComponent(
            base: Vector2(
              spot.tile.x * tileSize + tileSize / 2,
              spot.tile.y * tileSize + 6,
            ),
            halfWidth: 3,
            flameHeight: 9,
            seed: seed++,
          ),
          FireKind.window => FireComponent(
            base: Vector2(
              spot.tile.x * tileSize + tileSize / 2,
              spot.tile.y * tileSize + 13,
            ),
            halfWidth: 4,
            flameHeight: 12,
            seed: seed++,
          ),
          FireKind.campfire => _campfires[spot.tile] = FireComponent(
            base: Vector2(
              spot.tile.x * tileSize + tileSize / 2,
              spot.tile.y * tileSize + 11,
            ),
            halfWidth: 3,
            flameHeight: 9,
            seed: seed++,
          ),
        },
    ];
  }

  void _routeNewEvents() {
    if (presentation.turnCount == _processedTurn) {
      return;
    }
    _processedTurn = presentation.turnCount;
    tutorial.onEvents(presentation.lastEvents);
    for (final cue in <SfxCue>[
      ...soundscape.soundsFor(presentation.lastEvents),
      ...soundscape.idleMoans(),
    ]) {
      audio.play(cue.sfx, volume: cue.volume);
    }
    for (final event in presentation.lastEvents) {
      switch (event) {
        case CampfireUsedEvent(:final at):
          _startRest(at);
        case TeleportedEvent(:final to):
          final entering = _isIndoor(to);
          _addWithoutWaiting(
            camera.viewport,
            ScreenFadeComponent(
              size: Vector2(
                IntegerResolutionViewport.virtualWidth,
                IntegerResolutionViewport.virtualHeight,
              ),
              fadeIn: entering
                  ? ScreenFadeComponent.slowFadeIn
                  : ScreenFadeComponent.defaultFadeIn,
            ),
          );
          if (entering) {
            _startEntranceHold();
          }
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

  bool get _canAct => _acceptsInput && !inputLocked && _entranceHoldLeft <= 0;

  bool _isIndoor(GridPoint tile) => levelRegions.any(
    (region) => region.indoor && region.bounds.contains(tile),
  );

  /// Mario stops on the threshold while the room fades in: the steps queued
  /// on the street are dropped and a held arrow must be pressed again.
  void _startEntranceHold() {
    _heldDirection = null;
    _holdElapsed = 0;
    presentation.clearBuffer();
    aiming.value = false;
    _entranceHoldLeft = entranceHoldSeconds;
  }

  void _updateEntranceHold(double dt) {
    if (_entranceHoldLeft > 0) {
      _entranceHoldLeft -= dt;
    }
  }

  @override
  bool isTileVisible(GridPoint tile) {
    final view = camera.visibleWorldRect;
    return view.left <= tile.x * tileSize &&
        view.top <= tile.y * tileSize &&
        view.right >= (tile.x + 1) * tileSize &&
        view.bottom >= (tile.y + 1) * tileSize;
  }

  @override
  bool get isPromptVisible => prompt.value != null;

  String? _focusId;

  @override
  void focusOn(String? entityId) => _focusId = entityId;

  @override
  void showPrompt(List<TutorialLine> lines, {void Function()? onDismissed}) {
    _heldDirection = null;
    _holdElapsed = 0;
    presentation.clearBuffer();
    aiming.value = false;
    inputLocked = true;
    _onPromptDismissed = onDismissed;
    prompt.value = List<TutorialLine>.unmodifiable(lines);
  }

  /// Called by the dialogue overlay after the last line.
  void dismissPrompt() {
    final callback = _onPromptDismissed;
    _onPromptDismissed = null;
    prompt.value = null;
    inputLocked = false;
    callback?.call();
  }

  @override
  void playPickupAnimation() {
    _characters[playerId]?.playPickup(_playerFacing());
  }

  /// Adds [child] mid-frame; it finishes loading on its own.
  void _addWithoutWaiting(Component parent, Component child) {
    final result = parent.add(child);
    if (result is Future<void>) {
      unawaited(result);
    }
  }

  @override
  void spawnZombie(Entity zombie) {
    simulation.entities[zombie.id] = zombie;
    final component = CharacterComponent(entity: zombie)..playEmerge();
    audio.play(Sfx.zombieAlert);
    _characters[zombie.id] = component;
    _addWithoutWaiting(world, component);
  }

  @override
  bool isUnlocked(HudElement element) => hud.value.contains(element);

  /// Mario kneels by the fire, which roars up; the game is saved when the
  /// moment is over.
  void _startRest(GridPoint campfire) {
    _heldDirection = null;
    presentation.clearBuffer();
    aiming.value = false;
    inputLocked = true;
    _restingAt = campfire;
    _restLeft = CharacterComponent.restDuration;
    _campfires[campfire]?.flare();
    _characters[playerId]?.playRest(_playerFacing());
  }

  void _updateRest(double dt) {
    if (_restingAt == null) {
      return;
    }
    _restLeft -= dt;
    if (_restLeft > 0) {
      return;
    }
    final campfire = _restingAt!;
    _restingAt = null;
    unawaited(_save(campfire));
  }

  Future<void> _save(GridPoint campfire) async {
    await onRest?.call(snapshot(place: campfireNames()[campfire] ?? ''));
    showPrompt(const <TutorialLine>[TutorialLine(TutorialDirector.saved)]);
  }

  /// The whole game as it is now, ready to be saved.
  GameSnapshot snapshot({required String place}) => (
    world: simulation.toJson(),
    tutorial: tutorial.toJson(),
    hud: <String>[for (final element in hud.value) element.name],
    place: place,
  );

  @override
  void unlock(HudElement element) {
    if (!hud.value.contains(element)) {
      hud.value = <HudElement>{...hud.value, element};
    }
  }

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
      audio.play(Sfx.gameOver);
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (inputLocked) {
      return KeyEventResult.ignored;
    }
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
    if (!_canAct) {
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
    if (!_canAct || !hud.value.contains(HudElement.shoot)) {
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
    if (!_canAct) {
      return;
    }
    if (aiming.value) {
      aiming.value = false;
      return;
    }
    if (!hud.value.contains(HudElement.interact)) {
      return;
    }
    presentation.submit(const InteractAction());
  }

  void pressWait() {
    if (!_canAct || aiming.value) {
      return;
    }
    presentation.submit(const WaitAction());
  }

  void _updateHeldDirection(double dt) {
    final direction = _heldDirection;
    if (direction == null || !_canAct) {
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

  /// Follows the player with a dead zone; while a character is in focus it
  /// frames the player and that character together. The camera glides to
  /// its target so switching focus never jumps.
  LevelRegion? _cameraRegion;

  void _updateCamera(double dt) {
    final player = _characters[simulation.playerId]!;
    final region = _currentRegion();
    if (region != _cameraRegion) {
      _cameraRegion = region;
      _snapCameraToPlayer();
      return;
    }
    final current = camera.viewfinder.position.clone();
    final focus = _characters[_focusId ?? ''];
    final Vector2 target;
    if (focus != null) {
      target = (player.position + focus.position)..scale(0.5);
    } else {
      const deadZoneHalfWidth = 48.0;
      const deadZoneHalfHeight = 32.0;
      target = current.clone();
      final differenceX = player.position.x - current.x;
      final differenceY = player.position.y - current.y;
      if (differenceX.abs() > deadZoneHalfWidth) {
        target.x = player.position.x - differenceX.sign * deadZoneHalfWidth;
      }
      if (differenceY.abs() > deadZoneHalfHeight) {
        target.y = player.position.y - differenceY.sign * deadZoneHalfHeight;
      }
    }
    const panSpeed = 260.0;
    final offset = target - current;
    final maxStep = panSpeed * dt;
    if (offset.length > maxStep) {
      offset.scaleTo(maxStep);
    }
    final next = current + offset;
    camera.viewfinder.position = Vector2(
      next.x.roundToDouble(),
      next.y.roundToDouble(),
    );
    _clampCamera();
  }

  Rect _regionRect(LevelRegion region) => Rect.fromLTRB(
    region.bounds.left * tileSize,
    region.bounds.top * tileSize,
    (region.bounds.right + 1) * tileSize,
    (region.bounds.bottom + 1) * tileSize,
  );

  /// The region the player is drawn in (it changes when the step through a
  /// door has finished playing).
  LevelRegion _currentRegion() {
    final feet = _characters[playerId]!.position;
    final tile = GridPoint(
      (feet.x / tileSize).floor(),
      ((feet.y - 1) / tileSize).floor(),
    );
    return levelRegions.firstWhere(
      (region) => region.bounds.contains(tile),
      orElse: () => levelRegions.first,
    );
  }

  /// Keeps the view inside the current region; a region smaller than the
  /// view sits centred on the dark background.
  void _clampCamera() {
    final position = camera.viewfinder.position;
    final area = _regionRect(_currentRegion());
    const halfWidth = 192.0;
    const halfHeight = 108.0;
    final x = area.width <= halfWidth * 2
        ? area.center.dx
        : position.x.clamp(area.left + halfWidth, area.right - halfWidth);
    final y = area.height <= halfHeight * 2
        ? area.center.dy
        : position.y.clamp(area.top + halfHeight, area.bottom - halfHeight);
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
