import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/silent_story_host.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/save/published_save.dart';

/// Everything needed to resume a game from a campfire.
final class SaveGame {
  const SaveGame({
    required this.slot,
    required this.savedAt,
    required this.place,
    required this.world,
    required this.story,
    required this.progress,
    required this.hud,
    this.atCampfire = true,
    this.played = Duration.zero,
  });

  /// Reads a save of the current [format], checking every field: anything
  /// missing or of the wrong type is a [FormatException] naming the field,
  /// never a type error escaping from a cast.
  factory SaveGame.fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const FormatException('A save of another format');
    }
    final fields = _Fields(json);
    final slot = fields.read<int>('slot');
    if (slot < 1 || slot > SaveRepository.slotCount) {
      throw FormatException('No slot $slot');
    }
    final savedAt = DateTime.tryParse(fields.read<String>('savedAt'));
    if (savedAt == null) {
      throw const FormatException('"savedAt" is not a date');
    }
    final hud = fields.read<List<Object?>>('hud');
    if (hud.any((name) => name is! String)) {
      throw const FormatException('"hud" holds something else than names');
    }
    final played = fields.read<int>('played');
    if (played < 0) {
      throw const FormatException('"played" is negative');
    }
    return SaveGame(
      slot: slot,
      savedAt: savedAt,
      place: fields.read<String>('place'),
      world: fields.read<Map<String, Object?>>('world'),
      story: fields.read<Map<String, Object?>>('story'),
      progress: fields.read<Map<String, Object?>>('progress'),
      hud: hud.cast<String>(),
      atCampfire: fields.read<bool>('atCampfire'),
      played: Duration(seconds: played),
    );
  }

  /// What [encoded], as a slot stores it, holds: nothing, a save that can
  /// be played, or a damaged one. It never throws. A save of the last
  /// public build, [published], is migrated; one of any other [format]
  /// reads as empty, like no save at all. [check] is asked whether a save
  /// that reads well can really be played (see [checkRestorable]); whatever
  /// it throws makes the save a damaged one.
  static SaveRead decode(
    String? encoded, {
    SaveCheck? check,
    PublishedSaves published = const PublishedSaves(),
  }) {
    if (encoded == null) {
      return const EmptySave();
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return const DamagedSave('not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      return const DamagedSave('not a JSON object');
    }
    var json = decoded;
    final version = json['format'];
    if (version is! int) {
      return const DamagedSave('no format');
    }
    if (version != format) {
      if (version != published.format) {
        return const EmptySave();
      }
      try {
        json = <String, Object?>{...published.migrate(json), 'format': format};
      } on Object catch (error) {
        return DamagedSave('cannot be migrated from format $version: $error');
      }
    }
    final SaveGame save;
    try {
      save = SaveGame.fromJson(json);
    } on FormatException catch (error) {
      return DamagedSave(error.message);
    }
    try {
      check?.call(save);
    } on Object catch (error) {
      return DamagedSave('cannot be played: $error');
    }
    return LoadedSave(save);
  }

  /// Bump it whenever what a save holds changes. Saves of the formats in
  /// between public builds are dropped, never migrated; those of the last
  /// public build are, see `docs/save_policy.md`.
  static const int format = 49;

  /// 1 to [SaveRepository.slotCount].
  final int slot;
  final DateTime savedAt;

  /// Where the save was made, as shown in the slot list.
  final String place;

  /// The simulation, as `saveGameWorld`.
  final Map<String, Object?> world;

  /// What the story's scripts have done, as `StoryDirector.toJson`.
  final Map<String, Object?> story;

  /// The zombie types met and the story scenes seen, as `Progress.toJson`.
  final Map<String, Object?> progress;

  /// Names of the unlocked touch controls.
  final List<String> hud;

  /// Whether a campfire wrote this save. Every save is one except the
  /// slot written when the level starts over: there is no fire to go back
  /// to from that one, so the menus do not offer it.
  final bool atCampfire;

  /// How long this game has been played, counting from the very start
  /// of it. It is the one thing starting the level over at a camp does
  /// not throw away, and it only moves while the game is in front: a
  /// phone in a pocket is not play. Like everything else here it is
  /// only as fresh as the last save.
  final Duration played;

  SaveGame copyWith({int? slot}) => SaveGame(
    slot: slot ?? this.slot,
    savedAt: savedAt,
    place: place,
    world: world,
    story: story,
    progress: progress,
    hud: hud,
    atCampfire: atCampfire,
    played: played,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'slot': slot,
    'savedAt': savedAt.toIso8601String(),
    'place': place,
    'world': world,
    'story': story,
    'progress': progress,
    'hud': hud,
    'atCampfire': atCampfire,
    'played': played.inSeconds,
  };
}

