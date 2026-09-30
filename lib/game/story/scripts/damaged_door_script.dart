import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// A few palazzo doors in the old town's alleys are damaged enough that a
/// crowbar could force them. Looking at one says so; Mario can come back
/// and look again. There is no crowbar yet, so they stay shut.
final class DamagedDoorScript extends StoryScript {
  DamagedDoorScript(super.director);

  static String get doorLine => strings.damagedDoorLine;

  @override
  String get key => 'damagedDoor';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent ||
        !oldTownDamagedDoorTiles.contains(event.at)) {
      return;
    }
    say(StoryPrompt(<StoryLine>[StoryLine(doorLine)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
