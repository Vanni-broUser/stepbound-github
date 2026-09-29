import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/game_snapshot.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// A level started over: only its own city goes back to how the game
/// starts it. Every other city stays exactly as Mario left it (its
/// zombies, backpacks, story, fires, figures, missions and ammunition),
/// and so do the secret missions, the golden pistol with them.
typedef RestartedLevel = ({
  Map<String, Object?> world,
  Map<String, Object?> story,
  Progress progress,
  List<String> hud,
});

/// The city whose story each script tells, by `StoryScript.key`; the
/// scripts not listed are Molfetta's. A null city is the whole game's:
/// what it has taught stays taught.
const Map<String, LevelId?> storyScriptCities = <String, LevelId?>{
  'rome': LevelId.rome,
  'maranza': LevelId.rome,
  'journey': null,
};

LevelId? _scriptCity(String key) => storyScriptCities.containsKey(key)
    ? storyScriptCities[key]
    : LevelId.hometown;

/// [story] with the scripts of [city] as if nothing had happened yet.
Map<String, Object?> _storyWithout(Map<String, Object?> story, LevelId city) =>
    <String, Object?>{
      for (final MapEntry(:key, :value) in story.entries)
        if (_scriptCity(key) != city) key: value,
    };

extension CityItemGear on CityItem {
  /// Its badge among the controls.
  HudElement get badge => switch (this) {
    CityItem.grapplingHook => HudElement.grapplingHook,
  };

  bool carriedIn(AmmoComponent ammo) => switch (this) {
    CityItem.grapplingHook => ammo.grapplingHook,
  };

  void carry(AmmoComponent ammo, {required bool carried}) => switch (this) {
    CityItem.grapplingHook => ammo.grapplingHook = carried,
  };
}

/// A city other than Molfetta, from [current]: Mario is aboard the train
/// at the map, as when it first brought him there, with what the other
/// cities gave him but nothing of this one's, and the rounds a first
/// arrival gives.
RestartedLevel restartCity(GameSnapshot current) {
  final progress = Progress.fromJson(current.progress);
  final city = progress.level;
  progress
    ..forget(city)
    ..missions.arriveIn(city);
  if (city == LevelId.rome) {
    // Watched on the way there, the first time.
    progress.remember(StoryMemory.presidentFled);
  }
  final world = restoreGameWorld(restartLevelWorld(current.world, city));
  final player = world.player;
  player.component<PositionComponent>()
    ..position = trainMapStandTile
    ..facing = trainArrivalFacing;
  final health = player.component<HealthComponent>();
  health.current = health.maximum;
  final ammo = player.component<AmmoComponent>()
    ..loaded = arrivalRounds
    ..molotovs = 0
    ..rockets = 0;
  final lost = <CityItem>{
    for (final item in CityItem.values)
      if (item.level == city) item,
  };
  for (final item in lost) {
    item.carry(ammo, carried: false);
  }
  final badges = {for (final item in lost) item.badge.name};
  return (
    world: saveGameWorld(world),
    story: _storyWithout(current.story, city),
    progress: progress,
    hud: <String>[
      for (final name in current.hud)
        if (!badges.contains(name)) name,
    ],
  );
}

/// Molfetta from the first story scene, from [current] (none: a game
/// that had not got anywhere yet). Mario starts with nothing but
/// [fresh], the new game's progress, and the secret missions done; what
/// the other cities gave him is held away until he reaches the train with
/// Luigi again (see [HeldAway]), while the cities themselves stay as he
/// left them.
RestartedLevel restartHometown(GameSnapshot? current, Progress fresh) {
  if (current == null) {
    return (
      world: saveGameWorld(createGameWorld()),
      story: const <String, Object?>{},
      progress: fresh,
      hud: const <String>[],
    );
  }
  final old = Progress.fromJson(current.progress);
  final elsewhere = old.elsewhereThan(LevelId.hometown);
  final heldBefore = old.heldAway;
  if (heldBefore != null) {
    elsewhere.absorb(heldBefore.progress);
  }
  final ammo = restoreGameWorld(
    current.world,
  ).player.component<AmmoComponent>();
  fresh
    ..secretMissions.addAll(old.secretMissions)
    ..heldAway = HeldAway(
      progress: elsewhere,
      items: <CityItem>{
        ...?heldBefore?.items,
        for (final item in CityItem.values)
          if (item.level != LevelId.hometown && item.carriedIn(ammo)) item,
      },
    );
  return (
    world: restartLevelWorld(
      current.world,
      LevelId.hometown,
      freshPlayer: true,
    ),
    story: _storyWithout(current.story, LevelId.hometown),
    progress: fresh,
    hud: const <String>[],
  );
}

/// Molfetta, started over, has been completed again: what the other
/// cities gave Mario, held away until now, is his once more (see
/// [Progress.returnHeldAway]), and the items found there are back in his
/// hands in [world], their badges [unlock]ed.
void handBackHeldAway(
  Progress progress,
  WorldState world,
  void Function(HudElement badge) unlock,
) {
  final ammo = world.player.component<AmmoComponent>();
  for (final item in progress.returnHeldAway()) {
    item.carry(ammo, carried: true);
    unlock(item.badge);
  }
}
