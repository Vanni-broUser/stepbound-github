import 'dart:async';

import 'package:flame/camera.dart';
import 'package:flame/components.dart' hide PositionComponent;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/anim/turn_presentation_controller.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/audio/soundscape.dart';
import 'package:stepbound/game/campfire_rest.dart';
import 'package:stepbound/game/cover_controller.dart';
import 'package:stepbound/game/game_cover.dart';
import 'package:stepbound/game/game_snapshot.dart';
import 'package:stepbound/game/haptics/game_haptics.dart';
import 'package:stepbound/game/input/game_input_controller.dart';
import 'package:stepbound/game/input/mission_board.dart';
import 'package:stepbound/game/level_restart.dart';
import 'package:stepbound/game/levels/hometown_stage.dart';
import 'package:stepbound/game/levels/level_stage.dart';
import 'package:stepbound/game/levels/rome_stage.dart';
import 'package:stepbound/game/levels/train_stage.dart';
import 'package:stepbound/game/place_transition_controller.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/put_down_copy.dart';
import 'package:stepbound/game/render/aim_line_component.dart';
import 'package:stepbound/game/render/burning_ground_component.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/render/debug_overlay.dart';
import 'package:stepbound/game/render/depth_sorted_world.dart';
import 'package:stepbound/game/render/fire_component.dart';
import 'package:stepbound/game/render/follow_camera.dart';
import 'package:stepbound/game/render/grapple_component.dart';
import 'package:stepbound/game/render/molotov_blast_component.dart';
import 'package:stepbound/game/render/npc_component.dart';
import 'package:stepbound/game/render/offscreen_culled.dart';
import 'package:stepbound/game/render/pickup_component.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/game/render/place_layers.dart';
import 'package:stepbound/game/render/rocket_component.dart';
import 'package:stepbound/game/render/screen_fade_component.dart';
import 'package:stepbound/game/render/throw_preview_component.dart';
import 'package:stepbound/game/render/tile_place_component.dart';
import 'package:stepbound/game/render/torch_component.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/world_event_presenter.dart';
import 'package:stepbound/l10n/language.dart';

export 'package:stepbound/game/game_cover.dart';
export 'package:stepbound/game/game_snapshot.dart';
export 'package:stepbound/game/world_event_presenter.dart' show CharacterCue;

