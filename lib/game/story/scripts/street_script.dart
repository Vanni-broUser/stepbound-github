import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The first street: the zombie east of the crossroads is introduced as
/// soon as Mario, done with the movement hint, reaches the column just
/// before the west zebra crossing ([tutorialZombieLessonTrigger]), with the
/// view as it is. Then the wanderers' pace is explained and Mario decides
/// to get away from it. Its alert is only a fallback, should it notice him
/// before he gets there.
final class StreetScript extends StoryScript {
  StreetScript(super.director);

  static const String zombieSpotted = 'Merda uno zombi! Meglio svignarsela';

  bool _zombieLessonGiven = false;

  @override
  String get key => 'street';

  @override
  void update({required bool turnAnimating}) {
    if (_zombieLessonGiven || !host.inPlay || !director.isIdle) {
      return;
    }
    final zombie = world.entities[tutorialZombieId];
    if (zombie == null ||
        !zombie.isAlive ||
        !tutorialZombieLessonTrigger.contains(
          world.player.component<PositionComponent>().position,
        )) {
      return;
    }
    _introduce(zombie);
  }

  @override
  void onEvent(WorldEvent event) {
    if (event case AlertedEvent(
      entityId: tutorialZombieId,
    ) when !_zombieLessonGiven) {
      _introduce(world.entities[tutorialZombieId]!);
    }
  }

  void _introduce(Entity zombie) {
    _zombieLessonGiven = true;
    director.introduceZombie(
      zombie,
      then: const <StoryLine>[StoryLine.mario(zombieSpotted)],
    );
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
