import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/app_flow.dart';
import 'package:stepbound/app_services.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/input/touch_controls.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/render/pixel_palette.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/report/breadcrumbs.dart';
import 'package:stepbound/report/error_report.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/save/skin_links.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/blood_splat.dart';
import 'package:stepbound/ui/crash_guard.dart';
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
import 'package:stepbound/ui/save_failed_notice.dart';
import 'package:stepbound/ui/screen_wide_layer.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'package:stepbound/ui/work_in_progress_screen.dart';
import 'package:stepbound/ui/zombie_book.dart';

final class StepboundApp extends StatefulWidget {
  const StepboundApp({
    this.services,
    this.saves,
    this.skinLinks = const Stream<Uri>.empty(),
    this.audio,
    this.clock = DateTime.now,
    this.reporter,
    this.share,
    super.key,
  });

  /// What the app runs on, made by whoever runs it and closed by the app
  /// when it goes (see [AppServices]). Without one the app makes its own
  /// around [saves] and [audio], owning only what it had to make itself.
  final AppServices? services;

  /// Where the four save slots live; the device storage when null. Read
  /// only without [services].
  final SaveRepository? saves;

  /// Where an uncaught error ends up (see `CrashGuard`): the app tells it
  /// what to put in the report about the game in play.
  final ErrorReporter? reporter;

  /// How the report of a failed save leaves the phone (see `CrashGuard`,
  /// which shares the report of an error the same way); nowhere when
  /// null.
  final ShareReport? share;

  /// Gift links (see `lib/save/skin_links.dart`) the app was opened with,
  /// cold or warm, as the platform delivers them.
  final Stream<Uri> skinLinks;

  /// What time it is, to tell whether a gift link has expired.
  final DateTime Function() clock;

  /// The sound of the game; silent when null. Read only without
  /// [services].
  final GameAudio? audio;

  @override
  State<StepboundApp> createState() => _StepboundAppState();
}

/// Draws whatever phase the [AppFlowController] is in, and hands it what
/// the player does; the phone's side (gift links, the app going to the
/// background, the error report) is here too.
final class _StepboundAppState extends State<StepboundApp> {
  late final AppServices _services =
      widget.services ?? AppServices(saves: widget.saves, audio: widget.audio);
  SaveRepository get _saves => _services.saves;
  GameAudio get _audio => _services.audio;

  /// Which screen the app is on, and the game being played.
  late final AppFlowController _flow = AppFlowController(
    saves: _saves,
    audio: _audio,
  );

  /// Silences the game whenever it is not the app in front.
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<Uri>? _skinLinkSubscription;

