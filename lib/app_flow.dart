import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/game_session.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/put_down_writer.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/scripts/station_script.dart';
import 'package:stepbound/report/breadcrumbs.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/level_complete.dart';
import 'package:stepbound/ui/main_menu.dart';

/// The main menu first; a new game then plays the story scenes and the
/// protagonist's line before the controls appear, while a loaded game goes
/// straight to playing.
enum AppPhase {
  menu,
  story,
  outbreak,
  dialogue,
  playing,
  levelComplete,
  levelMap,
  romeStory,
}

/// What the results of a completed level show.
final class LevelResults {
  const LevelResults({
    required this.stats,
    required this.finale,
    required this.secret,
    required this.saveFailed,
  });

  final LevelStats stats;

  /// The mission the level ended on, crossed out on its results.
  final Mission? finale;

  /// A secret mission done as the level ended, crossed out with the rest.
  final SecretMission? secret;

  /// Whether the save aboard the train could not be written: the results
  /// say so, and the slot still holds the campfire before.
  final bool saveFailed;
}

/// Which screen the app is on and how it gets to the next: the menu, the
/// story, the game, the results, the map. It owns the [GameSession] that
/// keeps the slot, and the [StepboundGame] being played, and tells its
/// listener whenever any of that changes; drawing them is the widget's.
/// Framework-free but for [ChangeNotifier].
final class AppFlowController extends ChangeNotifier {
  AppFlowController({
    required SaveRepository saves,
    required this.audio,
    Breadcrumbs? trail,
  }) : trail = trail ?? Breadcrumbs.shared {
    session = GameSession(
      saves: saves,
      audio: audio,
      onLevelCompleted: completeLevel,
      onTravelMapRequested: travelFromTrain,
    );
  }

  /// The game being played, in its slot: what is saved and restored, and
  /// the games that play it.
  late final GameSession session;

  /// The sound of the game.
  final GameAudio audio;

  /// The trail an error report ends with.
  final Breadcrumbs trail;

  AppPhase _phase = AppPhase.menu;
  StepboundGame? _game;
  GameSnapshot? _completedSnapshot;
  LevelResults? _results;
  bool _loadingFadesIn = false;
  LinkNotice? _linkNotice;
  int _linkNoticeRevision = 0;

  /// Writes the game down when the app leaves the front, once per time
  /// away, and never counts a write the player came back during.
  late final PutDownWriter _putDown = PutDownWriter(suspend);
  bool _disposed = false;

  AppPhase get phase => _phase;

  /// The game on the stage, from Mario's first lines to the level's end.
  StepboundGame? get game => _game;

  /// The results of the level just completed, while they are shown.
  LevelResults? get results => _results;

  /// Whether the loading picture fades in from the black a story ended on.
  bool get loadingFadesIn => _loadingFadesIn;

  /// What the gift link just opened did, told on the main menu until a
  /// game starts.
  LinkNotice? get linkNotice => _linkNotice;

  /// Bumped with every notice, so the menu starts afresh to tell it.
  int get linkNoticeRevision => _linkNoticeRevision;

  /// Whether the game has been written down since the app left the front.
  bool get putDown => _putDown.putDown;

  /// Whether the game is what is on screen, Mario's opening lines over it
  /// or the controls.
  bool get showsGame =>
      _game != null &&
      (_phase == AppPhase.dialogue || _phase == AppPhase.playing);

  /// [change] happened; whoever draws the app is told.
  void _set(void Function() change) {
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _putDown.close();
    super.dispose();
  }

  // ---------------------------------------------------------- lifecycle

  /// The app is in front again: only then is the player looking at it.
  void cameToFront() {
    audio.resume();
    if (_phase != AppPhase.menu) {
      session.resumeClock();
    }
    _putDown.cameToFront();
  }

  /// The app has left the front, whatever the step (inactive, hidden,
  /// paused): the sound stops, the clock stops, and the game is written
  /// down, since Android may kill the app in the background and
  /// everything since the last fire would go. Once written it is not
  /// written again until the app has been back; while nothing could be
  /// written (no game, or one with nothing to come back to yet) every
  /// step on the way out tries again. A write the player came back
  /// during, and left again, is of the game as it was the first time:
  /// it does not count, and the game is written again as it is now (see
  /// [PutDownWriter]).
  void leftFront() {
    audio.pause();
    session.pauseClock();
    _putDown.leftFront();
  }

  /// Writes the game as it is beside the slot's save, to be picked up from
  /// the menu; the campfire's save stays the one to go back to. Only while
  /// playing, and only in a state the game can come back to: when it is
  /// in the middle of something, the last such state a few steps back (see
  /// [StepboundGame.putDownSnapshot]); with none, the slot keeps what it
  /// had. True once written.
  Future<bool> suspend() async {
    final game = _game;
    if (game == null || _phase != AppPhase.playing) {
      return false;
    }
    if (game.putDownSnapshot case final snapshot?) {
      return session.suspend(snapshot);
    }
    return false;
  }

  // --------------------------------------------------------------- menu

  Future<void> newGame(int slot) async {
    trail.add('app: nuova partita nello slot $slot');
    await session.startNew(slot);
    if (_disposed) {
      return;
    }
    playStoryAudio();
    _set(() {
      _completedSnapshot = null;
      _linkNotice = null;
      _phase = AppPhase.story;
    });
  }

  Future<void> loadGame(SaveGame save) async {
    trail.add(
      'app: carica lo slot ${save.slot} (${save.place}, formato '
      '${SaveGame.format})',
    );
    final game = await session.load(save);
    if (_disposed) {
      return;
    }
    _loadingFadesIn = false;
    _set(() {
      _linkNotice = null;
      _game = game;
      _phase = AppPhase.playing;
    });
  }

