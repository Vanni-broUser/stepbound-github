import 'dart:math' as math;

import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/missions.dart';

export 'package:stepbound/game/missions.dart';

/// How many rounds Mario has at least when the train brings him into a
/// level.
const int arrivalRounds = 5;

/// Clothes Mario can wear. Each outfit owns the matching world atlases and
/// dialogue/menu portrait so every view changes together.
enum PlayerOutfit {
  base,
  cultist,
  ghost,
  vampire,
  jackOLantern,
  zombie,
  roma,
  lazio,
}

/// Seasonal outfits obtained through their campaign links.
const List<PlayerOutfit> halloweenOutfits = <PlayerOutfit>[
  PlayerOutfit.ghost,
  PlayerOutfit.vampire,
  PlayerOutfit.jackOLantern,
  PlayerOutfit.zombie,
];

extension PlayerOutfitAssets on PlayerOutfit {
  String get label => switch (this) {
    PlayerOutfit.base => 'Base',
    PlayerOutfit.cultist => 'Occultista',
    PlayerOutfit.ghost => 'Fantasma',
    PlayerOutfit.vampire => 'Vampiro',
    PlayerOutfit.jackOLantern => 'Jack-o’-lantern',
    PlayerOutfit.zombie => 'Zombi',
    PlayerOutfit.roma => 'Roma',
    PlayerOutfit.lazio => 'Lazio',
  };

  String get portrait => switch (this) {
    PlayerOutfit.base => 'assets/characters/mario/portraits/base.png',
    PlayerOutfit.cultist => 'assets/characters/mario/portraits/cultist.png',
    PlayerOutfit.ghost => 'assets/characters/mario/portraits/ghost.png',
    PlayerOutfit.vampire => 'assets/characters/mario/portraits/vampire.png',
    PlayerOutfit.jackOLantern =>
      'assets/characters/mario/portraits/jack_o_lantern.png',
    PlayerOutfit.zombie => 'assets/characters/mario/portraits/zombie.png',
    PlayerOutfit.roma => 'assets/characters/mario/portraits/roma.png',
    PlayerOutfit.lazio => 'assets/characters/mario/portraits/lazio.png',
  };

  /// The city the outfit is found in: starting it over takes it away.
  /// Null for Mario's own clothes and for the gifts, his wherever he goes.
  LevelId? get foundIn => switch (this) {
    PlayerOutfit.cultist => LevelId.hometown,
    _ => null,
  };

  String get spriteStem => switch (this) {
    PlayerOutfit.base => 'base',
    PlayerOutfit.cultist => 'cultist',
    PlayerOutfit.ghost => 'ghost',
    PlayerOutfit.vampire => 'vampire',
    PlayerOutfit.jackOLantern => 'jack_o_lantern',
    PlayerOutfit.zombie => 'zombie',
    PlayerOutfit.roma => 'roma',
    PlayerOutfit.lazio => 'lazio',
  };
}

/// Story scenes that can be watched again at a camp once they have been
/// seen. The harbour and the hypermarket can be played in either order, so
/// what counts is not this list's order but the order they were
/// remembered in: see [Progress.memories].
enum StoryMemory {
  newsBroadcast,
  outbreakNight,
  luigiTrapped,
  luigiRescued,
  priestMet,
  priestErrand,
  priestWelcomed,
  priestFamily,
  priestMass,
  priestMassacre,
  luigiAtStation,

  /// Luigi at the station handing Mario the golden pistol: only when he
  /// got there without one (see [SecretMission.unarmedToLuigi]).
  goldenPistol,
  presidentFled,

  /// Tonino and Marcello at the bottom of Via Cavour, who want something
  /// of value before they let Mario onto their square.
  maranzaMet,
}

/// What Mario carries everywhere once found, and the city he finds it in:
/// starting that city over takes it from him.
enum CityItem {
  /// Found in the Baths of Diocletian.
  grapplingHook(LevelId.rome);

