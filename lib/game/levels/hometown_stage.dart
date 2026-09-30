import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/levels/level_stage.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/crucified_zombie_component.dart';
import 'package:stepbound/game/render/flag_component.dart';
import 'package:stepbound/game/render/interact_glint_component.dart';
import 'package:stepbound/game/render/mall_props.dart';
import 'package:stepbound/game/render/npc_component.dart';
import 'package:stepbound/game/render/quest_props.dart';
import 'package:stepbound/game/render/screen_fade_component.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';

/// What Molfetta's story asks of the stage.
abstract interface class HometownActions {
  /// Opens the churchyard and moves Don Angelo from the gate to the altar.
  void openDuomo();

  /// Clears the Duomo stair, moves its guard aside and consumes the ring.
  void openDuomoUpper();

  /// Collects the robe upstairs, fades to black and dresses Mario in it.
  void collectCultistRobe();

  /// What the mass leaves behind, once its scene is over: Don Angelo's
  /// community are four mutated cultists standing across the nave, his body
  /// lies behind them and the backpack beside it, with the key of the upper
  /// floor, can be picked up.
  void startDuomoMassacre();

  /// Luigi walks off through the shop's open shutter and vanishes, once he
  /// has agreed to meet Mario again; calls [onFinished] once he is gone.
  void sendLuigiAway({void Function()? onFinished});
}

/// Molfetta on the stage: Luigi behind the hypermarket's shutter, Don
/// Angelo and his community, the gates and doors the story opens, the
/// Duomo after the mass, the flag on the barracks' forecourt and the glints
/// on what can be used.
final class HometownStage extends LevelStage implements HometownActions {
  HometownStage(super.game);

  /// Standing this close to the cross, its groan is at its loudest; this
  /// much further away, at its faintest. Further still it stays there: the
  /// nave is long and the thing on the cross is loud.
  static const int crossHearingNear = 6;
  static const int crossHearingFar = 18;

  NpcComponent? _luigi;
  NpcComponent? _chiara;
  NpcComponent? _priest;
  NpcComponent? _stairCultist;
  NpcComponent? _welcomingCultist;
  PriestCorpseComponent? _priestCorpse;
  CrucifiedZombieComponent? _crucified;
  bool _priestInside = false;
  bool _stairCultistMoved = false;
  bool _changingOutfit = false;

  /// True while Luigi walks out of the hypermarket: Mario waits for him to
  /// be gone, so the two never walk through each other.
  bool _luigiLeaving = false;

  MallScript get _mallScript =>
      game.story.scripts.whereType<MallScript>().first;
  DuomoScript get _duomoScript =>
      game.story.scripts.whereType<DuomoScript>().first;
  CompanyScript get _companyScript =>
      game.story.scripts.whereType<CompanyScript>().first;

  /// The gates and doors the story has opened are in the save's map, and
  /// what Mario carries in its HUD: only where the people stand is read
  /// back from the map here.
  @override
  void restore() {
    _priestInside = simulation.map.tileAt(priestGateTiles.first).isWalkable;
    _stairCultistMoved = simulation.map
        .tileAt(duomoStairCultistTile)
        .isWalkable;
    // Nobody walks through a person: where each one stands is an obstacle.
    if (!_priestInside) {
      _occupy(priestTile);
    }
    if (_stairCultistMoved && !_duomoScript.massacrePlayed) {
      _occupy(duomoStairCultistMovedTile);
    }
    if (_mallScript.luigiGone) {
      _vacate(luigiTile);
    }
    if (_companyScript.aboard) {
      _vacate(chiaraTile);
    }
  }

