import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The carabinieri barracks: on the forecourt Mario hopes he is safe; a few
/// steps inside, the carabinieri zombies come out of the dark, and the
/// first one to become aware of him is framed while its reach is
/// explained. The lesson belongs here: the carabinieri in the hordes on the
/// hospital road never give it.
final class BarracksScript extends TutorialScript {
  BarracksScript(super.director);

  static const String barracksReached =
      "Ecco, ce l'ho fatta! La caserma dei carabinieri";
  static const String barracksSafe = 'Questo sarà un posto sicuro?';

  /// Steps inside the barracks before the carabinieri come out.
  static const int stepsBeforeCarabinieri = 4;

  bool _forecourtLinesGiven = false;
  bool _carabinieriOut = false;
  bool _carabiniereLessonGiven = false;
  int _stepsInside = 0;

  GridRect get _inside => place(PlaceId.barracks).bounds;

  @override
  String get key => 'barracks';

  @override
  void onEvent(WorldEvent event) {
    switch (event) {
      case AlertedEvent(entityId: final id) when _isBarracksCarabiniere(id):
        _giveCarabiniereLesson(id);
      case MovedEvent(entityId: final id, :final to)
          when id == world.playerId && _inside.contains(to):
        _stepsInside++;
        if (_stepsInside >= stepsBeforeCarabinieri) {
          _releaseCarabinieri();
        }
      case _:
        break;
    }
  }

  @override
  void update({required bool turnAnimating}) {
    _checkForecourt();
    _checkCarabiniereAware();
  }

  void _checkForecourt() {
    if (_forecourtLinesGiven) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (!barracksForecourt.contains(position)) {
      return;
    }
    _forecourtLinesGiven = true;
    say(
      TutorialPrompt(const <TutorialLine>[
        TutorialLine.mario(barracksReached),
        TutorialLine.mario(barracksSafe),
      ]),
    );
  }

  void _releaseCarabinieri() {
    if (_carabinieriOut) {
      return;
    }
    _carabinieriOut = true;
    // Past the street, the wanderers are known whatever happened there.
    progress
      ..meet(EntityKind.wanderer)
      ..meet(EntityKind.carabiniere);
    final occupied = world.occupiedPoints();
    var index = 0;
    for (final spawn in carabiniereSpawns) {
      if (!occupied.contains(spawn)) {
        host.spawnZombie(createCarabiniere('carabiniere-${index++}', spawn));
      }
    }
  }

  bool _isBarracksCarabiniere(String id) {
    final zombie = world.entities[id];
    return zombie != null &&
        zombie.kind == EntityKind.carabiniere &&
        _inside.contains(zombie.component<PositionComponent>().position);
  }

  /// A carabiniere that hears Mario (papers underfoot, a shot) comes after
  /// him without ever raising the alert: it still gets its lesson.
  void _checkCarabiniereAware() {
    if (_carabiniereLessonGiven) {
      return;
    }
    for (final zombie in world.entities.values) {
      if (_isBarracksCarabiniere(zombie.id) &&
          zombie.isAlive &&
          zombie.component<HearingComponent>().lastHeard != null) {
        _giveCarabiniereLesson(zombie.id);
        return;
      }
    }
  }

  void _giveCarabiniereLesson(String id) {
    if (_carabiniereLessonGiven) {
      return;
    }
    _carabiniereLessonGiven = true;
    director.introduceZombie(world.entities[id]!);
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'forecourtLines': _forecourtLinesGiven,
    'carabinieriOut': _carabinieriOut,
    'carabiniereLesson': _carabiniereLessonGiven,
    'stepsInside': _stepsInside,
  };

  @override
  void restore(Map<String, Object?> json) {
    _forecourtLinesGiven = json['forecourtLines'] as bool? ?? false;
    _carabinieriOut = json['carabinieriOut'] as bool? ?? false;
    _carabiniereLessonGiven = json['carabiniereLesson'] as bool? ?? false;
    _stepsInside = json['stepsInside'] as int? ?? 0;
  }
}
