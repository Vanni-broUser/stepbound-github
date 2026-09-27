import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/input/touch_controls.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/blood_splat.dart';
import 'package:stepbound/ui/diagnostics_overlay.dart';
import 'package:stepbound/ui/game_cutscene.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';
import 'package:stepbound/ui/letterbox.dart';
import 'package:stepbound/ui/level_complete.dart';
import 'package:stepbound/ui/level_map.dart';
import 'package:stepbound/ui/loading_art.dart';
import 'package:stepbound/ui/location_card.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/pause_menu.dart';
import 'package:stepbound/ui/rome_placeholder.dart';
import 'package:stepbound/ui/screen_wide_layer.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'package:stepbound/ui/zombie_book.dart';

/// The main menu first; a new game then plays the story scenes and the
/// protagonist's line before the controls appear, while a loaded game goes
/// straight to playing.
enum _Phase {
  menu,
  story,
  outbreak,
  dialogue,
  playing,
  levelComplete,
  levelMap,
  romeStory,
}

final class StepboundApp extends StatefulWidget {
  const StepboundApp({this.saves, this.audio, super.key});

  /// Where the four save slots live; the device storage when null.
  final SaveRepository? saves;

  /// The sound of the game; silent when null.
  final GameAudio? audio;

  @override
  State<StepboundApp> createState() => _StepboundAppState();
}

final class _StepboundAppState extends State<StepboundApp> {
  late final SaveRepository _saves =
      widget.saves ?? PreferencesSaveRepository();
  late final GameAudio _audio = widget.audio ?? SilentAudio();

  /// Silences the game whenever it is not the app in front.
  late final AppLifecycleListener _lifecycle;
  StepboundGame? _game;
  _Phase _phase = _Phase.menu;
  GameSnapshot? _completedSnapshot;
  late LevelStats _levelStats;

  /// Whether the loading picture fades in from the black a story ended on.
  bool _loadingFadesIn = false;

  /// Where the level being played starts over from, when it is not the
  /// first story scene: see [SaveGame.levelStart].
  LevelStart? _levelStart;

  /// The slot this game saves into at campfires and on the train.
  int _slot = 1;

  /// Where the current slot's save was made: a campfire or the train. Only
  /// with one is there anywhere to go back to, so only then do the menus
  /// offer it. The slot written when the level starts over does not count.
  ResumePoint? _resumePoint;

  /// What this game had been played for when it was loaded or started, and
  /// the clock running since. Together they are what a save records: it
  /// only runs while the game is in front and out of the menu, so a phone
  /// in a pocket is not play, and nothing between two saves is kept.
  Duration _playedBefore = Duration.zero;
  final Stopwatch _clock = Stopwatch();
  final Set<StoryMemory> _storyHistory = <StoryMemory>{};
  Future<void> _storyHistoryWrite = Future<void>.value();

  Duration get _played => _playedBefore + _clock.elapsed;

  /// Starts this game's clock over from [played].
  void _startClock(Duration played) {
    _playedBefore = played;
    _clock
      ..reset()
      ..start();
  }

