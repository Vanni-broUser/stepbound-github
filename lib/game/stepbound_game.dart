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
import 'package:stepbound/game/input/game_input_controller.dart';
import 'package:stepbound/game/levels/hometown_stage.dart';
import 'package:stepbound/game/levels/level_stage.dart';
import 'package:stepbound/game/levels/train_stage.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/aim_line_component.dart';
import 'package:stepbound/game/render/burning_ground_component.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/render/debug_overlay.dart';
import 'package:stepbound/game/render/fire_component.dart';
import 'package:stepbound/game/render/follow_camera.dart';
import 'package:stepbound/game/render/molotov_blast_component.dart';
import 'package:stepbound/game/render/offscreen_culled.dart';
import 'package:stepbound/game/render/pickup_component.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/game/render/place_layers.dart';
import 'package:stepbound/game/render/screen_fade_component.dart';
import 'package:stepbound/game/render/throw_preview_component.dart';
import 'package:stepbound/game/render/tile_place_component.dart';
import 'package:stepbound/game/render/torch_component.dart';
import 'package:stepbound/game/story/story_director.dart';

export 'package:stepbound/game/game_cover.dart';

/// What a save stores: the simulation, the story's scripts, the
/// player's progress, the unlocked controls and the name of the place.
typedef GameSnapshot = ({
  Map<String, Object?> world,
  Map<String, Object?> story,
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
    implements StoryHost {
  /// A new game, or one resumed from a save: [world], `storyState` and
  /// [progress] come from `SaveGame`, [unlocked] lists the touch controls
  /// already earned. [onRest] stores the snapshot taken at a campfire, and
  /// the one taken aboard the train when the level ends.
  /// Without [audio] the game is silent.
  StepboundGame({
    int seed = 20260920,
    WorldState? world,
    this._storyState,
    Set<HudElement> unlocked = const <HudElement>{},
    this.onRest,
    this.onLevelCompleted,
    this.onTravelMapRequested,
    this.onStoryViewed,
    GameAudio? audio,
    GameplayHaptics? haptics,
    Progress? progress,
  }) : simulation = world ?? createGameWorld(seed: seed),
       progress = progress ?? Progress.newGame(),
       audio = audio ?? SilentAudio(),
       haptics = haptics ?? const GameplayHaptics(),
       hud = ValueNotifier<Set<HudElement>>(Set<HudElement>.of(unlocked)),
       // The world fills the whole screen; FollowCamera zooms it so every
       // screen shows about as much of it.
       super(camera: CameraComponent(viewport: MaxViewport())) {
    ammoLoaded = ValueNotifier<int>(
      simulation.player.component<AmmoComponent>().loaded,
    );
    hasGun = ValueNotifier<bool>(
      simulation.player.component<AmmoComponent>().hasGun,
    );
    molotovs = ValueNotifier<int>(
      simulation.player.component<AmmoComponent>().molotovs,
    );
  }

  /// The side of a tile on screen: the level grid's own unit, shared
  /// with the baked backgrounds (lib/core/levels/place.dart).
  static const double tileSize = levelTileSize;

  /// How far outside the view a character is still drawn, in pixels: a
  /// sprite reaches above and beside the tile its feet stand on, and a
  /// walk animation leans into the tile it came from.
  static const double cullMargin = 3 * tileSize;

  /// How long Mario stands still on the threshold of a building, so the
  /// place he has just walked into can sink in.
  static const double entranceHoldSeconds = 2.2;

  final WorldState simulation;

  /// The zombie types met and the story scenes seen, over the whole game.
  final Progress progress;
  final ValueChanged<StoryMemory>? onStoryViewed;
  final GameAudio audio;
  final GameplayHaptics haptics;
  late final Soundscape soundscape = Soundscape(
    world: simulation,
    fires: outdoorFireSpots,
  );
  late final TurnPresentationController presentation;
  late final StoryDirector story;
  late final DebugWorldOverlay debugOverlay;
  late final GameInputController input = GameInputController(
    world: simulation,
    canAct: () => _canAct,
    ignoresKeys: () => inputLocked || cover.value != null,
    isUnlocked: isUnlocked,
    submit: (action) => presentation.submit(action),
    dropQueuedSteps: () => presentation.clearBuffer(),
    toggleDebug: () => debugOverlay.enabled = !debugOverlay.enabled,
    throwArea: () => placeAt(
      simulation.player.component<PositionComponent>().position,
    )?.bounds,
  );
  late final FollowCamera _camera = FollowCamera(camera);
  late final PlaceLayers _places = PlaceLayers(
    places: gamePlaces,
    playerFeet: () => _characters[playerId]!.position,
    showOpened: (place) => _stages.any((stage) => stage.showsOpened(place.id)),
    onKeptChanged: _syncProps,
  );

  /// What stands in each place kept loaded, besides its picture: its
  /// fires, torches, backpacks and burning ground. They come and go with
  /// the place (see [PlaceLayers]), so a level far from Mario costs no
  /// updates either.
  final Map<Place, List<Component>> _props = <Place, List<Component>>{};

  /// Molfetta on the stage, which its story drives.
  @override
  late final HometownStage hometown = HometownStage(this);
  late final List<LevelStage> _stages = <LevelStage>[
    TrainStage(this),
    hometown,
  ];
  final Map<String, CharacterComponent> _characters =
      <String, CharacterComponent>{};
  final Map<GridPoint, FireComponent> _campfires = <GridPoint, FireComponent>{};

  /// What covers the game, if anything.
  final ValueNotifier<GameCover?> cover = ValueNotifier<GameCover?>(null);

  late final ValueNotifier<int> ammoLoaded;

  /// Whether Mario carries the pistol itself, and not just its bullets:
  /// the ammo badge waits dimmed until the story hands the gun over.
  late final ValueNotifier<bool> hasGun;

  /// The molotovs Mario carries, for their badge.
  late final ValueNotifier<int> molotovs;

  /// Touch controls unlocked so far by the tutorial (walking is always
  /// available).
  final ValueNotifier<Set<HudElement>> hud;

  /// Turns true once everything is loaded and the first frame can be drawn.
  final ValueNotifier<bool> readyToShow = ValueNotifier<bool>(false);

  /// Set by the app while Mario's opening lines play over the game.
  bool inputLocked = false;

  /// True while two fingers are zooming the view: the touches that began
  /// as a step or an action are dropped, and nothing new starts until
  /// both have lifted.
  final ValueNotifier<bool> pinching = ValueNotifier<bool>(false);

  /// How close the view is: 1 for the whole of it, see [FollowCamera].
  double get zoom => _camera.zoom;

  /// Two fingers came down around [focus], in global coordinates.
  void beginPinch(Offset focus) {
    pinching.value = true;
    _camera.beginPinch(_viewFraction(focus));
  }

  /// The fingers are [scale] times as far apart as when they came down,
  /// now around [focus].
  void pinch(double scale, Offset focus) =>
      _camera.pinch(scale, _viewFraction(focus));

  /// Both fingers are up.
  void endPinch() {
    _camera.endPinch();
    pinching.value = false;
  }

  /// [global] as a fraction of the picture the game is drawn in.
  Offset _viewFraction(Offset global) {
    if (!isAttached || canvasSize.x == 0 || canvasSize.y == 0) {
      return const Offset(0.5, 0.5);
    }
    final local = convertGlobalToLocalCoordinate(Vector2(global.dx, global.dy));
    return Offset(local.x / canvasSize.x, local.y / canvasSize.y);
  }

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
  final Map<String, Object?>? _storyState;

  bool _acceptsInput = false;
  int _processedTurn = 0;
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
  Color backgroundColor() => PixelPalette.screenBlack;

  @override
  Future<void> onLoad() async {
    final clock = Stopwatch()..start();
    await super.onLoad();
    presentation = TurnPresentationController(world: simulation);
    story = StoryDirector(world: simulation, host: this, progress: progress);
    final storyState = _storyState;
    if (storyState != null) {
      story.restore(storyState);
    }
    for (final stage in _stages) {
      stage.restore();
    }
    // Only the area Mario is in, and what lies one door away from it, its
    // fires and backpacks with it: the rest comes in as he gets near it
    // (see the call in update).
    await _places.settle(
      placeAt(simulation.player.component<PositionComponent>().position) ??
          place(PlaceId.street),
      simulation.portals,
      world,
    );
    await world.addAll(<Component>[
      for (final stage in _stages) ...stage.build(),
    ]);
    for (final entity in simulation.entities.values) {
      final component = CharacterComponent(
        entity: entity,
        playerOutfit: progress.activeOutfit,
      );
      _characters[entity.id] = component;
      await world.add(component);
    }
    for (final stage in _stages) {
      stage.afterCharacters();
    }
    debugOverlay = DebugWorldOverlay(simulation: simulation);
    await world.addAll(<Component>[
      debugOverlay,
      AimLineComponent(
        simulation: simulation,
        aiming: input.aiming,
        hidden: () => input.throwing,
      ),
      ThrowPreviewComponent(simulation: simulation, target: input.throwTarget),
    ]);

    _syncPresentation();
    _camera.snapTo(_playerFeet, _placeShown);
    _acceptsInput = true;
    loadTime = clock.elapsed;
    readyToShow.value = true;
  }

  /// How long the game took to load, for measuring on a phone.
  Duration? loadTime;

  /// Puts in the world what stands in the places just [kept], and takes
  /// out what stood in those let go.
  void _syncProps(Set<Place> kept) {
    for (final place in _props.keys.toList()) {
      if (!kept.contains(place)) {
        for (final component in _props.remove(place)!) {
          component.removeFromParent();
        }
        _campfires.removeWhere((tile, _) => place.bounds.contains(tile));
      }
    }
    final added = <Component>[
      for (final place in kept)
        if (!_props.containsKey(place)) ...(_props[place] = _propsOf(place)),
    ];
    if (added.isNotEmpty) {
      unawaited(world.addAll(added));
    }
  }

  /// The fires, torches, backpacks and burning ground of [place]. The
  /// seeds are each fire's place in the level's list, so a fire flickers
  /// the same way whenever its place is loaded again.
  List<Component> _propsOf(Place place) {
    final bounds = place.bounds;
    final map = simulation.map;
    return <Component>[
      for (final (index, spot) in outdoorFireSpots.indexed)
        if (bounds.contains(spot.tile))
          if (spot.kind == FireKind.campfire)
            _campfires[spot.tile] = FireComponent.at(spot, seed: index)
          else
            FireComponent.at(spot, seed: index),
      for (final (index, torch)
          in gamePlaces.expand((place) => place.torches).indexed)
        if (bounds.contains(torch)) TorchComponent(tile: torch, seed: index),
      for (final pickup in simulation.pickups.values)
        if (bounds.contains(pickup.position)) PickupComponent(pickup: pickup),
      // The ground burning from the start, and any a burning zombie set
      // alight before the game was saved.
      for (var y = bounds.top; y <= bounds.bottom; y++)
        for (var x = bounds.left; x <= bounds.right; x++)
          if (map.tileAt(GridPoint(x, y)).kind == TileKind.fire)
            ...burningGround(GridPoint(x, y)),
    ];
  }

  /// Once the area Mario has walked into is composed, for the tests.
  @visibleForTesting
  Future<void> get areaSettled => _places.settling;

  /// Lets go of the pictures of every place the last game built and kept
  /// for the next: the app calls it when nothing will play for a while.
  static void releasePlacePictures() =>
      TilePlaceComponent.keepOnly(const <Place>{});

  /// Taken out of the widget tree: the places' pictures go, and whoever
  /// was listening to the game has stopped.
  @override
  void onRemove() {
    _places.release();
    input.dispose();
    for (final notifier in <ChangeNotifier>[
      cover,
      hud,
      ammoLoaded,
      hasGun,
      molotovs,
      readyToShow,
      pinching,
    ]) {
      notifier.dispose();
    }
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    presentation.update(dt);
    _routeNewEvents();
    _updateGameOverCountdown(dt);
    story.update(dt, turnAnimating: presentation.isAnimating);
    for (final stage in _stages) {
      stage.update(dt);
    }
    _updateRest(dt);
    if (_entranceHoldLeft > 0) {
      _entranceHoldLeft -= dt;
    }
    input.update(dt);
    _syncPresentation();
    _camera.follow(
      dt,
      player: _playerFeet,
      place: _placeShown,
      focus: _characters[_focusId ?? '']?.position,
    );
    _places.cull(camera.visibleWorldRect);
    _cullOffscreen();
    final shown = _placeShown;
    unawaited(_places.settle(shown, simulation.portals, world));
    final scene = cover.value;
    final mix = soundscape.update(
      dt,
      indoor: shown.indoor,
      resting: _campfire != null && scene == null,
      gameOver: scene is GameOverCover,
      theme: _musicOf(shown.id),
      scene: scene is CutsceneCover ? scene.music : null,
    );
    if (!soundscapePaused) {
      Soundscape.apply(audio, mix);
    }
    final ammo = simulation.player.component<AmmoComponent>();
    if (ammoLoaded.value != ammo.loaded) {
      ammoLoaded.value = ammo.loaded;
    }
    if (hasGun.value != ammo.hasGun) {
      hasGun.value = ammo.hasGun;
    }
    if (molotovs.value != ammo.molotovs) {
      molotovs.value = ammo.molotovs;
    }
    // The last one thrown (or the level left behind): the pistol is back.
    // Molotovs and no pistol yet: the molotov is the one weapon in hand.
    if (!input.aiming.value) {
      if (ammo.molotovs == 0 && input.weapon.value == Weapon.molotov) {
        input.weapon.value = Weapon.pistol;
      } else if (!ammo.hasGun &&
          input.weapon.value == Weapon.pistol &&
          input.hasWeapon(Weapon.molotov)) {
        input.weapon.value = Weapon.molotov;
      }
    }
  }

  /// The music of a place that has its own, if its level gives it one.
  Music? _musicOf(PlaceId place) {
    for (final stage in _stages) {
      if (stage.musicOf(place) case final music?) {
        return music;
      }
    }
    return null;
  }

  void _routeNewEvents() {
    if (presentation.turnCount == _processedTurn) {
      return;
    }
    _processedTurn = presentation.turnCount;
    story.onEvents(presentation.lastEvents);
    haptics.onEvents(presentation.lastEvents, playerId: playerId);
    for (final cue in <SfxCue>[
      ...soundscape.soundsFor(presentation.lastEvents),
      ...soundscape.idleMoans(),
    ]) {
      audio.play(cue.sfx, volume: cue.volume);
    }
    // The hits of a molotov show once the bottle has landed, not as it
    // leaves Mario's hand: they follow its event in the same turn.
    var blastDelay = 0.0;
    for (final event in presentation.lastEvents) {
      switch (event) {
        case MolotovThrownEvent(:final origin, :final target):
          _characters[playerId]?.playThrow(_facingOf(playerId));
          blastDelay =
              CharacterComponent.throwReleaseDelay +
              MolotovBlastComponent.flightSeconds;
          _later(
            CharacterComponent.throwReleaseDelay,
            () => addToWorld(
              MolotovBlastComponent(
                origin: origin,
                target: target,
                onLanded: () => audio.play(Sfx.gunshot),
              ),
            ),
          );
        case DamagedEvent(entityId: final target, sourceEntityId: final source)
            when source == playerId && blastDelay > 0:
          _later(
            blastDelay,
            () => _characters[target]?.playHit(_facingOf(target)),
          );
        case DiedEvent(entityId: final victim)
            when victim != playerId && blastDelay > 0:
          _characters[victim]?.deathPending = true;
          _later(
            blastDelay,
            () => _characters[victim]?.playDeath(_facingOf(victim)),
          );
        case CampfireUsedEvent(:final at):
          _startRest(at);
        case MovedEvent(:final entityId) when entityId == playerId:
          progress.countStep();
        case TeleportedEvent(:final from, :final to):
          _goThrough(from: from, to: to);
        case AlertedEvent(entityId: final spotter):
          _characters[spotter]?.playAlert();
        case FireStartedEvent(:final at):
          // Only in a place that is loaded: one that is not scans its
          // map for burning tiles when it comes in.
          final place = placeAt(at);
          final props = place == null ? null : _props[place];
          if (props != null) {
            final ground = burningGround(at);
            props.addAll(ground);
            unawaited(world.addAll(ground));
          }
        case ShotEvent(entityId: final shooter) when shooter == playerId:
          _characters[playerId]?.playFire(_facingOf(playerId));
        case DamagedEvent(entityId: final target, sourceEntityId: final source)
            when target == playerId:
          _characters[source]?.playBite(_facingOf(source));
        case DamagedEvent(entityId: final target, sourceEntityId: _):
          _characters[target]?.playHit(_facingOf(target));
        case DiedEvent(entityId: final victim) when victim == playerId:
          _acceptsInput = false;
          input.stop();
          _gameOverCountdown = CharacterComponent.deathDuration + 0.45;
        case DiedEvent(entityId: final victim):
          _characters[victim]?.playDeath(_facingOf(victim));
        case _:
          break;
      }
    }
  }

  /// Runs [then] [seconds] from now, on the game's own clock.
  void _later(double seconds, void Function() then) {
    unawaited(
      world.addAll(<Component>[
        TimerComponent(period: seconds, removeOnFinish: true, onTick: then),
      ]),
    );
  }

  // ------------------------------------------------------------ covers

  bool get _canAct =>
      _acceptsInput &&
      !inputLocked &&
      !_stages.any((stage) => stage.holdsMario) &&
      !story.holdsInput &&
      cover.value == null &&
      _campfire == null &&
      _entranceHoldLeft <= 0;

  void _cover(GameCover what) {
    input.stop();
    cover.value = what;
  }

  @override
  bool get isPromptVisible => cover.value != null;

  @override
  void stopWalking() => input.stopWalking();

  @override
  void showPrompt(List<StoryLine> lines, {void Function()? onDismissed}) =>
      _cover(
        PromptCover(
          List<StoryLine>.unmodifiable(lines),
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
    Set<StoryMemory> memories = const <StoryMemory>{},
    void Function()? onFinished,
    void Function()? onBlack,
    bool stayBlack = false,
    Music? music,
  }) {
    final canSkip = memories.isNotEmpty && memories.every(progress.hasViewed);
    _cover(
      CutsceneCover(
        List<CutsceneFrame>.unmodifiable(frames),
        onFinished: () {
          for (final memory in memories) {
            progress.view(memory);
            onStoryViewed?.call(memory);
          }
          onFinished?.call();
        },
        onBlack: onBlack,
        stayBlack: stayBlack,
        canSkip: canSkip,
        music: music,
      ),
    );
  }

  /// Called by the cutscene overlay once its last frame has faded to black.
  void cutsceneBlack() {
    final cutscene = cover.value;
    if (cutscene is CutsceneCover) {
      cutscene.onBlack?.call();
    }
  }

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
    final aboard = snapshot(place: trainPlaceName, confirmStory: true);
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
    // Whichever side of the table he opened it from, the trip starts, and
    // the next level with it, with Mario standing at the map.
    simulation.player.component<PositionComponent>()
      ..position = trainMapStandTile
      ..facing = trainArrivalFacing;
    onTravelMapRequested?.call(
      snapshot(place: trainPlaceName, confirmStory: true),
    );
  }

  @override
  void showEndOfDemo({void Function()? onClosed}) =>
      _cover(EndOfDemoCover(onClosed: onClosed));

  /// Called by the end-of-demo screen once it is tapped away.
  void closeEndOfDemo() {
    final end = cover.value;
    if (end is EndOfDemoCover) {
      cover.value = null;
      end.onClosed?.call();
    }
  }

  @override
  void openZombieBook() => _cover(const ZombieBookCover());

  @override
  void openAdventureStats() => _cover(const AdventureStatsCover());

  /// Called by the figures of the adventure once they are closed.
  void closeAdventureStats() {
    if (cover.value is AdventureStatsCover) {
      cover.value = null;
    }
  }

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

  /// A door or a road into another place: a short fade to black (a slower
  /// one into a building, where Mario then stands still a moment), or, into
  /// a place with a card, its picture and name. The card only announces a
  /// place reached by road: coming back out of one of its own buildings is
  /// no arrival. Until the card's fade has gone black Mario is still drawn
  /// on the [from] threshold, so the camera keeps showing the place he is
  /// leaving.
  void _goThrough({required GridPoint from, required GridPoint to}) {
    final destination = placeAt(to);
    final origin = placeAt(from);
    if (destination?.cardImage != null &&
        destination != origin &&
        !(origin?.indoor ?? false)) {
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
    fadeScreen(
      fadeIn: entering
          ? ScreenFadeComponent.slowFadeIn
          : ScreenFadeComponent.defaultFadeIn,
    );
    if (entering) {
      input.stop();
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

  /// Mario kneels by the fire, which roars up, or stops at the table
  /// aboard for a bite; when the moment is over the game is saved, and a
  /// line says so.
  void _startRest(GridPoint campfire) {
    input.stop();
    _campfire = campfire;
    if (campfireNames[campfire] case final name?
        when !trainFoodTiles.contains(campfire)) {
      progress.lightCampfire(name);
    }
    _restLeft = CharacterComponent.restDuration;
    _restSaving = false;
    if (_atTable) {
      return;
    }
    _campfires[campfire]?.flare();
    _characters[playerId]?.playRest(_facingOf(playerId));
  }

  bool get _atTable => trainFoodTiles.contains(_campfire);

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
  static const String mealSaveFailedLine =
      'Salvataggio non riuscito. Torna al tavolo per riprovare';

  /// Saves the game as it is at this campfire, then says whether it
  /// worked; Mario gets up once the line is gone either way, and a failed
  /// save is tried again by resting at the fire again.
  Future<void> _saveAtCamp() async {
    var saved = true;
    try {
      saved =
          await onRest?.call(
            snapshot(place: campfireNames[_campfire] ?? '', confirmStory: true),
          ) ??
          true;
    } on Object catch (error) {
      debugPrint('save: $error');
      saved = false;
    }
    showPrompt(<StoryLine>[
      StoryLine(
        saved
            ? savedLine
            : _atTable
            ? mealSaveFailedLine
            : saveFailedLine,
      ),
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

  @override
  void openWardrobe() => _cover(const PauseCover(wardrobe: true));

  /// Closes it and gives Mario back to the player.
  void closeMenu() {
    if (cover.value is PauseCover) {
      cover.value = null;
    }
  }

  /// Whether the game can be put down as it is and picked up again from
  /// the menu: playing, Mario alive and free to act, or the pause menu
  /// open over him. Not in the middle of a story line, a scene, a place
  /// card or a rest at a fire: the scripts' steps in between would be
  /// lost with the screen, and the game would come back stuck.
  bool get canBeSuspended {
    final scene = cover.value;
    return readyToShow.value &&
        _acceptsInput &&
        !_levelCompleted &&
        _campfire == null &&
        _cardThreshold == null &&
        !story.holdsInput &&
        !_stages.any((stage) => stage.holdsMario) &&
        (scene == null || scene is PauseCover);
  }

  /// The name of where Mario is, for the slot list: the place's own, or
  /// the level's where a place has none.
  String get placeName =>
      _placeShown.name ??
      switch (progress.level) {
        LevelId.hometown => 'Città natale',
        LevelId.rome => 'Roma',
      };

  /// The whole game as it is now, ready to be saved.
  GameSnapshot snapshot({required String place, bool confirmStory = false}) => (
    world: saveGameWorld(simulation),
    story: story.toJson(),
    progress: progress.toJson(confirmPendingMemories: confirmStory),
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

  // ---------------------------------------------------------- story host

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
    addCharacter(zombie).playEmerge();
    audio.play(Sfx.zombieAlert);
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

  @override
  void removeHud(HudElement element) {
    if (hud.value.contains(element)) {
      hud.value = <HudElement>{...hud.value.where((found) => found != element)};
    }
  }

  /// Changes every player action sheet immediately. The pause-menu wardrobe
  /// calls this only for clothes already found in the world.
  @override
  void wearOutfit(PlayerOutfit outfit) {
    if (!progress.wearOutfit(outfit)) {
      return;
    }
    _characters[playerId]?.wearOutfit(outfit);
  }

  /// Opens a small system text box naming a carried quest item.
  void inspectInventory(String name) {
    if (_canAct) {
      showPrompt(<StoryLine>[StoryLine(name)]);
    }
  }

  /// A tap on a weapon's badge. With more than one weapon it takes that
  /// one in hand; with only this one there is nothing to choose, and a
  /// small system text box tells how many rounds or bottles are left.
  void tapWeapon(Weapon weapon) {
    if (input.hasWeapon(Weapon.pistol) && input.hasWeapon(Weapon.molotov)) {
      input.selectWeapon(weapon);
      return;
    }
    final ammo = simulation.player.component<AmmoComponent>();
    inspectInventory(switch (weapon) {
      Weapon.pistol => '${ammo.loaded} proiettili',
      Weapon.molotov => '${ammo.molotovs} molotov',
    });
  }

  // --------------------------------------------------------------- input

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) => input.onKeyEvent(event);

  // ------------------------------------------------------------ drawing

  /// The backgrounds being drawn, for tests.
  @visibleForTesting
  List<String> get drawnPlaces => _places.drawn;

  /// The places whose pictures are in memory.
  @visibleForTesting
  Set<PlaceId> get loadedPlaces => _places.loaded.toSet();

  /// How long the last area took to compose, for measuring on a phone.
  Duration? get lastAreaLoad => _places.lastLoad;

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

  /// Stops drawing the fires, the torches and the burning ground the
  /// camera cannot see.
  void _cullOffscreen() {
    final view = camera.visibleWorldRect;
    for (final child in world.children) {
      if (child is OffscreenCulled) {
        child.onScreen = child.reach.overlaps(view);
      }
    }
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
        ..aimingPose = entry.key != playerId || !input.aiming.value
            ? null
            : input.throwing
            ? PlayerPoseFamily.throwable
            : PlayerPoseFamily.oneHanded
        ..aimingWeapon = entry.key == playerId && input.throwing
            ? PlayerWeaponSprite.molotov
            : null;
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

  /// Draws [entity], come into the simulation mid-game.
  CharacterComponent addCharacter(Entity entity) {
    final component = CharacterComponent(entity: entity);
    _characters[entity.id] = component;
    addToWorld(component);
    return component;
  }

  /// Adds [component] to the world mid-frame; it finishes loading on its
  /// own.
  void addToWorld(Component component) => _addWithoutWaiting(world, component);

  /// Fades the screen to black and back in over [fadeIn] seconds, calling
  /// [onBlack] while it is black.
  void fadeScreen({
    required double fadeIn,
    void Function()? onBlack,
    void Function()? onFinished,
  }) => _addWithoutWaiting(
    camera.viewport,
    ScreenFadeComponent(
      size: camera.viewport.size.clone(),
      fadeIn: fadeIn,
      onBlack: onBlack,
      onFinished: onFinished,
    ),
  );

  void _addWithoutWaiting(Component parent, Component child) {
    final result = parent.add(child);
    if (result is Future<void>) {
      unawaited(result);
    }
  }
}
