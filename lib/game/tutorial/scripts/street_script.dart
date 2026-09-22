import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The first street: the zombie east of the crossroads spots Mario and
/// steps closer, framed with him, then the wanderers' pace is explained.
final class StreetScript extends TutorialScript {
  StreetScript(super.director);

  static const String zombieLesson =
      'I normali zombi vaganti faranno un passo verso di te ogni due passi '
      'tuoi';
  static const String wandererPortrait = 'assets/story/portrait_wanderer.png';

  bool _zombieLessonGiven = false;

  @override
  String get key => 'street';

  @override
  void onEvent(WorldEvent event) {
    if (event case AlertedEvent(
      entityId: tutorialZombieId,
    ) when !_zombieLessonGiven) {
      _zombieLessonGiven = true;
      progress.meet(EntityKind.wanderer);
      // Pan so the alert balloon and the zombie's step are on screen.
      host.focusOn(tutorialZombieId);
      say(
        TutorialPrompt(
          const <TutorialLine>[
            TutorialLine(zombieLesson, portrait: wandererPortrait),
          ],
          delay: TutorialDirector.focusDelay,
          onDismissed: () => host.focusOn(null),
        ),
      );
    }
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'zombieLesson': _zombieLessonGiven,
  };

  @override
  void restore(Map<String, Object?> json) {
    _zombieLessonGiven = json['zombieLesson'] as bool? ?? false;
  }
}
