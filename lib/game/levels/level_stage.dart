import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/stepbound_game.dart';

/// What one level puts on the stage over the simulation: the people and
/// props of its story, the glints on what can be used, the music of its
/// places. The game knows none of it: it asks each stage in turn.
abstract class LevelStage {
  LevelStage(this.game);

  final StepboundGame game;

  WorldState get simulation => game.simulation;

  /// Brings the map in step with the story just restored, before anything
  /// is drawn: who stands where, which doors are open.
  void restore() {}

  /// What it adds to the world once the places are in.
  List<Component> build();

  /// Once every character of the simulation is drawn.
  void afterCharacters() {}

  /// Every frame.
  void update(double dt) {}

  /// Whether Mario has to wait for something the stage is playing.
  bool get holdsMario => false;

  /// The music of [place], if the level gives it its own.
  Music? musicOf(PlaceId place) => null;

  /// Whether the story has opened what [place] draws shut.
  bool showsOpened(PlaceId place) => false;
}
