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

  test('a save of another format reads as an empty slot', () {
    final older = save().toJson()..remove('format');
    expect(() => SaveGame.fromJson(older), throwsFormatException);
    final newer = save().toJson()..['format'] = SaveGame.format + 1;
    expect(() => SaveGame.fromJson(newer), throwsFormatException);
  });
}
