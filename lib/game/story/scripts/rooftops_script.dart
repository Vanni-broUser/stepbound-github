import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The roofs the airliner's tail came down in, the top of the Duomo's bell
/// tower and the hospital's roof. The lower terrace ends at a parapet with
/// the next block just across the gap, the tower faces its twin across the
/// nave, the hospital's roof the block east of it, and looking
/// over is the only thing Mario can do about either for now: the gap is
/// measured for him, and he can come back and look again.
final class RooftopsScript extends StoryScript {
  RooftopsScript(super.director);

  static const String gapLesson =
      'Il tetto vicino non è molto distante, è raggiungibile con un rampino';

  @override
  String get key => 'rooftops';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent ||
        (event.at != rooftopGapTile &&
            event.at != duomoTowerLookoutTile &&
            event.at != hospitalRoofLookoutTile)) {
      return;
    }
    say(StoryPrompt(const <StoryLine>[StoryLine(gapLesson)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
