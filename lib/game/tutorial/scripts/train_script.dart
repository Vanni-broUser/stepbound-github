import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// Mario and Luigi's home in the locomotive: talking to Luigi, the books by
/// Mario's cot (the zombie types met so far) and the cot itself (the
/// memories). None of it is used up, so each can be come back to.
final class TrainScript extends TutorialScript {
  TrainScript(super.director);

  static const TutorialLine luigiLine = TutorialLine.luigi(
    "Sarà un viaggio per l'Europa molto impegnativo",
  );

  @override
  String get key => 'train';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent) {
      return;
    }
    if (event.at == trainLuigiTile) {
      say(TutorialPrompt(const <TutorialLine>[luigiLine]));
    } else if (trainBookTiles.contains(event.at)) {
      host.openZombieBook();
    } else if (trainCotTiles.contains(event.at)) {
      host.replayMemories();
    }
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
