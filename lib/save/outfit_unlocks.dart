import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepbound/game/progress.dart';

/// The Halloween outfits obtained through campaign links on this device.
///
/// They do not belong to a save slot: obtaining one makes it available in
/// every existing and future game, once the story has introduced changing
/// clothes.
abstract interface class OutfitUnlockRepository {
  Future<Set<PlayerOutfit>> load();

  Future<void> unlock(PlayerOutfit outfit);
}

/// Device storage for outfits obtained through links.
final class PreferencesOutfitUnlockRepository
    implements OutfitUnlockRepository {
  PreferencesOutfitUnlockRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String key = 'stepbound.outfits.linked';

  final SharedPreferencesAsync _preferences;

  @override
  Future<Set<PlayerOutfit>> load() async {
    try {
      final names = await _preferences.getStringList(key) ?? const <String>[];
      return <PlayerOutfit>{
        for (final outfit in halloweenOutfits)
          if (names.contains(outfit.name)) outfit,
      };
    } on Object catch (error) {
      debugPrint('outfit unlocks: could not read them ($error)');
      return <PlayerOutfit>{};
    }
  }

  @override
  Future<void> unlock(PlayerOutfit outfit) async {
    if (!halloweenOutfits.contains(outfit)) {
      throw ArgumentError.value(outfit, 'outfit', 'is not link-unlockable');
    }
    final unlocked = await load()
      ..add(outfit);
    await _preferences.setStringList(key, <String>[
      for (final entry in unlocked) entry.name,
    ]);
  }
}

/// In-memory storage used by widget tests and embedders.
final class MemoryOutfitUnlockRepository implements OutfitUnlockRepository {
  MemoryOutfitUnlockRepository([
    Iterable<PlayerOutfit> unlocked = const <PlayerOutfit>[],
  ]) : unlocked = <PlayerOutfit>{...unlocked};

  final Set<PlayerOutfit> unlocked;

  @override
  Future<Set<PlayerOutfit>> load() async => <PlayerOutfit>{...unlocked};

  @override
  Future<void> unlock(PlayerOutfit outfit) async {
    if (!halloweenOutfits.contains(outfit)) {
      throw ArgumentError.value(outfit, 'outfit', 'is not link-unlockable');
    }
    unlocked.add(outfit);
  }
}

/// The campaign URL for [outfit].
Uri outfitUnlockLink(PlayerOutfit outfit) {
  final code = switch (outfit) {
    PlayerOutfit.ghost => '7fcc3bdba2794318b697b64046adf9f8',
    PlayerOutfit.vampire => '29c874a68fca4ed78a18a536ac003510',
    PlayerOutfit.jackOLantern => 'a6ead854a8d34080929282b76700d367',
    PlayerOutfit.zombie => '141e8b6eb1d6474b96c28e9972f2d050',
    PlayerOutfit.base || PlayerOutfit.cultist => throw ArgumentError.value(
      outfit,
      'outfit',
      'is not link-unlockable',
    ),
  };
  return Uri(scheme: 'stepbound', host: 'unlock', pathSegments: <String>[code]);
}

/// The outfit named by a campaign link, or null for any unrelated/malformed
/// URL. Keeping this strict prevents an accidental link from changing saves.
PlayerOutfit? outfitFromUnlockLink(Uri uri) {
  if (uri.scheme.toLowerCase() != 'stepbound' ||
      uri.host.toLowerCase() != 'unlock' ||
      uri.pathSegments.length != 1 ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  return switch (uri.pathSegments.single.toLowerCase()) {
    '7fcc3bdba2794318b697b64046adf9f8' => PlayerOutfit.ghost,
    '29c874a68fca4ed78a18a536ac003510' => PlayerOutfit.vampire,
    'a6ead854a8d34080929282b76700d367' => PlayerOutfit.jackOLantern,
    '141e8b6eb1d6474b96c28e9972f2d050' => PlayerOutfit.zombie,
    _ => null,
  };
}
