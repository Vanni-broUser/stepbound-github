import 'dart:math' as math;

import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/missions.dart';

export 'package:stepbound/game/missions.dart';

/// How many rounds Mario has at least when the train brings him into a
/// level.
const int arrivalRounds = 5;

/// Clothes Mario can wear. Each outfit owns the matching world atlases and
/// dialogue/menu portrait so every view changes together.
enum PlayerOutfit { base, cultist, ghost, vampire, jackOLantern, zombie }

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
  };

  String get portrait => switch (this) {
    PlayerOutfit.base => 'assets/characters/mario/portraits/base.png',
    PlayerOutfit.cultist => 'assets/characters/mario/portraits/cultist.png',
    PlayerOutfit.ghost => 'assets/characters/mario/portraits/ghost.png',
    PlayerOutfit.vampire => 'assets/characters/mario/portraits/vampire.png',
    PlayerOutfit.jackOLantern =>
      'assets/characters/mario/portraits/jack_o_lantern.png',
    PlayerOutfit.zombie => 'assets/characters/mario/portraits/zombie.png',
  };

  String get spriteStem => switch (this) {
    PlayerOutfit.base => 'base',
    PlayerOutfit.cultist => 'cultist',
    PlayerOutfit.ghost => 'ghost',
    PlayerOutfit.vampire => 'vampire',
    PlayerOutfit.jackOLantern => 'jack_o_lantern',
    PlayerOutfit.zombie => 'zombie',
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
  presidentFled,
}

extension StoryMemoryLevel on StoryMemory {
  /// The level the scene belongs to: Rome's story is not one of the
  /// memories left to find in Molfetta.
  LevelId get level => switch (this) {
    StoryMemory.presidentFled => LevelId.rome,
    _ => LevelId.hometown,
  };
}

/// What the player has come to know over the whole game: the zombie types
/// met and the story scenes seen. Unlike the tutorial's lessons, which
/// belong to one level, it carries over from level to level.
final class Progress {
  Progress({
    Iterable<EntityKind> knownZombies = const <EntityKind>[],
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
    MissionLog? missions,
  }) : missions = missions ?? MissionLog(),
       steps = Map<LevelId, int>.of(steps),
       roundsLeft = Map<LevelId, int>.of(roundsLeft),
       molotovsLeft = Map<LevelId, int>.of(molotovsLeft),
       litCampfires = Set<String>.of(litCampfires),
       knownZombies = Set<EntityKind>.of(knownZombies),
       memories = Set<StoryMemory>.of(memories),
       _viewedMemories = Set<StoryMemory>.of(viewedMemories),
       unlockedOutfits = Set<PlayerOutfit>.of(unlockedOutfits) {
    this.unlockedOutfits
      ..add(PlayerOutfit.base)
      ..add(activeOutfit);
  }

  /// A new game after the opening story. Until its first real save, the
  /// opening memories can remain pending instead of known.
  factory Progress.newGame({bool openingSaved = true}) {
    final progress = Progress();
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
      missions: MissionLog.fromJson(json['missions']! as Map<String, Object?>),
    );
  }

  final Set<EntityKind> knownZombies;

  /// The scenes seen so far, in the order they were lived: a `Set` keeps
  /// what was put in it first, and a save writes and reads it in that same
  /// order, so the camp replays them as the player met them.
  final Set<StoryMemory> memories;

  /// Story sequences completed in this attempt but not yet confirmed by a
  /// campfire or the train. They drive the current world's progression, but
  /// deliberately stay out of [memories], memory replay and level stats.
  final Set<StoryMemory> _pendingMemories = <StoryMemory>{};

  /// Story sequences completed in earlier attempts. This device-local,
  /// slot-specific history only decides whether a sequence may be skipped;
  /// it never unlocks gameplay or counts as a known memory.
  final Set<StoryMemory> _viewedMemories;

  /// Clothes found in the world and the one Mario is currently wearing.
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

  /// What Mario has been asked to do, open and done, in every level.
  final MissionLog missions;

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

  void meet(EntityKind kind) => knownZombies.add(kind);

  void remember(StoryMemory memory) => memories.add(memory);

  /// Marks [memory] as completed in the current attempt, awaiting a real
  /// save at a campfire or on the train.
  void view(StoryMemory memory) => _pendingMemories.add(memory);

  /// Whether this attempt has reached [memory], either before or after its
  /// next real save. Use this for gameplay state, never for replay or stats.
  bool hasExperienced(StoryMemory memory) =>
      memories.contains(memory) || _pendingMemories.contains(memory);

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
    'missions': missions.toJson(),
  };
}
