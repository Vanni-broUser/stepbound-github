import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/ui/level_complete.dart';

/// The memories of a level count its scenes, each whole: not the pictures
/// in them.
void main() {
  final world = createGameWorld();

  LevelStats stats(Progress progress, LevelId level) =>
      LevelStats.of(world, progress, level);

  test('Molfetta holds twelve scenes to remember, Rome three', () {
    expect(stats(Progress(), LevelId.hometown).totalMemories, 12);
    expect(stats(Progress(), LevelId.rome).totalMemories, 3);
  });

  test("Don Angelo's story is one memory a scene, the mass and the "
      'massacre after it one', () {
    final progress = Progress();
    int found() => stats(progress, LevelId.hometown).foundMemories;

    for (final (memory, count) in <(StoryMemory, int)>[
      (StoryMemory.priestMet, 1),
      (StoryMemory.priestErrand, 2),
      (StoryMemory.priestWelcomed, 3),
      (StoryMemory.priestFamily, 4),
      (StoryMemory.priestMass, 5),
      (StoryMemory.priestMassacre, 5),
    ]) {
      progress.remember(memory);
      expect(found(), count, reason: memory.name);
    }
  });

  test("the golden pistol is part of Luigi's welcome at the station", () {
    final progress = Progress()..remember(StoryMemory.luigiAtStation);
    expect(stats(progress, LevelId.hometown).foundMemories, 1);
    progress.remember(StoryMemory.goldenPistol);
    expect(stats(progress, LevelId.hometown).foundMemories, 1);
  });
}
