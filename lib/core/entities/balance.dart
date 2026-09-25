import 'package:stepbound/core/entities/entity.dart';

part 'default_balance.g.dart';

final class ActorStats {
  const ActorStats({
    required this.tickCost,
    required this.health,
    required this.vision,
    required this.hearing,
    required this.contactDamage,
    this.attackReach = 1,
    this.stationary = false,
    this.trailsFire = false,
    this.staggers = false,
  });

  factory ActorStats.fromJson(Map<String, Object?> json) {
    return ActorStats(
      tickCost: json['tickCost']! as int,
      health: json['health']! as int,
      vision: json['vision']! as int,
      hearing: json['hearing']! as int,
      contactDamage: json['contactDamage']! as int,
      attackReach: json['attackReach'] as int? ?? 1,
      stationary: json['stationary'] as bool? ?? false,
      trailsFire: json['trailsFire'] as bool? ?? false,
      staggers: json['staggers'] as bool? ?? false,
    );
  }

  final int tickCost;
  final int health;
  final int vision;
  final int hearing;
  final int contactDamage;

  /// Tiles in a straight line the attack reaches: 1 is a bite, 2 a baton.
  final int attackReach;

  /// True for a zombie that cannot walk: it stays on its tile for good.
  final bool stationary;

  /// True for a zombie that sets alight every tile it steps off.
  final bool trailsFire;

  /// True for a zombie that staggers about at random instead of hunting.
  final bool staggers;

  Map<String, Object?> toJson() => <String, Object?>{
    'tickCost': tickCost,
    'health': health,
    'vision': vision,
    'hearing': hearing,
    'contactDamage': contactDamage,
    'attackReach': attackReach,
    'stationary': stationary,
    'trailsFire': trailsFire,
    'staggers': staggers,
  };
}

final class BalanceConfig {
  BalanceConfig({required Map<EntityKind, ActorStats> actors})
    : actors = Map<EntityKind, ActorStats>.unmodifiable(actors);

  /// The checked-in defaults generated from `assets/balance/default.json`.
  factory BalanceConfig.standard() => BalanceConfig(actors: _defaultActorStats);

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