  @override
  void initState() {
    super.initState();
    // Only `resumed` means the player is looking at the game. Android
    // goes inactive, then hidden, then paused on the way out, and a
    // call or the app switcher stops at inactive: all of them silence
    // it, or the game over sting plays on over whatever comes next, and
    // all of them stop the clock.
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _audio.playMusic(Music.menu);
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _audio.resume();
      if (_phase != _Phase.menu) {
        _clock.start();
      }
      _putDown = false;
      return;
    }
    _audio.pause();
    _clock.stop();
    // Once on the way out, whatever the steps: Android may kill the app
    // in the background, and everything since the last fire would go.
    if (!_putDown) {
      _putDown = true;
      unawaited(_suspend());
    }
  }

  /// Whether the game has been written down since the app left the front.
  bool _putDown = false;

  /// Writes the game as it is beside the slot's save, to be picked up from
  /// the menu; the campfire's save stays the one to go back to. Only while
  /// playing, and only in a state the game can come back to (see
  /// [StepboundGame.canBeSuspended]): otherwise the slot keeps what it had.
  Future<void> _suspend() async {
    final game = _game;
    if (game == null || _phase != _Phase.playing || !game.canBeSuspended) {
      return;
    }
    final snapshot = game.snapshot(place: game.placeName);
    try {
      await _saves.suspend(
        SaveGame(
          slot: _slot,
          savedAt: DateTime.now(),
          place: snapshot.place,
          world: snapshot.world,
          story: snapshot.story,
          progress: snapshot.progress,
          hud: snapshot.hud,
          atCampfire: false,
          played: _played,
          levelStart: _levelStart,
        ),
      );
    } on SaveWriteException catch (error) {
      debugPrint('save: $error');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decoded up front, so the loading picture is there at once.
    for (final image in <String>[
      LoadingArt.image,
      LevelMap.hometownImage,
      LevelMap.romeImage,
      RomePlaceholder.image,
      MainMenu.logo,
    ]) {
      unawaited(precacheImage(AssetImage(image), context));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _newGame(int slot) async {
    await _storyHistoryWrite;
    try {
      await _saves.clear(slot);
    } on Object catch (error) {
      // The old game stays in the slot until the first campfire writes
      // over it: no reason to keep the new one from starting.
      debugPrint('save: could not clear slot $slot ($error)');
    }
    if (!mounted) {
      return;
    }
    _playStoryAudio();
    _startClock(Duration.zero);
    setState(() {
      _slot = slot;
      _storyHistory.clear();
      _resumePoint = null;
      _levelStart = null;
      _completedSnapshot = null;
      _phase = _Phase.story;
    });
  }

  Future<void> _loadGame(SaveGame save) async {
    final history = await _saves.loadStoryHistory(save.slot);
    // A game put down is picked up as it was, but the fire to go back to
    // is still the slot's own save.
    final checkpoint = await _saves.load(save.slot) ?? save;
    if (!mounted) {
      return;
    }
    final progress = Progress.fromJson(save.progress);
    _storyHistory
      ..clear()
      ..addAll(history)
      ..addAll(progress.memories);
    _startClock(save.played);
    _loadingFadesIn = false;
    setState(() {
      _slot = save.slot;
      _resumePoint = _resumePointOf(checkpoint);
      _levelStart = save.levelStart;
      _game = _gameFrom(save, progress: progress);
      _phase = _Phase.playing;
    });
  }

  StepboundGame _gameFrom(SaveGame save, {Progress? progress}) => _gameOf(
    world: save.world,
    story: save.story,
    progress: progress ?? Progress.fromJson(save.progress),
    hud: save.hud,
  );

  StepboundGame _gameOf({
    required Map<String, Object?> world,
    required Map<String, Object?> story,
    required Progress progress,
    required List<String> hud,
  }) {
    progress.addViewedMemories(_storyHistory);
    return StepboundGame(
      world: restoreGameWorld(world),
      storyState: story,
      progress: progress,
      unlocked: <HudElement>{
        for (final name in hud)
          for (final element in HudElement.values)
            if (element.name == name) element,
      },
      onRest: _store,
      onLevelCompleted: _completeLevel,
      onTravelMapRequested: _travelFromTrain,
      onStoryViewed: _rememberStory,
      audio: _audio,
    );
  }

  static ResumePoint? _resumePointOf(SaveGame save) => !save.atCampfire
      ? null
      : save.place == trainPlaceName
      ? ResumePoint.train
      : ResumePoint.campfire;

  /// Called by the game when Mario rests at a campfire, and when the level
  /// ends with him aboard the train. False when the save could not be
  /// written: the slot still holds the one before, and so does
  /// [_resumePoint].
  Future<bool> _store(GameSnapshot snapshot) async {
    final game = _game;
    try {
      await _saves.save(
        SaveGame(
          slot: _slot,
          savedAt: DateTime.now(),
          place: snapshot.place,
          world: snapshot.world,
          story: snapshot.story,
          progress: snapshot.progress,
          hud: snapshot.hud,
          played: _played,
          levelStart: _levelStart,
        ),
      );
    } on SaveWriteException catch (error) {
      debugPrint('save: $error');
      return false;
    }
    _resumePoint = snapshot.place == trainPlaceName
        ? ResumePoint.train
        : ResumePoint.campfire;
    game?.progress.confirmPendingMemories();
    return true;
  }

  void _finishIntro() {
    setState(() => _phase = _Phase.outbreak);
  }

  void _finishOutbreak() {
    _rememberStories(const <StoryMemory>{
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
    });
    final progress = Progress.newGame(openingSaved: false)
      ..addViewedMemories(_storyHistory);
    setState(() {
      _phase = _Phase.dialogue;
      _game = StepboundGame(
        onRest: _store,
        onLevelCompleted: _completeLevel,
        onTravelMapRequested: _travelFromTrain,
        onStoryViewed: _rememberStory,
        progress: progress,
        audio: _audio,
      )..inputLocked = true;
    });
  }

  void _finishDialogue() {
    setState(() {
      _phase = _Phase.playing;
      _game?.inputLocked = false;
    });
  }

  /// Back to the last campfire or to the train, from the menu or after
  /// dying. Only offered while there is a [_resumePoint]; if the slot has
  /// gone missing anyway, the level starts over rather than leaving the
  /// player stuck.
  Future<void> _resumeFromCamp() async {
    final save = await _saves.load(_slot);
    final history = await _saves.loadStoryHistory(_slot);
    // Going back to the fire is giving up whatever was put down since.
    try {
      await _saves.clearSuspended(_slot);
    } on Object catch (error) {
      debugPrint('save: could not drop the game put down ($error)');
    }
    if (!mounted) {
      return;
    }
    if (save == null) {
      await _restartLevel();
      return;
    }
    _startClock(save.played);
    _loadingFadesIn = false;
    _storyHistory.addAll(history);
    setState(() {
      _levelStart = save.levelStart;
      _game = _gameFrom(save);
      _phase = _Phase.playing;
    });
  }

  /// The level from the very start, the first story picture, with nothing
  /// kept but the hours played (bullets, known zombies, memories all go).
  /// It counts as a save: the slot now holds the start of the level, so
  /// loading it later starts the level over too — but not a campfire one,
  /// so there is nothing to resume from until the next fire.
  Future<void> _restartLevel() async {
    if (_levelStart case final start?) {
      await _restartFrom(start);
      return;
    }
    // The camp's fire and hushed music stop at once: the story plays.
    _game?.soundscapePaused = true;
    _playStoryAudio();
    var saved = true;
    try {
      await _saves.save(
        SaveGame(
          slot: _slot,
          savedAt: DateTime.now(),
          place: levelStartPlace,
          world: saveGameWorld(createGameWorld()),
          story: const <String, Object?>{},
          progress: Progress().toJson(),
          hud: const <String>[],
          atCampfire: false,
          // The hours played are the one thing starting over keeps.
          played: _played,
        ),
      );
    } on SaveWriteException catch (error) {
      // The level starts over all the same; the slot keeps the save it
      // had, and with it the fire to go back to.
      debugPrint('save: $error');
      saved = false;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (saved) {
        _resumePoint = null;
      }
      _game = null;
      _phase = _Phase.story;
    });
  }

  /// A level other than Molfetta starts over where Mario arrived in it,
  /// with what he had then. Like the story's restart it counts as a save,
  /// not a campfire one.
  Future<void> _restartFrom(LevelStart start) async {
    var saved = true;
    try {
      await _saves.save(
        SaveGame(
          slot: _slot,
          savedAt: DateTime.now(),
          place: levelStartPlace,
          world: start.world,
          story: start.story,
          progress: start.progress,
          hud: start.hud,
          atCampfire: false,
          played: _played,
          levelStart: start,
        ),
      );
    } on SaveWriteException catch (error) {
      debugPrint('save: $error');
      saved = false;
    }
    if (!mounted) {
      return;
    }
    _loadingFadesIn = false;
    setState(() {
      if (saved) {
        _resumePoint = null;
      }
      _game = _gameOf(
        world: start.world,
        story: start.story,
        progress: Progress.fromJson(start.progress),
        hud: start.hud,
      );
      _phase = _Phase.playing;
    });
  }

  /// The story's music at full volume, no ambience.
  void _playStoryAudio() {
    _audio
      ..silenceAmbience()
      ..setMusicLevel(1)
      ..playMusic(Music.story);
  }

  bool get _openingStorySeen =>
      _storyHistory.contains(StoryMemory.newsBroadcast) &&
      _storyHistory.contains(StoryMemory.outbreakNight);

  void _rememberStory(StoryMemory memory) =>
      _rememberStories(<StoryMemory>{memory});

  void _rememberStories(Set<StoryMemory> memories) {
    if (memories.every(_storyHistory.contains)) {
      return;
    }
    _storyHistory.addAll(memories);
    final copy = Set<StoryMemory>.of(_storyHistory);
    final slot = _slot;
    _storyHistoryWrite = _storyHistoryWrite.then(
      (_) => _saves.saveStoryHistory(slot, copy),
    );
  }

  /// What is drawn over the game for [cover]: the touch controls when
  /// nothing covers it.
  Widget _coverOf(StepboundGame game, GameCover? cover) => switch (cover) {
    null => TouchControls(game: game),
    PromptCover(:final lines) => GameplayDialogue(
      // A fresh state for every prompt restarts it from its first line.
      key: ObjectKey(cover),
      lines: <DialogueLine>[
        for (final line in lines)
          DialogueLine(
            speaker: line.speaker,
            text: line.text,
            portrait: line.speaker == 'Mario Rossi'
                ? game.progress.activeOutfit.portrait
                : line.portrait,
            demo: line.demo,
          ),
      ],
      onFinished: game.dismissPrompt,
    ),
    CutsceneCover(:final frames, :final canSkip) => GameCutscene(
      key: ObjectKey(cover),
      frames: frames,
      stayBlack: cover.stayBlack,
      canSkip: canSkip,
      onBlack: game.cutsceneBlack,
      onFinished: game.finishCutscene,
    ),
    PlaceCardCover(:final name, :final image) => LocationCard(
      key: ObjectKey(cover),
      name: name,
      image: image,
      onBlack: game.placeCardBlack,
      onFinished: game.dismissPlaceCard,
    ),
    AdventureStatsCover() => Letterbox(
      color: AdventureStats.backdrop,
      child: AdventureStats(
        world: game.simulation,
        progress: game.progress,
        onClose: game.closeAdventureStats,
      ),
    ),
    ZombieBookCover() => Letterbox(
      color: ZombieBook.backdrop,
      child: ZombieBook(progress: game.progress, onClose: game.closeZombieBook),
    ),
    MemoriesCover() => Letterbox(
      color: Colors.black,
      child: StoryIntro(
        key: const ValueKey<String>('train-memories-story'),
        scenes: seenScenes(game.progress, game.progress.level),
        allowBackNavigation: true,
        // Each memory with the music it was lived with, the rest with the
        // story's.
        onScene: (scene) => _audio.playMusic(scene.music ?? Music.story),
        onFinished: game.closeMemories,
        onExit: game.closeMemories,
      ),
    ),
    EndOfDemoCover() => Letterbox(
      color: Colors.black,
      child: RomePlaceholder(
        key: ObjectKey(cover),
        onBack: game.closeEndOfDemo,
      ),
    ),
    PauseCover(:final wardrobe) => PauseMenu(
      progress: game.progress,
      wardrobe: wardrobe,
      resumePoint: _resumePoint,
      restartsFromStory: _levelStart == null,
      onResumeFromCamp: () => unawaited(_resumeFromCamp()),
      onRestartLevel: () => unawaited(_restartLevel()),
      onMainMenu: _backToMenu,
      onClose: game.closeMenu,
      onWearOutfit: game.wearOutfit,
    ),
    GameOverCover() => Letterbox(
      color: _GameOverOverlay.backdrop,
      child: _GameOverOverlay(
        resumePoint: _resumePoint,
        restartsFromStory: _levelStart == null,
        onResumeFromCamp: () {
          _audio.stop(Sfx.gameOver);
          unawaited(_resumeFromCamp());
        },
        onRestartLevel: () {
          _audio.stop(Sfx.gameOver);
          unawaited(_restartLevel());
        },
        onMenu: () {
          _audio.stop(Sfx.gameOver);
          _backToMenu();
        },
      ),
    ),
  };

  /// What a save made by starting the level over is called in the slots.
  static const String levelStartPlace = 'Inizio del livello';

  void _completeLevel(GameSnapshot snapshot) {
    final world = restoreGameWorld(snapshot.world);
    final progress = Progress.fromJson(snapshot.progress);
    final stats = LevelStats.of(world, progress, progress.level);
    _playStoryAudio();
    StepboundGame.releasePlacePictures();
    setState(() {
      _completedSnapshot = snapshot;
      _levelStats = stats;
      _game = null;
      _phase = _Phase.levelComplete;
    });
  }

  void _openLevelMap() => setState(() => _phase = _Phase.levelMap);

  void _travelFromTrain(GameSnapshot snapshot) {
    _playStoryAudio();
    StepboundGame.releasePlacePictures();
    setState(() {
      _completedSnapshot = snapshot;
      _game = null;
      _phase = _Phase.levelMap;
    });
  }

  /// The train takes Mario and Luigi to [level]: the game picks up aboard,
  /// with the train's door onto that level's station, and is saved there.
  /// Mario's rounds and molotovs stay in the level he leaves (see
  /// [Progress.travel] and [Progress.swapMolotovs]).
  /// Rome starts over from here.
  void _startLevel(LevelId level) {
    final snapshot = _completedSnapshot;
    if (snapshot == null) {
      return;
    }
    final progress = Progress.fromJson(snapshot.progress);
    final world = restoreGameWorld(snapshot.world);
    final ammo = world.player.component<AmmoComponent>();
    ammo
      ..molotovs = progress.swapMolotovs(level, molotovs: ammo.molotovs)
      ..loaded = progress.travel(level, rounds: ammo.loaded);
    // At the map, but turned away from it: a stray tap on arrival does
    // not open it again.
    world.player.component<PositionComponent>()
      ..position = trainMapStandTile
      ..facing = trainArrivalFacing;
    if (level == LevelId.rome) {
      progress.remember(StoryMemory.presidentFled);
    }
    final arrival = (
      world: saveGameWorld(world),
      story: snapshot.story,
      progress: progress.toJson(),
      hud: snapshot.hud,
      place: trainPlaceName,
    );
    _levelStart = level == LevelId.hometown
        ? null
        : LevelStart(
            world: arrival.world,
            story: arrival.story,
            progress: arrival.progress,
            hud: arrival.hud,
          );
    unawaited(_store(arrival));
    setState(() {
      _game = _gameOf(
        world: arrival.world,
        story: arrival.story,
        progress: progress,
        hud: arrival.hud,
      );
      _phase = _Phase.playing;
    });
  }

  void _startHometown() {
    _loadingFadesIn = false;
    _startLevel(LevelId.hometown);
  }

  /// The first time, Rome's story plays before the city loads.
  void _startRome() {
    final snapshot = _completedSnapshot;
    if (snapshot == null) {
      return;
    }
    final seen = Progress.fromJson(
      snapshot.progress,
    ).memories.contains(StoryMemory.presidentFled);
    if (seen) {
      _loadingFadesIn = false;
      _startLevel(LevelId.rome);
      return;
    }
    setState(() => _phase = _Phase.romeStory);
  }

  void _finishRomeStory() {
    _rememberStory(StoryMemory.presidentFled);
    _loadingFadesIn = true;
    _startLevel(LevelId.rome);
  }

  /// From the pause menu or the game over screen. A game left from its
  /// menu is put down like one sent to the background: the slot offers it
  /// again as it was. The pictures of its places, kept for a game
  /// started over at once, go: the menu can stay open a long while.
  void _backToMenu() {
    unawaited(_suspend());
    _audio
      ..silenceAmbience()
      ..playMusic(Music.menu);
    StepboundGame.releasePlacePictures();
    setState(() {
      _game = null;
      _completedSnapshot = null;
      _phase = _Phase.menu;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return MaterialApp(
      title: 'Stepbound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: PixelPalette.screenBlack,
      ),
      // Browsers only start sound after a tap: the first one lets it play.
      home: Listener(
        onPointerDown: (_) => _audio.unlock(),
        child: AudioScope(
          audio: _audio,
          child: BloodSplatLayer(child: _surface(game)),
        ),
      ),
    );
  }

  Widget _surface(StepboundGame? game) {
    return ColoredBox(
      key: const ValueKey<String>('stepbound-game-surface'),
      color: PixelPalette.screenBlack,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = IntegerResolutionViewport.scaleFor(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          if (game != null &&
              (_phase == _Phase.dialogue || _phase == _Phase.playing)) {
            return _playing(
              game,
              Size(
                IntegerResolutionViewport.virtualWidth * scale,
                IntegerResolutionViewport.virtualHeight * scale,
              ),
            );
          }
          final picture = Center(
            child: SizedBox(
              width: IntegerResolutionViewport.virtualWidth * scale,
              height: IntegerResolutionViewport.virtualHeight * scale,
              child: switch (_phase) {
                _Phase.menu => MainMenu(
                  saves: _saves,
                  onNewGame: (slot) => unawaited(_newGame(slot)),
                  onLoad: (save) => unawaited(_loadGame(save)),
                ),
                _Phase.story => StoryIntro(
                  onFinished: _finishIntro,
                  onSkip: _openingStorySeen ? _finishOutbreak : null,
                ),
                _Phase.outbreak => StoryIntro(
                  key: const ValueKey<String>('outbreak-story'),
                  scenes: outbreakScenes,
                  fadeOutAtEnd: true,
                  onFinished: _finishOutbreak,
                  onSkip: _openingStorySeen ? _finishOutbreak : null,
                ),
                _Phase.levelComplete => LevelComplete(
                  stats: _levelStats,
                  onContinue: _openLevelMap,
                ),
                _Phase.levelMap => LevelMap(
                  onStartHometown: _startHometown,
                  onStartRome: _startRome,
                ),
                _Phase.romeStory => StoryIntro(
                  key: const ValueKey<String>('rome-story'),
                  scenes: romeScenes,
                  fadeOutAtEnd: true,
                  onFinished: _finishRomeStory,
                  onSkip: _storyHistory.contains(StoryMemory.presidentFled)
                      ? _finishRomeStory
                      : null,
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          );
          // The menu's picture spreads over the bands too.
          if (_phase == _Phase.menu) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[const MenuBackdrop(), picture],
            );
          }
          return picture;
        },
      ),
    );
  }

  /// The loading picture of the level the game is in: Rome's, and once
  /// Molfetta is behind them (Mario reached the train with Luigi) the
  /// harbour's, each with the level's name; before that the zombie one.
  Widget _levelLoadingCover(StepboundGame game, Size picture) {
    final progress = game.progress;
    final (image, caption) = switch (progress.level) {
      LevelId.rome => (LevelMap.romeImage, 'Roma'),
      LevelId.hometown when progress.hometownCompleted => (
        LevelMap.hometownImage,
        'Città natale',
      ),
      LevelId.hometown => (LoadingArt.image, 'Caricamento della partita'),
    };
    return LoadingCover(
      key: ObjectKey(game),
      ready: game.readyToShow,
      artSize: picture,
      fadeIn: _loadingFadesIn,
      image: image,
      caption: caption,
    );
  }

  /// The world fills the whole screen (see ScreenFillingViewport). The
  /// controls and the dialogue box spread as wide as it, as tall as the
  /// 16:9 picture; the pause menu stays on the picture, over the world, and
  /// every other cover lays its picture out itself, with its backdrop
  /// across the bands (see [Letterbox]).
  Widget _playing(StepboundGame game, Size picture) {
    Widget onPicture(Widget child) => Center(
      child: SizedBox.fromSize(size: picture, child: child),
    );
    Widget screenWide(Widget child) =>
        ScreenWideLayer(pictureHeight: picture.height, child: child);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GameWidget<StepboundGame>(
          key: const ValueKey<String>('stepbound-game'),
          game: game,
        ),
        if (_phase == _Phase.dialogue) ...<Widget>[
          // Mario speaks once the game behind him is there, so no line goes
          // by unseen under the loading picture.
          ValueListenableBuilder<bool>(
            valueListenable: game.readyToShow,
            builder: (context, ready, _) => ready
                ? screenWide(
                    SafeArea(
                      child: GameplayDialogue(onFinished: _finishDialogue),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const BlackFade(
            key: ValueKey<String>('gameplay-fade-in'),
            toBlack: false,
          ),
        ] else
          // Whatever covers the game, or else the controls.
          ValueListenableBuilder<GameCover?>(
            valueListenable: game.cover,
            builder: (context, cover, _) => switch (cover) {
              null => screenWide(_coverOf(game, cover)),
              PromptCover() => screenWide(
                SafeArea(child: _coverOf(game, cover)),
              ),
              PauseCover() => onPicture(_coverOf(game, cover)),
              _ => _coverOf(game, cover),
            },
          ),
        if (diagnosticsEnabled) DiagnosticsOverlay(game: game),
        // The loading picture instead of a black screen while the maps and
        // sprites load, over the bands too so no button shows beside it.
        if (_phase == _Phase.dialogue)
          LoadingCover(
            key: ObjectKey(game),
            ready: game.readyToShow,
            artSize: picture,
            // A new game comes out of the story's fade to black.
            fadeIn: true,
            caption: 'Caricamento del tutorial',
          )
        else
          _levelLoadingCover(game, picture),
      ],
    );
  }
}

final class _GameOverOverlay extends StatefulWidget {
  const _GameOverOverlay({
    required this.resumePoint,
    required this.restartsFromStory,
    required this.onResumeFromCamp,
    required this.onRestartLevel,
    required this.onMenu,
  });

  /// Where the save to go back to was made, if there is one. With one it
  /// is the first choice and the one the countdown takes, and starting the
  /// level over is offered under it; without one the level from the start
  /// is the only way on.
  final ResumePoint? resumePoint;

  /// Whether the level starts over from the first story scene (Molfetta),
  /// or from where Mario arrived in it.
  final bool restartsFromStory;
  final VoidCallback onResumeFromCamp;
  final VoidCallback onRestartLevel;
  final VoidCallback onMenu;

  /// Dims the whole screen, the world still in view behind it.
  static const Color backdrop = Color(0xc2180e0c);

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

final class _GameOverOverlayState extends State<_GameOverOverlay> {
  static const autoRestartSeconds = 60;
  Timer? _timer;
  int _secondsLeft = autoRestartSeconds;

  /// Starting the level over from here throws the save away, so it asks
  /// first, as the menus do.
  bool _confirmingRestart = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsLeft -= 1;
      });
      if (_secondsLeft <= 0) {
        timer.cancel();
        _takeCountdownChoice();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// What the countdown runs out into: the save when there is one, the
  /// level from the start when there is not.
  void _takeCountdownChoice() {
    if (widget.resumePoint != null) {
      widget.onResumeFromCamp();
      return;
    }
    widget.onRestartLevel();
  }

  /// The player has chosen: the clock stops either way.
  void _tapped(VoidCallback action) {
    _timer?.cancel();
    _timer = null;
    AudioScope.of(context).play(Sfx.uiClick);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1.0;
        return KeyedSubtree(
          key: const ValueKey<String>('game-over-overlay'),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Grows with the view, like the dialogue text.
                  BloodyTitle('GAME OVER', fontSize: 34 * unit),
                  SizedBox(height: 4 * unit),
                  ...(_confirmingRestart ? _confirm(unit) : _choices(unit)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _choices(double unit) => <Widget>[
    _primary(
      key: const ValueKey<String>('restart-button'),
      label: switch (widget.resumePoint) {
        final point? => '${point.resumeLabel} ($_secondsLeft)',
        null => 'RICOMINCIA IL LIVELLO ($_secondsLeft)',
      },
      onPressed: () => _tapped(_takeCountdownChoice),
    ),
    if (widget.resumePoint != null) ...<Widget>[
      SizedBox(height: 6 * unit),
      _secondary(
        key: const ValueKey<String>('game-over-restart'),
        label: 'RICOMINCIA IL LIVELLO',
        onPressed: () =>
            _tapped(() => setState(() => _confirmingRestart = true)),
      ),
    ],
    SizedBox(height: 6 * unit),
    _secondary(
      key: const ValueKey<String>('menu-button'),
      label: 'MENÙ PRINCIPALE',
      onPressed: () => _tapped(widget.onMenu),
    ),
  ];

  List<Widget> _confirm(double unit) => <Widget>[
    MenuPanel(
      unit: unit,
      width: MenuButton.fullWidth,
      child: MenuParagraph(
        widget.restartsFromStory
            ? 'Ricominciare il livello? ${widget.resumePoint!.savedHere} '
                  'va perso: si riparte dalla prima scena della storia, e '
                  'restano solo le ore di gioco.'
            : 'Ricominciare il livello? ${widget.resumePoint!.savedHere} '
                  'va perso: si riparte dall’arrivo in città, con quello '
                  'che avevi allora.',
        key: const ValueKey<String>('game-over-cost'),
        unit: unit,
        center: true,
      ),
    ),
    SizedBox(height: 5 * unit),
    MenuButton(
      key: const ValueKey<String>('game-over-restart-confirm'),
      label: 'SÌ, RICOMINCIA',
      unit: unit,
      compact: true,
      warning: true,
      onPressed: widget.onRestartLevel,
    ),
    SizedBox(height: 3 * unit),
    MenuButton(
      key: const ValueKey<String>('game-over-restart-cancel'),
      label: 'NO',
      unit: unit,
      compact: true,
      onPressed: () => setState(() => _confirmingRestart = false),
    ),
  ];

  Widget _primary({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) => TextButton(
    key: key,
    style: TextButton.styleFrom(
      backgroundColor: const Color(0xdd4a2823),
      foregroundColor: const Color(0xffe4705f),
      side: const BorderSide(color: Color(0xffe4705f), width: 2),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
    ),
    onPressed: onPressed,
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _secondary({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) => TextButton(
    key: key,
    style: TextButton.styleFrom(foregroundColor: const Color(0xffd8cfbf)),
    onPressed: onPressed,
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
