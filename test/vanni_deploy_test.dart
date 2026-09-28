import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/save/vanni_deploy.dart';

void main() {
  test('install replaces a stale slot with a current Molfetta save', () async {
    final saves = MemorySaveRepository();
    saves.values[StoredSaveRepository.slotKey(vanniDeploySlot)] =
        '{"format":${SaveGame.format - 1}}';
    saves.values[StoredSaveRepository.backupKey(vanniDeploySlot)] = 'old';

    await installVanniDeploySave(saves);

    final save = await saves.load(vanniDeploySlot);
    expect(save, isNotNull);
    expect(save!.place, trainPlaceName);
    expect(
      restoreGameWorld(save.world).player.component<AmmoComponent>().loaded,
      10,
    );
    expect(Progress.fromJson(save.progress).hometownCompleted, isTrue);
    final progress = Progress.fromJson(save.progress);
    expect(
      progress.knownZombies,
      containsAll(levelZombieKinds(LevelId.hometown).toSet()),
    );
    expect(
      restoreGameWorld(save.world).entities.values.where(
        (entity) => entity.kind != EntityKind.player && !entity.isAlive,
      ),
      isEmpty,
      reason: 'nobody killed: the level count starts from zero',
    );
    expect(
      saves.values,
      isNot(contains(StoredSaveRepository.backupKey(vanniDeploySlot))),
    );
  });

  test('install gives every Halloween skin to the test slot', () async {
    final saves = MemorySaveRepository();

    await installVanniDeploySave(saves);
    await installVanniDeployGifts(saves);

    expect(
      await saves.loadGifts(vanniDeploySlot),
      unorderedEquals(halloweenOutfits),
    );
  });
}
