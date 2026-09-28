import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/game_session.dart';
import 'package:stepbound/game/input/touch_controls.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/scripts/station_script.dart';
import 'package:stepbound/report/breadcrumbs.dart';
import 'package:stepbound/report/error_report.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/save/skin_links.dart';
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
  const StepboundApp({
    this.saves,
    this.skinLinks = const Stream<Uri>.empty(),
    this.audio,
    this.clock = DateTime.now,
    this.reporter,
    super.key,
  });

  /// Where the four save slots live; the device storage when null.
  final SaveRepository? saves;

  /// Where an uncaught error ends up (see `CrashGuard`): the app tells it
  /// what to put in the report about the game in play.
  final ErrorReporter? reporter;

  /// Gift links (see `lib/save/skin_links.dart`) the app was opened with,
  /// cold or warm, as the platform delivers them.
  final Stream<Uri> skinLinks;

  /// What time it is, to tell whether a gift link has expired.
  final DateTime Function() clock;

  /// The sound of the game; silent when null.
  final GameAudio? audio;

  @override
  State<StepboundApp> createState() => _StepboundAppState();
}

final class _StepboundAppState extends State<StepboundApp> {
  late final SaveRepository _saves =
      widget.saves ?? PreferencesSaveRepository();
  late final GameAudio _audio = widget.audio ?? SilentAudio();

  /// The game being played, in its slot: what is saved and restored, and
  /// the games that play it. The phases here decide what is on screen.
  late final GameSession _session = GameSession(
    saves: _saves,
    audio: _audio,
    onLevelCompleted: _completeLevel,
    onTravelMapRequested: _travelFromTrain,
  );

  /// Silences the game whenever it is not the app in front.
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<Uri>? _skinLinkSubscription;

  /// One link at a time: two gifts written at once would each keep only
  /// their own skin.
  Future<void> _skinLinkHandling = Future<void>.value();

  /// What the gift link just opened did, told on the main menu until a
  /// game starts.
  LinkNotice? _linkNotice;
  int _linkNoticeRevision = 0;
  StepboundGame? _game;
  _Phase _phase = _Phase.menu;
  GameSnapshot? _completedSnapshot;
  late LevelStats _levelStats;

  /// The mission the completed level ended on, crossed out on its results.
  Mission? _levelFinale;

  /// A secret mission done as the level ended, crossed out with the rest.
  SecretMission? _levelSecret;

  /// Whether the loading picture fades in from the black a story ended on.
  bool _loadingFadesIn = false;

  @override
  void initState() {
    super.initState();
    _skinLinkSubscription = widget.skinLinks.listen((uri) {
      _skinLinkHandling = _skinLinkHandling.then((_) => _handleSkinLink(uri));
    }, onError: (Object error) => debugPrint('skin links: $error'));
    // Only `resumed` means the player is looking at the game. Android
    // goes inactive, then hidden, then paused on the way out, and a
    // call or the app switcher stops at inactive: all of them silence
    // it, or the game over sting plays on over whatever comes next, and
    // all of them stop the clock.
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    widget.reporter?.context = _reportSections;
    Breadcrumbs.shared.add('app: menù principale');
    _audio.playMusic(Music.menu);
  }

  /// What an error report says about the game in play: the slot, the
  /// phase, where Mario is, and the save the menu would offer for that
  /// slot, to load and play the error back. Nothing here may throw.
  Future<List<ReportSection>> _reportSections() async {
    final game = _game;
    final slot = _session.slot;
    final sections = <ReportSection>[
      ReportSection(
        'Partita',
        'slot: $slot\n'
            'fase: ${_phase.name}\n'
            'posto: ${game == null ? 'nessuno' : _placeOf(game)}',
      ),
    ];
    try {
      final read = await _saves.read(slot);
      sections.add(
        ReportSection('Salvataggio dello slot $slot', switch (read) {
          LoadedSave(:final game) => jsonEncode(game.toJson()),
          DamagedSave(:final reason) => 'danneggiato: $reason',
          _ => 'vuoto',
        }),
      );
    } on Object catch (error) {
      sections.add(
        ReportSection('Salvataggio dello slot $slot', 'illeggibile: $error'),
      );
    }
    return sections;
  }

