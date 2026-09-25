import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The north district: the first camp in sight teaches resting (with the
/// interact button, if the player never picked up a backpack). The first
/// sprinter on screen, the one in the hypermarket's car park, is left to
/// [ZombieSightingsScript], like every type introduced on sight.
final class NorthDistrictScript extends TutorialScript {
  NorthDistrictScript(super.director);

  static const String campLesson =
      'Interagisci con i falò per salvare il gioco';

  bool _campLessonGiven = false;

  @override
  String get key => 'north';

  @override
  void update({required bool turnAnimating}) {
    if (_campLessonGiven || !world.campfires.any(host.isTileVisible)) {
      return;
    }
    _campLessonGiven = true;
    final needsInteract = !host.isUnlocked(HudElement.interact);
    say(
      TutorialPrompt(
        <TutorialLine>[
          const TutorialLine(campLesson),
          if (needsInteract) const TutorialLine(BackpacksScript.interactLesson),
        ],
        delay: TutorialDirector.reactionDelay,
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
