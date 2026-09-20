import 'package:stepbound/core/entities/entity.dart';

final class ActorStats {
  const ActorStats({
    required this.tickCost,
    required this.health,
    required this.vision,
    required this.hearing,
    required this.contactDamage,
  });

  factory ActorStats.fromJson(Map<String, Object?> json) {
    return ActorStats(
      tickCost: json['tickCost']! as int,
      health: json['health']! as int,
      vision: json['vision']! as int,
      hearing: json['hearing']! as int,
      contactDamage: json['contactDamage']! as int,
    );
  }

  final int tickCost;
  final int health;
  final int vision;
  final int hearing;
  final int contactDamage;

  Map<String, Object?> toJson() => <String, Object?>{
    'tickCost': tickCost,
    'health': health,
    'vision': vision,
    'hearing': hearing,
    'contactDamage': contactDamage,
  };
}

final class BalanceConfig {
  BalanceConfig({required Map<EntityKind, ActorStats> actors})
    : actors = Map<EntityKind, ActorStats>.unmodifiable(actors);

  factory BalanceConfig.standard() {
    return BalanceConfig(
      actors: const <EntityKind, ActorStats>{
        EntityKind.player: ActorStats(
          tickCost: 1,
          health: 6,
          vision: 0,
          hearing: 0,
          contactDamage: 0,
        ),
        EntityKind.wanderer: ActorStats(
          tickCost: 2,
          health: 1,
          vision: 6,
          hearing: 8,
          contactDamage: 1,
        ),
        EntityKind.sprinter: ActorStats(
          tickCost: 1,
          health: 1,
          vision: 8,
          hearing: 12,
          contactDamage: 1,
        ),
        EntityKind.brute: ActorStats(
          tickCost: 3,
          health: 2,
          vision: 4,
          hearing: 14,
          contactDamage: 1,
        ),
        EntityKind.blind: ActorStats(
          tickCost: 2,
          health: 1,
          vision: 0,
          hearing: 20,
          contactDamage: 1,
        ),
      },
    );
  }

  factory BalanceConfig.fromJson(Map<String, Object?> json) {
    final encodedActors = json['actors']! as Map<String, Object?>;
    return BalanceConfig(
      actors: <EntityKind, ActorStats>{
        for (final entry in encodedActors.entries)
          EntityKind.values.byName(entry.key): ActorStats.fromJson(
            entry.value! as Map<String, Object?>,
          ),
      },
    );
  }

  final Map<EntityKind, ActorStats> actors;

  ActorStats operator [](EntityKind kind) => actors[kind]!;

  Map<String, Object?> toJson() => <String, Object?>{
    'actors': <String, Object?>{
      for (final entry in actors.entries) entry.key.name: entry.value.toJson(),
    },
  };
}
