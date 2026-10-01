import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// The roofs the airliner's tail came down in, the top of the Duomo's bell
/// tower and the hospital's roof, and in Rome the terrace of the palazzo on
/// Via Marsala, the bank's roof across from it. The lower terrace ends at a
/// parapet with the next block just across the gap, the tower faces its
/// twin across the nave, the hospital's roof the block east of it, the
/// terrace the bank's roof west of it. Without the grappling
/// hook, looking over is all Mario can do: the gap is measured for him,
/// and he can come back and look again. With it, he swings across, and
/// the game says so. The first time he lands on the Duomo's other tower,
/// after the backpack seen from the first, a cultist comes up there after
/// him.
///
/// Back in Molfetta with the hook, Mario is given
/// [Mission.exploreTerraces]; it is done once he has crossed all three
/// gaps, each at least once, either way.
final class RooftopsScript extends StoryScript {
  RooftopsScript(super.director);

  static String get gapLesson => strings.rooftopsGapLesson;
  static String get grappleLine => strings.rooftopsGrappleLine;

  /// Whether the cultist on the Duomo's other tower has come out.
  bool _towerCultistOut = false;

  /// The gaps crossed with the hook, by their names in
  /// `hometownGrappleCrossings`.
  final Set<String> _crossed = <String>{};

  @override
  String get key => 'rooftops';

  @override
  void onEvent(WorldEvent event) {
    if (event case TeleportedEvent(grappled: true, :final to)) {
      if (hometownGrappleCrossings[to] case final crossing?) {
        _crossed.add(crossing);
        _checkTerraces();
      }
      final ontoFarTower =
          !_towerCultistOut && to == world.grapples[duomoTowerLookoutTile]?.to;
      // Said once he has landed: prompts wait for the swing to play.
      say(
        StoryPrompt(<StoryLine>[
          StoryLine(grappleLine),
        ], onDismissed: ontoFarTower ? _raiseTowerCultist : null),
      );
      return;
    }
    if (event is! LookedOutEvent ||
        (event.at != rooftopGapTile &&
            event.at != duomoTowerLookoutTile &&
            event.at != hospitalRoofLookoutTile &&
            event.at != romeTerraceLookoutTile)) {
      return;
    }
    say(StoryPrompt(<StoryLine>[StoryLine(gapLesson)]));
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
  void update({required bool turnAnimating}) {
    final missions = progress.missions;
    const mission = Mission.exploreTerraces;
    if (progress.level == LevelId.hometown &&
        !missions.isOpen(mission) &&
        !missions.isDone(mission) &&
        world.player.component<AmmoComponent>().grapplingHook) {
      missions.give(mission);
      _checkTerraces();
    }
  }

  /// Crosses [Mission.exploreTerraces] out once all three gaps are behind
  /// Mario and it has been handed out.
  void _checkTerraces() {
    if (_crossed.length == _allCrossings &&
        progress.missions.isOpen(Mission.exploreTerraces)) {
      progress.missions.complete(Mission.exploreTerraces);
    }
  }

  static final int _allCrossings = hometownGrappleCrossings.values
      .toSet()
      .length;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (_towerCultistOut) 'towerCultist': true,
    if (_crossed.isNotEmpty) 'crossed': <String>[..._crossed],
  };

  @override
  void restore(Map<String, Object?> json) {
    _towerCultistOut = json['towerCultist'] as bool? ?? false;
    _crossed
      ..clear()
      ..addAll((json['crossed'] as List<Object?>? ?? const <Object?>[]).cast());
  }
}
