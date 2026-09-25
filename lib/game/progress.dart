import 'package:stepbound/core/core.dart';

/// Clothes Mario can wear. Each outfit owns the matching world atlases and
/// dialogue/menu portrait so every view changes together.
enum PlayerOutfit { base, cultist }

extension PlayerOutfitAssets on PlayerOutfit {
  String get label => switch (this) {
    PlayerOutfit.base => 'Base',
    PlayerOutfit.cultist => 'Occultista',
  };

  String get portrait => switch (this) {
    PlayerOutfit.base => 'assets/story/portrait_mario.png',
    PlayerOutfit.cultist => 'assets/story/portrait_mario_cultist.png',
  };

  String get spriteStem => switch (this) {
    PlayerOutfit.base => 'protagonist',
    PlayerOutfit.cultist => 'protagonist_cultist',
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
    Iterable<PlayerOutfit> unlockedOutfits = const <PlayerOutfit>[
      PlayerOutfit.base,
    ],
    this.activeOutfit = PlayerOutfit.base,
    this.level = LevelId.hometown,
  }) : knownZombies = Set<EntityKind>.of(knownZombies),
       memories = Set<StoryMemory>.of(memories),
       unlockedOutfits = Set<PlayerOutfit>.of(unlockedOutfits) {
    this.unlockedOutfits
      ..add(PlayerOutfit.base)
      ..add(activeOutfit);
  }

  /// A new game: the opening story has just been watched.
  factory Progress.newGame() => Progress(
    memories: const <StoryMemory>[
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
    ],
  );

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
    );
  }

  final Set<EntityKind> knownZombies;

  /// The scenes seen so far, in the order they were lived: a `Set` keeps
  /// what was put in it first, and a save writes and reads it in that same
  /// order, so the camp replays them as the player met them.
  final Set<StoryMemory> memories;

  /// Clothes found in the world and the one Mario is currently wearing.
  final Set<PlayerOutfit> unlockedOutfits;
  PlayerOutfit activeOutfit;

  /// The level the train last took Mario and Luigi to: where the game is
  /// played, and where the train's door opens.
  LevelId level;

  /// Whether Molfetta is behind them: Mario has reached the train with
  /// Luigi, whatever backpacks and memories are still to be found there.
  bool get hometownCompleted => memories.contains(StoryMemory.luigiAtStation);

  void meet(EntityKind kind) => knownZombies.add(kind);

  void remember(StoryMemory memory) => memories.add(memory);

  void unlockOutfit(PlayerOutfit outfit) => unlockedOutfits.add(outfit);

  bool wearOutfit(PlayerOutfit outfit) {
    if (!unlockedOutfits.contains(outfit)) {
      return false;
    }
    activeOutfit = outfit;
    return true;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'knownZombies': <String>[for (final kind in knownZombies) kind.name],
    'memories': <String>[for (final memory in memories) memory.name],
    'unlockedOutfits': <String>[
      for (final outfit in unlockedOutfits) outfit.name,
    ],
    'activeOutfit': activeOutfit.name,
    'level': level.name,
  };
}
