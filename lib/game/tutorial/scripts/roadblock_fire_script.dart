import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The pile-up closing the shopping street west of the campfire behind the
/// hypermarket has a gap with no car in it, and fuel burning right across
/// it. It is the one stretch that looks like a way through, so looking at
/// it says what it would take; Mario can come back and look again.
final class RoadblockFireScript extends TutorialScript {
  RoadblockFireScript(super.director);

  static const String fireLine =
      "L'incendio blocca completamente la strada, potresti passare con un "
      'estintore';

  @override
  String get key => 'roadblockFire';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent || event.at != shoppingStreetFireTile) {
      return;
    }
    say(TutorialPrompt(const <TutorialLine>[TutorialLine(fireLine)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
