import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The first street: the zombie east of the crossroads spots Mario and
/// steps closer, then the wanderers' pace is explained and Mario decides
/// to get away from it.
final class StreetScript extends StoryScript {
  StreetScript(super.director);

  static const String zombieSpotted = 'Merda uno zombi! Meglio svignarsela';

  bool _zombieLessonGiven = false;

  @override
  String get key => 'street';

  @override
  void onEvent(WorldEvent event) {
    if (event case AlertedEvent(
      entityId: tutorialZombieId,
    ) when !_zombieLessonGiven) {
      _zombieLessonGiven = true;
      director.introduceZombie(
        world.entities[tutorialZombieId]!,
        then: const <StoryLine>[StoryLine.mario(zombieSpotted)],
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
