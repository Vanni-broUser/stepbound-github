import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/pause_menu.dart';

/// One game in one of the four slots, from the menu to the menu: it makes
/// the [StepboundGame]s that play it, new, loaded or started over, and
/// keeps what a save records around them: the slot, the fire to go back
/// to, where the level starts over, the hours played and the story scenes
/// watched. The app decides what is on screen; this decides what is in the
/// slot.
final class GameSession {
  GameSession({
    required this.saves,
    required this.audio,
    required this.onLevelCompleted,
    required this.onTravelMapRequested,
  });

  /// What a save made by starting the level over is called in the slots.
  static const String levelStartPlace = 'Inizio del livello';

  /// Where the four save slots live.
  final SaveRepository saves;

  /// The sound of the games made here.
  final GameAudio audio;

  /// Leaves gameplay for the results screen after the final cutscene.
  final void Function(GameSnapshot snapshot) onLevelCompleted;

  /// Leaves gameplay directly for the destination map from the train.
  final void Function(GameSnapshot snapshot) onTravelMapRequested;

  /// The slot this game saves into at campfires and on the train.
  int slot = 1;

  /// Where the current slot's save was made: a campfire or the train. Only
  /// with one is there anywhere to go back to, so only then do the menus
  /// offer it. The slot written when the level starts over does not count.
  ResumePoint? resumePoint;

  /// Where the level being played starts over from, when it is not the
  /// first story scene: see [SaveGame.levelStart].
  LevelStart? levelStart;

  /// The story scenes watched on this slot, campfire or not: they can be
  /// skipped from then on.
  final Set<StoryMemory> storyHistory = <StoryMemory>{};
  Future<void> _storyHistoryWrite = Future<void>.value();

  /// What this game had been played for when it was loaded or started, and
  /// the clock running since. Together they are what a save records: it
  /// only runs while the game is in front and out of the menu, so a phone
  /// in a pocket is not play, and nothing between two saves is kept.
  Duration _playedBefore = Duration.zero;
  final Stopwatch _clock = Stopwatch();

  Duration get played => _playedBefore + _clock.elapsed;

  /// Starts this game's clock over from [played].
  void _startClock(Duration played) {
    _playedBefore = played;
    _clock
      ..reset()
      ..start();
  }

  /// The app has left the front, or the menu: the hours stop.
  void pauseClock() => _clock.stop();

  /// The game is in front again.
  void resumeClock() => _clock.start();

  bool get openingStorySeen =>
      storyHistory.contains(StoryMemory.newsBroadcast) &&
      storyHistory.contains(StoryMemory.outbreakNight);

  /// Where a save was made, as far as going back to it goes.
  static ResumePoint? resumePointOf(SaveGame save) => !save.atCampfire
      ? null
      : save.place == trainPlaceName
      ? ResumePoint.train
      : ResumePoint.campfire;

  /// A new game in [newSlot], whatever it held.
  Future<void> startNew(int newSlot) async {
    await _storyHistoryWrite;
    try {
      await saves.clear(newSlot);
    } on Object catch (error) {
      // The old game stays in the slot until the first campfire writes
      // over it: no reason to keep the new one from starting.
      debugPrint('save: could not clear slot $newSlot ($error)');
    }
    slot = newSlot;
    storyHistory.clear();
    resumePoint = null;
    levelStart = null;
    _startClock(Duration.zero);
  }

  /// The game of a new slot, once the opening story has played: Mario's
  /// first lines play over it before the player has it.
  StepboundGame newGame() {
    rememberStories(const <StoryMemory>{
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
    });
    final progress = Progress.newGame(openingSaved: false)
      ..addViewedMemories(storyHistory);
    return _build(progress: progress)..inputLocked = true;
  }

  /// [save], picked from the menu. A game put down is picked up as it
  /// was, but the fire to go back to is still the slot's own save.
  Future<StepboundGame> load(SaveGame save) async {
    final history = await saves.loadStoryHistory(save.slot);
    final checkpoint = await saves.load(save.slot) ?? save;
    final progress = Progress.fromJson(save.progress);
    storyHistory
      ..clear()
      ..addAll(history)
      ..addAll(progress.memories);
    _startClock(save.played);
    slot = save.slot;
    resumePoint = resumePointOf(checkpoint);
    levelStart = save.levelStart;
    return gameOf(
      world: save.world,
      story: save.story,
      progress: progress,
      hud: save.hud,
    );
  }

  /// Back to the last campfire or to the train, from the menu or after
  /// dying: null if the slot has gone missing, and the level starts over
  /// instead. Going back to the fire is giving up whatever was put down
  /// since.
  Future<StepboundGame?> resumeFromCheckpoint() async {
    final save = await saves.load(slot);
    final history = await saves.loadStoryHistory(slot);
    try {
      await saves.clearSuspended(slot);
    } on Object catch (error) {
      debugPrint('save: could not drop the game put down ($error)');
    }
    if (save == null) {
      return null;
    }
    _startClock(save.played);
    storyHistory.addAll(history);
    levelStart = save.levelStart;
    return gameFrom(save);
  }

  /// Molfetta from the very start, the first story picture, with nothing
  /// kept but the hours played (bullets, known zombies, memories all go).
  /// It counts as a save: the slot now holds the start of the level, so
  /// loading it later starts the level over too — but not a campfire one,
  /// so there is nothing to resume from until the next fire. False when
  /// the save could not be written: the level starts over all the same,
  /// and the slot keeps the save it had, with its fire.
  Future<bool> saveLevelStart() async {
    try {
      await saves.save(
        SaveGame(
          slot: slot,
          savedAt: DateTime.now(),
          place: levelStartPlace,
          world: saveGameWorld(createGameWorld()),
          story: const <String, Object?>{},
          progress: Progress().toJson(),
          hud: const <String>[],
          atCampfire: false,
          // The hours played are the one thing starting over keeps.
          played: played,
        ),
      );
    } on SaveWriteException catch (error) {
      debugPrint('save: $error');
      return false;
    }
    resumePoint = null;
    return true;
  }

