import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/save/published_save.dart';
import 'package:stepbound/save/save_game.dart';

/// Storage that cannot even be read, as a broken preferences store.
final class _UnreadableRepository extends StoredSaveRepository {
  @override
  Future<String?> readValue(String key) async =>
      throw StateError('storage gone');

  @override
  Future<void> writeValue(String key, String value) async =>
      throw StateError('storage gone');

  @override
  Future<void> removeValue(String key) async {}
}

/// Storage that writes but never removes, as a store that has stopped
/// answering to one call.
final class _StuckRepository extends StoredSaveRepository {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> readValue(String key) async => values[key];

  @override
  Future<void> writeValue(String key, String value) async =>
      values[key] = value;

  @override
  Future<void> removeValue(String key) async =>
      throw StateError('cannot remove');
}

void main() {
  SaveGame save({
    String place = 'Dietro la caserma',
    Map<String, Object?>? progress,
    DateTime? savedAt,
  }) => SaveGame(
    slot: 1,
    savedAt: savedAt ?? DateTime(2026),
    place: place,
    world: saveGameWorld(createGameWorld()),
    story: const <String, Object?>{},
    progress: progress ?? Progress.newGame().toJson(),
    hud: const <String>[],
    played: const Duration(hours: 2, minutes: 7, seconds: 3),
  );

  test('a save reads back as it was written', () async {
    final saves = MemorySaveRepository();
    await saves.save(save());
    final loaded = (await saves.load(1))!;
    expect(loaded.place, 'Dietro la caserma');
    expect(loaded.world['mapChanges'], isEmpty);
    expect(
      loaded.played,
      const Duration(hours: 2, minutes: 7, seconds: 3),
      reason: 'the hours played are stored to the second',
    );
    expect(await saves.read(1), isA<LoadedSave>());
  });

  test('a save keeps the memories in the order they were lived', () async {
    // The Duomo met, then the hypermarket, then the Duomo again: the
    // harbour and the mall can be played in any order, even interleaved.
    final progress = Progress.newGame()
      ..remember(StoryMemory.priestMet)
      ..remember(StoryMemory.luigiTrapped)
      ..remember(StoryMemory.priestErrand);
    final saves = MemorySaveRepository();
    await saves.save(save(progress: progress.toJson()));
    final loaded = Progress.fromJson((await saves.load(1))!.progress);
    expect(loaded.memories.toList(), <StoryMemory>[
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
      StoryMemory.priestMet,
      StoryMemory.luigiTrapped,
      StoryMemory.priestErrand,
    ]);
  });

  test('viewed story stays separate until a campfire or train confirms it', () {
    final progress = Progress(
      viewedMemories: const <StoryMemory>{StoryMemory.priestMet},
    );
    expect(progress.hasViewed(StoryMemory.priestMet), isTrue);
    expect(progress.hasExperienced(StoryMemory.priestMet), isFalse);
    expect(progress.memories, isEmpty);

    progress.view(StoryMemory.priestMet);
    expect(progress.hasExperienced(StoryMemory.priestMet), isTrue);
    expect(progress.memories, isEmpty, reason: 'not saved yet');
    expect(progress.toJson()['memories'], isEmpty);
    expect(progress.toJson(confirmPendingMemories: true)['memories'], <String>[
      StoryMemory.priestMet.name,
    ]);

    progress.confirmPendingMemories();
    expect(progress.memories, <StoryMemory>{StoryMemory.priestMet});
  });

  test(
    'story viewing history survives without becoming save progress',
    () async {
      final saves = MemorySaveRepository();
      await saves.saveStoryHistory(1, <StoryMemory>{
        StoryMemory.luigiTrapped,
        StoryMemory.priestMet,
      });

      expect(await saves.load(1), isNull);
      expect(await saves.loadStoryHistory(1), <StoryMemory>{
        StoryMemory.luigiTrapped,
        StoryMemory.priestMet,
      });

      await saves.clear(1);
      expect(await saves.loadStoryHistory(1), isEmpty);
    },
  );

  test('a save keeps the steps walked in each level and the fires lit', () {
    final progress = Progress.newGame()
      ..countStep()
      ..countStep()
      ..lightCampfire('Zona nord')
      ..level = LevelId.rome
      ..countStep();
    final loaded = Progress.fromJson(progress.toJson());
    expect(loaded.steps, <LevelId, int>{LevelId.hometown: 2, LevelId.rome: 1});
    expect(loaded.litCampfires, <String>{'Zona nord'});
  });

  test(
    'bullets stay in the level they were found in: the train arrives '
    'with those left there, never fewer than five, and a save keeps them',
    () {
      final progress = Progress.newGame();
      expect(progress.hasTravelled, isFalse);

      expect(progress.travel(LevelId.rome, rounds: 12), arrivalRounds);
      expect(progress.level, LevelId.rome);
      expect(progress.hasTravelled, isTrue);
      expect(
        progress.travel(LevelId.hometown, rounds: 3),
        12,
        reason: 'more than five left at home stay his',
      );
      expect(progress.travel(LevelId.rome, rounds: 1), arrivalRounds);
      expect(
        progress.travel(LevelId.hometown, rounds: 2),
        arrivalRounds,
        reason: 'the one left at home made up to five',
      );

      final loaded = Progress.fromJson(progress.toJson());
      expect(loaded.roundsLeft, <LevelId, int>{
        LevelId.hometown: 1,
        LevelId.rome: 2,
      });
      expect(loaded.hasTravelled, isTrue);
    },
  );

  test('a save keeps unlocked clothes and the outfit in use', () {
    final progress = Progress.newGame()
      ..unlockOutfit(PlayerOutfit.cultist)
      ..wearOutfit(PlayerOutfit.cultist);
    final loaded = Progress.fromJson(progress.toJson());

    expect(loaded.unlockedOutfits, <PlayerOutfit>{
      PlayerOutfit.base,
      PlayerOutfit.cultist,
    });
    expect(loaded.activeOutfit, PlayerOutfit.cultist);

    final oldSave = Progress.newGame().toJson()
      ..remove('unlockedOutfits')
      ..remove('activeOutfit');
    final migrated = Progress.fromJson(oldSave);
    expect(migrated.unlockedOutfits, <PlayerOutfit>{PlayerOutfit.base});
    expect(migrated.activeOutfit, PlayerOutfit.base);
  });

  group('the saves of the public build', () {
    const publicFormat = SaveGame.format - 1;
    String public() => jsonEncode(save().toJson()..['format'] = publicFormat);

    test('are migrated to the current format', () {
      final read = SaveGame.decode(
        public(),
        published: PublishedSaves(
          format: publicFormat,
          migrate: (old) => <String, Object?>{...old, 'place': 'Migrato'},
        ),
      );
      expect(read.game?.place, 'Migrato');
      expect(read.game?.toJson()['format'], SaveGame.format);
    });

    test('are damaged while the migration fails', () {
      final read = SaveGame.decode(
        public(),
        published: const PublishedSaves(format: publicFormat),
      );
      expect(
        (read as DamagedSave).reason,
        startsWith('cannot be migrated from format $publicFormat'),
      );
    });

    test('are the only older ones migrated', () {
      final older = jsonEncode(save().toJson()..['format'] = publicFormat - 1);
      final read = SaveGame.decode(
        older,
        published: PublishedSaves(format: publicFormat, migrate: (old) => old),
      );
      expect(read, isA<EmptySave>());
    });

    test('have no migration until one is written', () {
      expect(
        () => migratePublishedSave(save().toJson()),
        throwsUnsupportedError,
      );
    });
  });

  group('reading a slot', () {
    test('a save of another format reads as an empty slot', () {
      final older = save().toJson()..['format'] = SaveGame.format - 1;
      expect(SaveGame.decode(jsonEncode(older)), isA<EmptySave>());
      final newer = save().toJson()..['format'] = SaveGame.format + 1;
      expect(SaveGame.decode(jsonEncode(newer)), isA<EmptySave>());
      expect(() => SaveGame.fromJson(older), throwsFormatException);
    });

    test('nothing stored is an empty slot', () {
      expect(SaveGame.decode(null), isA<EmptySave>());
    });

    test('truncated JSON is a damaged save, not an exception', () {
      final encoded = jsonEncode(save().toJson());
      final read = SaveGame.decode(encoded.substring(0, encoded.length ~/ 2));
      expect(read, isA<DamagedSave>());
    });

    test('JSON that is not a save object is damaged', () {
      expect(SaveGame.decode('[1, 2, 3]'), isA<DamagedSave>());
      expect(SaveGame.decode('"slot 1"'), isA<DamagedSave>());
      expect(SaveGame.decode('{}'), isA<DamagedSave>(), reason: 'no format');
    });

    for (final field in <String>[
      'slot',
      'savedAt',
      'place',
      'world',
      'story',
      'progress',
      'hud',
      'atCampfire',
      'played',
    ]) {
      test('a missing "$field" is a damaged save naming it', () {
        final read = SaveGame.decode(
          jsonEncode(save().toJson()..remove(field)),
        );
        expect(read, isA<DamagedSave>());
        expect((read as DamagedSave).reason, contains(field));
      });
    }

    test('a field of the wrong type is a damaged save, not a type error', () {
      for (final (field, value) in <(String, Object?)>[
        ('slot', '1'),
        ('slot', 9),
        ('savedAt', 'yesterday'),
        ('world', <Object?>[]),
        ('hud', <Object?>['interact', 3]),
        ('atCampfire', 'yes'),
        ('played', -5),
      ]) {
        final json = save().toJson()..[field] = value;
        expect(
          SaveGame.decode(jsonEncode(json)),
          isA<DamagedSave>(),
          reason: '$field: $value',
        );
      }
    });

    test('an unknown zombie type or tile kind is caught before the game '
        'loads it', () {
      final zombies = save().toJson()
        ..['progress'] = <String, Object?>{
          'knownZombies': <String>['dragon'],
          'memories': <String>[],
        };
      expect(
        SaveGame.decode(jsonEncode(zombies), check: checkRestorable),
        isA<DamagedSave>(),
      );
      final world = saveGameWorld(createGameWorld());
      world['mapChanges'] = <Object?>[
        <String, Object?>{'x': 1, 'y': 1, 'kind': 'lava'},
      ];
      final tiles = save().toJson()..['world'] = world;
      expect(
        SaveGame.decode(jsonEncode(tiles), check: checkRestorable),
        isA<DamagedSave>(),
      );
      // The save's own fields alone look fine: only the check sees it.
      expect(SaveGame.decode(jsonEncode(tiles)), isA<LoadedSave>());
    });

    test('a story flag of the wrong type is damaged, not a crash at the '
        'start of the game', () {
      for (final story in <Map<String, Object?>>[
        <String, Object?>{
          'street': <String, Object?>{'zombieLesson': 'yes'},
        },
        <String, Object?>{'duomo': 'ringDelivered'},
      ]) {
        final json = save().toJson()..['story'] = story;
        expect(
          SaveGame.decode(jsonEncode(json), check: checkRestorable),
          isA<DamagedSave>(),
          reason: '$story',
        );
        // The save's own fields alone look fine: only the check sees it.
        expect(SaveGame.decode(jsonEncode(json)), isA<LoadedSave>());
      }
    });

    test('a world with its entities missing is damaged', () {
      final json = save().toJson()
        ..['world'] = <String, Object?>{'mapChanges': <Object?>[]};
      expect(
        SaveGame.decode(jsonEncode(json), check: checkRestorable),
        isA<DamagedSave>(),
      );
    });

    test('storage that cannot be read makes every slot damaged, and the '
        'list still comes back', () async {
      final slots = await _UnreadableRepository().all();
      expect(slots, hasLength(SaveRepository.slotCount));
      expect(slots, everyElement(isA<DamagedSave>()));
    });
  });

  group('the backup', () {
    test('a damaged save falls back on the good one it replaced', () async {
      final saves = MemorySaveRepository();
      await saves.save(save(place: 'Il porto'));
      await saves.save(save());
      // The newer one gets cut short on its way to the disk.
      final key = StoredSaveRepository.slotKey(1);
      saves.values[key] = saves.values[key]!.substring(0, 100);

      final read = await saves.read(1);
      expect(read, isA<LoadedSave>());
      expect((read as LoadedSave).fromBackup, isTrue);
      expect(read.save.place, 'Il porto');
      expect((await saves.load(1))!.place, 'Il porto');
    });

    test('a damaged save never replaces the backup', () async {
      final saves = MemorySaveRepository();
      await saves.save(save(place: 'Il porto'));
      await saves.save(save());
      saves.values[StoredSaveRepository.slotKey(1)] = '{';
      await saves.save(save(place: 'La stazione'));
      saves.values[StoredSaveRepository.slotKey(1)] = '{';
      expect((await saves.load(1))!.place, 'Il porto');
    });

    test('with no good backup either, the slot is damaged', () async {
      final saves = MemorySaveRepository();
      saves.values[StoredSaveRepository.slotKey(1)] = '{';
      expect(await saves.read(1), isA<DamagedSave>());
      expect(await saves.load(1), isNull);
    });

    test('a new game in the slot clears the backup too', () async {
      final saves = MemorySaveRepository();
      await saves.save(save(place: 'Il porto'));
      await saves.save(save());
      await saves.clear(1);
      expect(saves.values, isEmpty);
      expect(await saves.read(1), isA<EmptySave>());
    });
  });

  group('the game put down', () {
    test(
      'is what the menu reads, while the fire is what is gone back to',
      () async {
        final saves = MemorySaveRepository();
        await saves.save(save(place: 'Il porto'));
        await saves.suspend(save(place: 'Via del porto'));
        final read = await saves.read(1);
        expect(read, isA<LoadedSave>());
        expect((read as LoadedSave).suspended, isTrue);
        expect(read.save.place, 'Via del porto');
        expect((await saves.load(1))!.place, 'Il porto');
        expect((await saves.all()).first, isA<LoadedSave>());
      },
    );

    test('can be put down with no fire behind it', () async {
      final saves = MemorySaveRepository();
      await saves.suspend(save(place: 'Via del porto'));
      expect((await saves.read(1)).game!.place, 'Via del porto');
      expect(await saves.load(1), isNull);
    });

    test(
      'goes with the next campfire, or with going back to the fire',
      () async {
        final saves = MemorySaveRepository();
        await saves.save(save(place: 'Il porto'));
        await saves.suspend(save(place: 'Via del porto'));
        await saves.save(save(place: 'La stazione'));
        expect((await saves.read(1)).game!.place, 'La stazione');
        expect((await saves.read(1) as LoadedSave).suspended, isFalse);

        await saves.suspend(save(place: 'Via del porto'));
        await saves.clearSuspended(1);
        expect((await saves.read(1)).game!.place, 'La stazione');
        expect((await saves.read(1) as LoadedSave).suspended, isFalse);
      },
    );

    test('older than the fire is left aside: the fire wrote over it', () async {
      final saves = MemorySaveRepository();
      await saves.suspend(
        save(place: 'Via del porto', savedAt: DateTime(2026, 9, 30, 10)),
      );
      // As if the fire's save had gone through but not the dropping of
      // the game put down: written straight, past `save`.
      saves.values[StoredSaveRepository.slotKey(1)] = jsonEncode(
        save(place: 'Il porto', savedAt: DateTime(2026, 9, 30, 11)).toJson(),
      );
      final read = await saves.read(1);
      expect(read.game!.place, 'Il porto');
      expect((read as LoadedSave).suspended, isFalse);
      expect((await saves.all()).first.game!.place, 'Il porto');
    });

    test('as old as the fire is still the game put down', () async {
      final saves = MemorySaveRepository();
      await saves.save(save(place: 'Il porto'));
      saves.values[StoredSaveRepository.suspendedKey(1)] = jsonEncode(
        save(place: 'Via del porto').toJson(),
      );
      expect((await saves.read(1)).game!.place, 'Via del porto');
    });

    test(
      'that the fire cannot drop is no failed save, and stays aside',
      () async {
        final saves = _StuckRepository();
        await saves.suspend(
          save(place: 'Via del porto', savedAt: DateTime(2026, 9, 30, 10)),
        );
        await saves.save(
          save(place: 'Il porto', savedAt: DateTime(2026, 9, 30, 11)),
        );
        expect(
          saves.values,
          contains(StoredSaveRepository.suspendedKey(1)),
          reason: 'still there',
        );
        final read = await saves.read(1);
        expect(read.game!.place, 'Il porto');
        expect((read as LoadedSave).suspended, isFalse);
        expect((await saves.load(1))!.place, 'Il porto');
      },
    );

    test('damaged, leaves the fire to play', () async {
      final saves = MemorySaveRepository();
      await saves.save(save(place: 'Il porto'));
      saves.values[StoredSaveRepository.suspendedKey(1)] = '{';
      final read = await saves.read(1);
      expect(read.game!.place, 'Il porto');
      expect((read as LoadedSave).suspended, isFalse);
    });

    test('is wiped with the slot', () async {
      final saves = MemorySaveRepository();
      await saves.save(save(place: 'Il porto'));
      await saves.suspend(save(place: 'Via del porto'));
      await saves.clear(1);
      expect(saves.values, isEmpty);
    });

    test('that cannot be written is a SaveWriteException', () async {
      final saves = MemorySaveRepository()..failWrites = true;
      await expectLater(
        saves.suspend(save()),
        throwsA(isA<SaveWriteException>()),
      );
    });
  });

  group('on the device', () {
    setUp(
      () => SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty(),
    );

    test('saves go through the preferences, backup and all', () async {
      final saves = PreferencesSaveRepository();
      await saves.save(save(place: 'Il porto'));
      await saves.save(save());
      final preferences = SharedPreferencesAsync();
      expect(
        await preferences.getString(StoredSaveRepository.slotKey(1)),
        contains('Dietro la caserma'),
      );
      expect(
        await preferences.getString(StoredSaveRepository.backupKey(1)),
        contains('Il porto'),
      );
      expect((await saves.load(1))!.place, 'Dietro la caserma');
      expect((await saves.all()).whereType<EmptySave>(), hasLength(3));

      await saves.clear(1);
      expect(await preferences.getKeys(), isEmpty);
    });

    test('a slot damaged on the device falls back on its backup', () async {
      final saves = PreferencesSaveRepository(
        preferences: SharedPreferencesAsync(),
      );
      await saves.save(save(place: 'Il porto'));
      await saves.save(save());
      await SharedPreferencesAsync().setString(
        StoredSaveRepository.slotKey(1),
        '{"format"',
      );
      expect((await saves.load(1))!.place, 'Il porto');
    });
  });

  group('a failed write', () {
    test('throws a SaveWriteException and leaves the slot as it was', () async {
      final saves = MemorySaveRepository();
      await saves.save(save(place: 'Il porto'));
      saves.failWrites = true;
      await expectLater(
        saves.save(save()),
        throwsA(
          isA<SaveWriteException>().having((error) => error.slot, 'slot', 1),
        ),
      );
      expect((await saves.load(1))!.place, 'Il porto');
    });

    test('from storage that is gone is a SaveWriteException too', () async {
      await expectLater(
        _UnreadableRepository().save(save()),
        throwsA(isA<SaveWriteException>()),
      );
    });
  });
}
