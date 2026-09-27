import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/test_scenarios.dart';
import 'package:stepbound/save/save_game.dart';

/// Whether this build should always offer the current end-of-Molfetta test
/// save. Dart defines are strings so the CI variable can deliberately use 1.
const bool vanniDeployEnabled = String.fromEnvironment('VANNI_DEPLOY') == '1';

/// Kept out of the normal three slots. A VANNI_DEPLOY build owns this slot
/// and rebuilds it at every launch, so a save-format bump can never stale it.
const int vanniDeploySlot = SaveRepository.slotCount;

Future<void> installVanniDeploySave(SaveRepository saves) async {
  await saves.clear(vanniDeploySlot);
  await saves.save(vanniDeployScenario.save(vanniDeploySlot));
}

/// Gives every Halloween skin to the test slot, as if their gift links had
/// been opened. Normal builds only get them through the links.
Future<void> installVanniDeployGifts(SaveRepository saves) =>
    saves.saveGifts(vanniDeploySlot, halloweenOutfits.toSet());
