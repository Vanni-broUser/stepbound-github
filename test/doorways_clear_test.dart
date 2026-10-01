import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

/// Nobody may be left standing in a doorway (see `WorldState.doorways`):
/// not at the start of the game, nor where the story raises zombies.
void main() {
  final world = createGameWorld();
  final doorways = world.doorways();

  test('nobody starts the game in a doorway', () {
    expect(<String>[
      for (final entity in world.entities.values)
        if (entity.id != world.playerId &&
            doorways.contains(entity.component<PositionComponent>().position))
          entity.id,
    ], isEmpty);
  });

  test('the story raises no zombie in a doorway', () {
    expect(
      <GridPoint>[
        ...carabiniereSpawns,
        ...mallHordeSpawns,
        createDuomoTowerCultist().component<PositionComponent>().position,
      ].where(doorways.contains),
      isEmpty,
    );
  });
}