  /// A level other than Molfetta starts over where Mario arrived in it,
  /// with what he had then. Like the story's restart it counts as a save,
  /// not a campfire one.
  Future<StepboundGame> restartFrom(LevelStart start) async {
    try {
      await saves.save(
        SaveGame(
          slot: slot,
          savedAt: DateTime.now(),
          place: levelStartPlace,
          world: start.world,
          story: start.story,
          progress: start.progress,
          hud: start.hud,
          atCampfire: false,
          played: played,
          levelStart: start,
        ),
      );
      resumePoint = null;
    } on SaveWriteException catch (error) {
      debugPrint('save: $error');
    }
    return gameOf(
      world: start.world,
      story: start.story,
      progress: Progress.fromJson(start.progress),
      hud: start.hud,
    );
  }

  /// Called by [game] when Mario rests at a campfire, and when the level
  /// ends with him aboard the train. False when the save could not be
  /// written: the slot still holds the one before, and so does
  /// [resumePoint].
  Future<bool> store(GameSnapshot snapshot, {StepboundGame? game}) async {
    try {
      await saves.save(
        SaveGame(
          slot: slot,
          savedAt: DateTime.now(),
          place: snapshot.place,
          world: snapshot.world,
          story: snapshot.story,
          progress: snapshot.progress,
          hud: snapshot.hud,
          played: played,
          levelStart: levelStart,
        ),
      );
    } on SaveWriteException catch (error) {
      debugPrint('save: $error');
      return false;
    }
    resumePoint = snapshot.place == trainPlaceName
        ? ResumePoint.train
        : ResumePoint.campfire;
    game?.progress.confirmPendingMemories();
    return true;
  }

  /// Writes [game] as it is beside the slot's save, to be picked up from
  /// the menu; the campfire's save stays the one to go back to. The app
  /// asks first whether the game is in a state it can come back to (see
  /// [StepboundGame.canBeSuspended]).
  Future<void> suspend(StepboundGame game) async {
    final snapshot = game.snapshot(place: game.placeName);
    try {
      await saves.suspend(
        SaveGame(
          slot: slot,
          savedAt: DateTime.now(),
          place: snapshot.place,
          world: snapshot.world,
          story: snapshot.story,
          progress: snapshot.progress,
          hud: snapshot.hud,
          atCampfire: false,
          played: played,
          levelStart: levelStart,
        ),
      );
    } on SaveWriteException catch (error) {
      debugPrint('save: $error');
    }
  }

  /// The train takes Mario and Luigi to [level] from [snapshot], the game
  /// as the last level left it: the game picks up aboard, with the
  /// train's door onto that level's station, and is saved there. Mario's
  /// rounds and molotovs stay in the level he leaves (see
  /// [Progress.travel] and [Progress.swapMolotovs]). Rome starts over
  /// from here.
  StepboundGame startLevel(LevelId level, GameSnapshot snapshot) {
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
    levelStart = level == LevelId.hometown
        ? null
        : LevelStart(
            world: arrival.world,
            story: arrival.story,
            progress: arrival.progress,
            hud: arrival.hud,
          );
    unawaited(store(arrival));
    return gameOf(
      world: arrival.world,
      story: arrival.story,
      progress: progress,
      hud: arrival.hud,
    );
  }

  /// The game [save] holds.
  StepboundGame gameFrom(SaveGame save) => gameOf(
    world: save.world,
    story: save.story,
    progress: Progress.fromJson(save.progress),
    hud: save.hud,
  );

  /// A game over [world] with [story] done, [progress] known and [hud]
  /// unlocked, as a save holds them.
  StepboundGame gameOf({
    required Map<String, Object?> world,
    required Map<String, Object?> story,
    required Progress progress,
    required List<String> hud,
  }) {
    progress.addViewedMemories(storyHistory);
    return _build(
      world: restoreGameWorld(world),
      storyState: story,
      progress: progress,
      unlocked: <HudElement>{
        for (final name in hud)
          for (final element in HudElement.values)
            if (element.name == name) element,
      },
    );
  }

  StepboundGame _build({
    required Progress progress,
    WorldState? world,
    Map<String, Object?>? storyState,
    Set<HudElement> unlocked = const <HudElement>{},
  }) {
    late final StepboundGame game;
    return game = StepboundGame(
      world: world,
      storyState: storyState,
      progress: progress,
      unlocked: unlocked,
      onRest: (snapshot) => store(snapshot, game: game),
      onLevelCompleted: onLevelCompleted,
      onTravelMapRequested: onTravelMapRequested,
      onStoryViewed: rememberStory,
      audio: audio,
    );
  }

  void rememberStory(StoryMemory memory) =>
      rememberStories(<StoryMemory>{memory});

  /// [memories] have been watched on this slot: written down at once, so
  /// they can be skipped even if the game ends before a fire.
  void rememberStories(Set<StoryMemory> memories) {
    if (memories.every(storyHistory.contains)) {
      return;
    }
    storyHistory.addAll(memories);
    final copy = Set<StoryMemory>.of(storyHistory);
    final writtenFor = slot;
    _storyHistoryWrite = _storyHistoryWrite.then(
      (_) => saves.saveStoryHistory(writtenFor, copy),
    );
  }
}
