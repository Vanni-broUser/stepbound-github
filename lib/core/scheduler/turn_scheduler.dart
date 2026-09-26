import 'package:stepbound/core/actions/player_action.dart';
import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/systems/noise_system.dart';
import 'package:stepbound/core/systems/zombie_ai.dart';
import 'package:stepbound/core/world.dart';
import 'package:stepbound/core/world_event.dart';

final class TurnScheduler {
  const TurnScheduler({
    this.ai = const ZombieAi(),
    this.noise = const NoiseSystem(),
  });

  final ZombieAi ai;
  final NoiseSystem noise;

  /// Resolves [action], then lets every zombie in reach act. Not when the
  /// action took Mario through a door: whatever waits on the other side,
  /// even one that chased him up to it, has not had time to move yet, so
  /// the next turn is his again (to shoot it, or to step back out).
  List<WorldEvent> advance(WorldState world, PlayerAction action) {
    final before = world.pendingEvents.length;
    action.resolve(world);
    final changedPlace = world.pendingEvents
        .skip(before)
        .any(
          (event) =>
              event is TeleportedEvent && event.entityId == world.playerId,
        );

    for (var index = 0; index < action.tickCost; index++) {
      world.tick += 1;
      noise.settle(world);
      final actors = world.actorsInSimulationRadius().toList()
        ..sort((left, right) => left.id.compareTo(right.id));
      // Out of reach (Mario went through a door), a zombie has lost him:
      // meeting it again raises a new alert.
      final simulated = actors.toSet();
      for (final entity in world.entities.values) {
        if (!simulated.contains(entity)) {
          entity.maybeComponent<HearingComponent>()?.hunting = false;
        }
      }
      if (changedPlace) {
        continue;
      }
      for (final entity in actors) {
        ai.perceive(world, entity);
        final actor = entity.component<ActorComponent>();
        if (!actor.gainEnergy()) {
          continue;
        }
        ai.takeTurn(world, entity);
      }
    }

    return world.drainEvents();
  }
}
