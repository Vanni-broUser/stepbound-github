import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The start of the Rome level. As soon as the city has loaded, before
/// Mario can move, Luigi says why they stop here. The stairs out of
/// Termini are as far as the game goes for now: they say so, and Mario is
/// back on the platform, facing it, once that is tapped away.
final class RomeScript extends TutorialScript {
  RomeScript(super.director);

  static const List<TutorialLine> arrivalLines = <TutorialLine>[
    TutorialLine.luigi('Come si suol dire: tutte le strade passano a Roma'),
    TutorialLine.luigi(
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
    say(TutorialPrompt(arrivalLines, delay: arrivalDelay, holdsInput: true));
  }

  @override
  void onEvent(WorldEvent event) {
    if (event case MovedEvent(
      :final entityId,
      :final to,
    ) when entityId == world.playerId && terminiExitTiles.contains(to)) {
      host.showEndOfDemo(onClosed: () => _stepBack(to));
    }
  }

  void _stepBack(GridPoint from) {
    world.player.component<PositionComponent>()
      ..position = from.step(Direction.north)
      ..facing = Direction.north;
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{'welcomed': _welcomed};

  @override
  void restore(Map<String, Object?> json) {
    _welcomed = json['welcomed'] as bool? ?? false;
  }
}
