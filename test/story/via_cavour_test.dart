import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/ui/zombie_book.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  group('Tonino and Marcello at the bottom of Via Cavour', () {
    MaranzaScript script() => director.scripts.whereType<MaranzaScript>().first;

    void standAt(GridPoint tile) =>
        world.player.component<PositionComponent>().position = tile;

    /// [rows] up Via Cavour from where the two of them stand.
    GridPoint upTheStreet(int rows) =>
        GridPoint(marcelloTile.x, marcelloTile.y - rows);

    // Luigi's welcome to Rome, and the lesson after it, said and gone.
    setUp(() {
      progress.travel(LevelId.rome, rounds: 3);
      for (settle(); host.isPromptVisible; settle()) {
        host.dismiss();
      }
      host.shown.clear();
    });

    test('they stand on the street, right where Via Cavour comes out', () {
      for (final tile in <GridPoint>[marcelloTile, toninoTile]) {
        expect(world.map.tileAt(tile).isWalkable, isTrue);
      }
      expect(toninoTile, marcelloTile.step(Direction.east));
    });

    test('walking down to them plays the meeting, and the mission comes once '
        'the game is back', () {
      standAt(upTheStreet(6));
      settle();
      expect(host.cutscenes, isEmpty, reason: 'still too far up the street');

      standAt(upTheStreet(5));
      settle();
      expect(host.cutscenes.single, MaranzaScript.meetingScene);
      expect(host.cutscenes.single.map((frame) => frame.speaker), <String?>[
        MaranzaScript.tonino,
        MaranzaScript.marcello,
        'Mario Rossi',
        MaranzaScript.tonino,
        'Mario Rossi',
        MaranzaScript.marcello,
      ]);
      expect(progress.memories, contains(StoryMemory.maranzaMet));
      expect(progress.missions.isOpen(Mission.findValuable), isFalse);

      host.onCutsceneFinished!();
      expect(progress.missions.isOpen(Mission.findValuable), isTrue);
      expect(script().metPlayed, isTrue);
    });

    test('once met, every step at them gets a warning, in turn, and Mario '
        'walked back up the street', () {
      standAt(upTheStreet(3));
      settle();
      host.onCutsceneFinished!();

      settle();
      expect(host.shown, isEmpty, reason: 'three rows away they let him be');

      standAt(upTheStreet(2));
      settle();
      expect(host.shown.single.single.text, MaranzaScript.warnings[0].text);
      expect(host.shown.single.single.portrait, MaranzaScript.toninoPortrait);
      expect(host.walked, isEmpty, reason: 'not before the line is read');
      host.dismiss();
      expect(host.walked, <Direction>[Direction.north]);

      standAt(upTheStreet(3));
      settle();
      expect(host.shown, hasLength(1));

      standAt(upTheStreet(2));
      settle();
      expect(host.shown.last.single.text, MaranzaScript.warnings[1].text);
      expect(host.shown.last.single.portrait, MaranzaScript.marcelloPortrait);
      host.dismiss();

      standAt(upTheStreet(3));
      settle();
      standAt(upTheStreet(2));
      settle();
      expect(host.shown.last.single.text, MaranzaScript.warnings[0].text);
    });

    test('the meeting is not played twice, and the next warning is kept '
        'through a save', () {
      standAt(upTheStreet(4));
      settle();
      host.onCutsceneFinished!();
      standAt(upTheStreet(2));
      settle();
      host.dismiss();

      final restored = StoryDirector(
        world: world,
        host: host,
        progress: progress,
      )..restore(director.toJson());
      standAt(upTheStreet(2));
      for (var i = 0; i < 20; i++) {
        restored.update(0.1, turnAnimating: false);
      }
      expect(host.cutscenes, hasLength(1));
      expect(host.shown.last.single.text, MaranzaScript.warnings[1].text);
    });

    test('the meeting is one of the memories of Rome', () {
      expect(StoryMemory.maranzaMet.level, LevelId.rome);
      expect(
        memoryScenes[StoryMemory.maranzaMet]!.map((scene) => scene.text),
        MaranzaScript.meetingScene.map((frame) => frame.text),
      );
    });
  });
}
