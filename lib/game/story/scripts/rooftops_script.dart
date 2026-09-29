import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The roofs the airliner's tail came down in, the top of the Duomo's bell
/// tower and the hospital's roof. The lower terrace ends at a parapet with
/// the next block just across the gap, the tower faces its twin across the
/// nave, the hospital's roof the block east of it. Without the grappling
/// hook, looking over is all Mario can do: the gap is measured for him,
/// and he can come back and look again. With it, he swings across, and
/// the game says so. The first time he lands on the Duomo's other tower,
/// after the backpack seen from the first, a cultist comes up there after
/// him.
final class RooftopsScript extends StoryScript {
  RooftopsScript(super.director);

  static const String gapLesson =
      'Il tetto vicino non è molto distante, è raggiungibile con un rampino';
  static const String grappleLine = 'Mario usa il rampino';

  /// Whether the cultist on the Duomo's other tower has come out.
  bool _towerCultistOut = false;

  @override
  String get key => 'rooftops';

  @override
  void onEvent(WorldEvent event) {
    if (event case TeleportedEvent(grappled: true, :final to)) {
      final ontoFarTower =
          !_towerCultistOut && to == world.grapples[duomoTowerLookoutTile]?.to;
      // Said once he has landed: prompts wait for the swing to play.
      say(
        StoryPrompt(const <StoryLine>[
          StoryLine(grappleLine),
        ], onDismissed: ontoFarTower ? _raiseTowerCultist : null),
      );
      return;
    }
    if (event is! LookedOutEvent ||
        (event.at != rooftopGapTile &&
            event.at != duomoTowerLookoutTile &&
            event.at != hospitalRoofLookoutTile)) {
      return;
    }
    say(StoryPrompt(const <StoryLine>[StoryLine(gapLesson)]));
  }

  /// The cultist comes out of the far corner of the other tower, headed
  /// for where Mario landed: it sees him at once, and raises the alert.
  void _raiseTowerCultist() {
    if (_towerCultistOut) {
      return;
    }
    _towerCultistOut = true;
    final cultist = createDuomoTowerCultist();
    cultist.component<HearingComponent>().lastHeard = world.player
        .component<PositionComponent>()
        .position;
    host.spawnZombie(cultist);
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (_towerCultistOut) 'towerCultist': true,
  };

  @override
  void restore(Map<String, Object?> json) {
    _towerCultistOut = json['towerCultist'] as bool? ?? false;
  }
}
