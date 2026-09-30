import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/levels/level_stage.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/interact_glint_component.dart';
import 'package:stepbound/game/render/npc_component.dart';
import 'package:stepbound/game/story/story_director.dart';

/// Rome on the stage: its music, the same in every place of the city, the
/// station and the streets alike, the glint on its campfires, and Tonino
/// and Marcello at the bottom of Via Cavour, looking up it. Once Mario has
/// met them, their own music takes over whenever they are in view.
final class RomeStage extends LevelStage {
  RomeStage(super.game);

  MaranzaScript get _maranza =>
      game.story.scripts.whereType<MaranzaScript>().first;

  /// Tonino and Marcello, while they are on the square.
  late final List<NpcComponent> _maranzaNpcs = <NpcComponent>[
    NpcComponent(
      asset: NpcComponent.maranzaLazioAsset,
      tile: marcelloTile,
      facing: Direction.north,
    ),
    NpcComponent(
      asset: NpcComponent.maranzaRomaAsset,
      tile: toninoTile,
      facing: Direction.north,
    ),
  ];

  /// Nobody walks through a person: where each one stands is an obstacle,
  /// until the two of them have gone.
  @override
  void restore() {
    if (_maranza.gone) {
      return;
    }
    for (final tile in <GridPoint>[marcelloTile, toninoTile]) {
      simulation.map.setTile(tile, const Tile(TileKind.obstacle));
    }
  }

  /// Once they have gone, the square is clear of them for good.
  @override
  void update(double dt) {
    if (!_maranza.gone || !_maranzaNpcs.first.isMounted) {
      return;
    }
    for (final npc in _maranzaNpcs) {
      npc.removeFromParent();
    }
    for (final tile in <GridPoint>[marcelloTile, toninoTile]) {
      simulation.map.setTile(tile, const Tile(TileKind.floor));
    }
  }

  @override
  List<Component> build() => <Component>[
    if (!_maranza.gone) ..._maranzaNpcs,
    for (final fire in romeCampfireNames.keys)
      InteractGlintComponent(
        tile: fire,
        spot: const Offset(11, 3),
        active: () => game.isUnlocked(HudElement.interact),
      ),
    for (final tile in <GridPoint>[
      roadblockFireTile,
      marsalaFireTile,
      romeTerraceLookoutTile,
    ])
      InteractGlintComponent(
        tile: tile,
        active: () => game.isUnlocked(HudElement.interact),
      ),
  ];

  static final Set<PlaceId> _rome = <PlaceId>{
    for (final place in gamePlaces)
      if (place.level == LevelId.rome) place.id,
  };

  /// Where the two of them are drawn, in world pixels: their two tiles and
  /// the one above, where their heads stand out.
  static final Rect _maranzaArea = Rect.fromLTRB(
    min(marcelloTile.x, toninoTile.x) * _tileSize,
    (min(marcelloTile.y, toninoTile.y) - 1) * _tileSize,
    (max(marcelloTile.x, toninoTile.x) + 1) * _tileSize,
    (max(marcelloTile.y, toninoTile.y) + 1) * _tileSize,
  );

  static const double _tileSize = 16;

  /// Whether Tonino and Marcello are known, still on the square and on
  /// screen right now.
  bool get _maranzaInView =>
      game.progress.hasExperienced(StoryMemory.maranzaMet) &&
      !(game.isLoaded && _maranza.gone) &&
      game.camera.visibleWorldRect.overlaps(_maranzaArea);

  @override
  Music? musicOf(PlaceId place) => !_rome.contains(place)
      ? null
      : _maranzaInView
      ? Music.maranza
      : Music.rome;
}
