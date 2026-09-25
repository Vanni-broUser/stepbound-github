import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/world.dart';
import 'package:stepbound/core/world_event.dart';

final class NoiseSystem {
  const NoiseSystem();

  void settle(WorldState world) {
    for (final noise in world.takePendingNoises()) {
      final distances = world.map.floodFillDistances(
        noise.origin,
        maxDistance: noise.radius,
      );
      for (final entity in world.actorsInSimulationRadius()) {
        final hearing = entity.component<HearingComponent>();
        final position = entity.component<PositionComponent>().position;
        final distance = distances[position];
        if (distance == null || distance > hearing.range) {
          continue;
        }
        hearing.lastHeard = noise.origin;
        world.emit(NoiseHeardEvent(entityId: entity.id, origin: noise.origin));
      }
    }
  }
}
