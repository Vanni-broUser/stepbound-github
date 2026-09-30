import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The flat door on the palazzo's third floor still locked. Without the
/// key found on the first floor it only says so; with it, the door opens
/// for good on the flat behind it, and the key is used up doing so, as
/// the Duomo's is.
final class PalazzoScript extends StoryScript {
  PalazzoScript(super.director);

  static const String lockedDoorLine =
      'Questa porta è chiusa a chiave. Qualcuno dei vicini avrà la chiave';
  static const String keyUsedLine =
      'Hai usato la Chiave del terzo piano per aprire la porta';

  @override
  String get key => 'palazzo';

  @override
  void onEvent(WorldEvent event) {
    if (event case NoInteractionEvent(
      :final at,
    ) when at == palazzoLockedDoorTile) {
      if (world.map.tileAt(at).isWalkable) {
        return;
      }
      if (host.isUnlocked(HudElement.palazzoKey)) {
        world.map.setTile(at, const Tile(TileKind.floor));
        host.removeHud(HudElement.palazzoKey);
        say(StoryPrompt(const <StoryLine>[StoryLine(keyUsedLine)]));
        return;
      }
      say(StoryPrompt(const <StoryLine>[StoryLine(lockedDoorLine)]));
    }
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
