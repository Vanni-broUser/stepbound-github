import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/levels/level_stage.dart';
import 'package:stepbound/game/render/interact_glint_component.dart';
import 'package:stepbound/game/story/story_director.dart';

/// Rome on the stage: its music, the same in every place of the city, the
/// station and the streets alike, and the glint on its campfires.
final class RomeStage extends LevelStage {
  RomeStage(super.game);

  @override
  List<Component> build() => <Component>[
    for (final fire in romeCampfireNames.keys)
      InteractGlintComponent(
        tile: fire,
        spot: const Offset(11, 3),
        active: () => game.isUnlocked(HudElement.interact),
      ),
  ];

  static final Set<PlaceId> _rome = <PlaceId>{
    for (final place in gamePlaces)
      if (place.level == LevelId.rome) place.id,
  };

  @override
  Music? musicOf(PlaceId place) => _rome.contains(place) ? Music.rome : null;
}
