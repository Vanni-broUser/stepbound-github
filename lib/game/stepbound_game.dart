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
import 'package:stepbound/game/haptics/game_haptics.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/aim_line_component.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/render/debug_overlay.dart';
import 'package:stepbound/game/render/fire_component.dart';
import 'package:stepbound/game/render/flag_component.dart';
import 'package:stepbound/game/render/follow_camera.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/render/interact_glint_component.dart';
import 'package:stepbound/game/render/mall_props.dart';
import 'package:stepbound/game/render/npc_component.dart';
import 'package:stepbound/game/render/pickup_component.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/game/render/place_layers.dart';
import 'package:stepbound/game/render/screen_fade_component.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

export 'package:stepbound/game/game_cover.dart';

/// What a save stores: the simulation, the tutorial's scripts, the
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
/// place card, the books on the train, game over) is a [GameCover] the app
/// draws.
final class StepboundGame extends FlameGame
    with KeyboardEvents
    implements TutorialHost {
  /// A new game, or one resumed from a save: [world], `tutorialState` and
  /// [progress] come from `SaveGame`, [unlocked] lists the touch controls
  /// already earned. [onRest] stores the snapshot taken at a campfire, and
  /// the one taken aboard the train when the level ends.
  /// Without [audio] the game is silent.
  StepboundGame({
    int seed = 20260920,
    WorldState? world,
    this._tutorialState,
    Set<HudElement> unlocked = const <HudElement>{},
    this.onRest,
    this.onLevelCompleted,
    this.onTravelMapRequested,
    GameAudio? audio,
    GameplayHaptics? haptics,
    Progress? progress,
  }) : simulation = world ?? createTutorialWorld(seed: seed),
       progress = progress ?? Progress.newGame(),
       audio = audio ?? SilentAudio(),
       haptics = haptics ?? const GameplayHaptics(),
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

  /// How far outside the view a character is still drawn, in pixels: a
  /// sprite reaches above and beside the tile its feet stand on, and a
  /// walk animation leans into the tile it came from.
  static const double cullMargin = 3 * tileSize;
  static const double holdRepeatSeconds = 0.18;

  /// How long Mario stands still on the threshold of a building, so the
  /// place he has just walked into can sink in.
  static const double entranceHoldSeconds = 2.2;

  final WorldState simulation;

  /// The zombie types met and the story scenes seen, over the whole game.
  final Progress progress;
  final GameAudio audio;
  final GameplayHaptics haptics;
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
    useAlternateBackground: (place) =>
        place.id == PlaceId.stationFarSide &&
        progress.memories.contains(StoryMemory.luigiRescued),
  );
  final Map<String, CharacterComponent> _characters =
      <String, CharacterComponent>{};
  final Map<GridPoint, FireComponent> _campfires = <GridPoint, FireComponent>{};
  NpcComponent? _luigi;

  MallScript get _mallScript => tutorial.scripts.whereType<MallScript>().first;

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

  /// Saves the progress when the player rests at a campfire, and aboard
  /// the train when the level ends; completes with whether it was written.
  final Future<bool> Function(GameSnapshot snapshot)? onRest;

  /// Leaves gameplay for the results screen after the final cutscene.
  final void Function(GameSnapshot snapshot)? onLevelCompleted;

  /// Leaves gameplay directly for the destination map from the train.
  final void Function(GameSnapshot snapshot)? onTravelMapRequested;
  final Map<String, Object?>? _tutorialState;

  bool _acceptsInput = false;
  int _processedTurn = 0;
  Direction? _heldDirection;
  double _holdElapsed = 0;
  String? _focusId;
  double _gameOverCountdown = 0;
  double _entranceHoldLeft = 0;
  bool _levelCompleted = false;

  /// The campfire Mario is resting at (kneeling, then saving).
  GridPoint? _campfire;
  double _restLeft = 0;
  bool _restSaving = false;

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
    _syncTrainDoor();
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
      if (!_mallScript.luigiGone)
        _luigi = NpcComponent(asset: NpcComponent.luigiAsset, tile: luigiTile),
      // Don Angelo never leaves his churchyard: he is there from the start.
      NpcComponent(asset: NpcComponent.priestAsset, tile: priestTile),
      // Luigi at home in the locomotive. Nobody gets aboard before he has
      // opened the door, so he can be there all along.
      NpcComponent(asset: NpcComponent.luigiAsset, tile: trainLuigiTile),
      ShutterComponent(bars: luigiBars, map: simulation.map),
      ..._interactGlints(),
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
    _syncTrainDoor();
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
      resting: _campfire != null && cover.value == null,
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

  /// The glint on every object Mario can use, the same one the backpacks
  /// give off (they draw their own, as it rides their drop): the panel
  /// until it is pulled, the map once there is somewhere to go, and the
  /// rest once there is an interact button to press. People go without:
  /// someone standing there is reason enough to try talking to them.
  List<InteractGlintComponent> _interactGlints() {
    bool canInteract() => hud.value.contains(HudElement.interact);
    return <InteractGlintComponent>[
      InteractGlintComponent(
        tile: mallPanelTile,
        spot: const Offset(11, 6),
        active: () => simulation.controls.containsKey(mallPanelTile),
      ),
      InteractGlintComponent(
        tile: trainMapPanelTile,
        spot: const Offset(11, 6),
        active: () => progress.memories.contains(StoryMemory.luigiRescued),
      ),
      InteractGlintComponent(tile: rooftopGapTile, active: canInteract),
      // Between the two open books of the crate.
      InteractGlintComponent(
        tile: trainBookTiles.first,
        spot: const Offset(16, 6),
        active: canInteract,
      ),
      // On the middle of Mario's cot.
      InteractGlintComponent(
        tile: trainCotTiles[trainCotTiles.length ~/ 2],
        active: canInteract,
      ),
      for (final fire in campfireNames.keys)
        InteractGlintComponent(
          tile: fire,
          spot: const Offset(11, 3),
          active: canInteract,
        ),
    ];
  }

  /// Luigi carries the keys: rescuing him opens the visible passenger door
  /// and its matching tile in the same frame. Before that the train remains
  /// a solid wall even though its portal already belongs to the level.
  void _syncTrainDoor() {
    final open = progress.memories.contains(StoryMemory.luigiRescued);
    final kind = open ? TileKind.floor : TileKind.wall;
    if (simulation.map.tileAt(stationTrainDoorTile).kind != kind) {
      simulation.map.setTile(stationTrainDoorTile, Tile(kind));
    }
  }

  void _routeNewEvents() {
    if (presentation.turnCount == _processedTurn) {
      return;
    }
    _processedTurn = presentation.turnCount;
    tutorial.onEvents(presentation.lastEvents);
    haptics.onEvents(presentation.lastEvents, playerId: playerId);
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
    stopWalking();
    aiming.value = false;
  }

  void _cover(GameCover what) {
    _stopMario();
    cover.value = what;
  }

  @override
  bool get isPromptVisible => cover.value != null;

  @override
  void stopWalking() {
    _heldDirection = null;
    _holdElapsed = 0;
    presentation.clearBuffer();
  }

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
    bool stayBlack = false,
  }) => _cover(
    CutsceneCover(
      List<CutsceneFrame>.unmodifiable(frames),
      onFinished: onFinished,
      stayBlack: stayBlack,
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

  @override
  void completeLevel() {
    if (_levelCompleted) {
      return;
    }
    _levelCompleted = true;
    inputLocked = true;
    soundscapePaused = true;
    final aboard = snapshot(place: trainPlaceName);
    unawaited(onRest?.call(aboard));
    onLevelCompleted?.call(aboard);
  }

  @override
  void openTravelMap() {
    if (_levelCompleted) {
      return;
    }
    _levelCompleted = true;
    inputLocked = true;
    soundscapePaused = true;
    onTravelMapRequested?.call(snapshot(place: trainPlaceName));
  }

  @override
  void openZombieBook() => _cover(const ZombieBookCover());

  /// Called by the book once it is closed.
  void closeZombieBook() {
    if (cover.value is ZombieBookCover) {
      cover.value = null;
    }
  }

  /// The memories play with the story's sound; the game's comes back when
  /// they end.
  @override
  void replayMemories() {
    soundscapePaused = true;
    audio
      ..silenceAmbience()
      ..setMusicLevel(1)
      ..playMusic(Music.story);
    _cover(const MemoriesCover());
  }

  /// Called once the memories are over, or left.
  void closeMemories() {
    if (cover.value is MemoriesCover) {
      soundscapePaused = false;
      cover.value = null;
    }
  }

  @override
  void sendLuigiAway({void Function()? onFinished}) {
    final luigi = _luigi;
    if (luigi == null) {
      onFinished?.call();
      return;
    }
    _luigi = null;
    luigi.walkAwayThrough(luigiExitPath, onArrived: onFinished);
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
  /// game is saved, and a line says so.
  void _startRest(GridPoint campfire) {
    _stopMario();
    _campfire = campfire;
    _restLeft = CharacterComponent.restDuration;
    _restSaving = false;
    _campfires[campfire]?.flare();
    _characters[playerId]?.playRest(_facingOf(playerId));
  }

  void _updateRest(double dt) {
    if (_campfire == null || _restSaving) {
      return;
    }
    _restLeft -= dt;
    if (_restLeft <= 0) {
      _restSaving = true;
      unawaited(_saveAtCamp());
    }
  }

  static const String savedLine = 'Salvataggio completato';
  static const String saveFailedLine =
      'Salvataggio non riuscito. Riposati di nuovo accanto al fuoco per '
      'riprovare';

  /// Saves the game as it is at this campfire, then says whether it
  /// worked; Mario gets up once the line is gone either way, and a failed
  /// save is tried again by resting at the fire again.
  Future<void> _saveAtCamp() async {
    var saved = true;
    try {
      saved =
          await onRest?.call(snapshot(place: campfireNames[_campfire] ?? '')) ??
          true;
    } on Object catch (error) {
      debugPrint('save: $error');
      saved = false;
    }
    showPrompt(<TutorialLine>[
      TutorialLine(saved ? savedLine : saveFailedLine),
    ], onDismissed: () => _campfire = null);
  }

  // -------------------------------------------------------- pause menu

  /// Opens the menu from the button in the corner. Mario stops where he
  /// is, the touch controls step aside and the menu takes their place.
  /// Nothing doing while something else already covers the game, or while
  /// Mario is kneeling at a fire: the game is being saved.
  void openMenu() {
    if (cover.value != null || _campfire != null) {
      return;
    }
    _cover(const PauseCover());
  }

  /// Closes it and gives Mario back to the player.
  void closeMenu() {
    if (cover.value is PauseCover) {
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
    simulation.addEntity(zombie);
    final component = CharacterComponent(entity: zombie)..playEmerge();
    audio.play(Sfx.zombieAlert);
    _characters[zombie.id] = component;
    _addWithoutWaiting(world, component);
  }

  @override
  void killZombies(Iterable<String> zombieIds) {
    for (final id in zombieIds) {
      final zombie = simulation.entities[id];
      if (zombie == null || !zombie.isAlive) {
        continue;
      }
      zombie.component<HealthComponent>().current = 0;
      _characters[id]?.playDeath(_facingOf(id));
      audio.play(Sfx.zombieDeath, volume: 0.7);
    }
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
        presentation.submit(const ShootAction());
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
    final view = camera.visibleWorldRect.inflate(cullMargin);
    for (final entry in _characters.entries) {
      // Mario drives the camera and the followed one is what it is panning
      // to, so those two are always kept up to date.
      final followed = entry.key == playerId || entry.key == _focusId;
      if (!followed && !_isInView(view, entry.key)) {
        entry.value.onScreen = false;
        continue;
      }
      final visual =
          entry.key == playerId &&
              threshold != null &&
              !presentation.isEntityMoving(playerId)
          ? VisualPosition(threshold.x.toDouble(), threshold.y.toDouble())
          : presentation.visualPositionFor(entry.key);
      entry.value
        ..onScreen = true
        ..position.setValues(
          visual.x * tileSize + tileSize / 2,
          visual.y * tileSize + tileSize,
        )
        ..isMoving = presentation.isEntityMoving(entry.key)
        ..animationProgress = presentation.progress
        ..aiming = entry.key == playerId && aiming.value;
    }
  }

  /// Whether [entityId] stands near enough [view] to be worth drawing. It
  /// reads the tile out of the simulation rather than the animated
  /// position, which is the work being skipped.
  bool _isInView(Rect view, String entityId) {
    final tile = simulation.entities[entityId]
        ?.maybeComponent<PositionComponent>()
        ?.position;
    if (tile == null) {
      return true;
    }
    final left = tile.x * tileSize;
    final top = tile.y * tileSize;
    return left + tileSize >= view.left &&
        left <= view.right &&
        top + tileSize >= view.top &&
        top <= view.bottom;
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
