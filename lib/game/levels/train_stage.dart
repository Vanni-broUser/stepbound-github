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

  /// Whether Chiara has come aboard, sent to the station from her desk:
  /// Molfetta's story, so starting it over sends her back there.
  bool get _chiaraAboard =>
      game.story.scripts.whereType<CompanyScript>().first.aboard;

  /// Chiara in her corner of the second coach, once she is aboard.
  NpcComponent? _chiara;

  @override
  void restore() {
    _syncDoor();
    parkTrain(simulation, game.progress.level);
    _syncChiaraTile();
  }

  /// Nobody walks through a person: her spot is an obstacle while she is
  /// there, and floor until she is.
  void _syncChiaraTile() => simulation.map.setTile(
    trainChiaraTile,
    Tile(_chiaraAboard ? TileKind.obstacle : TileKind.floor),
  );

  NpcComponent _chiaraAboardComponent() => _chiara = NpcComponent(
    asset: NpcComponent.chiaraAsset,
    tile: trainChiaraTile,
    name: CompanyScript.chiara,
    facing: Direction.west,
  );

  @override
  List<Component> build() {
    bool canInteract() => game.isUnlocked(HudElement.interact);
    return <Component>[
      // Nobody gets aboard before Luigi has opened the door, so he can be
      // there all along.
      NpcComponent(
        asset: NpcComponent.luigiAsset,
        tile: trainLuigiTile,
        name: MallScript.luigi,
      ),
      if (_chiaraAboard) _chiaraAboardComponent(),
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
      // Over the abacus in the middle of the desk.
      InteractGlintComponent(
        tile: trainBookTiles[trainBookTiles.length ~/ 2],
        spot: const Offset(8, 3),
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
  void update(double dt) {
    _syncDoor();
    // She comes aboard while Mario is elsewhere: the moment he leaves her
    // floor.
    if (_chiara == null && _chiaraAboard) {
      _syncChiaraTile();
      game.addToWorld(_chiaraAboardComponent());
    }
  }

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
