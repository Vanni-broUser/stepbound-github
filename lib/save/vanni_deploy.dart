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