  const CityItem(this.level);

  final LevelId level;
}

/// What the other cities had given Mario when Molfetta was started over:
/// the missions, the figures, the zombies met, the clothes and the
/// [items] found there. Molfetta starts him with nothing; it all waits
/// aboard the train, and is his again once he has reached it with Luigi
/// (see [Progress.returnHeldAway]).
final class HeldAway {
  HeldAway({
    required this.progress,
    Iterable<CityItem> items = const <CityItem>[],
  }) : items = Set<CityItem>.of(items);

  factory HeldAway.fromJson(Map<String, Object?> json) => HeldAway(
    progress: Progress.fromJson(json['progress']! as Map<String, Object?>),
    items: <CityItem>[
      for (final name in (json['items']! as List<Object?>).cast<String>())
        CityItem.values.byName(name),
    ],
  );

  /// The other cities' part of Mario's progress, and nothing of Molfetta.
  final Progress progress;
  final Set<CityItem> items;

  Map<String, Object?> toJson() => <String, Object?>{
    'progress': progress.toJson(),
    'items': <String>[for (final item in items) item.name],
  };
}

/// What is never asked of Mario, only dared, on the secret missions page
/// of the figures of the adventure. Done once, it stays done for the slot,
/// through starting the level over.
enum SecretMission {
  /// Luigi freed and reached at the station without ever picking the
  /// pistol up: he hands over the golden one.
  unarmedToLuigi(
    'Se hai il coraggio ricomincia il livello completando la trama di '
    'Luigi senza raccogliere la pistola',
    short: 'da Luigi senza la pistola',
    level: LevelId.hometown,
  );

  const SecretMission(this.text, {required this.short, required this.level});

  /// The city it is done in: its figures list it among their missions.
  final LevelId level;

  /// As the secret missions page dares it.
  final String text;

  /// On one line, among the level's missions when it is done.
  final String short;
}

extension StoryMemoryLevel on StoryMemory {
  /// The level the scene belongs to: Rome's story is not one of the
  /// memories left to find in Molfetta.
  LevelId get level => switch (this) {
    StoryMemory.presidentFled || StoryMemory.maranzaMet => LevelId.rome,
    _ => LevelId.hometown,
  };
}

/// What the player has come to know over the whole game: the zombie types
/// met and the story scenes seen. Unlike the tutorial's lessons, which
/// belong to one level, it carries over from level to level.
final class Progress {
  Progress({
    Iterable<EntityKind> knownZombies = const <EntityKind>[],
    Map<EntityKind, Iterable<LevelId>> zombieCities =
        const <EntityKind, Iterable<LevelId>>{},
    Iterable<StoryMemory> memories = const <StoryMemory>[],
    Iterable<StoryMemory> viewedMemories = const <StoryMemory>[],
    Iterable<PlayerOutfit> unlockedOutfits = const <PlayerOutfit>[
      PlayerOutfit.base,
    ],
    this.activeOutfit = PlayerOutfit.base,
    this.level = LevelId.hometown,
    Map<LevelId, int> steps = const <LevelId, int>{},
    Iterable<String> litCampfires = const <String>[],
    Map<LevelId, int> roundsLeft = const <LevelId, int>{},
    Map<LevelId, int> molotovsLeft = const <LevelId, int>{},
    Map<LevelId, int> rocketsLeft = const <LevelId, int>{},
    MissionLog? missions,
    Iterable<SecretMission> secretMissions = const <SecretMission>[],
    this.heldAway,
  }) : missions = missions ?? MissionLog(),
       secretMissions = Set<SecretMission>.of(secretMissions),
       steps = Map<LevelId, int>.of(steps),
       roundsLeft = Map<LevelId, int>.of(roundsLeft),
       molotovsLeft = Map<LevelId, int>.of(molotovsLeft),
       rocketsLeft = Map<LevelId, int>.of(rocketsLeft),
       litCampfires = Set<String>.of(litCampfires),
       _zombieCities = <EntityKind, Set<LevelId>>{
         for (final kind in knownZombies)
           kind: Set<LevelId>.of(
             zombieCities[kind] ?? const <LevelId>[LevelId.hometown],
           ),
       },
       memories = Set<StoryMemory>.of(memories),
       _viewedMemories = Set<StoryMemory>.of(viewedMemories),
       // Mario has his own clothes from the start: first, unless something
       // was already his before the game began.
       unlockedOutfits = <PlayerOutfit>{
         if (!unlockedOutfits.contains(PlayerOutfit.base)) PlayerOutfit.base,
         ...unlockedOutfits,
       } {
    this.unlockedOutfits.add(activeOutfit);
  }

