import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/input/touch_controls.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/blood_splat.dart';
import 'package:stepbound/ui/game_cutscene.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';
import 'package:stepbound/ui/level_complete.dart';
import 'package:stepbound/ui/level_map.dart';
import 'package:stepbound/ui/loading_art.dart';
import 'package:stepbound/ui/location_card.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/pause_menu.dart';
import 'package:stepbound/ui/rome_placeholder.dart';
import 'package:stepbound/ui/screen_wide_layer.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'package:stepbound/ui/title_splash.dart';
import 'package:stepbound/ui/zombie_book.dart';

/// The main menu first; a new game then plays the story scenes, the title
/// card and the protagonist's line before the controls appear, while a
/// loaded game goes straight to playing.
enum _Phase {
  menu,
  story,
  title,
  outbreak,
  dialogue,
  playing,
  levelComplete,
  levelMap,
  romePlaceholder,
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
  int _foundBackpacks = 0;
  int _totalBackpacks = 0;
  int _foundMemoryImages = 0;
  int _totalMemoryImages = 0;
  String _gameLoadingCaption = 'Caricamento della partita';

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
      return;
    }
    _audio.pause();
    _clock.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decoded up front, so the loading picture is there at once.
    for (final image in <String>[LoadingArt.image, MainMenu.logo]) {
      unawaited(precacheImage(AssetImage(image), context));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _newGame(int slot) async {
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
      _resumePoint = null;
      _completedSnapshot = null;
      _phase = _Phase.story;
    });
  }

  void _loadGame(SaveGame save) {
    _startClock(save.played);
    _gameLoadingCaption = 'Caricamento della partita';
    setState(() {
      _slot = save.slot;
      _resumePoint = _resumePointOf(save);
      _game = _gameFrom(save);
      _phase = _Phase.playing;
    });
  }

  StepboundGame _gameFrom(SaveGame save) => StepboundGame(
    world: restoreTutorialWorld(save.world),
    tutorialState: save.tutorial,
    progress: Progress.fromJson(save.progress),
    unlocked: <HudElement>{
      for (final name in save.hud)
        for (final element in HudElement.values)
          if (element.name == name) element,
    },
    onRest: _store,
    onLevelCompleted: _completeLevel,
    onTravelMapRequested: _travelFromTrain,
    audio: _audio,
  );

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
    try {
      await _saves.save(
        SaveGame(
          slot: _slot,
          savedAt: DateTime.now(),
          place: snapshot.place,
          world: snapshot.world,
          tutorial: snapshot.tutorial,
          progress: snapshot.progress,
          hud: snapshot.hud,
          played: _played,
        ),
      );
    } on SaveWriteException catch (error) {
      debugPrint('save: $error');
      return false;
    }
    _resumePoint = snapshot.place == trainPlaceName
        ? ResumePoint.train
        : ResumePoint.campfire;
    return true;
  }

  void _finishIntro() {
    setState(() => _phase = _Phase.title);
  }

  void _finishTitle() {
    setState(() => _phase = _Phase.outbreak);
  }

  void _finishOutbreak() {
    setState(() {
      _phase = _Phase.dialogue;
      _game = StepboundGame(
        onRest: _store,
        onLevelCompleted: _completeLevel,
        onTravelMapRequested: _travelFromTrain,
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
    if (!mounted) {
      return;
    }
    if (save == null) {
      await _restartLevel();
      return;
    }
    _startClock(save.played);
    _gameLoadingCaption = 'Caricamento della partita';
    setState(() {
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
          world: saveTutorialWorld(createTutorialWorld()),
          tutorial: const <String, Object?>{},
          progress: Progress.newGame().toJson(),
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

  /// The story's music at full volume, no ambience.
  void _playStoryAudio() {
    _audio
      ..silenceAmbience()
      ..setMusicLevel(1)
      ..playMusic(Music.story);
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
          ),
      ],
      onFinished: game.dismissPrompt,
    ),
    CutsceneCover(:final frames) => GameCutscene(
      key: ObjectKey(cover),
      frames: frames,
      stayBlack: cover.stayBlack,
      onFinished: game.finishCutscene,
    ),
    PlaceCardCover(:final name, :final image) => LocationCard(
      key: ObjectKey(cover),
      name: name,
      image: image,
      onBlack: game.placeCardBlack,
      onFinished: game.dismissPlaceCard,
    ),
    ZombieBookCover() => ZombieBook(
      progress: game.progress,
      onClose: game.closeZombieBook,
    ),
    MemoriesCover() => StoryIntro(
      key: const ValueKey<String>('train-memories-story'),
      scenes: seenScenes(game.progress),
      onFinished: game.closeMemories,
      onExit: game.closeMemories,
    ),
    PauseCover() => PauseMenu(
      progress: game.progress,
      resumePoint: _resumePoint,
      onResumeFromCamp: () => unawaited(_resumeFromCamp()),
      onRestartLevel: () => unawaited(_restartLevel()),
      onMainMenu: _backToMenu,
      onClose: game.closeMenu,
      onWearOutfit: game.wearOutfit,
    ),
    GameOverCover() => _GameOverOverlay(
      resumePoint: _resumePoint,
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
  };

  /// What a save made by starting the level over is called in the slots.
  static const String levelStartPlace = 'Inizio del livello';

  void _completeLevel(GameSnapshot snapshot) {
    final world = restoreTutorialWorld(snapshot.world);
    final progress = Progress.fromJson(snapshot.progress);
    Set<String> pictures(Iterable<StoryMemory> memories) => <String>{
      for (final memory in memories)
        for (final scene in memoryScenes[memory] ?? const <StoryScene>[])
          scene.image,
    };
    _playStoryAudio();
    setState(() {
      _completedSnapshot = snapshot;
      _foundBackpacks = world.pickups.values
          .where((pickup) => pickup.collected)
          .length;
      _totalBackpacks = world.pickups.length;
      _foundMemoryImages = pictures(progress.memories).length;
      _totalMemoryImages = pictures(StoryMemory.values).length;
      _game = null;
      _phase = _Phase.levelComplete;
    });
  }

  void _openLevelMap() => setState(() => _phase = _Phase.levelMap);

  void _travelFromTrain(GameSnapshot snapshot) {
    _playStoryAudio();
    setState(() {
      _completedSnapshot = snapshot;
      _game = null;
      _phase = _Phase.levelMap;
    });
  }

  void _startHometown() {
    final snapshot = _completedSnapshot;
    if (snapshot == null) {
      return;
    }
    _gameLoadingCaption = 'Caricamento di Città Natale';
    setState(() {
      _game = StepboundGame(
        world: restoreTutorialWorld(snapshot.world),
        tutorialState: snapshot.tutorial,
        progress: Progress.fromJson(snapshot.progress),
        unlocked: <HudElement>{
          for (final name in snapshot.hud)
            for (final element in HudElement.values)
              if (element.name == name) element,
        },
        onRest: _store,
        onLevelCompleted: _completeLevel,
        onTravelMapRequested: _travelFromTrain,
        audio: _audio,
      );
      _phase = _Phase.playing;
    });
  }

  void _startRome() => setState(() => _phase = _Phase.romePlaceholder);

  void _backToMenu() {
    _audio
      ..silenceAmbience()
      ..playMusic(Music.menu);
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
        scaffoldBackgroundColor: const Color(0xff111718),
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
      color: const Color(0xff111718),
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
          return Center(
            child: SizedBox(
              width: IntegerResolutionViewport.virtualWidth * scale,
              height: IntegerResolutionViewport.virtualHeight * scale,
              child: switch (_phase) {
                _Phase.menu => MainMenu(
                  saves: _saves,
                  onNewGame: (slot) => unawaited(_newGame(slot)),
                  onLoad: _loadGame,
                ),
                _Phase.story => StoryIntro(onFinished: _finishIntro),
                _Phase.title => TitleSplash(onFinished: _finishTitle),
                _Phase.outbreak => StoryIntro(
                  key: const ValueKey<String>('outbreak-story'),
                  scenes: outbreakScenes,
                  fadeOutAtEnd: true,
                  onFinished: _finishOutbreak,
                ),
                _Phase.levelComplete => LevelComplete(
                  foundBackpacks: _foundBackpacks,
                  totalBackpacks: _totalBackpacks,
                  foundMemories: _foundMemoryImages,
                  totalMemories: _totalMemoryImages,
                  onContinue: _openLevelMap,
                ),
                _Phase.levelMap => LevelMap(
                  onStartHometown: _startHometown,
                  onStartRome: _startRome,
                ),
                _Phase.romePlaceholder => RomePlaceholder(
                  onBack: _openLevelMap,
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          );
        },
      ),
    );
  }

  /// The game picture keeps its 16:9 in the middle of the screen, while the
  /// controls and the dialogue box spread sideways into the bands a longer
  /// phone leaves beside it. Every other cover stays on the picture.
  Widget _playing(StepboundGame game, Size picture) {
    Widget onPicture(Widget child) => Center(
      child: SizedBox.fromSize(size: picture, child: child),
    );
    Widget screenWide(Widget child) =>
        ScreenWideLayer(pictureHeight: picture.height, child: child);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        onPicture(
          GameWidget<StepboundGame>(
            key: const ValueKey<String>('stepbound-game'),
            game: game,
          ),
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
              _ => onPicture(_coverOf(game, cover)),
            },
          ),
        // The loading picture instead of a black screen while the maps and
        // sprites load, over the bands too so no button shows beside it.
        LoadingCover(
          key: ObjectKey(game),
          ready: game.readyToShow,
          artSize: picture,
          // A new game comes out of the story's fade to black.
          fadeIn: _phase == _Phase.dialogue,
          caption: _phase == _Phase.dialogue
              ? 'Caricamento del tutorial'
              : _gameLoadingCaption,
        ),
      ],
    );
  }
}

final class _GameOverOverlay extends StatefulWidget {
  const _GameOverOverlay({
    required this.resumePoint,
    required this.onResumeFromCamp,
    required this.onRestartLevel,
    required this.onMenu,
  });

  /// Where the save to go back to was made, if there is one. With one it
  /// is the first choice and the one the countdown takes, and starting the
  /// level over is offered under it; without one the level from the start
  /// is the only way on.
  final ResumePoint? resumePoint;
  final VoidCallback onResumeFromCamp;
  final VoidCallback onRestartLevel;
  final VoidCallback onMenu;

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
        return ColoredBox(
          key: const ValueKey<String>('game-over-overlay'),
          color: const Color(0xc2180e0c),
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
        'Ricominciare il livello? ${widget.resumePoint!.savedHere} '
        'va perso: si riparte dalla prima scena della storia, e restano '
        'solo le ore di gioco.',
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
