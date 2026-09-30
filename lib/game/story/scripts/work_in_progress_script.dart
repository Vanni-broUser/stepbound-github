import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// Wherever the game goes no further yet, it says so. Mario stepping on a
/// tile of `workInProgressEnds` -- the last tile of a street, a platform
/// or a track that runs off its map with no next map -- or on a door of
/// `workInProgressDoors` -- stairs into a building with no map yet --
/// brings up the work-in-progress screen, the same one in every level;
/// once it is tapped away he is back a step inside, facing into the place,
/// or back where he stepped onto the door from, facing away from it.
///
/// It holds for every place of every level without being told: see
/// docs/level_pipeline.md, "Strade incomplete".
final class WorkInProgressScript extends StoryScript {
  WorkInProgressScript(super.director);

  @override
  String get key => 'workInProgress';

  @override
  void onEvent(WorldEvent event) {
    if (event case MovedEvent(
      :final entityId,
      :final from,
      :final to,
    ) when entityId == world.playerId) {
      final back = workInProgressEnds[to];
      if (back != null) {
        host.showWorkInProgress(onClosed: () => _stepBack(to, back));
        return;
      }
      if (workInProgressDoors.contains(to)) {
        final away = Direction.values.firstWhere((way) => to.step(way) == from);
        host.showWorkInProgress(onClosed: () => _stepBack(to, away));
      }
    }
  }

  void _stepBack(GridPoint from, Direction back) {
    world.player.component<PositionComponent>()
      ..position = from.step(back)
      ..facing = back;
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