  /// A new game after the opening story. Until its first real save, the
  /// opening memories can remain pending instead of known. [gifts] are the
  /// skins the slot was given before the game began: Mario had them before
  /// his own clothes, so they come before them.
  factory Progress.newGame({
    bool openingSaved = true,
    Iterable<PlayerOutfit> gifts = const <PlayerOutfit>[],
  }) {
    final progress = Progress(
      unlockedOutfits: <PlayerOutfit>[...gifts, PlayerOutfit.base],
    );
    progress.missions.arriveIn(progress.level);
    final opening = <StoryMemory>{
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
    };
    if (openingSaved) {
      progress.memories.addAll(opening);
    } else {
      progress._pendingMemories.addAll(opening);
    }
    return progress;
  }

  factory Progress.fromJson(Map<String, Object?> json) {
    final outfitName = json['activeOutfit'] as String?;
    return Progress(
      knownZombies: <EntityKind>[
        for (final name
            in (json['knownZombies']! as List<Object?>).cast<String>())
          EntityKind.values.byName(name),
      ],
      zombieCities: <EntityKind, List<LevelId>>{
        for (final MapEntry(:key, :value)
            in (json['zombieCities'] as Map<String, Object?>? ??
                    const <String, Object?>{})
                .entries)
          EntityKind.values.byName(key): <LevelId>[
            for (final city in (value! as List<Object?>).cast<String>())
              LevelId.values.byName(city),
          ],
      },
      memories: <StoryMemory>[
        for (final name in (json['memories']! as List<Object?>).cast<String>())
          StoryMemory.values.byName(name),
      ],
      unlockedOutfits: <PlayerOutfit>[
        for (final name
            in ((json['unlockedOutfits'] as List<Object?>?) ??
                    const <Object?>['base'])
                .cast<String>())
          PlayerOutfit.values.byName(name),
      ],
      activeOutfit: outfitName == null
          ? PlayerOutfit.base
          : PlayerOutfit.values.byName(outfitName),
      level: LevelId.values.byName(json['level']! as String),
      steps: <LevelId, int>{
        for (final MapEntry(:key, :value)
            in (json['steps']! as Map<String, Object?>).entries)
          LevelId.values.byName(key): value! as int,
      },
      litCampfires: (json['litCampfires']! as List<Object?>).cast<String>(),
      roundsLeft: <LevelId, int>{
        for (final MapEntry(:key, :value)
            in (json['roundsLeft']! as Map<String, Object?>).entries)
          LevelId.values.byName(key): value! as int,
      },
      molotovsLeft: <LevelId, int>{
        for (final MapEntry(:key, :value)
            in (json['molotovsLeft']! as Map<String, Object?>).entries)
          LevelId.values.byName(key): value! as int,
      },
      rocketsLeft: <LevelId, int>{
        for (final MapEntry(:key, :value)
            in (json['rocketsLeft'] as Map<String, Object?>? ??
                    const <String, Object?>{})
                .entries)
          LevelId.values.byName(key): value! as int,
      },
      missions: MissionLog.fromJson(json['missions']! as Map<String, Object?>),
      secretMissions: <SecretMission>[
        for (final name
            in (json['secretMissions']! as List<Object?>).cast<String>())
          SecretMission.values.byName(name),
      ],
      heldAway: switch (json['heldAway']) {
        final Map<String, Object?> held => HeldAway.fromJson(held),
        _ => null,
      },
    );
  }

