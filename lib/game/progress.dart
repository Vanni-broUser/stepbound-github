import 'package:stepbound/core/core.dart';

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
  luigiAtStation,
}

/// What the player has come to know over the whole game: the zombie types
/// met and the story scenes seen. Unlike the tutorial's lessons, which
/// belong to one level, it carries over from level to level.
final class Progress {
  Progress({
    Iterable<EntityKind> knownZombies = const <EntityKind>[],
    Iterable<StoryMemory> memories = const <StoryMemory>[],
  }) : knownZombies = Set<EntityKind>.of(knownZombies),
       memories = Set<StoryMemory>.of(memories);

  /// A new game: the opening story has just been watched.
  factory Progress.newGame() => Progress(
    memories: const <StoryMemory>[
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
    ],
  );

  factory Progress.fromJson(Map<String, Object?> json) => Progress(
    knownZombies: <EntityKind>[
      for (final name
          in (json['knownZombies']! as List<Object?>).cast<String>())
        EntityKind.values.byName(name),
    ],
    memories: <StoryMemory>[
      for (final name in (json['memories']! as List<Object?>).cast<String>())
        StoryMemory.values.byName(name),
    ],
  );

  final Set<EntityKind> knownZombies;

  /// The scenes seen so far, in the order they were lived: a `Set` keeps
  /// what was put in it first, and a save writes and reads it in that same
  /// order, so the camp replays them as the player met them.
  final Set<StoryMemory> memories;

  void meet(EntityKind kind) => knownZombies.add(kind);

  void remember(StoryMemory memory) => memories.add(memory);

  Map<String, Object?> toJson() => <String, Object?>{
    'knownZombies': <String>[for (final kind in knownZombies) kind.name],
    'memories': <String>[for (final memory in memories) memory.name],
  };
}
