import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/zombie_lore.dart';

/// The zombie types introduced the first time one is on screen, wherever
/// that happens (see [ZombieLore.introducedOnSight]): the sprinter, in the
/// hypermarket's car park, the mutilated, in the crashed airliner, the
/// burning one, on the roofs past it, and the drunk in the Bar Arcobaleno.
///
/// What it has done is `Progress.knownZombies` itself: a type is introduced
/// once in the whole game, not once a level, and a save keeps that with the
/// rest of the progress, so this script has nothing of its own to save.
/// A type already known elsewhere, of any kind, becomes known in this city
/// too the first time one is seen here, without a word: starting over the
/// city where it was met leaves it known where it has been seen since.
///
/// Through a door or a portal, or across a gap on the grappling hook, the
/// new place is not introduced at once: the lesson waits for Mario's first
/// step there, so that the player sees where he has landed before the text
/// covers it.
final class ZombieSightingsScript extends StoryScript {
  ZombieSightingsScript(super.director);

  @override
  String get key => 'sightings';

  /// Mario has just landed somewhere through a door and has not taken a
  /// step there yet.
  bool _justArrived = false;

  @override
  void onEvent(WorldEvent event) {
    // Stepping onto a portal moves Mario first and then takes him through:
    // the step that counts is the next one.
    if (event case TeleportedEvent(:final entityId)
        when entityId == world.playerId) {
      _justArrived = true;
    } else if (event case MovedEvent(:final entityId)
        when entityId == world.playerId) {
      _justArrived = false;
    }
  }

  @override
  void update({required bool turnAnimating}) {
    // One lesson at a time: a new type waits for whatever is being said to
    // be over, two in sight at once come one after the other.
    if (!director.isIdle || _justArrived) {
      return;
    }
    for (final zombie in world.entities.values) {
      final kind = zombie.kind;
      final lore = zombieLore[kind];
      if (lore == null ||
          progress.knowsIn(kind, progress.level) ||
          !zombie.isAlive ||
          !host.isTileVisible(zombie.component<PositionComponent>().position)) {
        continue;
      }
      if (progress.knownZombies.contains(kind)) {
        progress.meet(kind);
        continue;
      }
      if (lore.introducedOnSight) {
        director.introduceZombie(zombie);
        return;
      }
    }
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