  @override
  List<Component> build() {
    final massacre = _duomoScript.massacrePlayed;
    return <Component>[
      FlagComponent(
        foot: Vector2(
          flagpoleTile.x * StepboundGame.tileSize + StepboundGame.tileSize / 2,
          flagpoleTile.y * StepboundGame.tileSize + StepboundGame.tileSize - 2,
        ),
      ),
      if (!_mallScript.luigiGone)
        _luigi = NpcComponent(
          asset: NpcComponent.luigiAsset,
          tile: luigiTile,
          name: MallScript.luigi,
        ),
      // The mass is where Don Angelo and his community end: after it none
      // of the three is in the nave any more.
      if (!massacre)
        _priest = NpcComponent(
          asset: NpcComponent.priestAsset,
          tile: _priestInside ? duomoPriestTile : priestTile,
          name: PriestScript.priest,
        ),
      if (!massacre)
        _stairCultist = NpcComponent(
          asset: NpcComponent.cultistAsset,
          tile: _stairCultistMoved
              ? duomoStairCultistMovedTile
              : duomoStairCultistTile,
          name: DuomoScript.cultist,
        ),
      if (!massacre)
        _welcomingCultist = NpcComponent(
          asset: NpcComponent.cultistAsset,
          tile: duomoWelcomingCultistTile,
          name: DuomoScript.cultist,
        ),
      // At her workstation in the company, behind the glass, on the phone,
      // until she leaves for the train.
      if (!_companyScript.aboard)
        _chiara = NpcComponent(
          asset: NpcComponent.chiaraAsset,
          tile: chiaraTile,
          name: CompanyScript.chiara,
          facing: Direction.north,
        ),
      ShutterComponent(bars: luigiBars, map: simulation.map),
      ChurchyardGateComponent(gate: priestGate, map: simulation.map),
      BarServiceDoorComponent(door: barLockedDoorTile, map: simulation.map),
      ShopBackDoorComponent(door: electronicsShopBackDoor, map: simulation.map),
      ShopShutterComponent(door: northDistrictShopDoor, map: simulation.map),
      ..._interactGlints(),
    ];
  }

  /// A save from after the mass has the cultists among its entities and
  /// the body's tile among its map changes; a test scenario built from the
  /// level has neither. The same call puts whatever is missing back,
  /// without a sound.
  @override
  void afterCharacters() {
    if (_duomoScript.massacrePlayed) {
      _applyDuomoMassacre(announce: false);
    }
  }

  /// Once Mario has left her floor, Chiara has left her desk for the
  /// train: gone from it, and her tile is free.
  @override
  void update(double dt) {
    if (_chiara != null && _companyScript.aboard) {
      _chiara!.removeFromParent();
      _chiara = null;
      _vacate(chiaraTile);
    }
  }

  @override
  bool get holdsMario => _changingOutfit || _luigiLeaving;

  @override
  Music? musicOf(PlaceId place) => switch (place) {
    PlaceId.church ||
    PlaceId.duomo ||
    PlaceId.duomoUpper ||
    PlaceId.duomoSecondFloor ||
    PlaceId.duomoTower ||
    PlaceId.duomoBells ||
    PlaceId.duomoTowerRoof => Music.sacred,
    PlaceId.industryStreet ||
    PlaceId.companyGround ||
    PlaceId.companyFirst ||
    PlaceId.companySecond => Music.weasel,
    _ => null,
  };

  /// The door the key opens stands open from then on.
  @override
  bool showsOpened(PlaceId place) => switch (place) {
    PlaceId.duomoUpper =>
      simulation.map.tileAt(duomoUpperLockedDoorTile).isWalkable,
    PlaceId.palazzoThirdFloor =>
      simulation.map.tileAt(palazzoLockedDoorTile).isWalkable,
    _ => false,
  };

