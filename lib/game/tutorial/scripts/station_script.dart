import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The station, where Luigi said he would wait. Getting to him is the
/// whole of it: the doorway onto the platform leads to a dead end behind
/// the derailed train, and only the other one, through the underpass,
/// comes out on the far side. Once Luigi has been rescued, taking the
/// first step on that platform plays their meeting, and that is the end of
/// the level: Mario is aboard, at the map table in the locomotive, and
/// the game is saved there.
final class StationScript extends TutorialScript {
  StationScript(super.director);

  static const String luigi = 'Luigi Rovaga';
  static const String platformScene = 'assets/story/scene_station_luigi.jpg';
  static const String planScene = 'assets/story/scene_station_plan.jpg';
  static const String northCapeScene =
      'assets/story/scene_station_north_cape.jpg';

  /// Luigi leaning out of the cab of the one train still in one piece.
  static const List<CutsceneFrame> reunionScene = <CutsceneFrame>[
    CutsceneFrame(
      image: platformScene,
      speaker: luigi,
      text: "Eccoti ragazzo, ce l'hai fatta finalmente!",
    ),
    CutsceneFrame(
      image: planScene,
      speaker: 'Mario Rossi',
      text:
          'Quale sarebbe il tuo piano quindi? Cosa vuoi farci con questo '
          'treno?',
    ),
    CutsceneFrame(
      image: planScene,
      speaker: luigi,
      text: 'Andare via da qui ovviamente!',
    ),
    CutsceneFrame(
      image: planScene,
      speaker: 'Mario Rossi',
      text: 'Si ma dove?',
    ),
    CutsceneFrame(
      image: northCapeScene,
      speaker: luigi,
      text: 'La nostra meta é Capo Nord ragazzo. In Norvegia',
    ),
    CutsceneFrame(
      image: northCapeScene,
      speaker: luigi,
      text: 'Lì gli zombi non arrivano, il freddo li tiene lontani',
    ),
  ];

  bool _reunionPlayed = false;
  bool _steppedOnPlatform = false;

  @override
  String get key => 'station';

  /// The portal itself only gives Mario time to take in the platform. The
  /// meeting becomes eligible on his first proper step after arriving,
  /// and only if Luigi was rescued from the hypermarket first.
  @override
  void onEvent(WorldEvent event) {
    if (!progress.memories.contains(StoryMemory.luigiRescued)) {
      return;
    }
    if (event case TravelMapUsedEvent(:final at)
        when trainMapTiles.contains(at) &&
            progress.memories.contains(StoryMemory.luigiAtStation)) {
      host.openTravelMap();
      return;
    }
    if (event case MovedEvent(
      entityId: final id,
      :final to,
    ) when id == world.playerId && stationPlatform.contains(to)) {
      _steppedOnPlatform = true;
    }
  }

  @override
  void update({required bool turnAnimating}) {
    if (_reunionPlayed ||
        !_steppedOnPlatform ||
        !progress.memories.contains(StoryMemory.luigiRescued) ||
        turnAnimating ||
        host.isPromptVisible) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (!stationPlatform.contains(position)) {
      return;
    }
    _reunionPlayed = true;
    progress.remember(StoryMemory.luigiAtStation);
    host.playCutscene(reunionScene, stayBlack: true, onFinished: _board);
  }

  /// Behind the black the scene ends on, Mario gets on the train and
  /// stands at the map table: that is where the save puts him, and where the
  /// game picks up again when the map sends him back home.
  void _board() {
    world.player.component<PositionComponent>()
      ..position = trainMapStandTile
      ..facing = Direction.south;
    host.completeLevel();
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{'reunion': _reunionPlayed};

  @override
  void restore(Map<String, Object?> json) {
    _reunionPlayed = json['reunion'] as bool? ?? false;
  }
}