  /// The zombie types met, in the order they were: the book lists them so.
  Set<EntityKind> get knownZombies =>
      Set<EntityKind>.unmodifiable(_zombieCities.keys);

  /// The cities each of [knownZombies] is known in: met there, or seen
  /// there once already known. Starting a city over forgets what is known
  /// in it, and a type is known as long as one city knows it.
  final Map<EntityKind, Set<LevelId>> _zombieCities;

  /// Whether [kind] is known in [city].
  bool knowsIn(EntityKind kind, LevelId city) =>
      _zombieCities[kind]?.contains(city) ?? false;

  /// The zombie types known in [city], in the order they were met.
  Iterable<EntityKind> zombiesKnownIn(LevelId city) => <EntityKind>[
    for (final MapEntry(key: kind, value: cities) in _zombieCities.entries)
      if (cities.contains(city)) kind,
  ];

  /// The scenes seen so far, in the order they were lived: a `Set` keeps
  /// what was put in it first, and a save writes and reads it in that same
  /// order, so the camp replays them as the player met them.
  final Set<StoryMemory> memories;

  /// Story sequences completed in this attempt but not yet confirmed by a
  /// campfire or the train. They drive the current world's progression and
  /// can be lived again on the cot (see [livedMemories]), but stay out of
  /// [memories] and the level stats: a death takes them back.
  final Set<StoryMemory> _pendingMemories = <StoryMemory>{};

  /// Story sequences completed in earlier attempts. This device-local,
  /// slot-specific history only decides whether a sequence may be skipped;
  /// it never unlocks gameplay or counts as a known memory.
  final Set<StoryMemory> _viewedMemories;

  /// Clothes found in the world, in the order they became Mario's, and
  /// the one he is currently wearing.
  final Set<PlayerOutfit> unlockedOutfits;
  PlayerOutfit activeOutfit;

  /// The level the train last took Mario and Luigi to: where the game is
  /// played, and where the train's door opens.
  LevelId level;

  /// How many steps Mario has walked in each level.
  final Map<LevelId, int> steps;

  /// The campfires Mario has rested at, by name: each one lit is a place
  /// to come back to.
  final Set<String> litCampfires;

  /// The rounds Mario had on him when the train last left each level:
  /// bullets are used up, so they stay with the level they were found in.
  final Map<LevelId, int> roundsLeft;

  /// The molotovs Mario had on him when the train last left each level:
  /// like the rounds, they stay where they were found.
  final Map<LevelId, int> molotovsLeft;

  /// The rounds for the rocket launcher Mario had on him when the train
  /// last left each level: used up like the rest, they stay behind.
  final Map<LevelId, int> rocketsLeft;

  /// What Mario has been asked to do, open and done, in every level.
  final MissionLog missions;

  /// The secret missions done, in the order they were.
  final Set<SecretMission> secretMissions;

  /// What the other cities gave Mario, while Molfetta, started over, has
  /// not been completed again; null the rest of the time.
  HeldAway? heldAway;

  /// Whether Mario's pistol is the golden one, which Luigi hands over for
  /// [SecretMission.unarmedToLuigi]: it does twice the damage, and stays
  /// his wherever he goes and whenever the level starts over.
  bool get hasGoldenPistol =>
      secretMissions.contains(SecretMission.unarmedToLuigi);

  /// Whether the train has taken Mario anywhere yet, from the Europe map.
  bool get hasTravelled => roundsLeft.isNotEmpty;

  /// The train leaves [level] for [destination] with Mario carrying
  /// [rounds]. Those stay behind, and what he has on arrival is returned:
  /// the ones he left in [destination], but never fewer than
  /// [arrivalRounds]. Whatever is not used up (the pistol, the keys) is
  /// not counted here: it travels with him.
  int travel(LevelId destination, {required int rounds}) {
    roundsLeft[level] = rounds;
    level = destination;
    missions.arriveIn(destination);
    return math.max(roundsLeft[destination] ?? 0, arrivalRounds);
  }