  /// A gift link's skin, for the slot and for the game being played.
  void giveOutfit(PlayerOutfit outfit) {
    session.gifts.add(outfit);
    _game?.progress.unlockOutfit(outfit);
  }

  /// From the pause menu or the game over screen. A game left from its
  /// menu is put down like one sent to the background: the slot offers it
  /// again as it was. The pictures of its places, kept for a game
  /// started over at once, go: the menu can stay open a long while.
  void backToMenu({LinkNotice? linkNotice}) {
    trail.add('app: al menù principale');
    unawaited(suspend());
    audio
      ..silenceAmbience()
      ..playMusic(Music.menu);
    StepboundGame.releasePlacePictures();
    _set(() {
      _game = null;
      _completedSnapshot = null;
      _linkNotice = linkNotice;
      if (linkNotice != null) {
        _linkNoticeRevision += 1;
      }
      _phase = AppPhase.menu;
    });
  }

  // -------------------------------------------------------------- story

  void finishIntro() => _set(() => _phase = AppPhase.outbreak);

  void finishOutbreak() {
    trail.add('app: la storia finisce, il gioco comincia');
    _set(() {
      _phase = AppPhase.dialogue;
      _game = session.newGame();
    });
  }

  void finishDialogue() {
    _set(() {
      _phase = AppPhase.playing;
      _game?.inputLocked = false;
    });
  }

  /// The story's music at full volume, no ambience.
  void playStoryAudio() {
    audio
      ..silenceAmbience()
      ..setMusicLevel(1)
      ..playMusic(Music.story);
  }

  // ---------------------------------------------------- back into play

  /// Back to the last campfire or to the train, from the menu or after
  /// dying. Only offered while there is a resume point; if the slot has
  /// gone missing anyway, the level starts over rather than leaving the
  /// player stuck.
  Future<void> resumeFromCamp() async {
    trail.add('app: torna all’ultimo salvataggio');
    final game = await session.resumeFromCheckpoint();
    if (_disposed) {
      return;
    }
    if (game == null) {
      await restartLevel();
      return;
    }
    _loadingFadesIn = false;
    _set(() {
      _game = game;
      _phase = AppPhase.playing;
    });
  }

  /// The level from the very start: Molfetta from the first story picture,
  /// any other level from where Mario arrived in it (see [GameSession]).
  /// Only the city being played starts over: the others stay as they are.
  Future<void> restartLevel() async {
    trail.add('app: ricomincia il livello');
    final game = _game;
    final current = game?.snapshot(place: GameSession.levelStartPlace);
    if (current != null && game!.progress.level != LevelId.hometown) {
      await _restartCity(current);
      return;
    }
    // The camp's fire and hushed music stop at once: the story plays.
    game?.soundscapePaused = true;
    playStoryAudio();
    await session.saveLevelStart(current: current);
    if (_disposed) {
      return;
    }
    _set(() {
      _game = null;
      _phase = AppPhase.story;
    });
  }

  Future<void> _restartCity(GameSnapshot current) async {
    final game = await session.restartCityLevel(current);
    if (_disposed) {
      return;
    }
    _loadingFadesIn = false;
    _set(() {
      _game = game;
      _phase = AppPhase.playing;
    });
  }

  // ------------------------------------------------------ level's end

  /// The game has ended the level aboard the train (see
  /// [GameSession.onLevelCompleted]): its results.
  void completeLevel(GameSnapshot snapshot, {required bool saved}) {
    trail.add(
      'app: livello completato, risultati'
      '${saved ? '' : ' (salvataggio sul treno non riuscito)'}',
    );
    final world = restoreGameWorld(snapshot.world);
    final progress = Progress.fromJson(snapshot.progress);
    final results = LevelResults(
      stats: LevelStats.of(world, progress, progress.level),
      finale: Mission.finaleOf(progress.level),
      secret: StationScript.gaveGoldenPistol(snapshot.story)
          ? SecretMission.unarmedToLuigi
          : null,
      saveFailed: !saved,
    );
    playStoryAudio();
    StepboundGame.releasePlacePictures();
    _set(() {
      _completedSnapshot = snapshot;
      _results = results;
      _game = null;
      _phase = AppPhase.levelComplete;
    });
  }

  void openLevelMap() => _set(() => _phase = AppPhase.levelMap);

  /// The map opened aboard the train (see
  /// [GameSession.onTravelMapRequested]).
  void travelFromTrain(GameSnapshot snapshot) {
    playStoryAudio();
    StepboundGame.releasePlacePictures();
    _set(() {
      _completedSnapshot = snapshot;
      _game = null;
      _phase = AppPhase.levelMap;
    });
  }

  /// The train takes Mario and Luigi to [level] (see
  /// [GameSession.startLevel]).
  void _startLevel(LevelId level) {
    final snapshot = _completedSnapshot;
    if (snapshot == null) {
      return;
    }
    _set(() {
      _game = session.startLevel(level, snapshot);
      _phase = AppPhase.playing;
    });
  }

  void startHometown() {
    trail.add('app: parte la città natale');
    _loadingFadesIn = false;
    _startLevel(LevelId.hometown);
  }

  /// The first time, Rome's story plays before the city loads.
  void startRome() {
    trail.add('app: parte Roma');
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
    // The city's music from the first picture of its story.
    audio.playMusic(Music.rome);
    _set(() => _phase = AppPhase.romeStory);
  }

  void finishRomeStory() {
    session.rememberStory(StoryMemory.presidentFled);
    _loadingFadesIn = true;
    _startLevel(LevelId.rome);
  }
}
