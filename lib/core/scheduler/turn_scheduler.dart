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

  List<WorldEvent> advance(WorldState world, PlayerAction action) {
    action.resolve(world);

    for (var index = 0; index < action.tickCost; index++) {
      world.tick += 1;
      final actors = world.actorsInSimulationRadius().toList()
        ..sort((left, right) => left.id.compareTo(right.id));
      for (final entity in actors) {
        final actor = entity.component<ActorComponent>();
        if (!actor.gainEnergy()) {
          continue;
        }
        ai.takeTurn(world, entity);
      }
      noise.settle(world);
    }

    return world.drainEvents();
  }
}
