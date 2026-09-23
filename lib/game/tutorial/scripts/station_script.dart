import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The station, where Luigi said he would wait. Getting to him is the
/// whole of it: the doorway onto the platform leads to a dead end behind
/// the derailed train, and only the other one, through the underpass,
/// comes out on the far side. Setting foot on that platform plays their
/// meeting.
final class StationScript extends TutorialScript {
  StationScript(super.director);

  static const String luigi = 'Luigi Rovaga';
  static const String platformScene = 'assets/story/scene_station_luigi.jpg';

  /// Luigi leaning out of the cab of the one train still in one piece.
  static const List<CutsceneFrame> reunionScene = <CutsceneFrame>[
    CutsceneFrame(
      image: platformScene,
      speaker: luigi,
      text: "Eccoti ragazzo, ce l'hai fatta finalmente!",
    ),
  ];

  bool _reunionPlayed = false;

  @override
  String get key => 'station';

  /// Coming up the second flight onto the far platform: Luigi is there,
  /// and hails Mario as soon as he is out in the open.
  @override
  void update({required bool turnAnimating}) {
    if (_reunionPlayed || turnAnimating || host.isPromptVisible) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (!stationPlatform.contains(position)) {
      return;
    }
    _reunionPlayed = true;
    progress.remember(StoryMemory.luigiAtStation);
    host.playCutscene(reunionScene);
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{'reunion': _reunionPlayed};

  @override
  void restore(Map<String, Object?> json) {
    _reunionPlayed = json['reunion'] as bool? ?? false;
  }
}
