import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/levels/level_stage.dart';

/// Rome on the stage: for now only its music, the same in every place of
/// the city, the station and the streets alike.
final class RomeStage extends LevelStage {
  RomeStage(super.game);

  @override
  List<Component> build() => const <Component>[];

  static final Set<PlaceId> _rome = <PlaceId>{
    for (final place in gamePlaces)
      if (place.level == LevelId.rome) place.id,
  };

  @override
  Music? musicOf(PlaceId place) => _rome.contains(place) ? Music.rome : null;
}
