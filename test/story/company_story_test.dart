import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
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
      expect(Mission.reachSurvivor.text, 'Raggiungi la sopravvissuta');
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