/// The fields of a save, each read as the type it must have.
final class _Fields {
  const _Fields(this._json);

  final Map<String, Object?> _json;

  T read<T>(String name) {
    final value = _json[name];
    if (value is! T) {
      throw FormatException(
        value == null
            ? '"$name" is missing'
            : '"$name" is a ${value.runtimeType}, not a $T',
      );
    }
    return value;
  }
}

/// Throws unless a save can be played. [SaveGame.decode] only looks at the
/// save's own fields; a check rebuilds what the game will rebuild from
/// them, so that a slot the menu shows as a save is one that loads.
typedef SaveCheck = void Function(SaveGame save);

/// The [SaveCheck] of the game: the world, the progress and the story's
/// scripts rebuild, as they do when the game starts. What they throw (a
/// missing field, a zombie type or a tile kind the game does not know, a
/// script's flag of the wrong type) marks the save as damaged.
void checkRestorable(SaveGame save) {
  StoryDirector(
    world: restoreGameWorld(save.world),
    host: const SilentStoryHost(),
    progress: Progress.fromJson(save.progress),
  ).restore(save.story);
}

/// What a slot holds, read back.
sealed class SaveRead {
  const SaveRead();

  /// The save to play, when there is one.
  SaveGame? get game => null;
}

/// Nothing, or a save of another format.
final class EmptySave extends SaveRead {
  const EmptySave();
}

/// A save that can be played. [fromBackup] when the slot's own save was
/// damaged and this is the good one it had replaced; [suspended] when it
/// is the game as it was put down, not the last campfire (see
/// [SaveRepository.suspend]).
final class LoadedSave extends SaveRead {
  const LoadedSave(
    this.save, {
    this.fromBackup = false,
    this.suspended = false,
  });

  final SaveGame save;
  final bool fromBackup;
  final bool suspended;

  @override
  SaveGame get game => save;
}

/// Something that is not a save that can be played, with no earlier one to
/// fall back on. [reason] is for the logs.
final class DamagedSave extends SaveRead {
  const DamagedSave(this.reason);

  final String reason;
}

/// A save that could not be written. The slot still holds what it held.
final class SaveWriteException implements Exception {
  const SaveWriteException(this.slot, this.cause);

  final int slot;
  final Object cause;

  @override
  String toString() => 'Could not write save slot $slot: $cause';
}

/// The four save slots.
abstract interface class SaveRepository {
  static const int slotCount = 4;

  /// Every slot in order, as [read] gives them.
  Future<List<SaveRead>> all();

  /// What [slot] holds for the menu: the game as it was put down, if it
  /// was put down since the last campfire, else the campfire's save.
  /// Never throws: storage that cannot be read makes the slot a damaged
  /// one.
  Future<SaveRead> read(int slot);

  /// The save in [slot] to go back to: the last campfire's (or the
  /// train's), never the game as it was put down. Null when there is
  /// none to play.
  Future<SaveGame?> load(int slot);

  /// Writes [game] in its slot, keeping the save it replaces as a backup,
  /// and drops the game put down since: this is newer. Throws a
  /// [SaveWriteException] when it cannot.
  Future<void> save(SaveGame game);

  /// Writes [game] beside its slot's save, as the game put down: what
  /// the app was doing when it went to the background, to be picked up
  /// from the menu. The slot's own save, the campfire to go back to,
  /// stays as it is; the next campfire, or going back to it, drops this.
  /// Throws a [SaveWriteException] when it cannot.
  Future<void> suspend(SaveGame game);