  /// One link at a time: two gifts written at once would each keep only
  /// their own skin.
  Future<void> _skinLinkHandling = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _flow.addListener(_flowChanged);
    _skinLinkSubscription = widget.skinLinks.listen((uri) {
      _skinLinkHandling = _skinLinkHandling.then((_) => _handleSkinLink(uri));
    }, onError: (Object error) => debugPrint('skin links: $error'));
    // Only `resumed` means the player is looking at the game. Android
    // goes inactive, then hidden, then paused on the way out, and a
    // call or the app switcher stops at inactive: all of them silence
    // it, or the game over sting plays on over whatever comes next, and
    // all of them stop the clock.
    _lifecycle = AppLifecycleListener(
      onStateChange: _onLifecycle,
      // The engine is letting go of the app: the last chance to close what
      // was made for it (the phone's sound), before the process ends.
      onDetach: () => unawaited(_services.dispose()),
    );
    widget.reporter?.context = _reportSections;
    Breadcrumbs.shared.add('app: menù principale');
    _audio.playMusic(Music.menu);
  }

  void _flowChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// What an error report says about the game in play: the slot, the
  /// phase, where Mario is, and the save the menu would offer for that
  /// slot, to load and play the error back. Nothing here may throw.
  Future<List<ReportSection>> _reportSections() async {
    final game = _flow.game;
    final slot = _flow.session.slot;
    final sections = <ReportSection>[
      ReportSection(
        'Partita',
        'slot: $slot\n'
            'fase: ${_flow.phase.name}\n'
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

  /// The report of the last save that could not be written, to send like
  /// the one of an error: the same text, the failure in the error's place.
  Future<void> _shareSaveFailure() async {
    final failure = _flow.session.lastSaveFailure;
    if (failure == null) {
      return;
    }
    Breadcrumbs.shared.add('app: rapporto del salvataggio condiviso');
    await _shareReport(
      ErrorReport(
        error: failure.error,
        stack: failure.stack,
        source: 'salvataggio: ${failure.place}',
        at: failure.at,
      ),
    );
  }

  /// The report a player asks for from the pause menu, with no error in
  /// it: the trail is the point, for the bugs that throw nothing, a script
  /// that never lets go of Mario or a button that does not answer.
  Future<void> _shareTrail() async {
    Breadcrumbs.shared.add('app: rapporto chiesto dal menù pausa');
    await _shareReport(
      ErrorReport(
        error: 'nessun errore: rapporto chiesto dal giocatore',
        source: 'menù pausa',
        at: DateTime.now(),
      ),
    );
  }

  /// Renders [report] like the one of an error and hands it to the share
  /// sheet; nothing if the app cannot share.
  Future<void> _shareReport(ErrorReport report) async {
    final share = widget.share;
    if (share == null) {
      return;
    }
    final reporter = (widget.reporter ?? ErrorReporter())
      ..context ??= _reportSections;
    try {
      await share(reporter.fileNameFor(report), await reporter.render(report));
    } on Object catch (error) {
      debugPrint('report: could not share ($error)');
    }
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
      _flow.giveOutfit(outfit);
      notice = SkinGiftNotice(outfit);
    }
    if (mounted) {
      _flow.backToMenu(linkNotice: notice);
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _flow.cameToFront();
      return;
    }
    _flow.leftFront();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decoded up front, so the loading picture is there at once.
    for (final image in <String>[
      LoadingArt.image,
      LevelMap.hometownImage,
      LevelMap.romeImage,
      WorkInProgressScreen.image,
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
    _flow
      ..removeListener(_flowChanged)
      ..dispose();
    unawaited(_services.dispose());
    super.dispose();
  }

  /// The game over sting stops with the choice made on its screen.
  void _afterGameOver(void Function() choice) {
    _audio.stop(Sfx.gameOver);
    choice();
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
    AdventureStatsCover(:final level) => Letterbox(
      color: AdventureStats.backdrop,
      child: AdventureStats(
        world: game.simulation,
        level: level,
        progress: game.progress,
        onClose: game.closeAdventureStats,
        onReplayMemories: game.replayMemories,
      ),
    ),
    ZombieBookCover() => Letterbox(
      color: ZombieBook.backdrop,
      child: ZombieBook(progress: game.progress, onClose: game.closeZombieBook),
    ),
    MemoriesCover(:final level) => Letterbox(
      color: Colors.black,
      child: StoryIntro(
        key: const ValueKey<String>('train-memories-story'),
        scenes: seenScenes(game.progress, level),
        allowBackNavigation: true,
        // Each memory with the music it was lived with, the rest with the
        // story's.
        onScene: (scene) => _audio.playMusic(scene.music ?? Music.story),
        onFinished: game.closeMemories,
        onExit: game.closeMemories,
      ),
    ),
    SaveFailedCover(:final line) => SaveFailedNotice(
      key: ObjectKey(cover),
      line: line,
      onShare: () => unawaited(_shareSaveFailure()),
      onContinue: game.dismissSaveFailed,
    ),
    WorkInProgressCover() => Letterbox(
      color: Colors.black,
      child: WorkInProgressScreen(
        key: ObjectKey(cover),
        onBack: game.closeWorkInProgress,
      ),
    ),
    PauseCover(:final wardrobe) => PauseMenu(
      progress: game.progress,
      wardrobe: wardrobe,
      resumePoint: _flow.session.resumePoint,
      restartsFromStory: game.progress.level == LevelId.hometown,
      onResumeFromCamp: () => unawaited(_flow.resumeFromCamp()),
      onRestartLevel: () => unawaited(_flow.restartLevel()),
      onMainMenu: _flow.backToMenu,
      onClose: game.closeMenu,
      onWearOutfit: game.wearOutfit,
      onShareReport: widget.share == null
          ? null
          : () => unawaited(_shareTrail()),
    ),
    LevelEndCover() => const ColoredBox(
      key: ValueKey<String>('level-end-black'),
      color: Colors.black,
    ),
    GameOverCover() => Letterbox(
      color: _GameOverOverlay.backdrop,
      child: _GameOverOverlay(
        resumePoint: _flow.session.resumePoint,
        restartsFromStory: game.progress.level == LevelId.hometown,
        onResumeFromCamp: () =>
            _afterGameOver(() => unawaited(_flow.resumeFromCamp())),
        onRestartLevel: () =>
            _afterGameOver(() => unawaited(_flow.restartLevel())),
        onMenu: () => _afterGameOver(_flow.backToMenu),
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
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
          child: BloodSplatLayer(child: _surface()),
        ),
      ),
    );
  }

  Widget _surface() {
    final phase = _flow.phase;
    final session = _flow.session;
    return ColoredBox(
      key: const ValueKey<String>('stepbound-game-surface'),
      color: PixelPalette.screenBlack,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = IntegerResolutionViewport.scaleFor(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          if (_flow.game case final game? when _flow.showsGame) {
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
              child: switch (phase) {
                AppPhase.menu => MainMenu(
                  key: ValueKey<int>(_flow.linkNoticeRevision),
                  saves: _saves,
                  linkNotice: _flow.linkNotice,
                  onNewGame: (slot) => unawaited(_flow.newGame(slot)),
                  onLoad: (save) => unawaited(_flow.loadGame(save)),
                ),
                AppPhase.story => StoryIntro(
                  onFinished: _flow.finishIntro,
                  onSkip: session.openingStorySeen
                      ? _flow.finishOutbreak
                      : null,
                ),
                AppPhase.outbreak => StoryIntro(
                  key: const ValueKey<String>('outbreak-story'),
                  scenes: outbreakScenes,
                  fadeOutAtEnd: true,
                  onFinished: _flow.finishOutbreak,
                  onSkip: session.openingStorySeen
                      ? _flow.finishOutbreak
                      : null,
                ),
                AppPhase.levelComplete => LevelComplete(
                  stats: _flow.results!.stats,
                  finale: _flow.results!.finale,
                  secret: _flow.results!.secret,
                  saveFailed: _flow.results!.saveFailed,
                  onShareReport: () => unawaited(_shareSaveFailure()),
                  onContinue: _flow.openLevelMap,
                ),
                AppPhase.levelMap => LevelMap(
                  onStartHometown: _flow.startHometown,
                  onStartRome: _flow.startRome,
                ),
                AppPhase.romeStory => StoryIntro(
                  key: const ValueKey<String>('rome-story'),
                  scenes: romeScenes,
                  fadeOutAtEnd: true,
                  onFinished: _flow.finishRomeStory,
                  onSkip:
                      session.storyHistory.contains(StoryMemory.presidentFled)
                      ? _flow.finishRomeStory
                      : null,
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          );
          // The menu's picture spreads over the bands too.
          if (phase == AppPhase.menu) {
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
      fadeIn: _flow.loadingFadesIn,
      image: image,
      caption: caption,
    );
  }

  /// The world fills the whole screen (see ScreenFillingViewport). The
  /// controls and the dialogue box spread as wide as it, as tall as the
  /// 16:9 picture; every other cover lays its picture out itself, with its
  /// backdrop across the bands (see [Letterbox]).
  Widget _playing(StepboundGame game, Size picture) {
    final dialogue = _flow.phase == AppPhase.dialogue;
    Widget screenWide(Widget child) =>
        ScreenWideLayer(pictureHeight: picture.height, child: child);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GameWidget<StepboundGame>(
          key: const ValueKey<String>('stepbound-game'),
          game: game,
        ),
        if (dialogue) ...<Widget>[
          // Mario speaks once the game behind him is there, so no line goes
          // by unseen under the loading picture.
          ValueListenableBuilder<bool>(
            valueListenable: game.readyToShow,
            builder: (context, ready, _) => ready
                ? screenWide(
                    SafeArea(
                      child: GameplayDialogue(onFinished: _flow.finishDialogue),
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
        if (dialogue)
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
                  'va perso: si riparte dalla prima scena della storia. Le '
                  'altre città restano come sono.'
            : 'Ricominciare il livello? ${widget.resumePoint!.savedHere} '
                  'va perso: si riparte dall’arrivo in città. Le altre '
                  'città restano come sono.',
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
