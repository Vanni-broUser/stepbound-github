import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
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

void main() {
  SaveGame save({
    String place = 'Dietro la caserma',
    Map<String, Object?>? progress,
  }) => SaveGame(
    slot: 1,
    savedAt: DateTime(2026),
    place: place,
    world: saveTutorialWorld(createTutorialWorld()),
    tutorial: const <String, Object?>{},
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
      'tutorial',
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
      final world = saveTutorialWorld(createTutorialWorld());
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
