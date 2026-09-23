import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
    this.played = Duration.zero,
  });

  factory SaveGame.fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const FormatException('A save of another format');
    }
    return SaveGame(
      slot: json['slot']! as int,
      savedAt: DateTime.parse(json['savedAt']! as String),
      place: json['place']! as String,
      world: json['world']! as Map<String, Object?>,
      tutorial: json['tutorial']! as Map<String, Object?>,
      progress: json['progress']! as Map<String, Object?>,
      hud: (json['hud']! as List<Object?>).cast<String>(),
      played: Duration(seconds: json['played']! as int),
    );
  }

  /// A save of any other format reads as an empty slot. Bump it whenever
  /// what a save holds changes: old saves are dropped, never migrated.
  static const int format = 12;

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
    'played': played.inSeconds,
  };
}

/// The four save slots.
abstract interface class SaveRepository {
  static const int slotCount = 4;

  /// Every slot in order, null where it is empty.
  Future<List<SaveGame?>> all();

  Future<SaveGame?> load(int slot);

  Future<void> save(SaveGame game);

  Future<void> clear(int slot);
}

/// Saves kept on the device (local storage on the web).
final class PreferencesSaveRepository implements SaveRepository {
  PreferencesSaveRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static String _key(int slot) => 'stepbound.save.$slot';

  @override
  Future<List<SaveGame?>> all() async => <SaveGame?>[
    for (var slot = 1; slot <= SaveRepository.slotCount; slot++)
      await load(slot),
  ];

  @override
  Future<SaveGame?> load(int slot) async {
    final encoded = await _preferences.getString(_key(slot));
    if (encoded == null) {
      return null;
    }
    try {
      return SaveGame.fromJson(jsonDecode(encoded) as Map<String, Object?>);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(SaveGame game) =>
      _preferences.setString(_key(game.slot), jsonEncode(game.toJson()));

  @override
  Future<void> clear(int slot) => _preferences.remove(_key(slot));
}

/// Saves that live as long as the app, for tests.
final class MemorySaveRepository implements SaveRepository {
  final Map<int, String> _slots = <int, String>{};

  @override
  Future<List<SaveGame?>> all() async => <SaveGame?>[
    for (var slot = 1; slot <= SaveRepository.slotCount; slot++)
      await load(slot),
  ];

  @override
  Future<SaveGame?> load(int slot) async {
    final encoded = _slots[slot];
    if (encoded == null) {
      return null;
    }
    try {
      return SaveGame.fromJson(jsonDecode(encoded) as Map<String, Object?>);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(SaveGame game) async {
    // Through JSON, like the real storage, so tests catch encoding bugs.
    _slots[game.slot] = jsonEncode(game.toJson());
  }

  @override
  Future<void> clear(int slot) async {
    _slots.remove(slot);
  }
}
