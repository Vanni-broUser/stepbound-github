import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/test_scenarios.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/save/save_game.dart';

const int _slot = SaveRepository.slotCount;

TestScenario _named(String name) =>
    testScenarios.singleWhere((scenario) => scenario.name == name);

/// The game a scenario's save loads into, the way the app builds it.
Future<StepboundGame> _play(WidgetTester tester, TestScenario scenario) async {
  final save = scenario.save(_slot);
  final game = StepboundGame(
    world: restoreTutorialWorld(save.world),
    tutorialState: save.tutorial,
    progress: Progress.fromJson(save.progress),
    unlocked: <HudElement>{
      for (final name in save.hud) HudElement.values.byName(name),
    },
  );
  await tester.pumpWidget(GameWidget<StepboundGame>(game: game));
  final state = tester.state<GameWidgetState<StepboundGame>>(
    find.byType(GameWidget<StepboundGame>),
  );
  await state.loaderFuture;
  await game.ready();
  game.update(1 / 30);
  return game;
}

void main() {
  test('every scenario is saved where a game can be: beside a real fire, '
      'facing it and named after it, or aboard the train', () {
    for (final scenario in testScenarios) {
      final save = scenario.save(_slot);
      expect(save.slot, _slot);
      expect(save.atCampfire, isTrue, reason: '${scenario.name}: resumable');
      final read = SaveGame.decode(
        jsonEncode(save.toJson()),
        check: checkRestorable,
      );
      expect(read, isA<LoadedSave>(), reason: scenario.name);
      final mario = restoreTutorialWorld(
        save.world,
      ).player.component<PositionComponent>();
      if (save.place == trainPlaceName) {
        expect(mario.position, trainMapStandTile, reason: scenario.name);
        expect(mario.facing, Direction.south, reason: scenario.name);
        continue;
      }
      final fire = mario.position.step(mario.facing);
      expect(
        campfireNames[fire],
        save.place,
        reason: '${scenario.name}: facing the fire it is named after',
      );
    }
  });

  test('the fire is the one nearest on foot, not across the grid', () {
    String savedAt(String name) => _named(name).save(_slot).place;
    String fireIn(PlaceId id) => campfireNames.entries
        .singleWhere((fire) => placeAt(fire.key)?.id == id)
        .value;
    expect(
      savedAt('Porto, Don Angelo al cancello'),
      fireIn(PlaceId.northDistrict),
    );
    expect(savedAt("Duomo, con l'anello"), fireIn(PlaceId.northDistrict));
    expect(
      savedAt('Luigi liberato, verso la stazione'),
      fireIn(PlaceId.mallNorthStreet),
    );
    expect(savedAt('Treno, dopo la fine del livello'), trainPlaceName);
  });

  test('a scenario that is not saved anywhere is refused', () {
    final nowhere = TestScenario('Da nessuna parte', (story) {});
    expect(() => nowhere.save(_slot), throwsStateError);
  });

  testWidgets('each scenario loads into a game that runs, with the story '
      'where it says', (tester) {
    return tester.runAsync(() async {
      for (final scenario in testScenarios) {
        final game = await _play(tester, scenario);
        for (var i = 0; i < 5; i++) {
          game.update(0.05);
        }
        expect(game.cover.value, isNot(isA<GameOverCover>()));
        await tester.pumpWidget(const SizedBox());
      }

      final station = await _play(
        tester,
        _named('Luigi liberato, verso la stazione'),
      );
      expect(station.progress.memories, contains(StoryMemory.luigiRescued));
      expect(
        station.simulation.map.tileAt(stationTrainDoorTile).isWalkable,
        isTrue,
        reason: 'Luigi has opened the train',
      );
      await tester.pumpWidget(const SizedBox());

      final incense = await _play(
        tester,
        _named("Porto, ritorno con l'incenso"),
      );
      expect(incense.hud.value, contains(HudElement.incense));
      await tester.pumpWidget(const SizedBox());

      final bar = await _play(tester, _named('Bar Arcobaleno, con la chiave'));
      expect(bar.hud.value, contains(HudElement.barKey));
      expect(
        bar.simulation.map.tileAt(priestGateTiles.first).isWalkable,
        isTrue,
        reason: 'the gate stays open after the welcome',
      );
      await tester.pumpWidget(const SizedBox());

      final upstairs = await _play(tester, _named('Duomo, piano di sopra'));
      expect(
        upstairs.simulation.map.tileAt(duomoStairCultistTile).isWalkable,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());

      final mass = await _play(
        tester,
        _named('Duomo, la messa (con la tunica)'),
      );
      expect(mass.progress.activeOutfit, PlayerOutfit.cultist);
      await tester.pumpWidget(const SizedBox());

      // The one after it starts where the mass leaves the nave: the four
      // cultists raised, the body in the aisle and the backpack beside it,
      // none of which a save built from the level carries by itself.
      final after = await _play(
        tester,
        _named('Duomo, dopo la messa (i cultisti)'),
      );
      expect(
        after.simulation.entities.values.where(
          (entity) => entity.kind == EntityKind.cultist,
        ),
        hasLength(4),
      );
      expect(
        after.simulation.map.tileAt(duomoPriestCorpseTile).isWalkable,
        isFalse,
      );
      expect(after.simulation.pickups[duomoKeyPickupId]!.active, isTrue);
      expect(after.progress.memories, contains(StoryMemory.priestMassacre));
    });
  });
}
