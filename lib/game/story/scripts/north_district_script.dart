import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// The north district: the first camp in sight teaches resting (with the
/// interact button, if the player never picked up a backpack). The first
/// sprinter on screen, the one in the hypermarket's car park, is left to
/// [ZombieSightingsScript], like every type introduced on sight.
final class NorthDistrictScript extends StoryScript {
  NorthDistrictScript(super.director);

  static String get campLesson => strings.northDistrictCampLesson;

  bool _campLessonGiven = false;

  @override
  String get key => 'north';

  @override
  void update({required bool turnAnimating}) {
    // The table aboard saves too, but it is no fire: the lesson waits for
    // a real one.
    if (_campLessonGiven ||
        !world.campfires
            .where((camp) => !trainFoodTiles.contains(camp))
            .any(host.isTileVisible)) {
      return;
    }
    _campLessonGiven = true;
    final needsInteract = !host.isUnlocked(HudElement.interact);
    say(
      StoryPrompt(
        <StoryLine>[
          StoryLine(campLesson),
          if (needsInteract)
            StoryLine(
              BackpacksScript.interactLesson,
              demo: ControlDemo.interact,
            ),
        ],
        delay: StoryDirector.reactionDelay,
        onDismissed: () => host.unlock(HudElement.interact),
      ),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'campLesson': _campLessonGiven,
  };

  @override
  void restore(Map<String, Object?> json) {
    _campLessonGiven = json['campLesson'] as bool? ?? false;
  }
}
