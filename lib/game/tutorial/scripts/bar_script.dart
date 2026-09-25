import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The locked service door in the Bar Arcobaleno. Before Don Angelo gives
/// Mario its key it explains what is missing; afterwards one interaction
/// unlocks the way into the storeroom, consumes the key and says so.
final class BarScript extends TutorialScript {
  BarScript(super.director);

  static const String lockedDoorLine =
      'Questa porta è chiusa. Serve una chiave';
  static const String keyUsedLine = 'Hai usato la chiave per aprire la porta';

  @override
  String get key => 'bar';

  @override
  void onEvent(WorldEvent event) {
    if (event case NoInteractionEvent(:final at) when at == barLockedDoorTile) {
      if (world.map.tileAt(at).isWalkable) {
        return;
      }
      if (host.isUnlocked(HudElement.barKey)) {
        world.map.setTile(at, const Tile(TileKind.floor));
        host.removeHud(HudElement.barKey);
        say(TutorialPrompt(const <TutorialLine>[TutorialLine(keyUsedLine)]));
        return;
      }
      say(TutorialPrompt(const <TutorialLine>[TutorialLine(lockedDoorLine)]));
    }
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
