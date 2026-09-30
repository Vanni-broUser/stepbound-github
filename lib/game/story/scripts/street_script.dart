import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// The first street: the zombie east of the crossroads is introduced as
/// soon as the whole of it is on screen and the player has the controls,
/// wherever Mario is standing and whatever the screen, with the view as it
/// is: nothing waits for him to walk into the crossroads, where the view
/// starts following him and the zombie steps closer. Then the wanderers'
/// pace is explained and Mario decides to get away from it. Its alert is
/// only a fallback, should it notice him before it is in sight.
final class StreetScript extends StoryScript {
  StreetScript(super.director);

  static String get zombieSpotted => strings.streetZombieSpotted;

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
        !host.isTileVisible(zombie.component<PositionComponent>().position)) {
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
      then: <StoryLine>[StoryLine.mario(zombieSpotted)],
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
