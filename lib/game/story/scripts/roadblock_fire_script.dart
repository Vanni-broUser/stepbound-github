import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The pile-up closing the shopping street west of the campfire behind the
/// hypermarket has a gap with no car in it, and fuel burning right across
/// it. It is the one stretch that looks like a way through, so looking at
/// it says what it would take; Mario can come back and look again. The gap
/// between the station's burning car and the rubble, the one way from the
/// platform onto the tracks, says the same, and so does the gap in the
/// roadblock of burning police cars east of Termini, in Rome.
final class RoadblockFireScript extends StoryScript {
  RoadblockFireScript(super.director);

  static const String fireLine =
      "L'incendio blocca completamente la strada, potresti passare con un "
      'estintore';

  @override
  String get key => 'roadblockFire';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent ||
        (event.at != shoppingStreetFireTile &&
            event.at != stationTrackFireTile &&
            event.at != roadblockFireTile)) {
      return;
    }
    say(StoryPrompt(const <StoryLine>[StoryLine(fireLine)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