  /// Leaves Mario's [molotovs] in the level he is in and returns those he
  /// left in [destination], none if he never did. Called just before
  /// [travel], which moves him there.
  int swapMolotovs(LevelId destination, {required int molotovs}) {
    molotovsLeft[level] = molotovs;
    return molotovsLeft[destination] ?? 0;
  }

  /// Like [swapMolotovs], for the rounds of the rocket launcher.
  int swapRockets(LevelId destination, {required int rockets}) {
    rocketsLeft[level] = rockets;
    return rocketsLeft[destination] ?? 0;
  }

  /// Whether Mario has been to [level] at least once: Molfetta always,
  /// another city once the train has brought him there.
  bool visited(LevelId level) =>
      level == LevelId.hometown ||
      this.level == level ||
      roundsLeft.containsKey(level);

  void countStep() => steps[level] = (steps[level] ?? 0) + 1;

  void lightCampfire(String name) => litCampfires.add(name);

  /// Whether Molfetta is behind them: Mario has reached the train with
  /// Luigi, whatever backpacks and memories are still to be found there.
  bool get hometownCompleted => memories.contains(StoryMemory.luigiAtStation);

  /// Whether [level] has been played to its end. Rome has no end yet.
  bool completed(LevelId level) => switch (level) {
    LevelId.hometown => hometownCompleted,
    LevelId.rome => false,
  };

  /// [kind] is known, and known in the city Mario is in.
  void meet(EntityKind kind) =>
      (_zombieCities[kind] ??= <LevelId>{}).add(level);

  /// Forgets everything [city] gave: the zombies known there, its
  /// story, its clothes, its fires, its figures, its missions and the
  /// ammunition left in it. What the rest of the game gave stays, the
  /// secret missions too.
  void forget(LevelId city) {
    bool ofCity(StoryMemory memory) => memory.level == city;
    for (final cities in _zombieCities.values) {
      cities.remove(city);
    }
    _zombieCities.removeWhere((_, cities) => cities.isEmpty);
    memories.removeWhere(ofCity);
    _pendingMemories.removeWhere(ofCity);
    unlockedOutfits.removeWhere((outfit) => outfit.foundIn == city);
    if (!unlockedOutfits.contains(activeOutfit)) {
      activeOutfit = PlayerOutfit.base;
    }
    litCampfires.removeWhere((name) => campfireLevel(name) == city);
    for (final perCity in <Map<LevelId, int>>[
      steps,
      roundsLeft,
      molotovsLeft,
      rocketsLeft,
    ]) {
      perCity.remove(city);
    }
    missions.forget(city);
  }

  /// Only what the cities but [city] gave, as [forget] tells them apart,
  /// to be held away while [city] starts over.
  Progress elsewhereThan(LevelId city) => Progress.fromJson(toJson())
    ..forget(city)
    ..secretMissions.clear()
    ..heldAway = null;

  /// Takes on what [other] knows besides: its zombies, story, clothes,
  /// fires, figures and missions, and the ammunition left in its cities.
  void absorb(Progress other) {
    for (final MapEntry(key: kind, value: cities)
        in other._zombieCities.entries) {
      (_zombieCities[kind] ??= <LevelId>{}).addAll(cities);
    }
    memories.addAll(other.memories);
    unlockedOutfits.addAll(other.unlockedOutfits);
    litCampfires.addAll(other.litCampfires);
    for (final (mine, theirs) in <(Map<LevelId, int>, Map<LevelId, int>)>[
      (steps, other.steps),
      (roundsLeft, other.roundsLeft),
      (molotovsLeft, other.molotovsLeft),
      (rocketsLeft, other.rocketsLeft),
    ]) {
      for (final MapEntry(:key, :value) in theirs.entries) {
        mine.putIfAbsent(key, () => value);
      }
    }
    missions.absorb(other.missions);
    secretMissions.addAll(other.secretMissions);
  }

