import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The north district: the first camp in sight teaches resting (with the
/// interact button, if the player never picked up a backpack), and the
/// first sprinter on screen, the one in the hypermarket's car park, is
/// framed while its pace is explained.
final class NorthDistrictScript extends TutorialScript {
  NorthDistrictScript(super.director);

  static const String campLesson =
      'Usa gli accampamenti per salvare i tuoi progressi';
  static const String sprinterLesson =
      'Gli zombi veloci si muovono alla tua stessa velocità';
  static const String sprinterPortrait = 'assets/story/portrait_sprinter.png';

  bool _campLessonGiven = false;
  bool _sprinterLessonGiven = false;

  @override
  String get key => 'north';

  @override
  void update({required bool turnAnimating}) {
    _checkCampSeen();
    _checkSprinterSeen();
  }

  void _checkCampSeen() {
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

  void _checkSprinterSeen() {
    if (_sprinterLessonGiven) {
      return;
    }
    for (final zombie in world.entities.values) {
      if (zombie.kind != EntityKind.sprinter ||
          !zombie.isAlive ||
          !host.isTileVisible(zombie.component<PositionComponent>().position)) {
        continue;
      }
      _sprinterLessonGiven = true;
      progress.meet(EntityKind.sprinter);
      host.focusOn(zombie.id);
      say(
        TutorialPrompt(
          const <TutorialLine>[
            TutorialLine(sprinterLesson, portrait: sprinterPortrait),
          ],
          delay: TutorialDirector.focusDelay,
          onDismissed: () => host.focusOn(null),
        ),
      );
      return;
    }
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'campLesson': _campLessonGiven,
    'sprinterLesson': _sprinterLessonGiven,
  };

  @override
  void restore(Map<String, Object?> json) {
    _campLessonGiven = json['campLesson'] as bool? ?? false;
    _sprinterLessonGiven = json['sprinterLesson'] as bool? ?? false;
  }
}
