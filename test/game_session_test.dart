import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/game_session.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/pause_menu.dart';

void main() {
  late MemorySaveRepository saves;
  late List<GameSnapshot> completed;
  late GameSession session;

  setUp(() {
    saves = MemorySaveRepository();
    completed = <GameSnapshot>[];
    session = GameSession(
      saves: saves,
      audio: SilentAudio(),
      onLevelCompleted: (snapshot, {required saved}) => completed.add(snapshot),
      onTravelMapRequested: completed.add,
    );
  });

  GameSnapshot snapshot({String place = 'Dietro la caserma'}) => (
    world: saveGameWorld(createGameWorld()),
    story: const <String, Object?>{},
    progress: Progress.newGame().toJson(),
    hud: const <String>['interact'],
    place: place,
  );

  SaveGame checkpoint({int slot = 2, String place = 'Dietro la caserma'}) =>
      SaveGame(
        slot: slot,
        savedAt: DateTime(2026),
        place: place,
        world: saveGameWorld(createGameWorld()),
        story: const <String, Object?>{},
        progress: Progress.newGame().toJson(),
        hud: const <String>['interact'],
        played: const Duration(hours: 1),
      );

  test('a new game takes the slot over, whatever it held', () async {
    await saves.save(checkpoint(slot: 3));
    session
      ..resumePoint = ResumePoint.campfire
      ..levelStart = LevelStart(
        world: snapshot().world,
        story: const <String, Object?>{},
        progress: Progress().toJson(),
        hud: const <String>[],
      )
      ..rememberStory(StoryMemory.newsBroadcast);
    await session.startNew(3);
    expect(session.slot, 3);
    expect(session.resumePoint, isNull);
    expect(session.levelStart, isNull);
    expect(session.storyHistory, isEmpty);
    expect(session.played, lessThan(const Duration(seconds: 1)));
    expect(await saves.read(3), isA<EmptySave>());

    final game = session.newGame();
    expect(game.inputLocked, isTrue);
    expect(session.openingStorySeen, isTrue);
    // The history is written on its own time.
    await Future<void>.delayed(Duration.zero);
    expect(
      await saves.loadStoryHistory(3),
      containsAll(<StoryMemory>[
        StoryMemory.newsBroadcast,
        StoryMemory.outbreakNight,
      ]),
    );
  });

  test('a campfire writes the slot and is the place to go back to', () async {
    session.slot = 2;
    expect(await session.store(snapshot()), isTrue);
    expect(session.resumePoint, ResumePoint.campfire);
    expect((await saves.load(2))!.place, 'Dietro la caserma');

    expect(await session.store(snapshot(place: trainPlaceName)), isTrue);
    expect(session.resumePoint, ResumePoint.train);
  });

  test('a campfire that cannot be written leaves the slot and the resume '
      'point as they were', () async {
    session.slot = 2;
    await session.store(snapshot());
    saves.failWrites = true;
    expect(await session.store(snapshot(place: trainPlaceName)), isFalse);
    expect(session.resumePoint, ResumePoint.campfire);
    expect((await saves.load(2))!.place, 'Dietro la caserma');
  });

  test(
    'a save loaded from the menu sets the slot, the fire and the clock',
    () async {
      await saves.save(checkpoint());
      final save = (await saves.load(2))!;
      final game = await session.load(save);
      expect(game, isA<StepboundGame>());
      expect(session.slot, 2);
      expect(session.resumePoint, ResumePoint.campfire);
      expect(session.played, greaterThanOrEqualTo(const Duration(hours: 1)));
    },
  );

  test(
    'a game put down is loaded as it was, with the fire behind it',
    () async {
      await saves.save(checkpoint());
      await saves.suspend(
        SaveGame(
          slot: 2,
          savedAt: DateTime(2026, 1, 2),
          place: 'Città natale',
          world: saveGameWorld(createGameWorld()),
          story: const <String, Object?>{},
          progress: Progress.newGame().toJson(),
          hud: const <String>['interact'],
          atCampfire: false,
        ),
      );
      final putDown = (await saves.read(2)).game!;
      expect(putDown.atCampfire, isFalse);
      await session.load(putDown);
      expect(
        session.resumePoint,
        ResumePoint.campfire,
        reason: "the slot's own save is a campfire's",
      );
    },
  );

  test('going back to the fire gives up the game put down, and starts the '
      'level over when there is no fire', () async {
    session.slot = 2;
    expect(await session.resumeFromCheckpoint(), isNull);

    await saves.save(checkpoint());
    await saves.suspend(checkpoint(place: 'Città natale'));
    final game = await session.resumeFromCheckpoint();
    expect(game, isNotNull);
    expect((await saves.read(2) as LoadedSave).suspended, isFalse);
  });

  test(
    'starting Molfetta over saves its start, keeping only the hours',
    () async {
      session.slot = 2;
      await session.store(snapshot());
      expect(await session.saveLevelStart(), isTrue);
      expect(session.resumePoint, isNull);
      final start = (await saves.load(2))!;
      expect(start.place, GameSession.levelStartPlace);
      expect(start.atCampfire, isFalse);
      expect(start.hud, isEmpty);

      saves.failWrites = true;
      session.resumePoint = ResumePoint.campfire;
      expect(await session.saveLevelStart(), isFalse);
      expect(session.resumePoint, ResumePoint.campfire);
    },
  );

  test('starting Molfetta over keeps the secret missions done, and the '
      'golden pistol with them', () async {
    session.slot = 2;
    await session.store(snapshot());
    expect(
      await session.saveLevelStart(
        secretMissions: const <SecretMission>{SecretMission.unarmedToLuigi},
      ),
      isTrue,
    );
    final start = Progress.fromJson((await saves.load(2))!.progress);
    expect(start.hasGoldenPistol, isTrue);
    expect(session.newGame().progress.hasGoldenPistol, isTrue);

    await session.startNew(2);
    expect(
      session.newGame().progress.hasGoldenPistol,
      isFalse,
      reason: 'a new game in the slot starts with nothing',
    );
  });

  test('another level starts over where Mario arrived in it', () async {
    session.slot = 2;
    final start = LevelStart(
      world: snapshot().world,
      story: const <String, Object?>{},
      progress: Progress(level: LevelId.rome).toJson(),
      hud: const <String>['interact', 'ammo'],
    );
    session.resumePoint = ResumePoint.campfire;
    final game = await session.restartFrom(start);
    expect(game.progress.level, LevelId.rome);
    expect(session.resumePoint, isNull);
    final saved = (await saves.load(2))!;
    expect(saved.place, GameSession.levelStartPlace);
    expect(saved.levelStart, isNotNull);
    expect(saved.hud, <String>['interact', 'ammo']);
  });

  test(
    'the train to Rome saves the arrival as where Rome starts over',
    () async {
      session.slot = 2;
      final game = session.startLevel(
        LevelId.rome,
        snapshot(place: trainPlaceName),
      );
      expect(game.progress.level, LevelId.rome);
      expect(game.progress.memories, contains(StoryMemory.presidentFled));
      expect(session.levelStart, isNotNull);
      expect(
        game.simulation.player.component<PositionComponent>().position,
        trainMapStandTile,
      );
      await Future<void>.delayed(Duration.zero);
      expect((await saves.load(2))!.place, trainPlaceName);
      expect(session.resumePoint, ResumePoint.train);

      session.startLevel(LevelId.hometown, snapshot(place: trainPlaceName));
      expect(
        session.levelStart,
        isNull,
        reason: 'Molfetta starts from its story',
      );
    },
  );

  test('a save that cannot be written is kept for the report', () async {
    expect(session.lastSaveFailure, isNull);
    saves.failWrites = true;
    expect(await session.store(snapshot(place: 'Zona nord')), isFalse);
    final failure = session.lastSaveFailure!;
    expect(failure.place, 'Zona nord');
    expect(failure.error, isA<SaveWriteException>());
    expect('${failure.error}', contains('storage full'));
    expect(failure.at.year, greaterThanOrEqualTo(2026));
  });

  test('story scenes watched are written down for the slot at once', () async {
    session
      ..slot = 4
      ..rememberStories(const <StoryMemory>{StoryMemory.luigiTrapped})
      ..rememberStory(StoryMemory.luigiTrapped);
    await Future<void>.delayed(Duration.zero);
    expect(await saves.loadStoryHistory(4), <StoryMemory>{
      StoryMemory.luigiTrapped,
    });
    expect(session.openingStorySeen, isFalse);
  });
}
