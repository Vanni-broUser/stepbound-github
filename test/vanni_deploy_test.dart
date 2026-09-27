import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/save/outfit_unlocks.dart';
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
    expect(
      saves.values,
      isNot(contains(StoredSaveRepository.backupKey(vanniDeploySlot))),
    );
  });

  test('install exposes every Halloween skin in the test build', () async {
    final outfits = MemoryOutfitUnlockRepository();

    await installVanniDeployOutfits(outfits);

    expect(await outfits.load(), unorderedEquals(halloweenOutfits));
  });
}
