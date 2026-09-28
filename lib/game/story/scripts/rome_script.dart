import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The start of the Rome level. As soon as the city has loaded, before
/// Mario can move, Luigi says why they stop here, and the supplies are the
/// mission once he has. Where its streets run off the map, the
/// work-in-progress screen takes over (`WorkInProgressScript`).
final class RomeScript extends StoryScript {
  RomeScript(super.director);

  static const List<StoryLine> arrivalLines = <StoryLine>[
    StoryLine.luigi('Come si suol dire: tutte le strade passano a Roma'),
    StoryLine.luigi(
      'Facciamo una piccola fermata qui, io cerco un po’ di carburante in '
      'giro e tu vai a trovare delle provviste, ce ne serviranno parecchie '
      'per arrivare alla nostra meta',
    ),
  ];

  /// Leaves the loading picture time to fade off the game first.
  static const double arrivalDelay = 1.6;

  bool _welcomed = false;

  @override
  String get key => 'rome';

  @override
  void update({required bool turnAnimating}) {
    if (_welcomed || progress.level != LevelId.rome) {
      return;
    }
    _welcomed = true;
    host.stopWalking();
    say(
      StoryPrompt(
        arrivalLines,
        delay: arrivalDelay,
        holdsInput: true,
        onDismissed: () => progress.missions.give(Mission.findSupplies),
      ),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{'welcomed': _welcomed};

  @override
  void restore(Map<String, Object?> json) {
    _welcomed = json['welcomed'] as bool? ?? false;
  }
}
