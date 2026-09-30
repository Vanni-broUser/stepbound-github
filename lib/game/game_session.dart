import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/level_restart.dart';
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
/// A save that could not be written, kept for the report the player can
/// share: what failed, where the game was, when.
final class SaveFailure {
  const SaveFailure({
    required this.error,
    required this.stack,
    required this.place,
    required this.at,
  });

  final Object error;
  final StackTrace stack;
  final String place;
  final DateTime at;
}

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

  /// The last save that could not be written, campfire, table or train,
  /// for the report; null until one fails.
  SaveFailure? lastSaveFailure;

  /// Leaves gameplay for the results screen after the final cutscene;
  /// `saved` says whether the train's save was written.
  final void Function(GameSnapshot snapshot, {required bool saved})
  onLevelCompleted;

  /// Leaves gameplay directly for the destination map from the train.
  final void Function(GameSnapshot snapshot) onTravelMapRequested;

  /// The slot this game saves into at campfires and on the train.
  int slot = 1;

  /// Where the current slot's save was made: a campfire or the train. Only
  /// with one is there anywhere to go back to, so only then do the menus
  /// offer it. The slot written when the level starts over does not count.
  ResumePoint? resumePoint;

  /// The story scenes watched on this slot, campfire or not: they can be
  /// skipped from then on.
  final Set<StoryMemory> storyHistory = <StoryMemory>{};

  /// The skins given to this slot by gift links (see
  /// [SaveRepository.loadGifts]): every game made here can wear them.
  final Set<PlayerOutfit> gifts = <PlayerOutfit>{};

  /// Molfetta as it was started over, for the game to begin once its
  /// story has played: the other cities as they were, the secret missions
  /// done and what the other cities gave (see [restartHometown]).
  RestartedLevel? _restarted;
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

  /// A new game in [newSlot], whatever it held. The slot's gifts were
  /// for the game saved there: they go with it. An empty slot's are for
  /// the game started in it, this one.
  Future<void> startNew(int newSlot) async {
    await _storyHistoryWrite;
    gifts.clear();
    _restarted = null;
    if (await saves.read(newSlot) is EmptySave) {
      gifts.addAll(await saves.loadGifts(newSlot));
    } else {
      try {
        await saves.saveGifts(newSlot, const <PlayerOutfit>{});
      } on Object catch (error) {
        debugPrint('save: could not drop the gifts of slot $newSlot ($error)');
      }
    }
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
    _startClock(Duration.zero);
  }

  /// The game of a new slot, once the opening story has played: Mario's
  /// first lines play over it before the player has it.
  StepboundGame newGame() {
    rememberStories(const <StoryMemory>{
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
    });
    final progress = Progress.newGame(openingSaved: false, gifts: gifts)
      ..addViewedMemories(storyHistory);
    final kept = _restarted;
    if (kept == null) {
      return _build(progress: progress)..inputLocked = true;
    }
    final held = kept.progress.heldAway;
    progress
      ..secretMissions.addAll(kept.progress.secretMissions)
      ..heldAway = held == null ? null : HeldAway.fromJson(held.toJson());
    return _build(
      progress: progress,
      world: restoreGameWorld(kept.world),
      storyState: kept.story,
      // Only what Mario carries for the other cities' errands.
      unlocked: <HudElement>{
        for (final name in kept.hud) HudElement.values.byName(name),
      },
    )..inputLocked = true;
  }

  /// [save], picked from the menu. A game put down is picked up as it
  /// was, but the fire to go back to is still the slot's own save.
  Future<StepboundGame> load(SaveGame save) async {
    final history = await saves.loadStoryHistory(save.slot);
    final checkpoint = await saves.load(save.slot) ?? save;
    gifts
      ..clear()
      ..addAll(await saves.loadGifts(save.slot));
    final progress = Progress.fromJson(save.progress);
    storyHistory
      ..clear()
      ..addAll(history)
      ..addAll(progress.memories);
    _startClock(save.played);
    slot = save.slot;
    resumePoint = resumePointOf(checkpoint);
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
    return gameFrom(save);
  }

  /// Molfetta from the very start, the first story picture, with nothing
  /// of Molfetta kept: its bullets, zombies met, memories, clothes and
  /// missions all go. The other cities stay as [current], the game being
  /// played, left them, and what they gave Mario waits for him aboard the
  /// train; the hours played and the secret missions done stay too (see
  /// [restartHometown]).
  /// It counts as a save: the slot now holds the start of the level, so
  /// loading it later starts the level over too — but not a campfire one,
  /// so there is nothing to resume from until the next fire. False when
  /// the save could not be written: the level starts over all the same,
  /// and the slot keeps the save it had, with its fire.
  Future<bool> saveLevelStart({GameSnapshot? current}) async {
    final restarted = restartHometown(
      current,
      Progress.newGame(openingSaved: false, gifts: gifts),
    );
    _restarted = restarted;
    return _saveRestarted(restarted);
  }

  /// A level other than Molfetta starts over where Mario first arrived in
  /// it, from [current], the game being played: only that city goes back
  /// to its start (see [restartCity]). Like Molfetta's restart it counts
  /// as a save, not a campfire one.
  Future<StepboundGame> restartCityLevel(GameSnapshot current) async {
    final restarted = restartCity(current);
    await _saveRestarted(restarted);
    return gameOf(
      world: restarted.world,
      story: restarted.story,
      progress: restarted.progress,
      hud: restarted.hud,
    );
  }

  Future<bool> _saveRestarted(RestartedLevel restarted) async {
    try {
      await saves.save(
        SaveGame(
          slot: slot,
          savedAt: DateTime.now(),
          place: levelStartPlace,
          world: restarted.world,
          story: restarted.story,
          progress: restarted.progress.toJson(),
          hud: restarted.hud,
          atCampfire: false,
          // The hours played are what starting over always keeps.
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
        ),
      );
    } on SaveWriteException catch (error, stack) {
      debugPrint('save: $error');
      lastSaveFailure = SaveFailure(
        error: error,
        stack: stack,
        place: snapshot.place,
        at: DateTime.now(),
      );
      return false;
    }
    resumePoint = snapshot.place == trainPlaceName
        ? ResumePoint.train
        : ResumePoint.campfire;
    game?.progress.confirmPendingMemories();
    return true;
  }

  /// Writes [snapshot], the game as it was put down, beside the slot's
  /// save, to be picked up from the menu; the campfire's save stays the
  /// one to go back to (see [StepboundGame.putDownSnapshot]). False when
  /// it could not be written.
  Future<bool> suspend(GameSnapshot snapshot) async {
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
        ),
      );
    } on SaveWriteException catch (error) {
      debugPrint('save: $error');
      return false;
    }
    return true;
  }

  /// The train takes Mario and Luigi to [level] from [snapshot], the game
  /// as the last level left it: the game picks up aboard, with the
  /// train's door onto that level's station, and is saved there. Mario's
  /// rounds, molotovs and rockets stay in the level he leaves (see
  /// [Progress.travel], [Progress.swapMolotovs] and
  /// [Progress.swapRockets]).
  StepboundGame startLevel(LevelId level, GameSnapshot snapshot) {
    final progress = Progress.fromJson(snapshot.progress);
    final world = restoreGameWorld(snapshot.world);
    final ammo = world.player.component<AmmoComponent>();
    ammo
      ..molotovs = progress.swapMolotovs(level, molotovs: ammo.molotovs)
      ..rockets = progress.swapRockets(level, rockets: ammo.rockets)
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
    progress.unlockedOutfits.addAll(gifts);
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