/// The game: the simulation, drawn and animated, played with the keyboard
/// or the touch controls. Whatever covers it (a text box, a story scene, a
/// place card, the books on the train, game over) is a [GameCover] the app
/// draws, put up and taken down by a [CoverController]. The turn's events
/// are presented by a [WorldEventPresenter], for which the game is the
/// [EventStage]; the way from place to place is a
/// [PlaceTransitionController]'s; the rest at a fire, with its save, a
/// [CampfireRest]'s.
final class StepboundGame extends FlameGame
    with KeyboardEvents
    implements StoryHost, EventStage {
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
       super(
         camera: CameraComponent(viewport: MaxViewport()),
         world: DepthSortedWorld(),
       ) {
    ammoLoaded = ValueNotifier<int>(
      simulation.player.component<AmmoComponent>().loaded,
    );
    hasGun = ValueNotifier<bool>(
      simulation.player.component<AmmoComponent>().hasGun,
    );
    molotovs = ValueNotifier<int>(
      simulation.player.component<AmmoComponent>().molotovs,
    );
    rockets = ValueNotifier<int>(
      simulation.player.component<AmmoComponent>().rockets,
    );
    hasRocketLauncher = ValueNotifier<bool>(
      simulation.player.component<AmmoComponent>().hasRocketLauncher,
    );
    // Where the missions stand as the game is made, not as the corner
    // first catches up: whatever the story does before that is news.
    _missionsSeen = this.progress.missions.revision;
    _doneSeen = this.progress.missions.done.length;
  }

  /// The side of a tile on screen: the level grid's own unit, shared
  /// with the baked backgrounds (lib/core/levels/place.dart).
  static const double tileSize = levelTileSize;

  /// How far outside the view a character is still drawn, in pixels: a
  /// sprite reaches above and beside the tile its feet stand on, and a
  /// walk animation leans into the tile it came from.
  static const double cullMargin = 3 * tileSize;

  /// How long Mario stands still on the threshold of a building (see
  /// [PlaceTransitionController]).
  static const double entranceHoldSeconds =
      PlaceTransitionController.entranceHoldSeconds;

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
    goldenPistol: () => progress.hasGoldenPistol,
  );
  late final FollowCamera _camera = FollowCamera(camera);
  late final CoverController _covers = CoverController(
    onShow: () => input.stop(),
    progress: progress,
    onStoryViewed: onStoryViewed,
  );
  late final PlaceTransitionController _transitions = PlaceTransitionController(
    cover: _covers.cover,
    show: _covers.show,
    fadeScreen: fadeScreen,
    stopInput: input.stop,
  );
  late final CampfireRest _camp = CampfireRest(
    progress: progress,
    covers: _covers,
    checkpoint: (place) =>
        _storeCheckpoint(snapshot(place: place, confirmStory: true)),
    onKneel: (campfire) {
      _campfires[campfire]?.flare();
      _characters[playerId]?.playRest(_facingOf(playerId));
    },
    placeName: () => placeName,
  );
  final PutDownCopy _putDownCopy = PutDownCopy();

  /// What the turn's events become on the stage; made once the story is,
  /// in [onLoad].
  late final WorldEventPresenter _events;
  late final PlaceLayers _places = PlaceLayers(
    places: gamePlaces,
    playerFeet: () => _characters[playerId]!.position,
    showOpened: (place) => _stages.any((stage) => stage.showsOpened(place.id)),
    shutRows: (place) =>
        _stages.map((stage) => stage.shutRows(place.id)).nonNulls.firstOrNull,
    onKeptChanged: _syncProps,
    beacons: () => <GridPoint>[
      for (final id in beaconPickupIds)
        if (simulation.pickups[id] case final pickup? when pickup.active)
          pickup.position,
    ],
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
    RomeStage(this),
  ];
  final Map<String, CharacterComponent> _characters =
      <String, CharacterComponent>{};
  final Map<GridPoint, FireComponent> _campfires = <GridPoint, FireComponent>{};

  /// What covers the game, if anything.
  ValueNotifier<GameCover?> get cover => _covers.cover;

  late final ValueNotifier<int> ammoLoaded;

  /// Whether Mario carries the pistol itself, and not just its bullets:
  /// the ammo badge waits dimmed until the story hands the gun over.
  late final ValueNotifier<bool> hasGun;

  /// The molotovs Mario carries, for their badge.
  late final ValueNotifier<int> molotovs;

  /// The rounds for the rocket launcher Mario carries, for its badge.
  late final ValueNotifier<int> rockets;

  /// Whether Mario has the rocket launcher itself: until then its badge
  /// waits dimmed, as the pistol's does.
  late final ValueNotifier<bool> hasRocketLauncher;

  /// Goes off whenever which weapons Mario could take in hand may have
  /// changed, or which one he holds: the weapons' badges follow it.
  late final Listenable weaponsCarried = Listenable.merge(<Listenable>[
    input.weapon,
    hasGun,
    molotovs,
    rockets,
    hasRocketLauncher,
  ]);

  /// Touch controls unlocked so far by the tutorial (walking is always
  /// available).
  final ValueNotifier<Set<HudElement>> hud;

  /// Turns true once everything is loaded and the first frame can be drawn.
  final ValueNotifier<bool> readyToShow = ValueNotifier<bool>(false);

  /// Set by the app while Mario's opening lines play over the game.
  bool inputLocked = false;

  /// Whether the player has the game: nothing said or about to be, no
  /// story holding Mario, no rest at a fire. What he carries and what he
  /// has to do are only shown then.
  final ValueNotifier<bool> freeToMove = ValueNotifier<bool>(false);

  /// The missions in the corner: the open ones of the level being played,
  /// in the order they were handed out, and those just done until their
  /// row has been crossed out (see [missionCrossedOut]).
  late final ValueNotifier<List<BoardMission>> missions =
      ValueNotifier<List<BoardMission>>(<BoardMission>[
        for (final mission in progress.missions.open)
          if (mission.level == progress.level) (mission: mission, done: false),
      ]);
  late int _missionsSeen;

  /// How many missions were done when the corner last caught up: those
  /// done since, handed out and done in the same breath, are new to it.
  late int _doneSeen;

  /// How long the corner still has, while Mario is free, to cross out the
  /// missions just done (see [missionsSettling]). Counted here rather than
  /// by the corner, so that no scene ever waits on a corner not drawn.
  double _crossOutLeft = 0;

  /// The corner fading back in after a scene, before it starts crossing.
  static const double _crossOutLead = 0.4;

  /// The missions the corner has shown in this game. The corner goes
  /// while something is said and comes back after: only a mission it has
  /// never shown fades in, the others are just there, like the rest of
  /// the controls. Those open when the game is loaded count as shown.
  late final Set<Mission> _missionsShown = <Mission>{
    for (final row in missions.value) row.mission,
  };

  /// Whether the corner is showing [mission] for the first time: true
  /// once, then false.
  bool showsMissionFirst(Mission mission) => _missionsShown.add(mission);

  /// The corner has crossed [mission] out: its row goes.
  void missionCrossedOut(Mission mission) {
    final rows = missions.value;
    if (rows.any((row) => row.mission == mission && row.done)) {
      missions.value = <BoardMission>[
        for (final row in rows)
          if (row.mission != mission || !row.done) row,
      ];
    }
  }

  @override
  bool get missionsSettling =>
      _crossOutLeft > 0 && missions.value.any((row) => row.done);

  /// Brings the corner up to the missions the story has just handed out or
  /// seen done. One handed out and done in the same breath, because Mario
  /// had already seen to it (Luigi's shutter lifted before his scene, the
  /// incense in hand when Don Angelo asks for it), still shows, crossed
  /// out.
  void _syncMissions() {
    final log = progress.missions;
    if (log.revision == _missionsSeen) {
      return;
    }
    _missionsSeen = log.revision;
    final justDone = log.done.skip(_doneSeen).toList();
    _doneSeen = log.done.length;
    final rows = missions.value;
    bool shown(Mission mission) => rows.any((row) => row.mission == mission);
    final synced = <BoardMission>[
      for (final row in rows)
        if (log.isOpen(row.mission))
          (mission: row.mission, done: false)
        else if (log.isDone(row.mission))
          (mission: row.mission, done: true),
      for (final mission in justDone)
        if (mission.level == progress.level && !shown(mission))
          (mission: mission, done: true),
      for (final mission in log.open)
        if (mission.level == progress.level && !shown(mission))
          (mission: mission, done: false),
    ];
    if (!listEquals(synced, rows)) {
      bool crossing(BoardMission row) => row.done;
      if (synced.where(crossing).length > rows.where(crossing).length) {
        _crossOutLeft =
            MissionBoard.crossOut.inMicroseconds /
                Duration.microsecondsPerSecond +
            _crossOutLead;
      }
      missions.value = synced;
    }
  }

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

  /// Leaves gameplay for the results screen after the final cutscene,
  /// once the train's save is written; `saved` is false when it could
  /// not be, and the results say so.
  final void Function(GameSnapshot snapshot, {required bool saved})?
  onLevelCompleted;

  /// Leaves gameplay directly for the destination map from the train.
  final void Function(GameSnapshot snapshot)? onTravelMapRequested;
  final Map<String, Object?>? _storyState;

  bool _acceptsInput = false;
  double _gameOverCountdown = 0;
  bool _levelCompleted = false;

  /// True while Mario takes a step the story makes him take.
  bool _storyStep = false;

  @override
  String get playerId => simulation.playerId;

  @override
  Color backgroundColor() => PixelPalette.screenBlack;

  @override
  Future<void> onLoad() async {
    final clock = Stopwatch()..start();
    await super.onLoad();
    presentation = TurnPresentationController(world: simulation)
      ..holdsBack = _readBeforeSwinging;
    story = StoryDirector(world: simulation, host: this, progress: progress);
    _events = WorldEventPresenter(
      stage: this,
      audio: audio,
      soundscape: soundscape,
      haptics: haptics,
      progress: progress,
      onStoryEvents: story.onEvents,
    );
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
        throughEntities: () => input.weapon.value == Weapon.rocketLauncher,
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
    _covers.dispose();
    for (final notifier in <ChangeNotifier>[
      hud,
      ammoLoaded,
      hasGun,
      molotovs,
      rockets,
      hasRocketLauncher,
      readyToShow,
      pinching,
      freeToMove,
      missions,
    ]) {
      notifier.dispose();
    }
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    presentation.update(dt);
    if (_storyStep && !presentation.isAnimating) {
      _storyStep = false;
    }
    _events.present(presentation.turnCount, presentation.lastEvents);
    _updateGameOverCountdown(dt);
    // What a scene just over did to the missions, before the story looks
    // at whether the corner has something to cross out.
    _syncMissions();
    story.update(dt, turnAnimating: presentation.isAnimating);
    for (final stage in _stages) {
      stage.update(dt);
    }
    _camp.update(dt);
    _putDownCopy.keep(
      dt,
      canBePutDown: canBeSuspended,
      take: () => snapshot(place: placeName),
    );
    _transitions.update(dt);
    input.update(dt);
    _syncPresentation();
    _syncMissions();
    final free =
        _acceptsInput &&
        !inputLocked &&
        !_levelCompleted &&
        !_storyStep &&
        !_stages.any((stage) => stage.holdsMario) &&
        story.isIdle &&
        !_camp.resting;
    if (freeToMove.value != free) {
      freeToMove.value = free;
    }
    if (free && _crossOutLeft > 0) {
      _crossOutLeft -= dt;
    }
    _camera.follow(player: _playerFeet, place: _placeShown, dt: dt);
    _places.cull(camera.visibleWorldRect);
    _cullOffscreen();
    final shown = _placeShown;
    unawaited(_places.settle(shown, simulation.portals, world));
    final scene = cover.value;
    final mix = soundscape.update(
      dt,
      indoor: shown.indoor,
      resting: _camp.resting && scene == null,
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
    if (rockets.value != ammo.rockets) {
      rockets.value = ammo.rockets;
    }
    if (hasRocketLauncher.value != ammo.hasRocketLauncher) {
      hasRocketLauncher.value = ammo.hasRocketLauncher;
    }
    // What is in hand and gone (the last molotov thrown, the last rocket
    // fired, the level left behind): the first weapon he has is back, the
    // pistol first of all. Molotovs and no pistol yet: the molotov is the
    // one weapon in hand.
    if (!input.aiming.value && !input.hasWeapon(input.weapon.value)) {
      input.weapon.value = input.weaponsCarried.firstOrNull ?? Weapon.pistol;
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

  // -------------------------------------------------------- event stage

  @override
  void play(String entityId, CharacterCue cue) {
    final character = _characters[entityId];
    if (character == null) {
      return;
    }
    final facing = _facingOf(entityId);
    switch (cue) {
      case CharacterCue.fire:
        character.playFire(facing);
      case CharacterCue.fireRocket:
        character.playFire(facing, weapon: PlayerWeaponSprite.rocketLauncher);
      case CharacterCue.throwWeapon:
        character.playThrow(facing);
      case CharacterCue.throwGrapple:
        character.playThrow(facing, thrown: PlayerWeaponSprite.grapplingHook);
      case CharacterCue.hit:
        character.playHit(facing);
      case CharacterCue.bite:
        character.playBite(facing);
      case CharacterCue.death:
        character.playDeath(facing);
      case CharacterCue.alert:
        character.playAlert();
    }
  }

  /// Runs [then] [seconds] from now, on the game's own clock.
  @override
  void later(double seconds, void Function() then) {
    unawaited(
      world.addAll(<Component>[
        TimerComponent(period: seconds, removeOnFinish: true, onTick: then),
      ]),
    );
  }

  @override
  void launchMolotov({
    required GridPoint origin,
    required GridPoint target,
    required void Function() onLanded,
  }) => addToWorld(
    MolotovBlastComponent(
      origin: origin,
      target: target,
      onLanded: onLanded,
      burns: (tile) =>
          simulation.map.contains(tile) &&
          simulation.map.tileAt(tile).isWalkable,
    ),
  );

  @override
  void launchRocket({
    required GridPoint origin,
    required GridPoint impact,
    required Direction direction,
    required void Function() onImpact,
  }) => addToWorld(
    RocketComponent(
      origin: origin,
      impact: impact,
      direction: direction,
      onImpact: onImpact,
    ),
  );

  @override
  void goThrough({required GridPoint from, required GridPoint to}) =>
      _transitions.goThrough(from: from, to: to);

  @override
  void grapple({
    required GridPoint from,
    required GridPoint anchor,
    required GridPoint to,
  }) => addToWorld(
    GrappleComponent(
      from: from,
      anchor: anchor,
      mario: () => _characters[playerId]!.position,
    ),
  );

  /// Only in a place that is loaded: one that is not scans its map for
  /// burning tiles when it comes in.
  @override
  void groundCaughtFire(GridPoint at) {
    final place = placeAt(at);
    final props = place == null ? null : _props[place];
    if (props != null) {
      final ground = burningGround(at);
      props.addAll(ground);
      unawaited(world.addAll(ground));
    }
  }

  @override
  void playerDied() {
    // Dead is not a state to pick up again, nor is the moment before it:
    // the way back is the game over's.
    _putDownCopy.drop();
    _acceptsInput = false;
    input.stop();
    _gameOverCountdown = CharacterComponent.deathDuration + 0.45;
  }

  // ------------------------------------------------------------ covers

  bool get _canAct =>
      _acceptsInput &&
      !inputLocked &&
      !_storyStep &&
      !_stages.any((stage) => stage.holdsMario) &&
      !story.holdsInput &&
      !_covers.isCovered &&
      !_camp.resting &&
      !_transitions.holdsMario;

  /// A swing with the grappling hook is said before it is played: the
  /// line first, and Mario sets off, the hook thrown, its sound with it,
  /// the moment it is dismissed.
  bool _readBeforeSwinging(PlayerAction action) {
    if (action is! InteractAction ||
        InteractAction.swingAhead(simulation) == null) {
      return false;
    }
    input.stop();
    showPrompt(<StoryLine>[
      StoryLine(RooftopsScript.grappleLine),
    ], onDismissed: () => presentation.play(action));
    return true;
  }

  @override
  bool get inPlay => _acceptsInput && !inputLocked;

  @override
  bool get isPromptVisible => _covers.isCovered;

  @override
  void stopWalking() => input.stopWalking();

  @override
  void showPrompt(List<StoryLine> lines, {void Function()? onDismissed}) {
    _turnSpeakersToMario(lines.map((line) => line.speaker));
    _covers.showPrompt(lines, onDismissed: onDismissed);
  }

  /// Whoever speaks in the lines about to show turns to Mario, the way
  /// anyone spoken to would: of the people of the stage with a speaker's
  /// name, the one nearest him, so that of two cultists only the one at
  /// his side answers. Mario's own lines, and voices from out of sight,
  /// turn nobody.
  void _turnSpeakersToMario(Iterable<String?> speakers) {
    final mario = simulation.player.component<PositionComponent>().position;
    for (final speaker in speakers.nonNulls.toSet()) {
      NpcComponent? nearest;
      var nearestDistance = 0;
      for (final npc in world.children.whereType<NpcComponent>()) {
        if (npc.name != speaker) {
          continue;
        }
        final tile = npc.tile;
        final distance = (tile.x - mario.x).abs() + (tile.y - mario.y).abs();
        if (nearest == null || distance < nearestDistance) {
          nearest = npc;
          nearestDistance = distance;
        }
      }
      nearest?.turnTowards(mario);
    }
  }

  /// Called by the dialogue overlay after the last line.
  void dismissPrompt() => _covers.dismissPrompt();

  @override
  void playCutscene(
    List<CutsceneFrame> frames, {
    Set<StoryMemory> memories = const <StoryMemory>{},
    void Function()? onFinished,
    void Function()? onBlack,
    bool stayBlack = false,
    Music? music,
  }) {
    _turnSpeakersToMario(frames.map((frame) => frame.speaker));
    _covers.playCutscene(
      frames,
      memories: memories,
      onFinished: onFinished,
      onBlack: onBlack,
      stayBlack: stayBlack,
      music: music,
    );
  }

  /// Called by the cutscene overlay once its last frame has faded to black.
  void cutsceneBlack() => _covers.cutsceneBlack();

  /// Called by the cutscene overlay once the game has faded back in.
  void finishCutscene() => _covers.finishCutscene();

  @override
  void completeLevel() {
    if (_levelCompleted) {
      return;
    }
    _levelCompleted = true;
    inputLocked = true;
    soundscapePaused = true;
    // The scene ended on black: it stays so while the train's save is
    // written, the results coming straight out of it.
    _covers.endLevel();
    // Molfetta started over is done again: what the other cities gave
    // Mario was waiting aboard.
    handBackHeldAway(progress, simulation, unlock);
    final aboard = snapshot(place: trainPlaceName, confirmStory: true);
    unawaited(_finishLevel(aboard));
  }

  /// Saves the game aboard the train, then hands the level's end over:
  /// the results come after the save, and know whether it was written.
  Future<void> _finishLevel(GameSnapshot aboard) async {
    var saved = true;
    try {
      saved = await _storeCheckpoint(aboard) ?? true;
    } on Object catch (error) {
      debugPrint('save: $error');
      saved = false;
    }
    onLevelCompleted?.call(aboard, saved: saved);
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
  void showWorkInProgress({void Function()? onClosed}) =>
      _covers.showWorkInProgress(onClosed: onClosed);

  /// Called by the work-in-progress screen once it is tapped away.
  void closeWorkInProgress() => _covers.closeWorkInProgress();

  @override
  void endWithNoWayOut(String reason) {
    input.stopWalking();
    _covers.gameOver(reason: reason);
    audio.play(Sfx.gameOver);
  }

  @override
  void openZombieBook() => _covers.openZombieBook();

  @override
  void openAdventureStats() => _covers.openAdventureStats();

  /// Called by the figures of the adventure once they are closed.
  void closeAdventureStats() => _covers.closeAdventureStats();

  /// Called by the book once it is closed.
  void closeZombieBook() => _covers.closeZombieBook();

  /// The memories of [level], played from the figures of the adventure
  /// with the story's sound; the game's comes back when they end.
  void replayMemories(LevelId level) {
    soundscapePaused = true;
    audio
      ..silenceAmbience()
      ..setMusicLevel(1)
      ..playMusic(Music.story);
    _covers.showMemories(level);
  }

  /// Called once the memories are over, or left: back to the figures of
  /// the city they were played from.
  void closeMemories() {
    if (_covers.closeMemories()) {
      soundscapePaused = false;
    }
  }

  /// Called by the card overlay once the screen is black: Mario moves to
  /// the new place behind it.
  void placeCardBlack() => _transitions.cardBlack();

  /// Called by the card overlay once the new place has faded in.
  void dismissPlaceCard() => _transitions.dismissCard();

  // ------------------------------------------------------------- camps

  /// Mario has used a fire, or the table aboard (see [CampfireRest]).
  @override
  void restAt(GridPoint campfire) {
    input.stop();
    _camp.restAt(campfire);
  }

  static String get savedLine => CampfireRest.savedLine;
  static String get saveFailedLine => CampfireRest.saveFailedLine;
  static String get mealSaveFailedLine => CampfireRest.mealSaveFailedLine;

  /// Called by the notice of a failed save once the player goes on.
  void dismissSaveFailed() => _covers.dismissSaveFailed();

  // -------------------------------------------------------- pause menu

  /// Opens the menu from the button in the corner. Mario stops where he
  /// is, the touch controls step aside and the menu takes their place.
  /// Nothing doing while something else already covers the game, or while
  /// Mario is kneeling at a fire: the game is being saved.
  void openMenu() {
    if (!_camp.resting) {
      _covers.openMenu();
    }
  }

  @override
  void openWardrobe() => _covers.openWardrobe();

  /// Closes it and gives Mario back to the player.
  void closeMenu() => _covers.closeMenu();

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
        !_camp.resting &&
        !_transitions.inTransit &&
        // A bottle or a rocket in the air: spent, and its burst not
        // played yet.
        !presentation.holdsProjectile &&
        !story.holdsInput &&
        !_stages.any((stage) => stage.holdsMario) &&
        (scene == null || scene is PauseCover);
  }

  /// How often, while the game can be put down, a copy of it is kept for
  /// when the app leaves at a moment it cannot (see [PutDownCopy]).
  static const double putDownCopyInterval = PutDownCopy.defaultInterval;

  /// What to write when the app leaves: the game as it is when it can be
  /// put down, or else the copy of the last moment it could, a few steps
  /// back (a story line, a place card, a scene is on); null when there is
  /// none, such as once Mario is dead or a fire's save is newer.
  GameSnapshot? get putDownSnapshot => _putDownCopy.snapshot(
    canBePutDown: canBeSuspended,
    take: () => snapshot(place: placeName),
  );

  /// A save of the slot's own, at a fire or aboard the train: whatever was
  /// copied before it is older, and never written over it.
  Future<bool>? _storeCheckpoint(GameSnapshot checkpoint) {
    _putDownCopy.drop();
    return onRest?.call(checkpoint);
  }

  /// The name of where Mario is, for the slot list: the place's own, or
  /// the level's where a place has none.
  @override
  String get placeName =>
      _placeShown.name ??
      switch (progress.level) {
        LevelId.hometown => 'Città natale',
        LevelId.rome => 'Roma',
      };

  /// The whole game as it is now, ready to be saved.
  GameSnapshot snapshot({required String place, bool confirmStory = false}) => (
    world: saveGameWorld(simulation),
    // Not loaded yet, the story is still what the game was given.
    story: isLoaded ? story.toJson() : <String, Object?>{...?_storyState},
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
      _covers.gameOver();
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
  void showWholeView() => _camera.showWholeView();

  @override
  void playPickupAnimation() {
    _characters[playerId]?.playPickup(_facingOf(playerId));
  }

  @override
  void walkPlayer(Direction direction) {
    input.stop();
    presentation
      ..clearBuffer()
      ..submit(MoveAction(direction));
    _storyStep = presentation.isAnimating;
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
    if (input.hasWeaponChoice) {
      input.selectWeapon(weapon);
      return;
    }
    final ammo = simulation.player.component<AmmoComponent>();
    inspectInventory(switch (weapon) {
      Weapon.pistol => strings.bulletsLeft(ammo.loaded),
      Weapon.molotov => strings.molotovsLeft(ammo.molotovs),
      Weapon.rocketLauncher => strings.rocketsLeft(ammo.rockets),
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
  Place get _placeShown => _transitions.placeShown(_playerFeet);

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
    final threshold = _transitions.drawnAt(
      playerMoving: presentation.isEntityMoving(playerId),
    );
    final view = camera.visibleWorldRect.inflate(cullMargin);
    for (final entry in _characters.entries) {
      // Mario drives the camera, so he is always kept up to date.
      if (entry.key != playerId && !_isInView(view, entry.key)) {
        entry.value.onScreen = false;
        continue;
      }
      final visual = entry.key == playerId && threshold != null
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
        ..aimingWeapon = entry.key != playerId || !input.aiming.value
            ? null
            : input.throwing
            ? PlayerWeaponSprite.molotov
            : input.weapon.value == Weapon.rocketLauncher
            ? PlayerWeaponSprite.rocketLauncher
            : null
        ..goldenPistol = entry.key == playerId && progress.hasGoldenPistol;
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
