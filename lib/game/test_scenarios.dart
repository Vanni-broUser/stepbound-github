import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/save/save_game.dart';

/// A point of the story to jump straight to while testing. It is not part
/// of the game: `tools/make_save.dart` turns one into a save written
/// straight into a browser's storage, where the menu loads it like any
/// other. It is built from the level every time, so it never goes stale
/// when the save format changes.
final class TestScenario {
  const TestScenario(this.name, this._build);

  /// What the menu calls it.
  final String name;
  final void Function(ScenarioBuilder story) _build;

  /// The game at this point, as a save in [slot]: loading it plays from
  /// there, and the fires on the way save into that slot.
  SaveGame save(int slot) {
    final story = ScenarioBuilder();
    _build(story);
    return story._save(slot);
  }
}

/// Puts a fresh level in a given state: what has been played, what Mario
/// carries and where he stands.
final class ScenarioBuilder {
  final WorldState world = createTutorialWorld();
  final Progress progress = Progress.newGame();
  final Map<String, Map<String, Object?>> _scripts =
      <String, Map<String, Object?>>{};
  final Set<HudElement> _hud = <HudElement>{};

  /// Merges [state] into what the script called [key] remembers.
  void script(String key, Map<String, Object?> state) =>
      (_scripts[key] ??= <String, Object?>{}).addAll(state);

  void unlock(HudElement element) => _hud.add(element);

  void remember(StoryMemory memory) => progress.remember(memory);

  /// The backpack [id] has been picked up.
  void collect(String id) {
    world.pickups[id]!
      ..active = false
      ..collected = true;
  }

  /// Every zombie whose id starts with [prefix] is dead.
  void kill(String prefix) {
    for (final entity in world.entities.values) {
      if (entity.id.startsWith(prefix)) {
        entity.component<HealthComponent>().current = 0;
      }
    }
  }

  String? _savedAt;

  /// Saved at [fire], as a game is: Mario beside it, facing it, the slot
  /// named after it and resumable from it.
  void restAt(GridPoint fire) {
    for (final side in <Direction>[
      Direction.south,
      Direction.west,
      Direction.east,
      Direction.north,
    ]) {
      final tile = fire.step(side);
      if (_free(tile)) {
        world.player.component<PositionComponent>()
          ..position = tile
          ..facing = side.opposite;
        _savedAt = campfireNames[fire];
        return;
      }
    }
    throw StateError('nowhere to rest at $fire');
  }

  /// Saved at the fire nearest [target] on foot, through the doors and
  /// roads open at this point of the story: the one a player heading
  /// there would have rested at.
  void restNearest(GridPoint target) => restAt(nearestFire(target));

  /// Saved aboard the train, the way the level ends: at the map table.
  void aboardTrain() {
    world.player.component<PositionComponent>()
      ..position = trainMapStandTile
      ..facing = Direction.south;
    _savedAt = trainPlaceName;
  }

  /// The campfire from which a walk gets closest to [target], through the
  /// doors and roads open at this point of the story: in [target]'s own
  /// place, the fire whose walk ends nearest it, and of two the one with
  /// the shorter walk. [target] itself may lie behind something shut (Luigi
  /// behind his shutter, Don Angelo behind his gate).
  GridPoint nearestFire(GridPoint target) {
    final place = placeAt(target);
    GridPoint? best;
    (int, int)? bestScore;
    for (final fire in campfireNames.keys) {
      for (final (tile, steps) in _walk(fire)) {
        if (placeAt(tile) != place) {
          continue;
        }
        final score = (tile.manhattanDistanceTo(target), steps);
        if (bestScore == null ||
            score.$1 < bestScore.$1 ||
            (score.$1 == bestScore.$1 && score.$2 < bestScore.$2)) {
          best = fire;
          bestScore = score;
        }
      }
    }
    if (best == null) {
      throw StateError('no campfire can be walked to near $target');
    }
    return best;
  }