  /// Drops the game put down in [slot], if any: the player went back to
  /// the campfire instead.
  Future<void> clearSuspended(int slot);

  /// Empties [slot], backup and game put down included. Its gifts stay:
  /// see [loadGifts].
  Future<void> clear(int slot);

  /// The skins given to [slot] by gift links: the game saved there has
  /// them, or the one started there next if it was empty. A game started
  /// over one that is saved there drops them (see `GameSession.startNew`).
  Future<Set<PlayerOutfit>> loadGifts(int slot);

  /// Replaces the gifts of [slot]. Throws a [SaveWriteException] when it
  /// cannot.
  Future<void> saveGifts(int slot, Set<PlayerOutfit> gifts);

  /// Story sequences watched on [slot], even when the attempt that showed
  /// them ended before a campfire or the train saved the game.
  Future<Set<StoryMemory>> loadStoryHistory(int slot);

  /// Replaces the lightweight viewing history for [slot]. It only enables
  /// skipping repeated scenes; it is not part of the saved game progress.
  Future<void> saveStoryHistory(int slot, Set<StoryMemory> memories);
}

/// A [SaveRepository] over a store of strings: each slot's save under
/// [slotKey], and under [backupKey] the last good save it replaced, which
/// takes its place if the slot's own turns out damaged.
abstract base class StoredSaveRepository implements SaveRepository {
  StoredSaveRepository({this.check = checkRestorable});

  /// Asked whether a save that reads well can really be played.
  final SaveCheck? check;

  static String slotKey(int slot) => 'stepbound.save.$slot';
  static String backupKey(int slot) => 'stepbound.save.$slot.previous';
  static String suspendedKey(int slot) => 'stepbound.save.$slot.suspended';
  static String storyHistoryKey(int slot) => 'stepbound.story-history.$slot';
  static String giftsKey(int slot) => 'stepbound.gifts.$slot';

  @protected
  Future<String?> readValue(String key);

  @protected
  Future<void> writeValue(String key, String value);

  @protected
  Future<void> removeValue(String key);

  @override
  Future<List<SaveRead>> all() async => <SaveRead>[
    for (var slot = 1; slot <= SaveRepository.slotCount; slot++)
      await read(slot),
  ];

  @override
  Future<SaveRead> read(int slot) async {
    // Both at once: the menu is waiting on this.
    final reads = await Future.wait(<Future<Object>>[
      _readAt(suspendedKey(slot)),
      _readCheckpoint(slot),
    ]);
    final (_, suspended) = reads[0] as (String?, SaveRead);
    switch (suspended) {
      case LoadedSave(:final save):
        return LoadedSave(save, suspended: true);
      case DamagedSave(:final reason):
        // The campfire's save is still there to play.
        debugPrint(
          'save: the game put down in slot $slot is damaged ($reason)',
        );
      case EmptySave():
        break;
    }
    return reads[1] as SaveRead;
  }

  @override
  Future<SaveGame?> load(int slot) async => (await _readCheckpoint(slot)).game;

  /// The slot's own save, or the backup it replaced when it is damaged.
  Future<SaveRead> _readCheckpoint(int slot) async {
    final (_, current) = await _readAt(slotKey(slot));
    if (current is! DamagedSave) {
      return current;
    }
    debugPrint('save: slot $slot is damaged (${current.reason})');
    final (_, backup) = await _readAt(backupKey(slot));
    return switch (backup) {
      LoadedSave(:final save) => LoadedSave(save, fromBackup: true),
      _ => current,
    };
  }

  @override
  Future<void> save(SaveGame game) async {
    final (encoded, current) = await _readAt(slotKey(game.slot));
    try {
      // Only a good save becomes the backup: a damaged one would push out
      // the one save there is to fall back on.
      if (encoded != null && current is LoadedSave) {
        await writeValue(backupKey(game.slot), encoded);
      }
      await writeValue(slotKey(game.slot), jsonEncode(game.toJson()));
      // Whatever was put down before this campfire is older than it.
      await removeValue(suspendedKey(game.slot));
    } on Object catch (error) {
      throw SaveWriteException(game.slot, error);
    }
  }

  @override
  Future<void> suspend(SaveGame game) async {
    try {
      await writeValue(suspendedKey(game.slot), jsonEncode(game.toJson()));
    } on Object catch (error) {
      throw SaveWriteException(game.slot, error);
    }
  }

  @override
  Future<void> clearSuspended(int slot) => removeValue(suspendedKey(slot));

  @override
  Future<void> clear(int slot) async {
    await removeValue(slotKey(slot));
    await removeValue(backupKey(slot));
    await removeValue(suspendedKey(slot));
    await removeValue(storyHistoryKey(slot));
  }

  @override
  Future<Set<StoryMemory>> loadStoryHistory(int slot) async {
    final String? encoded;
    try {
      encoded = await readValue(storyHistoryKey(slot));
    } on Object catch (error) {
      debugPrint('story history: slot $slot is unreadable ($error)');
      return <StoryMemory>{};
    }
    if (encoded == null) {
      return <StoryMemory>{};
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List<Object?> || decoded.any((name) => name is! String)) {
        throw const FormatException('not a list of names');
      }
      return <StoryMemory>{
        for (final name in decoded.cast<String>())
          StoryMemory.values.byName(name),
      };
    } on Object catch (error) {
      debugPrint('story history: slot $slot is damaged ($error)');
      return <StoryMemory>{};
    }
  }

  @override
  Future<void> saveStoryHistory(int slot, Set<StoryMemory> memories) async {
    try {
      await writeValue(
        storyHistoryKey(slot),
        jsonEncode(<String>[for (final memory in memories) memory.name]),
      );
    } on Object catch (error) {
      debugPrint('story history: could not write slot $slot ($error)');
    }
  }

  @override
  Future<Set<PlayerOutfit>> loadGifts(int slot) async {
    try {
      final encoded = await readValue(giftsKey(slot));
      if (encoded == null) {
        return <PlayerOutfit>{};
      }
      final names = (jsonDecode(encoded) as List<Object?>).cast<String>();
      return <PlayerOutfit>{
        for (final outfit in PlayerOutfit.values)
          if (names.contains(outfit.name)) outfit,
      };
    } on Object catch (error) {
      debugPrint('gifts: slot $slot is unreadable ($error)');
      return <PlayerOutfit>{};
    }
  }

  @override
  Future<void> saveGifts(int slot, Set<PlayerOutfit> gifts) async {
    try {
      if (gifts.isEmpty) {
        await removeValue(giftsKey(slot));
      } else {
        await writeValue(
          giftsKey(slot),
          jsonEncode(<String>[for (final outfit in gifts) outfit.name]),
        );
      }
    } on Object catch (error) {
      throw SaveWriteException(slot, error);
    }
  }

  Future<(String?, SaveRead)> _readAt(String key) async {
    final String? encoded;
    try {
      encoded = await readValue(key);
    } on Object catch (error) {
      return (null, DamagedSave('unreadable: $error'));
    }
    return (encoded, SaveGame.decode(encoded, check: check));
  }
}

/// Saves kept on the device (local storage on the web).
final class PreferencesSaveRepository extends StoredSaveRepository {
  PreferencesSaveRepository({SharedPreferencesAsync? preferences, super.check})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readValue(String key) => _preferences.getString(key);

  @override
  Future<void> writeValue(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> removeValue(String key) => _preferences.remove(key);
}

/// Saves that live as long as the app, for tests. Everything goes through
/// JSON strings like the real storage, so tests catch encoding bugs.
final class MemorySaveRepository extends StoredSaveRepository {
  MemorySaveRepository({super.check});

  /// The strings stored, by key: tests write damaged saves straight here.
  final Map<String, String> values = <String, String>{};

  /// Makes every write fail, as a full disk would.
  bool failWrites = false;

  @override
  Future<String?> readValue(String key) async => values[key];

  @override
  Future<void> writeValue(String key, String value) async {
    if (failWrites) {
      throw StateError('storage full');
    }
    values[key] = value;
  }

  @override
  Future<void> removeValue(String key) async {
    values.remove(key);
  }
}
