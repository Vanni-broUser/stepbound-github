import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/save/save_game.dart';

void main() {
  SaveGame save() => SaveGame(
    slot: 1,
    savedAt: DateTime(2026),
    place: 'Accampamento dietro la caserma',
    world: saveTutorialWorld(createTutorialWorld()),
    tutorial: const <String, Object?>{},
    progress: Progress.newGame().toJson(),
    hud: const <String>[],
  );

  test('a save reads back as it was written', () async {
    final saves = MemorySaveRepository();
    await saves.save(save());
    final loaded = (await saves.load(1))!;
    expect(loaded.place, 'Accampamento dietro la caserma');
    expect(loaded.world['mapChanges'], isEmpty);
  });

  test('a save keeps the memories in the order they were lived', () async {
    // The Duomo met, then the hypermarket, then the Duomo again: the
    // harbour and the mall can be played in any order, even interleaved.
    final progress = Progress.newGame()
      ..remember(StoryMemory.priestMet)
      ..remember(StoryMemory.luigiTrapped)
      ..remember(StoryMemory.priestErrand);
    final saves = MemorySaveRepository();
    await saves.save(
      SaveGame(
        slot: 1,
        savedAt: DateTime(2026),
        place: 'Accampamento dietro la caserma',
        world: saveTutorialWorld(createTutorialWorld()),
        tutorial: const <String, Object?>{},
        progress: progress.toJson(),
        hud: const <String>[],
      ),
    );
    final loaded = Progress.fromJson((await saves.load(1))!.progress);
    expect(loaded.memories.toList(), <StoryMemory>[
      StoryMemory.newsBroadcast,
      StoryMemory.outbreakNight,
      StoryMemory.priestMet,
      StoryMemory.luigiTrapped,
      StoryMemory.priestErrand,
    ]);
  });

  test('a save of another format reads as an empty slot', () {
    final older = save().toJson()..remove('format');
    expect(() => SaveGame.fromJson(older), throwsFormatException);
    final newer = save().toJson()..['format'] = SaveGame.format + 1;
    expect(() => SaveGame.fromJson(newer), throwsFormatException);
  });
}
