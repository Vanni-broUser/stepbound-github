import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/test_scenarios.dart';
import 'package:stepbound/save/save_game.dart';

/// Whether this build should always offer the current end-of-Molfetta test
/// save. Dart defines are strings so the CI variable can deliberately use 1.
const bool vanniDeployEnabled = String.fromEnvironment('VANNI_DEPLOY') == '1';

/// Kept out of the normal three slots. A VANNI_DEPLOY build owns this slot
/// and rebuilds it at every launch, so a save-format bump can never stale it.
const int vanniDeploySlot = SaveRepository.slotCount;

/// Outfits available only in the build-owned test slot. Roma and Lazio have
/// no normal unlock path yet; keeping them here prevents regular games from
/// wearing them while their future distribution is undecided.
const List<PlayerOutfit> vanniDeployOutfits = <PlayerOutfit>[
  ...halloweenOutfits,
  PlayerOutfit.roma,
  PlayerOutfit.lazio,
];

Future<void> installVanniDeploySave(SaveRepository saves) async {
  await saves.clear(vanniDeploySlot);
  await saves.save(vanniDeployScenario.save(vanniDeploySlot));
}

/// Gives every test skin to the build-owned slot. Normal saves never receive
/// Roma or Lazio, while Halloween skins keep their existing gift-link path.
Future<void> installVanniDeployGifts(SaveRepository saves) =>
    saves.saveGifts(vanniDeploySlot, vanniDeployOutfits.toSet());
