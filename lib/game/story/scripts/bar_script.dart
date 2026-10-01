import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// The locked service door in the Bar Arcobaleno. Before Don Angelo gives
/// Mario its key it explains what is missing; afterwards one interaction
/// unlocks the way into the storeroom, consumes the key and says so.
final class BarScript extends StoryScript {
  BarScript(super.director);

  static String get lockedDoorLine => strings.barLockedDoorLine;
  static String get keyUsedLine => strings.barKeyUsedLine;

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
        say(StoryPrompt(<StoryLine>[StoryLine(keyUsedLine)]));
        return;
      }
      say(StoryPrompt(<StoryLine>[StoryLine(lockedDoorLine)]));
    }
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