  /// The game may be the very thing that broke.
  String _placeOf(StepboundGame game) {
    try {
      return game.placeName;
    } on Object catch (error) {
      return 'sconosciuto ($error)';
    }
  }

  /// A gift link gives its skin to all four slots, whatever they hold,
  /// and the game being played gets it at once; the menu then says so.
  /// An expired or broken one gives nothing, and the menu says that.
  Future<void> _handleSkinLink(Uri uri) async {
    if (!isSkinLink(uri)) {
      return;
    }
    final link = readSkinLink(uri);
    final LinkNotice notice;
    if (link == null || link.expiredAt(widget.clock())) {
      notice = const InvalidLinkNotice();
    } else {
      final outfit = link.outfit;
      for (var slot = 1; slot <= SaveRepository.slotCount; slot++) {
        try {
          await _saves.saveGifts(slot, {
            ...await _saves.loadGifts(slot),
            outfit,
          });
        } on Object catch (error) {
          debugPrint('gifts: could not give ${outfit.name} to $slot ($error)');
        }
      }
      _session.gifts.add(outfit);
      _game?.progress.unlockOutfit(outfit);
      notice = SkinGiftNotice(outfit);
    }
    if (mounted) {
      _backToMenu(linkNotice: notice);
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _audio.resume();
      if (_phase != _Phase.menu) {
        _session.resumeClock();
      }
      _putDown = false;
      return;
    }
    _audio.pause();
    _session.pauseClock();
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
    await _session.suspend(game);
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
    unawaited(_skinLinkSubscription?.cancel());
    _lifecycle.dispose();
    if (widget.reporter?.context == _reportSections) {
      widget.reporter?.context = null;
    }
    super.dispose();
  }

  Future<void> _newGame(int slot) async {
    Breadcrumbs.shared.add('app: nuova partita nello slot $slot');
    await _session.startNew(slot);
    if (!mounted) {
      return;
    }
    _playStoryAudio();
    setState(() {
      _completedSnapshot = null;
      _linkNotice = null;
      _phase = _Phase.story;
    });
  }

  Future<void> _loadGame(SaveGame save) async {
    Breadcrumbs.shared.add(
      'app: carica lo slot ${save.slot} (${save.place}, formato '
      '${SaveGame.format})',
    );
    final game = await _session.load(save);
    if (!mounted) {
      return;
    }
    _loadingFadesIn = false;
    setState(() {
      _linkNotice = null;
      _game = game;
      _phase = _Phase.playing;
    });
  }

  void _finishIntro() {
    setState(() => _phase = _Phase.outbreak);
  }

  void _finishOutbreak() {
    Breadcrumbs.shared.add('app: la storia finisce, il gioco comincia');
    setState(() {
      _phase = _Phase.dialogue;
      _game = _session.newGame();
    });
  }

  void _finishDialogue() {
    setState(() {
      _phase = _Phase.playing;
      _game?.inputLocked = false;
    });
  }

  /// Back to the last campfire or to the train, from the menu or after
  /// dying. Only offered while there is a resume point; if the slot has
  /// gone missing anyway, the level starts over rather than leaving the
  /// player stuck.
  Future<void> _resumeFromCamp() async {
    Breadcrumbs.shared.add('app: torna all’ultimo salvataggio');
    final game = await _session.resumeFromCheckpoint();
    if (!mounted) {
      return;
    }
    if (game == null) {
      await _restartLevel();
      return;
    }
    _loadingFadesIn = false;
    setState(() {
      _game = game;
      _phase = _Phase.playing;
    });
  }

