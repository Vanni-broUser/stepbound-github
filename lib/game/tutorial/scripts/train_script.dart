import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// Mario and Luigi's home in the locomotive: talking to Luigi, the books by
/// Mario's cot (the zombie types met so far), the cot itself (the
/// memories) and the ammunition crate beside it, which loads Mario up to
/// [trainAmmoRefill] rounds whenever he has fewer. None of it is used up,
/// so each can be come back to.
final class TrainScript extends TutorialScript {
  TrainScript(super.director);

  static const TutorialLine luigiLine = TutorialLine.luigi(
    "Sarà un viaggio per l'Europa molto impegnativo",
  );

  static const String ammoRefilled =
      'Munizioni ricaricate. Torna qui in qualsiasi momento se hai meno di '
      '$trainAmmoRefill proiettili per ricaricare';

  @override
  String get key => 'train';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent) {
      return;
    }
    if (event.at == trainLuigiTile) {
      say(TutorialPrompt(const <TutorialLine>[luigiLine]));
    } else if (trainBookTiles.contains(event.at)) {
      host.openZombieBook();
    } else if (trainCotTiles.contains(event.at)) {
      host.replayMemories();
    } else if (trainAmmoTiles.contains(event.at)) {
      _refill();
    }
  }

  /// With five rounds or more there is nothing to take: nothing happens.
  void _refill() {
    final ammo = world.player.component<AmmoComponent>();
    if (ammo.loaded >= trainAmmoRefill) {
      return;
    }
    ammo.loaded = trainAmmoRefill;
    host.unlock(HudElement.ammo);
    say(TutorialPrompt(const <TutorialLine>[TutorialLine(ammoRefilled)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