  /// The glint on every object Mario can use here, the same one the
  /// backpacks give off (they draw their own, as it rides their drop): the
  /// panel until it is pulled, and the rest once there is an interact
  /// button to press. People go without: someone standing there is reason
  /// enough to try talking to them.
  List<InteractGlintComponent> _interactGlints() {
    bool canInteract() => game.isUnlocked(HudElement.interact);
    return <InteractGlintComponent>[
      InteractGlintComponent(
        tile: mallPanelTile,
        spot: const Offset(11, 6),
        active: () => simulation.controls.containsKey(mallPanelTile),
      ),
      InteractGlintComponent(tile: rooftopGapTile, active: canInteract),
      InteractGlintComponent(tile: duomoTowerLookoutTile, active: canInteract),
      InteractGlintComponent(
        tile: hospitalRoofLookoutTile,
        active: canInteract,
      ),
      // The way back across each gap, for as long as there is a hook to
      // go back with.
      for (final edge in <GridPoint>[
        rooftopFarEdgeTile,
        duomoFarTowerEdgeTile,
        hospitalNextRoofEdgeTile,
      ])
        InteractGlintComponent(
          tile: edge,
          active: () =>
              canInteract() &&
              simulation.player.component<AmmoComponent>().grapplingHook,
        ),
      InteractGlintComponent(tile: shoppingStreetFireTile, active: canInteract),
      InteractGlintComponent(tile: stationTrackFireTile, active: canInteract),
      for (final door in oldTownDamagedDoorTiles)
        InteractGlintComponent(tile: door, active: canInteract),
      // On the closed leaf, until the key opens it.
      InteractGlintComponent(
        tile: barLockedDoorTile,
        spot: const Offset(8, 8),
        active: () => !simulation.map.tileAt(barLockedDoorTile).isWalkable,
      ),
      // The shop's back door, bolted on this side, until it is drawn.
      InteractGlintComponent(
        tile: electronicsShopBackDoor,
        active: () =>
            canInteract() &&
            !simulation.map.tileAt(electronicsShopBackDoor).isWalkable,
      ),
      // Like the bar's own door: nothing left to use once it is open.
      InteractGlintComponent(
        tile: duomoUpperLockedDoorTile,
        active: () =>
            canInteract() &&
            !simulation.map.tileAt(duomoUpperLockedDoorTile).isWalkable,
      ),
      for (final fire in hometownCampfireNames.keys)
        InteractGlintComponent(
          tile: fire,
          spot: const Offset(11, 3),
          active: canInteract,
        ),
    ];
  }

  @override
  void sendLuigiAway({void Function()? onFinished}) {
    final luigi = _luigi;
    if (luigi == null) {
      onFinished?.call();
      return;
    }
    _luigi = null;
    game.input.stop();
    _luigiLeaving = true;
    luigi.walkAwayThrough(
      luigiExitPath,
      onArrived: () {
        _luigiLeaving = false;
        _vacate(luigiTile);
        onFinished?.call();
      },
    );
  }

  @override
  void openDuomo() {
    _openPriestGate();
    if (_priestInside) {
      return;
    }
    _priestInside = true;
    _vacate(priestTile);
    _priest?.removeFromParent();
    game.addToWorld(
      _priest = NpcComponent(
        asset: NpcComponent.priestAsset,
        tile: duomoPriestTile,
        name: PriestScript.priest,
      ),
    );
  }

  @override
  void openDuomoUpper() {
    _openDuomoUpperAccess();
    if (_stairCultistMoved) {
      return;
    }
    _stairCultistMoved = true;
    _stairCultist?.removeFromParent();
    game.addToWorld(
      _stairCultist = NpcComponent(
        asset: NpcComponent.cultistAsset,
        tile: duomoStairCultistMovedTile,
        name: DuomoScript.cultist,
      ),
    );
  }

  @override
  void startDuomoMassacre() => _applyDuomoMassacre(announce: true);

  @override
  void collectCultistRobe() {
    if (game.progress.unlockedOutfits.contains(PlayerOutfit.cultist)) {
      return;
    }
    game.input.stop();
    _changingOutfit = true;
    game.fadeScreen(
      fadeIn: ScreenFadeComponent.slowFadeIn,
      onBlack: () {
        game.progress.unlockOutfit(PlayerOutfit.cultist);
        game.wearOutfit(PlayerOutfit.cultist);
      },
      onFinished: () => _changingOutfit = false,
    );
  }