  /// The level from the very start: Molfetta from the first story picture,
  /// any other level from where Mario arrived in it (see [GameSession]).
  Future<void> _restartLevel() async {
    Breadcrumbs.shared.add('app: ricomincia il livello');
    if (_session.levelStart case final start?) {
      await _restartFrom(start);
      return;
    }
    // The camp's fire and hushed music stop at once: the story plays.
    _game?.soundscapePaused = true;
    _playStoryAudio();
    await _session.saveLevelStart(
      secretMissions: <SecretMission>{...?_game?.progress.secretMissions},
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _game = null;
      _phase = _Phase.story;
    });
  }

  Future<void> _restartFrom(LevelStart start) async {
    final game = await _session.restartFrom(start);
    if (!mounted) {
      return;
    }
    _loadingFadesIn = false;
    setState(() {
      _game = game;
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
        onReplayMemories: game.replayMemories,
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
      resumePoint: _session.resumePoint,
      restartsFromStory: _session.levelStart == null,
      onResumeFromCamp: () => unawaited(_resumeFromCamp()),
      onRestartLevel: () => unawaited(_restartLevel()),
      onMainMenu: _backToMenu,
      onClose: game.closeMenu,
      onWearOutfit: game.wearOutfit,
    ),
    GameOverCover() => Letterbox(
      color: _GameOverOverlay.backdrop,
      child: _GameOverOverlay(
        resumePoint: _session.resumePoint,
        restartsFromStory: _session.levelStart == null,
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

  void _completeLevel(GameSnapshot snapshot) {
    Breadcrumbs.shared.add('app: livello completato, risultati');
    final world = restoreGameWorld(snapshot.world);
    final progress = Progress.fromJson(snapshot.progress);
    final stats = LevelStats.of(world, progress, progress.level);
    _playStoryAudio();
    StepboundGame.releasePlacePictures();
    setState(() {
      _completedSnapshot = snapshot;
      _levelStats = stats;
      _levelFinale = Mission.finaleOf(progress.level);
      _levelSecret = StationScript.gaveGoldenPistol(snapshot.story)
          ? SecretMission.unarmedToLuigi
          : null;
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

  /// The train takes Mario and Luigi to [level] (see
  /// [GameSession.startLevel]).
  void _startLevel(LevelId level) {
    final snapshot = _completedSnapshot;
    if (snapshot == null) {
      return;
    }
    setState(() {
      _game = _session.startLevel(level, snapshot);
      _phase = _Phase.playing;
    });
  }

  void _startHometown() {
    Breadcrumbs.shared.add('app: parte la città natale');
    _loadingFadesIn = false;
    _startLevel(LevelId.hometown);
  }

  /// The first time, Rome's story plays before the city loads.
  void _startRome() {
    Breadcrumbs.shared.add('app: parte Roma');
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
    _session.rememberStory(StoryMemory.presidentFled);
    _loadingFadesIn = true;
    _startLevel(LevelId.rome);
  }

  /// From the pause menu or the game over screen. A game left from its
  /// menu is put down like one sent to the background: the slot offers it
  /// again as it was. The pictures of its places, kept for a game
  /// started over at once, go: the menu can stay open a long while.
  void _backToMenu({LinkNotice? linkNotice}) {
    Breadcrumbs.shared.add('app: al menù principale');
    unawaited(_suspend());
    _audio
      ..silenceAmbience()
      ..playMusic(Music.menu);
    StepboundGame.releasePlacePictures();
    setState(() {
      _game = null;
      _completedSnapshot = null;
      _linkNotice = linkNotice;
      if (linkNotice != null) {
        _linkNoticeRevision += 1;
      }
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
                  key: ValueKey<int>(_linkNoticeRevision),
                  saves: _saves,
                  linkNotice: _linkNotice,
                  onNewGame: (slot) => unawaited(_newGame(slot)),
                  onLoad: (save) => unawaited(_loadGame(save)),
                ),
                _Phase.story => StoryIntro(
                  onFinished: _finishIntro,
                  onSkip: _session.openingStorySeen ? _finishOutbreak : null,
                ),
                _Phase.outbreak => StoryIntro(
                  key: const ValueKey<String>('outbreak-story'),
                  scenes: outbreakScenes,
                  fadeOutAtEnd: true,
                  onFinished: _finishOutbreak,
                  onSkip: _session.openingStorySeen ? _finishOutbreak : null,
                ),
                _Phase.levelComplete => LevelComplete(
                  stats: _levelStats,
                  finale: _levelFinale,
                  secret: _levelSecret,
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
                  onSkip:
                      _session.storyHistory.contains(StoryMemory.presidentFled)
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
  /// 16:9 picture; every other cover lays its picture out itself, with its
  /// backdrop across the bands (see [Letterbox]).
  Widget _playing(StepboundGame game, Size picture) {
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
