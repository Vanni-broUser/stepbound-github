import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
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
    // Keys used up on their doors, the doors open.
    expect(save.hud, isNot(contains(HudElement.barKey.name)));
    expect(save.hud, isNot(contains(HudElement.duomoKey.name)));
    final world = restoreGameWorld(save.world);
    expect(world.map.tileAt(barLockedDoorTile).isWalkable, isTrue);
    expect(world.map.tileAt(duomoUpperLockedDoorTile).isWalkable, isTrue);
    expect(world.pickups[duomoKeyPickupId]!.collected, isTrue);
    final progress = Progress.fromJson(save.progress);
    expect(progress.hasGoldenPistol, isTrue);
    expect(progress.memories, contains(StoryMemory.goldenPistol));
    // Every type of Molfetta but the call centre's operators, only met
    // in the company after Rome, with the grappling hook.
    expect(
      progress.knownZombies,
      containsAll(
        levelZombieKinds(
          LevelId.hometown,
        ).where((kind) => kind != EntityKind.callCenter).toSet(),
      ),
    );
    expect(progress.knownZombies, isNot(contains(EntityKind.callCenter)));
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
    // Tonino and Marcello already seen to: the ingot taken from the vault
    // and handed over, the ticket for the Colosseum in its place, the two
    // of them gone.
    expect(save.hud, contains(HudElement.colosseumTicket.name));
    expect(save.hud, isNot(contains(HudElement.goldIngot.name)));
    expect(world.pickups[bankIngotBackpackId]!.collected, isTrue);
    expect(progress.missions.isDone(Mission.findValuable), isTrue);
    expect(progress.missions.isOpen(Mission.discoverColosseum), isTrue);
    expect(progress.memories, contains(StoryMemory.maranzaPaid));
    final maranza = save.story['maranza']! as Map<String, Object?>;
    expect(maranza['paid'], isTrue);
    expect(maranza['gone'], isTrue);
  });

  test('install gives every test skin to the VANNI_DEPLOY slot', () async {
    final saves = MemorySaveRepository();

    await installVanniDeploySave(saves);
    await installVanniDeployGifts(saves);

    expect(
      await saves.loadGifts(vanniDeploySlot),
      unorderedEquals(vanniDeployOutfits),
    );
  });

  test('Roma and Lazio have no normal-game unlock path', () {
    for (final outfit in <PlayerOutfit>[
      PlayerOutfit.roma,
      PlayerOutfit.lazio,
    ]) {
      expect(Progress.newGame().unlockedOutfits, isNot(contains(outfit)));
      expect(
        halloweenOutfits,
        isNot(contains(outfit)),
        reason: 'team skins are not distributed by seasonal gift links',
      );
    }
  });
}
