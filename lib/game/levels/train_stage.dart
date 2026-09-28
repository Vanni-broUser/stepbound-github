import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/levels/level_stage.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/interact_glint_component.dart';
import 'package:stepbound/game/render/npc_component.dart';
import 'package:stepbound/game/story/story_director.dart';

/// Luigi's train, wherever it stands: Luigi at home in the locomotive, its
/// door onto the platform, the glints on what Mario keeps aboard and
/// Luigi's music once he is waiting there.
final class TrainStage extends LevelStage {
  TrainStage(super.game);

  bool get _luigiRescued =>
      game.progress.hasExperienced(StoryMemory.luigiRescued);

  @override
  void restore() {
    _syncDoor();
    parkTrain(simulation, game.progress.level);
  }

  @override
  List<Component> build() {
    bool canInteract() => game.isUnlocked(HudElement.interact);
    return <Component>[
      // Nobody gets aboard before Luigi has opened the door, so he can be
      // there all along.
      NpcComponent(asset: NpcComponent.luigiAsset, tile: trainLuigiTile),
      InteractGlintComponent(
        tile: trainMapPanelTile,
        spot: const Offset(11, 6),
        active: () => _luigiRescued,
      ),
      // Luigi has the key: until he is free, the shut passenger door can
      // still be examined and explains why Mario cannot board.
      InteractGlintComponent(
        tile: stationTrainDoorTile,
        active: () => !simulation.map.tileAt(stationTrainDoorTile).isWalkable,
      ),
      // Over the open book on the desk.
      InteractGlintComponent(
        tile: trainBookTiles.first,
        spot: const Offset(5, 6),
        active: canInteract,
      ),
      // On the middle of the wardrobe rail.
      InteractGlintComponent(
        tile: trainWardrobeTiles[trainWardrobeTiles.length ~/ 2],
        active: canInteract,
      ),
      // On the middle of Mario's cot.
      InteractGlintComponent(
        tile: trainCotTiles[trainCotTiles.length ~/ 2],
        active: canInteract,
      ),
      // In the middle of the weapons table.
      InteractGlintComponent(
        tile: trainAmmoTiles[trainAmmoTiles.length ~/ 2],
        active: canInteract,
      ),
      // The table aboard is one place to eat: one glint, in its middle.
      InteractGlintComponent(
        tile: trainFoodTiles[trainFoodTiles.length ~/ 2],
        active: canInteract,
      ),
    ];
  }

  @override
  void update(double dt) => _syncDoor();

  /// The station reunion starts Luigi's music with its cutscene, not while
  /// Mario is still crossing the station.
  @override
  Music? musicOf(PlaceId place) =>
      place == PlaceId.trainInterior && _luigiRescued ? Music.luigi : null;

  @override
  bool showsOpened(PlaceId place) => switch (place) {
    // At Termini the train is Mario's own, its door open from the start.
    PlaceId.romeTermini => true,
    PlaceId.stationFarSide => _luigiRescued,
    _ => false,
  };

  /// Luigi carries the keys: rescuing him opens the visible passenger door
  /// and its matching tile in the same frame. Before that the train remains
  /// a solid wall even though its portal already belongs to the level.
  void _syncDoor() {
    final kind = _luigiRescued ? TileKind.floor : TileKind.wall;
    if (simulation.map.tileAt(stationTrainDoorTile).kind != kind) {
      simulation.map.setTile(stationTrainDoorTile, Tile(kind));
    }
  }
}
