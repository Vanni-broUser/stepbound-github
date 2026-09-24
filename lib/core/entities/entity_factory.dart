import 'package:stepbound/core/entities/balance.dart';
import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/grid/grid_point.dart';

final class EntityFactory {
  const EntityFactory(this.balance);

  final BalanceConfig balance;

  Entity player({
    required String id,
    required GridPoint position,
    Direction facing = Direction.east,
    int? health,
    int loadedAmmo = 6,
    bool hasGun = true,
  }) {
    final stats = balance[EntityKind.player];
    final maximum = health ?? stats.health;
    return Entity(
      id: id,
      kind: EntityKind.player,
      components: <EntityComponent>[
        PositionComponent(position: position, facing: facing),
        HealthComponent(current: maximum, maximum: maximum),
        AmmoComponent(loaded: loadedAmmo, hasGun: hasGun),
        ActorComponent(
          tickCost: stats.tickCost,
          contactDamage: stats.contactDamage,
        ),
      ],
    );
  }

  Entity zombie({
    required String id,
    required EntityKind kind,
    required GridPoint position,
    Direction facing = Direction.west,
  }) {
    if (kind == EntityKind.player) {
      throw ArgumentError.value(kind, 'kind', 'A zombie cannot be a player.');
    }
    final stats = balance[kind];
    return Entity(
      id: id,
      kind: kind,
      components: <EntityComponent>[
        PositionComponent(position: position, facing: facing),
        HealthComponent(current: stats.health, maximum: stats.health),
        VisionComponent(range: stats.vision),
        HearingComponent(range: stats.hearing),
        ActorComponent(
          tickCost: stats.tickCost,
          contactDamage: stats.contactDamage,
          attackReach: stats.attackReach,
          stationary: stats.stationary,
          trailsFire: stats.trailsFire,
          staggers: stats.staggers,
        ),
      ],
    );
  }
}