  /// Every tile a walk from beside [fire] reaches, with its steps; a door
  /// leads where it leads in the game.
  Iterable<(GridPoint, int)> _walk(GridPoint fire) sync* {
    final steps = <GridPoint, int>{};
    final queue = <GridPoint>[
      for (final side in Direction.values)
        if (_walkable(fire.step(side))) fire.step(side),
    ];
    for (final tile in queue) {
      steps[tile] = 0;
    }
    for (var i = 0; i < queue.length; i++) {
      final here = queue[i];
      yield (here, steps[here]!);
      for (final side in Direction.values) {
        var next = here.step(side);
        if (!_walkable(next)) {
          continue;
        }
        next = world.portals[next]?.to ?? next;
        if (!steps.containsKey(next)) {
          steps[next] = steps[here]! + 1;
          queue.add(next);
        }
      }
    }
  }

  bool _walkable(GridPoint tile) =>
      world.map.contains(tile) && world.map.tileAt(tile).isWalkable;

  bool _free(GridPoint tile) =>
      _walkable(tile) &&
      world.entityAt(tile) == null &&
      world.pickupAt(tile) == null &&
      !world.portals.containsKey(tile);

  SaveGame _save(int slot) {
    final place = _savedAt;
    if (place == null) {
      throw StateError('a scenario must end at a fire or on the train');
    }
    return SaveGame(
      slot: slot,
      savedAt: DateTime.now(),
      place: place,
      world: saveTutorialWorld(world),
      tutorial: _scripts,
      progress: progress.toJson(),
      hud: <String>[for (final element in _hud) element.name],
    );
  }
}

/// The points of the story worth jumping to, in the order they are played.
/// Each one builds on the ones before it, and is saved where a player
/// would have saved on the way: at the fire nearest the place it is
/// about, or aboard the train once the level is over.
final List<TestScenario> testScenarios = <TestScenario>[
  TestScenario('Quartiere nord, armato', (story) {
    _armed(story);
    story.restAt(_campfireIn(PlaceId.northDistrict));
  }),
  TestScenario('Centro commerciale, Luigi in trappola', (story) {
    _armed(story);
    story.restNearest(luigiTile);
  }),
  TestScenario('Luigi liberato, quartiere nord', (story) {
    _luigiFree(story);
    story.restAt(_campfireIn(PlaceId.northDistrict));
  }),
  TestScenario('Luigi liberato, verso la stazione', (story) {
    _luigiFree(story);
    story.restNearest(stationWestDoor.first);
  }),
  TestScenario('Treno, dopo la fine del livello', (story) {
    _luigiFree(story);
    story
      ..remember(StoryMemory.luigiAtStation)
      ..script('station', <String, Object?>{'reunion': true})
      ..aboardTrain();
  }),
  TestScenario('Porto, Don Angelo al cancello', (story) {
    _armed(story);
    story.restNearest(priestTile);
  }),
  TestScenario("Porto, in cerca dell'incenso", (story) {
    _incenseErrand(story);
    story.restNearest(churchPortalTile);
  }),
  TestScenario("Porto, ritorno con l'incenso", (story) {
    _incenseErrand(story);
    story
      ..collect(incenseBackpackId)
      ..unlock(HudElement.incense)
      ..restNearest(priestTile);
  }),
  TestScenario('Bar Arcobaleno, con la chiave', (story) {
    _welcomed(story);
    story.restNearest(barLockedDoorTile);
  }),
  TestScenario("Duomo, con l'anello", (story) {
    _ringFound(story);
    story.restNearest(duomoPortalTile);
  }),
  TestScenario('Duomo, piano di sopra', (story) {
    _upstairs(story);
    story.restNearest(duomoUpperRobeTile);
  }),
  TestScenario('Duomo, la messa (con la tunica)', (story) {
    _upstairs(story);
    story.collect(cultistRobePickupId);
    story.progress
      ..unlockOutfit(PlayerOutfit.cultist)
      ..wearOutfit(PlayerOutfit.cultist);
    story.restNearest(duomoPortalTile);
  }),
  TestScenario('Duomo, dopo la messa (i cultisti)', (story) {
    _afterTheMass(story);
    story.restNearest(duomoPortalTile);
  }),
  TestScenario('Aereo schiantato', (story) {
    _luigiFree(story);
    story.restNearest(airlinerTear.first);
  }),
];

