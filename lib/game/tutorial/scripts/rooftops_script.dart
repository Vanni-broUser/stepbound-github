import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The roofs the airliner's tail came down in. The lower terrace ends at a
/// parapet with the next block just across the gap, and looking at it is
/// the only thing Mario can do about it for now: the gap is measured for
/// him, and he can come back and look again.
final class RooftopsScript extends TutorialScript {
  RooftopsScript(super.director);

  static const String gapLesson =
      'Il tetto vicino non è molto distante, è raggiungibile con un rampino';

  @override
  String get key => 'rooftops';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent || event.at != rooftopGapTile) {
      return;
    }
    say(TutorialPrompt(const <TutorialLine>[TutorialLine(gapLesson)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
