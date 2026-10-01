import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/level_restart.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/ui/level_complete.dart';
import 'package:stepbound/ui/zombie_book.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  group('Chiara behind the glass in the company past the palazzo', () {
    CompanyScript script() => director.scripts.whereType<CompanyScript>().first;

    /// Just inside the gate, and [rows] further up the west wing.
    GridPoint inside(int rows) =>
        GridPoint(companyGate.first.x, companyGate.first.y - 1 - rows);

    void standAt(GridPoint tile) {
      world.player.component<PositionComponent>().position = tile;
      settle();
    }

    // Whatever the start of Molfetta has to say, said and gone.
    setUp(() {
      for (settle(); host.isPromptVisible; settle()) {
        host.dismiss();
      }
      host.shown.clear();
    });

    test('she stands at a workstation in the east wing, behind the glass, '
        'and the west wing does not lead to her', () {
      expect(companyEastWing.contains(chiaraTile), isTrue);
      expect(world.map.tileAt(chiaraTile).isWalkable, isFalse);
      final reached = world.map.floodFillDistances(
        inside(0),
        maxDistance: 5000,
      );
      for (final side in Direction.values) {
        expect(reached.containsKey(chiaraTile.step(side)), isFalse);
      }
    });

    test('walking up the west wing, the call plays a few steps after she '
        'comes into view, then the mission to reach her', () {
      standAt(inside(0));
      standAt(inside(1));
      standAt(inside(2));
      expect(host.cutscenes, isEmpty, reason: 'she is not in view yet');

      host.visible.add(chiaraTile);
      standAt(inside(3));
      expect(host.cutscenes, isEmpty, reason: 'just seen');
      for (var step = 1; step < CompanyScript.stepsInView; step++) {
        standAt(inside(3 + step));
        expect(host.cutscenes, isEmpty, reason: 'step $step');
      }
      standAt(inside(3 + CompanyScript.stepsInView));
      expect(host.cutscenes.single, CompanyScript.callFrames);
      expect(host.cutscenes.single.map((frame) => frame.speaker), <String?>[
        CompanyScript.chiara,
        CompanyScript.zombie,
        CompanyScript.chiara,
        CompanyScript.zombie,
        CompanyScript.chiara,
        CompanyScript.chiara,
      ]);
      expect(
        host.cutscenes.single.last.text,
        "Mamma mia... Al giorno d'oggi sono tutti senza cervello...",
      );
      expect(progress.memories, contains(StoryMemory.chiaraCall));
      expect(progress.missions.isOpen(Mission.reachSurvivor), isFalse);

      host.onCutsceneFinished!();
      expect(progress.missions.isOpen(Mission.reachSurvivor), isTrue);
      expect(
        Mission.reachSurvivor.text,
        "Raggiungi Chiara dall'altra parte degli uffici",
      );
      expect(script().callPlayed, isTrue);

      standAt(inside(1));
      standAt(inside(2));
      expect(host.cutscenes, hasLength(1), reason: 'only once');
    });

    test('steps with her out of view, or outside the company, do not '
        'count', () {
      host.visible.add(chiaraTile);
      standAt(inside(3));
      host.visible.clear();
      for (var row = 4; row < 10; row++) {
        standAt(inside(row));
      }
      host.visible.add(chiaraTile);
      standAt(industryStreetGate.first.step(Direction.south));
      standAt(
        industryStreetGate.first.step(Direction.south).step(Direction.east),
      );
      expect(host.cutscenes, isEmpty);
    });

    test('where it was is saved: seen once, the steps go on counting after '
        'a restore', () {
      host.visible.add(chiaraTile);
      standAt(inside(3));
      standAt(inside(4));
      final saved = script().toJson();

      startStory();
      script().restore(saved);
      host.visible.add(chiaraTile);
      standAt(inside(4));
      standAt(inside(5));
      expect(host.cutscenes, isEmpty);
      standAt(inside(6));
      expect(host.cutscenes, hasLength(1));
    });

    test('reached at last, a couple of cells from her workstation: they '
        'meet, and the mission to reach her is done', () {
      progress.missions.give(Mission.reachSurvivor);
      // Along the aisle below her desk, from the glass.
      GridPoint aisle(int fromHer) =>
          GridPoint(chiaraTile.x - fromHer, chiaraTile.y + 1);
      standAt(aisle(3));
      expect(host.cutscenes, isEmpty, reason: 'four steps from her');
      standAt(aisle(2));
      expect(
        aisle(2).manhattanDistanceTo(chiaraTile),
        CompanyScript.meetingReach,
      );
      expect(host.cutscenes.single, CompanyScript.meetingFrames);
      expect(host.cutscenes.single.map((frame) => frame.speaker), <String?>[
        CompanyScript.mario,
        CompanyScript.chiara,
        CompanyScript.mario,
        CompanyScript.chiara,
      ]);
      expect(host.cutscenes.single.map((frame) => frame.text), <String>[
        'Ei ma che ci fai qui?',
        'Ho degli straordinari da recuperare',
        "Signora c'è l'apocalisse zombi qui!",
        'Ecco perché non chiudevo più nessun contratto',
      ]);
      expect(progress.memories, contains(StoryMemory.chiaraMet));
      expect(StoryMemory.chiaraMet.level, LevelId.hometown);
      expect(progress.missions.isDone(Mission.reachSurvivor), isFalse);

      host.onCutsceneFinished!();
      settle();
      // Back in the game, Mario sends her to the station before he can
      // move; the mission is done once he has said it.
      expect(host.shown.last.single.text, CompanyScript.sendToStation);
      expect(host.shown.last.single.speaker, 'Mario Rossi');
      expect(progress.missions.isDone(Mission.reachSurvivor), isFalse);
      host.dismiss();
      expect(progress.missions.isDone(Mission.reachSurvivor), isTrue);
      expect(progress.missions.isOpen(Mission.reachSurvivor), isFalse);
      expect(script().met, isTrue);
      expect(script().aboard, isFalse, reason: 'still at her desk');
      expect(
        memoryScenes[StoryMemory.chiaraMet]!.map((scene) => scene.image),
        CompanyScript.meetingFrames.map((frame) => frame.image),
      );

      standAt(aisle(3));
      standAt(chiaraTile.step(Direction.south));
      expect(host.cutscenes, hasLength(1), reason: 'only once');

      final saved = script().toJson();
      startStory();
      script().restore(saved);
      standAt(chiaraTile.step(Direction.south));
      expect(host.cutscenes, isEmpty, reason: 'a save remembers it');
    });

    test('once met, talking to her again: she will see him at the station; '
        'the moment he leaves her floor she has gone to the train, and '
        'starting Molfetta over puts her back at her desk', () {
      script().restore(<String, Object?>{
        'seen': true,
        'played': true,
        'met': true,
      });
      final beside = chiaraTile.step(Direction.south);
      world.player.component<PositionComponent>()
        ..position = beside
        ..facing = Direction.north;
      expect(world.lookouts, contains(chiaraTile));
      director.onEvents(
        const TurnScheduler().advance(world, const InteractAction()),
      );
      settle();
      final line = host.shown.last.single;
      expect(line.text, 'Allora ci vediamo in stazione...');
      expect(line.speaker, CompanyScript.chiara);
      expect(line.portrait, 'assets/characters/npcs/portraits/chiara.png');
      host.dismiss();
      host.shown.clear();

      // Up the stairs: another place, and she is gone.
      standAt(companyStairs.last.step(Direction.south));
      expect(script().aboard, isFalse, reason: 'still on her floor');
      final (_, above) = companyFlights[1];
      standAt(above.step(Direction.north));
      expect(script().aboard, isTrue);
      expect(script().toJson()['gone'], isTrue);

      // Back by her desk, nobody there to talk to.
      world.player.component<PositionComponent>()
        ..position = beside
        ..facing = Direction.north;
      director.onEvents(<WorldEvent>[LookedOutEvent(at: chiaraTile)]);
      settle();
      expect(host.shown, isEmpty);

      startStory();
      expect(script().aboard, isFalse);
      expect(
        storyScriptCities.containsKey(script().key),
        isFalse,
        reason: "Molfetta's story, reset with it",
      );
    });

    test('her corner aboard: in the second coach, bottom right, with her '
        'cot, her suitcases, her washing on a line and cans about', () {
      final train = place(PlaceId.trainInterior);
      expect(placeAt(trainChiaraTile), train);
      expect(
        world.map.tileAt(trainChiaraTile).isWalkable,
        isTrue,
        reason: 'nobody there until she comes aboard',
      );
      final coaches = train.tilesOf('I').map((tile) => tile.x).toSet().toList()
        ..sort();
      expect(trainChiaraTile.x, greaterThan(coaches.first));
      expect(trainChiaraTile.x, lessThan(coaches.last));
      expect(trainChiaraTile.y, greaterThan(trainExitTile.y - 6));
      for (final glyph in <String>['~', 'O', 'o', 'b', 'c']) {
        expect(
          train
              .tilesOf(glyph)
              .any((tile) => tile.manhattanDistanceTo(trainChiaraTile) <= 6),
          isTrue,
          reason: glyph,
        );
      }
      expect(world.map.tileAt(train.tilesOf('~').first).isWalkable, isFalse);
    });

    test('her things come aboard with her: until then the train is drawn '
        'with her corner bare', () {
      final train = place(PlaceId.trainInterior);
      expect(trainChiaraThings.values.toSet(), <String>{
        '~',
        'O',
        'o',
        'b',
        'c',
      });
      for (final tile in trainChiaraThings.keys) {
        expect(tile.manhattanDistanceTo(trainChiaraTile), lessThanOrEqualTo(8));
      }
      // Luigi's cot, suitcases and mess in the locomotive stay.
      expect(
        train
            .tilesOf('b')
            .where((tile) => !trainChiaraThings.containsKey(tile)),
        isNotEmpty,
      );
      expect(trainRowsBeforeChiara, hasLength(train.height));
      for (final (tile, glyph) in train.glyphs) {
        final drawn =
            trainRowsBeforeChiara[tile.y - train.origin.y][tile.x -
                train.origin.x];
        expect(
          drawn,
          trainChiaraThings.containsKey(tile) ? '.' : glyph,
          reason: '$tile',
        );
      }
    });

    test('aboard, she talks about the journey in Molfetta and about Rome '
        'in Rome; before she has come aboard, nobody answers there', () {
      void talk() {
        director.onEvents(<WorldEvent>[LookedOutEvent(at: trainChiaraTile)]);
        settle();
      }

      expect(world.lookouts, contains(trainChiaraTile));
      talk();
      expect(host.shown, isEmpty, reason: 'not aboard yet');

      script().restore(<String, Object?>{'met': true, 'gone': true});
      talk();
      expect(host.shown.last.map((line) => line.text), <String>[
        'Dobbiamo arrivare fino in Norvegia? Sembra un sacco di strada',
      ]);
      expect(host.shown.last.single.speaker, CompanyScript.chiara);
      expect(host.shown.last.single.portrait, CompanyScript.chiaraPortrait);
      host.dismiss();

      progress.travel(LevelId.rome, rounds: 3);
      for (settle(); host.isPromptVisible; settle()) {
        host.dismiss();
      }
      talk();
      expect(host.shown.last.map((line) => line.text), <String>[
        'Cosa?! Non eri mai stato a Roma?',
        TrainScript.chiaraRomeLines.last.text,
      ]);
      expect(
        TrainScript.chiaraRomeLines.last.text,
        'È la città eterna, ti ritrovi tra le rovine romane senza rendertene '
        'conto',
      );
    });

    test('Molfetta started over after she came aboard: she is back at her '
        'desk, not on the train, not even in Rome if she is not found '
        'again first', () {
      final world = createGameWorld()
        ..map.setTile(trainChiaraTile, const Tile(TileKind.obstacle));
      final restarted = restartHometown((
        world: saveGameWorld(world),
        story: <String, Object?>{
          'company': <String, Object?>{'met': true, 'gone': true},
        },
        progress: Progress().toJson(),
        hud: const <String>[],
        place: trainPlaceName,
      ), Progress.newGame());
      expect(restarted.story.containsKey('company'), isFalse);
      final again = restoreGameWorld(restarted.world);
      expect(again.map.tileAt(trainChiaraTile).isWalkable, isTrue);
      expect(again.map.tileAt(chiaraTile).isWalkable, isFalse);

      // And on to Rome in the new run, the company never entered.
      script().restore(
        restarted.story['company'] as Map<String, Object?>? ??
            const <String, Object?>{},
      );
      progress.travel(LevelId.rome, rounds: 3);
      for (settle(); host.isPromptVisible; settle()) {
        host.dismiss();
      }
      host.shown.clear();
      expect(script().aboard, isFalse);
      director.onEvents(<WorldEvent>[LookedOutEvent(at: trainChiaraTile)]);
      settle();
      expect(host.shown, isEmpty);
    });

    test("her call is one of Molfetta's memories and the mission one of "
        "Molfetta's, counted in its figures", () {
      expect(StoryMemory.chiaraCall.level, LevelId.hometown);
      expect(Mission.reachSurvivor.level, LevelId.hometown);
      expect(
        memoryScenes[StoryMemory.chiaraCall]!.map((scene) => scene.text),
        CompanyScript.callFrames.map((frame) => frame.text),
      );

      final before = LevelStats.of(world, progress, LevelId.hometown);
      expect(before.missions, contains(Mission.reachSurvivor));
      progress.remember(StoryMemory.chiaraCall);
      progress.missions.give(Mission.reachSurvivor);
      final after = LevelStats.of(world, progress, LevelId.hometown);
      // Five pictures for six lines: the zombie's roar is shown twice.
      expect(after.foundMemories - before.foundMemories, 5);
      expect(after.openMissions, contains(Mission.reachSurvivor));
      expect(
        LevelStats.of(world, progress, LevelId.rome).missions,
        isNot(contains(Mission.reachSurvivor)),
      );
    });
  });
}
