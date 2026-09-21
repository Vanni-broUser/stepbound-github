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
    required this.hud,
  });

  factory SaveGame.fromJson(Map<String, Object?> json) {
    return SaveGame(
      slot: json['slot']! as int,
      savedAt: DateTime.parse(json['savedAt']! as String),
      place: json['place']! as String,
      world: json['world']! as Map<String, Object?>,
      tutorial: json['tutorial']! as Map<String, Object?>,
      hud: (json['hud']! as List<Object?>).cast<String>(),
    );
  }

  /// 1 to [SaveRepository.slotCount].
  final int slot;
  final DateTime savedAt;

  /// Where the save was made, as shown in the slot list.
  final String place;

  /// The simulation, as `WorldState.toJson`.
  final Map<String, Object?> world;

  /// The tutorial's progress, as `TutorialDirector.toJson`.
  final Map<String, Object?> tutorial;

  /// Names of the unlocked touch controls.
  final List<String> hud;

  SaveGame copyWith({int? slot}) => SaveGame(
    slot: slot ?? this.slot,
    savedAt: savedAt,
    place: place,
    world: world,
    tutorial: tutorial,
    hud: hud,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'slot': slot,
    'savedAt': savedAt.toIso8601String(),
    'place': place,
    'world': world,
    'tutorial': tutorial,
    'hud': hud,
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
    return encoded == null
        ? null
        : SaveGame.fromJson(jsonDecode(encoded) as Map<String, Object?>);
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
