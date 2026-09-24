import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/game/zombie_lore.dart';

/// The zombie types introduced the first time one is on screen, wherever
/// that happens (see [ZombieLore.introducedOnSight]): the sprinter, in the
/// hypermarket's car park, the mutilated, in the crashed airliner, the
/// burning one, on the roofs past it, and the drunk in the Bar Arcobaleno.
///
/// What it has done is `Progress.knownZombies` itself: a type is introduced
/// once in the whole game, not once a level, and a save keeps that with the
/// rest of the progress, so this script has nothing of its own to save.
final class ZombieSightingsScript extends TutorialScript {
  ZombieSightingsScript(super.director);

  @override
  String get key => 'sightings';

  @override
  void update({required bool turnAnimating}) {
    // The camera can frame one zombie at a time: a new type waits for
    // whatever is being said to be over, two in sight at once come one
    // after the other.
    if (!director.isIdle) {
      return;
    }
    for (final zombie in world.entities.values) {
      if (zombieLore[zombie.kind]?.introducedOnSight != true ||
          progress.knownZombies.contains(zombie.kind) ||
          !zombie.isAlive ||
          !host.isTileVisible(zombie.component<PositionComponent>().position)) {
        continue;
      }
      director.introduceZombie(zombie);
      return;
    }
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
