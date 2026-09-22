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
import 'package:stepbound/game/game_cover.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/aim_line_component.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/render/debug_overlay.dart';
import 'package:stepbound/game/render/fire_component.dart';
import 'package:stepbound/game/render/flag_component.dart';
import 'package:stepbound/game/render/follow_camera.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/render/mall_props.dart';
import 'package:stepbound/game/render/pickup_component.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/game/render/place_layers.dart';
import 'package:stepbound/game/render/screen_fade_component.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

export 'package:stepbound/game/game_cover.dart';

/// What a campfire save stores: the simulation, the tutorial's scripts, the
/// player's progress, the unlocked controls and the name of the place.
typedef GameSnapshot = ({
  Map<String, Object?> world,
  Map<String, Object?> tutorial,
  Map<String, Object?> progress,
  List<String> hud,
  String place,
});

/// The game: the simulation, drawn and animated, played with the keyboard
/// or the touch controls. Whatever covers it (a text box, a story scene, a
/// place card, the camp menu, game over) is a [GameCover] the app draws.
final class StepboundGame extends FlameGame
    with KeyboardEvents
    implements TutorialHost {
  /// A new game, or one resumed from a save: [world], `tutorialState` and
  /// [progress] come from `SaveGame`, [unlocked] lists the touch controls
  /// already earned. [onRest] stores the snapshot taken at a campfire.
  /// Without [audio] the game is silent.
  StepboundGame({
    int seed = 20260920,
    WorldState? world,
    this._tutorialState,
    Set<HudElement> unlocked = const <HudElement>{},
    this.onRest,
    GameAudio? audio,
    Progress? progress,
  }) : simulation = world ?? createTutorialWorld(seed: seed),
       progress = progress ?? Progress.newGame(),
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
    ammoLoaded = ValueNotifier<int>(
      simulation.player.component<AmmoComponent>().loaded,
    );
  }

  static const double tileSize = 16;
  static const double holdRepeatSeconds = 0.18;

  /// How long Mario stands still on the threshold of a building, so the
  /// place he has just walked into can sink in.
  static const double entranceHoldSeconds = 2.2;

  final WorldState simulation;

  /// The zombie types met and the story scenes seen, over the whole game.
  final Progress progress;
  final GameAudio audio;
  late final Soundscape soundscape = Soundscape(
    world: simulation,
    fires: outdoorFireSpots,
  );
  late final TurnPresentationController presentation;
  late final TutorialDirector tutorial;
  late final DebugWorldOverlay debugOverlay;
  late final FollowCamera _camera = FollowCamera(camera);
  late final PlaceLayers _places = PlaceLayers(
    places: tutorialPlaces,
    playerFeet: () => _characters[playerId]!.position,
  );
  final Map<String, CharacterComponent> _characters =
      <String, CharacterComponent>{};
  final Map<GridPoint, FireComponent> _campfires = <GridPoint, FireComponent>{};

  /// What covers the game, if anything.
  final ValueNotifier<GameCover?> cover = ValueNotifier<GameCover?>(null);

  final ValueNotifier<bool> aiming = ValueNotifier<bool>(false);
  late final ValueNotifier<int> ammoLoaded;

  /// Touch controls unlocked so far by the tutorial (the arrows are always
  /// available).
  final ValueNotifier<Set<HudElement>> hud;

  /// Turns true once everything is loaded and the first frame can be drawn.
  final ValueNotifier<bool> readyToShow = ValueNotifier<bool>(false);

  /// Set by the app while Mario's opening lines play over the game.
  bool inputLocked = false;

  /// While true the game leaves the music and ambience alone: a story is
  /// playing over it (memories at a camp, the level starting over).
  bool soundscapePaused = false;

  /// Saves the progress when the player rests at a campfire.
  final Future<void> Function(GameSnapshot snapshot)? onRest;
  final Map<String, Object?>? _tutorialState;

  bool _acceptsInput = false;
  int _processedTurn = 0;
  Direction? _heldDirection;
  double _holdElapsed = 0;
  String? _focusId;
  double _gameOverCountdown = 0;
  double _entranceHoldLeft = 0;

  /// The campfire Mario is resting at (kneeling, then the camp menu).
  GridPoint? _campfire;
  double _restLeft = 0;

  /// Where Mario is drawn while a place card fades to black, if one does.
  GridPoint? _cardThreshold;

  String get playerId => simulation.playerId;

  @override
  Color backgroundColor() => PixelPalette.voidBlack;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    presentation = TurnPresentationController(world: simulation);
    tutorial = TutorialDirector(
      world: simulation,
      host: this,
      progress: progress,
    );
    final tutorialState = _tutorialState;
    if (tutorialState != null) {
      tutorial.restore(tutorialState);
    }
    await world.addAll(_places.components);
    await world.addAll(<Component>[
      for (final (index, spot) in outdoorFireSpots.indexed)
        if (spot.kind == FireKind.campfire)
          _campfires[spot.tile] = FireComponent.at(spot, seed: index)
        else
          FireComponent.at(spot, seed: index),
      FlagComponent(
        foot: Vector2(
          flagpoleTile.x * tileSize + tileSize / 2,
          flagpoleTile.y * tileSize + tileSize - 2,
        ),
      ),
      for (final pickup in simulation.pickups.values)
        PickupComponent(pickup: pickup),
      LuigiComponent(tile: luigiTile),
      ShutterComponent(bars: luigiBars, map: simulation.map),
      PanelGlintComponent(panel: mallPanelTile, world: simulation),
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

    _syncPresentation();
    _camera.snapTo(_playerFeet, _placeShown);
    _acceptsInput = true;
    readyToShow.value = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    presentation.update(dt);
    _routeNewEvents();
    _updateGameOverCountdown(dt);
    tutorial.update(dt, turnAnimating: presentation.isAnimating);
    _updateRest(dt);
    if (_entranceHoldLeft > 0) {
      _entranceHoldLeft -= dt;
    }
    _updateHeldDirection(dt);
    _syncPresentation();
    _camera.follow(
      dt,
      player: _playerFeet,
      place: _placeShown,
      focus: _characters[_focusId ?? '']?.position,
    );
    _places.cull(camera.visibleWorldRect);
    final mix = soundscape.update(
      dt,
      indoor: _placeShown.indoor,
      resting: _campfire != null && cover.value is! CampCover,
      gameOver: cover.value is GameOverCover,
    );
    if (!soundscapePaused) {
      Soundscape.apply(audio, mix);
    }
    final loaded = simulation.player.component<AmmoComponent>().loaded;
    if (ammoLoaded.value != loaded) {
      ammoLoaded.value = loaded;
    }
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
        case TeleportedEvent(:final from, :final to):
          _goThrough(from: from, to: to);
        case AlertedEvent(entityId: final spotter):
          _characters[spotter]?.playAlert();
        case ShotEvent(entityId: final shooter) when shooter == playerId:
          _characters[playerId]?.playFire(_facingOf(playerId));
        case DamagedEvent(entityId: final target, sourceEntityId: final source)
            when target == playerId:
          _characters[source]?.playBite(_facingOf(source));
        case DamagedEvent(entityId: final target, sourceEntityId: _):
          _characters[target]?.playHit(_facingOf(target));
        case DiedEvent(entityId: final victim) when victim == playerId:
          _acceptsInput = false;
          _stopMario();
          _gameOverCountdown = CharacterComponent.deathDuration + 0.45;
        case DiedEvent(entityId: final victim):
          _characters[victim]?.playDeath(_facingOf(victim));
        case _:
          break;
      }
    }
  }

  // ------------------------------------------------------------ covers

  bool get _canAct =>
      _acceptsInput &&
      !inputLocked &&
      cover.value == null &&
      _campfire == null &&
      _entranceHoldLeft <= 0;

  /// Drops the steps queued and the arrow held, and lowers the pistol.
  void _stopMario() {
    _heldDirection = null;
    _holdElapsed = 0;
    presentation.clearBuffer();
    aiming.value = false;
  }

  void _cover(GameCover what) {
    _stopMario();
    cover.value = what;
  }

  @override
  bool get isPromptVisible => cover.value != null;

  @override
  void showPrompt(List<TutorialLine> lines, {void Function()? onDismissed}) =>
      _cover(
        PromptCover(
          List<TutorialLine>.unmodifiable(lines),
          onDismissed: onDismissed,
        ),
      );

  /// Called by the dialogue overlay after the last line.
  void dismissPrompt() {
    final prompt = cover.value;
    if (prompt is PromptCover) {
      cover.value = null;
      prompt.onDismissed?.call();
    }
  }

  @override
  void playCutscene(
    List<CutsceneFrame> frames, {
    void Function()? onFinished,
  }) => _cover(
    CutsceneCover(
      List<CutsceneFrame>.unmodifiable(frames),
      onFinished: onFinished,
    ),
  );

  /// Called by the cutscene overlay once the game has faded back in.
  void finishCutscene() {
    final cutscene = cover.value;
    if (cutscene is CutsceneCover) {
      cover.value = null;
      cutscene.onFinished?.call();
    }
  }

  /// A door or a road into another place: a short fade to black (a slower
  /// one into a building, where Mario then stands still a moment), or, into
  /// a place with a card, its picture and name. Until the card's fade has
  /// gone black Mario is still drawn on the [from] threshold, so the camera
  /// keeps showing the place he is leaving.
  void _goThrough({required GridPoint from, required GridPoint to}) {
    final destination = placeAt(to);
    if (destination?.cardImage != null && destination != placeAt(from)) {
      _cardThreshold = from;
      _cover(
        PlaceCardCover(
          name: destination!.name ?? '',
          image: destination.cardImage!,
        ),
      );
      return;
    }
    final entering = destination?.indoor ?? false;
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
      _stopMario();
      _entranceHoldLeft = entranceHoldSeconds;
    }
  }

  /// Called by the card overlay once the screen is black: Mario moves to
  /// the new place behind it.
  void placeCardBlack() => _cardThreshold = null;

  /// Called by the card overlay once the new place has faded in.
  void dismissPlaceCard() {
    _cardThreshold = null;
    if (cover.value is PlaceCardCover) {
      cover.value = null;
    }
  }

  // ------------------------------------------------------------- camps

  /// Mario kneels by the fire, which roars up; when the moment is over the
  /// camp menu opens (save, start over, zombie types, memories).
  void _startRest(GridPoint campfire) {
    _stopMario();
    _campfire = campfire;
    _restLeft = CharacterComponent.restDuration;
    _campfires[campfire]?.flare();
    _characters[playerId]?.playRest(_facingOf(playerId));
  }

  void _updateRest(double dt) {
    if (_campfire == null || cover.value is CampCover) {
      return;
    }
    _restLeft -= dt;
    if (_restLeft <= 0) {
      _cover(const CampCover());
    }
  }

  /// Saves the game as it is at this campfire.
  Future<void> saveAtCamp() async {
    await onRest?.call(snapshot(place: campfireNames[_campfire] ?? ''));
  }

  /// Closes the camp menu and gives Mario back to the player.
  void leaveCamp() {
    _campfire = null;
    if (cover.value is CampCover) {
      cover.value = null;
    }
  }

  /// The whole game as it is now, ready to be saved.
  GameSnapshot snapshot({required String place}) => (
    world: saveTutorialWorld(simulation),
    tutorial: tutorial.toJson(),
    progress: progress.toJson(),
    hud: <String>[for (final element in hud.value) element.name],
    place: place,
  );

  void _updateGameOverCountdown(double dt) {
    if (_gameOverCountdown <= 0 || cover.value is GameOverCover) {
      return;
    }
    _gameOverCountdown -= dt;
    if (_gameOverCountdown <= 0) {
      cover.value = const GameOverCover();
      audio.play(Sfx.gameOver);
    }
  }

  // ------------------------------------------------------- tutorial host

  @override
  bool isTileVisible(GridPoint tile) {
    final view = camera.visibleWorldRect;
    return view.left <= tile.x * tileSize &&
        view.top <= tile.y * tileSize &&
        view.right >= (tile.x + 1) * tileSize &&
        view.bottom >= (tile.y + 1) * tileSize;
  }

  @override
  void focusOn(String? entityId) => _focusId = entityId;

  @override
  void playPickupAnimation() {
    _characters[playerId]?.playPickup(_facingOf(playerId));
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

  @override
  void unlock(HudElement element) {
    if (!hud.value.contains(element)) {
      hud.value = <HudElement>{...hud.value, element};
    }
  }

  // --------------------------------------------------------------- input

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (inputLocked || cover.value != null) {
      return KeyEventResult.ignored;
    }
    final direction = _directionFor(event.logicalKey);
    if (event is KeyUpEvent && direction != null) {
      releaseDirection(direction);
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (direction != null) {
      pressDirection(direction);
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyB) {
      pressShoot();
    } else if (key == LogicalKeyboardKey.keyE) {
      pressInteract();
    } else if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyX) {
      pressWait();
    } else if (key == LogicalKeyboardKey.keyG) {
      debugOverlay.enabled = !debugOverlay.enabled;
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
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
      if (simulation.player.component<AmmoComponent>().loaded == 0) {
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
    if (hud.value.contains(HudElement.interact)) {
      presentation.submit(const InteractAction());
    }
  }

  void pressWait() {
    if (_canAct && !aiming.value) {
      presentation.submit(const WaitAction());
    }
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

  static Direction? _directionFor(LogicalKeyboardKey key) {
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

  // ------------------------------------------------------------ drawing

  /// The backgrounds being drawn, for tests.
  @visibleForTesting
  List<String> get drawnPlaces => _places.drawn;

  Vector2 get _playerFeet => _characters[playerId]!.position;

  /// The place Mario is drawn in (it changes once the step through a door
  /// has finished playing).
  Place get _placeShown {
    final feet = _playerFeet;
    final tile = GridPoint(
      (feet.x / tileSize).floor(),
      ((feet.y - 1) / tileSize).floor(),
    );
    return placeAt(tile) ?? place(PlaceId.street);
  }

  void _syncPresentation() {
    final threshold = _cardThreshold;
    for (final entry in _characters.entries) {
      final visual =
          entry.key == playerId &&
              threshold != null &&
              !presentation.isEntityMoving(playerId)
          ? VisualPosition(threshold.x.toDouble(), threshold.y.toDouble())
          : presentation.visualPositionFor(entry.key);
      entry.value
        ..position.setValues(
          visual.x * tileSize + tileSize / 2,
          visual.y * tileSize + tileSize,
        )
        ..isMoving = presentation.isEntityMoving(entry.key)
        ..animationProgress = presentation.progress
        ..aiming = entry.key == playerId && aiming.value;
    }
  }

  Direction _facingOf(String entityId) =>
      simulation.entities[entityId]?.component<PositionComponent>().facing ??
      Direction.south;

  /// Adds [child] mid-frame; it finishes loading on its own.
  void _addWithoutWaiting(Component parent, Component child) {
    final result = parent.add(child);
    if (result is Future<void>) {
      unawaited(result);
    }
  }
}
