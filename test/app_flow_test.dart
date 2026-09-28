import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app_flow.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/report/breadcrumbs.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/main_menu.dart';

void main() {
  late MemorySaveRepository saves;
  late SilentAudio audio;
  late Breadcrumbs trail;
  late AppFlowController flow;
  late int changes;

  setUp(() {
    saves = MemorySaveRepository();
    audio = SilentAudio();
    trail = Breadcrumbs();
    changes = 0;
    flow = AppFlowController(saves: saves, audio: audio, trail: trail)
      ..addListener(() => changes++);
  });

  tearDown(() => flow.dispose());

  SaveGame campfire({int slot = 1, Progress? progress}) => SaveGame(
    slot: slot,
    savedAt: DateTime(2026),
    place: 'Porto',
    world: saveGameWorld(createGameWorld()),
    story: const <String, Object?>{},
    progress: (progress ?? Progress.newGame()).toJson(),
    hud: const <String>['interact'],
    played: const Duration(minutes: 30),
  );

  GameSnapshot aboard({Progress? progress}) => (
    world: saveGameWorld(createGameWorld()),
    story: const <String, Object?>{},
    progress: (progress ?? Progress.newGame()).toJson(),
    hud: const <String>[],
    place: trainPlaceName,
  );

  test('starts on the menu with nothing on the stage', () {
    expect(flow.phase, AppPhase.menu);
    expect(flow.game, isNull);
    expect(flow.results, isNull);
    expect(flow.showsGame, isFalse);
    expect(changes, 0);
  });

  test('a new game plays the story, then Mario speaks, then plays', () async {
    await flow.newGame(2);
    expect(flow.phase, AppPhase.story);
    expect(flow.session.slot, 2);
    expect(audio.music, Music.story);
    expect(changes, 1);

    flow.finishIntro();
    expect(flow.phase, AppPhase.outbreak);
    expect(flow.game, isNull);

    flow.finishOutbreak();
    expect(flow.phase, AppPhase.dialogue);
    expect(flow.game, isNotNull);
    expect(flow.game!.inputLocked, isTrue);
    expect(flow.showsGame, isTrue);

    flow.finishDialogue();
    expect(flow.phase, AppPhase.playing);
    expect(flow.game!.inputLocked, isFalse);
    expect(changes, 4);
    expect(
      trail.entries.map((entry) => entry.text),
      containsAll(<String>[
        'app: nuova partita nello slot 2',
        'app: la storia finisce, il gioco comincia',
      ]),
    );
  });

  test('a loaded game goes straight to playing', () async {
    final save = campfire(slot: 3);
    await saves.save(save);
    await flow.loadGame(save);
    expect(flow.phase, AppPhase.playing);
    expect(flow.game, isNotNull);
    expect(flow.session.slot, 3);
    expect(flow.loadingFadesIn, isFalse);
  });

  test('back to the menu drops the game and tells about the link', () async {
    await flow.newGame(1);
    flow
      ..finishIntro()
      ..finishOutbreak()
      ..backToMenu(linkNotice: const InvalidLinkNotice());
    expect(flow.phase, AppPhase.menu);
    expect(flow.game, isNull);
    expect(flow.linkNotice, isA<InvalidLinkNotice>());
    expect(flow.linkNoticeRevision, 1);
    expect(audio.music, Music.menu);

    flow.backToMenu();
    expect(flow.linkNotice, isNull);
    expect(flow.linkNoticeRevision, 1, reason: 'no notice, no new menu');
  });

  test('a new game clears the notice', () async {
    flow.backToMenu(linkNotice: const SkinGiftNotice(PlayerOutfit.ghost));
    await flow.newGame(1);
    expect(flow.linkNotice, isNull);
  });

  test('a gift goes to the slot and to the game being played', () async {
    await flow.newGame(1);
    flow
      ..finishIntro()
      ..finishOutbreak()
      ..giveOutfit(PlayerOutfit.cultist);
    expect(flow.session.gifts, contains(PlayerOutfit.cultist));
    expect(flow.game!.progress.unlockedOutfits, contains(PlayerOutfit.cultist));
  });

  test('the level’s end shows its results, then the map', () {
    final progress = Progress.newGame();
    flow.completeLevel(aboard(progress: progress), saved: false);
    expect(flow.phase, AppPhase.levelComplete);
    expect(flow.game, isNull);
    final results = flow.results!;
    expect(results.saveFailed, isTrue);
    expect(results.finale, Mission.finaleOf(progress.level));
    expect(results.secret, isNull);
    expect(audio.music, Music.story);

    flow.openLevelMap();
    expect(flow.phase, AppPhase.levelMap);
  });

  test('the secret mission is on the results when the story says so', () {
    final snapshot = aboard();
    flow.completeLevel((
      world: snapshot.world,
      story: const <String, Object?>{
        'station': <String, Object?>{'goldenPistol': true},
      },
      progress: snapshot.progress,
      hud: snapshot.hud,
      place: snapshot.place,
    ), saved: true);
    expect(flow.results!.secret, SecretMission.unarmedToLuigi);
    expect(flow.results!.saveFailed, isFalse);
  });

  test('from the map, the hometown starts at once', () {
    flow
      ..travelFromTrain(aboard())
      ..startHometown();
    expect(flow.phase, AppPhase.playing);
    expect(flow.game!.progress.level, LevelId.hometown);
    expect(flow.loadingFadesIn, isFalse);
  });

  test('the map opened aboard leaves the game for the map', () {
    flow.travelFromTrain(aboard());
    expect(flow.phase, AppPhase.levelMap);
    expect(flow.game, isNull);
    expect(flow.results, isNull);
  });

  test('Rome plays its story the first time, and only then', () {
    flow
      ..travelFromTrain(aboard())
      ..startRome();
    expect(flow.phase, AppPhase.romeStory);
    expect(flow.game, isNull);

    flow.finishRomeStory();
    expect(flow.phase, AppPhase.playing);
    expect(flow.game!.progress.level, LevelId.rome);
    expect(flow.loadingFadesIn, isTrue, reason: 'out of the story’s black');
    expect(flow.session.storyHistory, contains(StoryMemory.presidentFled));

    final seen = Progress.newGame()..remember(StoryMemory.presidentFled);
    flow
      ..travelFromTrain(aboard(progress: seen))
      ..startRome();
    expect(flow.phase, AppPhase.playing);
    expect(flow.loadingFadesIn, isFalse);
  });

  test('the map does nothing without a train to come from', () {
    flow
      ..startHometown()
      ..startRome();
    expect(flow.phase, AppPhase.menu);
    expect(changes, 0);
  });

  test('going back to a fire that is gone starts the level over', () async {
    await flow.newGame(1);
    flow
      ..finishIntro()
      ..finishOutbreak()
      ..finishDialogue();
    await flow.resumeFromCamp();
    expect(flow.phase, AppPhase.story, reason: 'Molfetta from the first scene');
    expect(flow.game, isNull);
    expect(await saves.read(1), isA<LoadedSave>());
  });

  test('going back to the fire loads its save', () async {
    await saves.save(campfire());
    await flow.newGame(2);
    flow.session.slot = 1;
    await flow.resumeFromCamp();
    expect(flow.phase, AppPhase.playing);
    expect(flow.game, isNotNull);
  });

  test('a level that starts where Mario arrived restarts there', () async {
    final seen = Progress.newGame()..remember(StoryMemory.presidentFled);
    flow
      ..travelFromTrain(aboard(progress: seen))
      ..startRome();
    expect(flow.session.levelStart, isNotNull);
    final rome = flow.game;
    await flow.restartLevel();
    expect(flow.phase, AppPhase.playing);
    expect(flow.game, isNot(same(rome)));
    expect(flow.game!.progress.level, LevelId.rome);
  });

  test('leaving the front silences the game and writes it down once', () {
    flow.leftFront();
    expect(audio.paused, isTrue);
    expect(flow.putDown, isTrue);
    flow.leftFront();
    expect(flow.putDown, isTrue);

    flow.cameToFront();
    expect(audio.paused, isFalse);
    expect(flow.putDown, isFalse);
  });

  test('nothing is written down unless a game is playing', () async {
    await flow.newGame(1);
    flow
      ..finishIntro()
      ..finishOutbreak();
    await flow.suspend();
    expect(
      await saves.read(1),
      isA<EmptySave>(),
      reason: 'Mario still speaking: not a state to come back to',
    );
  });

  test('nothing happens after dispose', () async {
    final later = AppFlowController(saves: saves, audio: audio, trail: trail);
    final starting = later.newGame(1);
    later.dispose();
    await starting;
    expect(later.phase, AppPhase.menu);
  });
}
