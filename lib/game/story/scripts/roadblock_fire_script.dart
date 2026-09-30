import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// The pile-up closing the shopping street west of the campfire behind the
/// hypermarket has a gap with no car in it, and fuel burning right across
/// it. It is the one stretch that looks like a way through, so looking at
/// it says what it would take; Mario can come back and look again. The gap
/// between the station's burning car and the rubble, the one way from the
/// platform onto the tracks, says the same, and so does the gap in the
/// roadblock of burning police cars east of Termini and the pile-up west on
/// Via Marsala, in Rome.
final class RoadblockFireScript extends StoryScript {
  RoadblockFireScript(super.director);

  static String get fireLine => strings.roadblockFireLine;

  @override
  String get key => 'roadblockFire';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent ||
        (event.at != shoppingStreetFireTile &&
            event.at != stationTrackFireTile &&
            event.at != roadblockFireTile &&
            event.at != marsalaFireTile)) {
      return;
    }
    say(StoryPrompt(<StoryLine>[StoryLine(fireLine)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
