import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The first street: the zombie east of the crossroads spots Mario and
/// steps closer, framed with him, then the wanderers' pace is explained.
final class StreetScript extends TutorialScript {
  StreetScript(super.director);

  bool _zombieLessonGiven = false;

  @override
  String get key => 'street';

  @override
  void onEvent(WorldEvent event) {
    if (event case AlertedEvent(
      entityId: tutorialZombieId,
    ) when !_zombieLessonGiven) {
      _zombieLessonGiven = true;
      // The framing pans so the alert balloon and the zombie's step are on
      // screen.
      director.introduceZombie(world.entities[tutorialZombieId]!);
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
