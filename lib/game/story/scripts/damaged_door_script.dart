import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// A few palazzo doors in the old town's alleys are damaged enough that a
/// crowbar could force them. Looking at one says so; Mario can come back
/// and look again. There is no crowbar yet, so they stay shut.
final class DamagedDoorScript extends StoryScript {
  DamagedDoorScript(super.director);

  static const String doorLine =
      "Questa porta è un po' danneggiata, con un piede di porco potresti "
      'aprirla';

  @override
  String get key => 'damagedDoor';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent ||
        !oldTownDamagedDoorTiles.contains(event.at)) {
      return;
    }
    say(StoryPrompt(const <StoryLine>[StoryLine(doorLine)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