  /// Someone now stands on [tile]: nobody walks through them.
  void _occupy(GridPoint tile) =>
      simulation.map.setTile(tile, const Tile(TileKind.obstacle));

  /// Whoever stood on [tile] has gone.
  void _vacate(GridPoint tile) =>
      simulation.map.setTile(tile, const Tile(TileKind.floor));

  void _openPriestGate() {
    for (final tile in priestGateTiles) {
      simulation.map.setTile(tile, const Tile(TileKind.floor));
    }
  }

  /// The stair cultist steps aside: his old tile, in front of the door
  /// upstairs, is free, the one he moves to is not.
  void _openDuomoUpperAccess() {
    simulation.map.setTile(duomoStairCultistTile, const Tile(TileKind.floor));
    _occupy(duomoStairCultistMovedTile);
  }

  /// The nave after the mass: Don Angelo and the two cultists who stood in
  /// it are gone, the tiles they filled are free again, his body lies in the
  /// aisle between the first two blocks of pews with the backpack beside it,
  /// and the four that his community has become stand across that aisle.
  /// Called again on the next load, it only puts back what is missing:
  /// [announce] is false then, so no zombie is heard coming out of the dark.
  void _applyDuomoMassacre({required bool announce}) {
    _priest?.removeFromParent();
    _stairCultist?.removeFromParent();
    _welcomingCultist?.removeFromParent();
    _priest = null;
    _stairCultist = null;
    _welcomingCultist = null;
    _priestInside = true;
    <GridPoint>[
      duomoPriestTile,
      duomoWelcomingCultistTile,
      duomoStairCultistTile,
      duomoStairCultistMovedTile,
    ].forEach(_vacate);
    _occupy(duomoPriestCorpseTile);
    if (_priestCorpse == null) {
      game.addToWorld(
        _priestCorpse = PriestCorpseComponent(tile: duomoPriestCorpseTile),
      );
    }
    if (_crucified == null) {
      game.addToWorld(
        _crucified = CrucifiedZombieComponent(
          tile: duomoCrucifixTile,
          seed: simulation.tick,
          onTwitch: _groanFromTheCross,
        ),
      );
    }
    final key = simulation.pickups[duomoKeyPickupId];
    if (key != null && !key.collected) {
      key.active = true;
    }
    var raised = false;
    for (final (index, tile) in duomoCultistSpawns.indexed) {
      final id = '$duomoCultistPrefix$index';
      // Already raised, or somebody is standing on the tile: nobody is
      // raised on top of Mario, whatever an old save had him doing.
      if (simulation.entities[id] != null ||
          simulation.entityAt(tile) != null) {
        continue;
      }
      // Already standing when the game fades back in from the mass: they
      // do not climb out of the floor in front of Mario.
      final cultist = createDuomoCultist(id, tile);
      simulation.addEntity(cultist);
      game.addCharacter(cultist);
      raised = true;
    }
    if (announce && raised) {
      game.audio.play(Sfx.zombieAlert);
    }
  }

  /// The thing on the cross thrashes: it is heard by anyone in the Duomo,
  /// louder the nearer they are, and not at all over a story scene or a
  /// text box, where it would land on top of someone talking.
  void _groanFromTheCross() {
    if (game.cover.value != null) {
      return;
    }
    final mario = simulation.player.component<PositionComponent>().position;
    if (placeAt(mario)?.id != PlaceId.duomo) {
      return;
    }
    final steps = mario.manhattanDistanceTo(duomoCrucifixTile);
    final nearness = (1 - (steps - crossHearingNear) / crossHearingFar).clamp(
      0.0,
      1.0,
    );
    game.audio.play(Sfx.zombieAlert, volume: 0.15 + 0.3 * nearness);
  }
}