  /// Molfetta has been completed again: what the other cities gave is
  /// Mario's once more. The items found there are returned, for the game
  /// to hand back.
  Set<CityItem> returnHeldAway() {
    final held = heldAway;
    if (held == null) {
      return const <CityItem>{};
    }
    heldAway = null;
    absorb(held.progress);
    return held.items;
  }

  void remember(StoryMemory memory) => memories.add(memory);

  /// Marks [memory] as completed in the current attempt, awaiting a real
  /// save at a campfire or on the train.
  void view(StoryMemory memory) => _pendingMemories.add(memory);

  /// Whether this attempt has reached [memory], either before or after its
  /// next real save. Use this for gameplay state, never for stats.
  bool hasExperienced(StoryMemory memory) =>
      memories.contains(memory) || _pendingMemories.contains(memory);

  /// The scenes this attempt has reached, in the order they were lived:
  /// the saved [memories], then the ones still waiting for a save. In Rome
  /// the cot is on the train, which saves only when it leaves, so a scene
  /// seen on the way there is not saved yet and still one to live again.
  Iterable<StoryMemory> get livedMemories => <StoryMemory>{
    ...memories,
    ..._pendingMemories,
  };

  /// Whether [memory] has ever been watched on this slot, including an
  /// earlier attempt lost to death. This is only for showing the skip button.
  bool hasViewed(StoryMemory memory) =>
      hasExperienced(memory) || _viewedMemories.contains(memory);

  /// Adds device-local viewing history loaded by the app.
  void addViewedMemories(Iterable<StoryMemory> viewed) =>
      _viewedMemories.addAll(viewed);

  /// Promotes the current attempt's story to confirmed memories after a
  /// campfire/train save succeeds.
  void confirmPendingMemories() {
    memories.addAll(_pendingMemories);
    _pendingMemories.clear();
  }

  void unlockOutfit(PlayerOutfit outfit) => unlockedOutfits.add(outfit);

  bool wearOutfit(PlayerOutfit outfit) {
    if (!unlockedOutfits.contains(outfit)) {
      return false;
    }
    activeOutfit = outfit;
    return true;
  }

  Map<String, Object?> toJson({
    bool confirmPendingMemories = false,
  }) => <String, Object?>{
    'knownZombies': <String>[for (final kind in knownZombies) kind.name],
    'zombieCities': <String, List<String>>{
      for (final MapEntry(key: kind, value: cities) in _zombieCities.entries)
        kind.name: <String>[for (final city in cities) city.name],
    },
    'memories': <String>[
      for (final memory in memories) memory.name,
      if (confirmPendingMemories)
        for (final memory in _pendingMemories)
          if (!memories.contains(memory)) memory.name,
    ],
    'unlockedOutfits': <String>[
      for (final outfit in unlockedOutfits) outfit.name,
    ],
    'activeOutfit': activeOutfit.name,
    'level': level.name,
    'steps': <String, int>{
      for (final MapEntry(:key, :value) in steps.entries) key.name: value,
    },
    'litCampfires': <String>[...litCampfires],
    'roundsLeft': <String, int>{
      for (final MapEntry(:key, :value) in roundsLeft.entries) key.name: value,
    },
    'molotovsLeft': <String, int>{
      for (final MapEntry(:key, :value) in molotovsLeft.entries)
        key.name: value,
    },
    if (rocketsLeft.isNotEmpty)
      'rocketsLeft': <String, int>{
        for (final MapEntry(:key, :value) in rocketsLeft.entries)
          key.name: value,
      },
    'missions': missions.toJson(),
    'secretMissions': <String>[
      for (final mission in secretMissions) mission.name,
    ],
    if (heldAway case final held?) 'heldAway': held.toJson(),
  };
}
