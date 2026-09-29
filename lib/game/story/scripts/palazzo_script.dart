import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The flat door on the palazzo's third floor still locked. Without the
/// key found on the first floor it only says so; with it, the door would
/// open on a flat that has no map yet, so the key opens the
/// work-in-progress screen instead, and is kept for when it has one.
final class PalazzoScript extends StoryScript {
  PalazzoScript(super.director);

  static const String lockedDoorLine =
      'Questa porta è chiusa a chiave. Qualcuno dei vicini avrà la chiave';

  @override
  String get key => 'palazzo';

  @override
  void onEvent(WorldEvent event) {
    if (event case NoInteractionEvent(
      :final at,
    ) when at == palazzoLockedDoorTile) {
      if (host.isUnlocked(HudElement.palazzoKey)) {
        host.showWorkInProgress();
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