/// The mass over: Mario in the robe, Don Angelo dead and the four mutated
/// cultists in the nave. The game raises them and reveals the key when the
/// save loads, so only what was lived is recorded here.
void _afterTheMass(ScenarioBuilder story) {
  _upstairs(story);
  story.collect(cultistRobePickupId);
  story.progress
    ..unlockOutfit(PlayerOutfit.cultist)
    ..wearOutfit(PlayerOutfit.cultist);
  story
    ..remember(StoryMemory.priestMass)
    ..remember(StoryMemory.priestMassacre)
    ..script('duomo', <String, Object?>{'massacre': true});
}

/// The campfire of [place].
GridPoint _campfireIn(PlaceId id) =>
    campfireNames.keys.firstWhere((fire) => placeAt(fire)?.id == id);

/// The street and the barracks behind him: every lesson learnt, the
/// pistol found, a few rounds in it, all the buttons.
void _armed(ScenarioBuilder story) {
  story
    ..collect(gunBackpackId)
    ..unlock(HudElement.interact)
    ..unlock(HudElement.ammo)
    ..unlock(HudElement.shoot)
    ..script('backpacks', <String, Object?>{'lesson': true})
    ..script('street', <String, Object?>{'zombieLesson': true})
    ..script('barracks', <String, Object?>{
      'forecourtLines': true,
      'carabinieriOut': true,
      'carabiniereLesson': true,
      'stepsInside': 10,
    })
    ..script('north', <String, Object?>{'campLesson': true});
  story.world.player.component<AmmoComponent>()
    ..loaded = 12
    ..hasGun = true;
}

/// Luigi out of his shop and gone ahead to the station.
void _luigiFree(ScenarioBuilder story) {
  _armed(story);
  final world = story.world;
  world.controls.remove(mallPanelTile);
  for (var y = luigiBars.top; y <= luigiBars.bottom; y++) {
    for (var x = luigiBars.left; x <= luigiBars.right; x++) {
      world.map.setTile(GridPoint(x, y), const Tile(TileKind.floor));
    }
  }
  story
    ..remember(StoryMemory.luigiTrapped)
    ..remember(StoryMemory.luigiRescued)
    ..script('mall', <String, Object?>{
      'stepsInside': 10,
      'voice': true,
      'luigiScene': true,
      'horde': true,
      'shutter': true,
      'reunion': true,
      'luigiGone': true,
    });
}

/// Don Angelo met, his zombies dead, the incense asked for.
void _incenseErrand(ScenarioBuilder story) {
  _armed(story);
  story
    ..kill(priestZombiePrefix)
    ..remember(StoryMemory.priestMet)
    ..remember(StoryMemory.priestErrand)
    ..script('priest', <String, Object?>{
      'met': true,
      'clearAsked': true,
      'deal': true,
      'errand': true,
    });
}

/// The incense delivered: the gate open and the bar's key in hand (the
/// game hands over the key when the save loads).
void _welcomed(ScenarioBuilder story) {
  _incenseErrand(story);
  final map = story.world.map;
  for (final tile in priestGateTiles) {
    map.setTile(tile, const Tile(TileKind.floor));
  }
  story
    ..collect(incenseBackpackId)
    ..remember(StoryMemory.priestWelcomed)
    ..script('priest', <String, Object?>{'welcome': true});
}

/// The storeroom opened and Don Angelo's ring found in it.
void _ringFound(ScenarioBuilder story) {
  _welcomed(story);
  story.world.map.setTile(barLockedDoorTile, const Tile(TileKind.floor));
  story
    ..collect(episcopalRingPickupId)
    ..unlock(HudElement.episcopalRing);
}

/// The ring handed over: the way upstairs is open.
void _upstairs(ScenarioBuilder story) {
  _ringFound(story);
  // As the game leaves them once the ring is handed over: the stair
  // cultist stepped aside, the stair free.
  story.world.map
    ..setTile(duomoStairCultistTile, const Tile(TileKind.floor))
    ..setTile(duomoStairEntryTile, const Tile(TileKind.floor))
    ..setTile(duomoStairCultistMovedTile, const Tile(TileKind.obstacle));
  story
    ..remember(StoryMemory.priestFamily)
    ..script('duomo', <String, Object?>{'ringDelivered': true});
}
