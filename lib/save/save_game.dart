import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';

/// Everything needed to resume a game from a campfire.
final class SaveGame {
  const SaveGame({
    required this.slot,
    required this.savedAt,
    required this.place,
    required this.world,
    required this.tutorial,
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
      tutorial: fields.read<Map<String, Object?>>('tutorial'),
      progress: fields.read<Map<String, Object?>>('progress'),
      hud: hud.cast<String>(),
      atCampfire: fields.read<bool>('atCampfire'),
      played: Duration(seconds: played),
    );
  }

  /// What [encoded], as a slot stores it, holds: nothing, a save that can
  /// be played, or a damaged one. It never throws. A save of another
  /// [format] reads as empty, like no save at all: old saves are dropped,
  /// never migrated. [check] is asked whether a save that reads well can
  /// really be played (see [checkRestorable]); whatever it throws makes the
  /// save a damaged one.
  static SaveRead decode(String? encoded, {SaveCheck? check}) {
    if (encoded == null) {
      return const EmptySave();
    }
    final Object? json;
    try {
      json = jsonDecode(encoded);
    } on FormatException {
      return const DamagedSave('not JSON');
    }
    if (json is! Map<String, Object?>) {
      return const DamagedSave('not a JSON object');
    }
    final version = json['format'];
    if (version is! int) {
      return const DamagedSave('no format');
    }
    if (version != format) {
      return const EmptySave();
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

  /// A save of any other format reads as an empty slot. Bump it whenever
  /// what a save holds changes: old saves are dropped, never migrated.
  static const int format = 18;

  /// 1 to [SaveRepository.slotCount].
  final int slot;
  final DateTime savedAt;

  /// Where the save was made, as shown in the slot list.
  final String place;

  /// The simulation, as `saveTutorialWorld`.
  final Map<String, Object?> world;

  /// What the tutorial's scripts have done, as `TutorialDirector.toJson`.
  final Map<String, Object?> tutorial;

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
    tutorial: tutorial,
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
    'tutorial': tutorial,
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

/// The [SaveCheck] of the game: the world and the progress rebuild. What
/// they throw (a missing field, a zombie type or a tile kind the game does
/// not know) marks the save as damaged.
void checkRestorable(SaveGame save) {
  restoreTutorialWorld(save.world);
  Progress.fromJson(save.progress);
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
/// damaged and this is the good one it had replaced.
final class LoadedSave extends SaveRead {
  const LoadedSave(this.save, {this.fromBackup = false});

  final SaveGame save;
  final bool fromBackup;

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

  /// Every slot in order.
  Future<List<SaveRead>> all();

  /// What [slot] holds. Never throws: storage that cannot be read makes
  /// the slot a damaged one.
  Future<SaveRead> read(int slot);

  /// The save in [slot], null when there is none to play.
  Future<SaveGame?> load(int slot);

  /// Writes [game] in its slot, keeping the save it replaces as a backup.
  /// Throws a [SaveWriteException] when it cannot.
  Future<void> save(SaveGame game);

  /// Empties [slot], backup included.
  Future<void> clear(int slot);
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
  Future<SaveGame?> load(int slot) async => (await read(slot)).game;

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
    } on Object catch (error) {
      throw SaveWriteException(game.slot, error);
    }
  }

  @override
  Future<void> clear(int slot) async {
    await removeValue(slotKey(slot));
    await removeValue(backupKey(slot));
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
