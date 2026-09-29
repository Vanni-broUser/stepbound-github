import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  group('hypermarket', () {
    void stepTo(GridPoint to) {
      final position = world.player.component<PositionComponent>();
      final from = position.position;
      position.position = to;
      director.onEvents(<WorldEvent>[
        MovedEvent(entityId: world.playerId, from: from, to: to),
      ]);
    }

    test('a few steps inside, a voice calls and Mario answers', () {
      final hall = GridPoint(
        place(PlaceId.mallGround).bounds.left + 10,
        place(PlaceId.mallGround).bounds.top + 10,
      );
      for (var i = 0; i < MallScript.stepsBeforeVoice - 1; i++) {
        stepTo(hall.step(Direction.north));
        settle();
      }
      expect(host.shown, isEmpty);
      stepTo(hall);
      settle();
      final lines = host.shown.single;
      expect(lines.first.speaker, MallScript.mysteryVoice);
      expect(lines.first.text, MallScript.helpCall);
      expect(lines.last.speaker, 'Mario Rossi');
      expect(lines.last.portrait, isNotNull);
      expect(lines.last.text, MallScript.someoneAlive);
    });

    test("the shutter plays Luigi's scene, then zombies come in", () {
      final trigger = luigiSceneTrigger;
      stepTo(GridPoint(trigger.left + 2, trigger.bottom));
      settle();
      final frames = host.cutscenes.single;
      expect(host.cutsceneMusic.single, isNull, reason: 'still trapped');
      expect(frames.map((frame) => frame.speaker), <String>[
        MallScript.luigi,
        MallScript.luigi,
        'Zombi',
      ]);
      expect(host.spawned, isEmpty);
      host.onCutsceneFinished!();
      expect(host.spawned, hasLength(mallHordeSpawns.length));
      expect(host.spawned.map((zombie) => zombie.kind).toSet(), <EntityKind>{
        EntityKind.wanderer,
      });
      settle();
      expect(host.cutscenes, hasLength(1), reason: 'the scene plays once');
    });

    test('working the panel lifts the shutter and says so', () {
      director.onEvents(<WorldEvent>[
        ControlUsedEvent(at: mallPanelTile, opened: luigiBars),
      ]);
      settle();
      expect(host.shown.single.single.text, MallScript.shutterOpened);
    });

    /// The scene at the shutter, then the horde between Mario and the
    /// panel he has to reach.
    void releaseTheHorde() {
      final trigger = luigiSceneTrigger;
      stepTo(GridPoint(trigger.left + 2, trigger.bottom));
      settle();
      host.onCutsceneFinished!();
      expect(host.spawned, isNotEmpty);
      host.spawned.forEach(world.addEntity);
    }

    /// The panel, and the news of the shutter read.
    void liftTheShutter() {
      director.onEvents(<WorldEvent>[
        ControlUsedEvent(at: mallPanelTile, opened: luigiBars),
      ]);
      settle();
      expect(host.shown.last.single.text, MallScript.shutterOpened);
      host.dismiss();
      settle();
    }

    test('the shutter, not the deaths of the horde, is what frees Luigi', () {
      releaseTheHorde();
      // Killing them all would take every round Mario can pick up on the
      // way here -- the street's two, the accident's four, the car park's
      // two -- none of them fired at anything else, and none missed. The
      // story cannot hang on that.
      const roundsOnTheWay = 2 + 4 + 2;
      expect(host.spawned.length, greaterThanOrEqualTo(roundsOnTheWay));

      // Mario slips past them to the panel without firing a shot.
      liftTheShutter();
      expect(host.cutscenes, hasLength(2), reason: 'the reunion plays anyway');
      expect(
        host.spawned.every((zombie) => zombie.isAlive),
        isTrue,
        reason: 'they are all still on their feet',
      );
      host.onCutsceneFinished!();
      expect(
        host.killed.toSet(),
        host.spawned.map((zombie) => zombie.id).toSet(),
        reason: 'Luigi sees off what is left of them, as his line says',
      );
    });

    test('lifting the shutter plays the reunion, then Luigi leaves for the '
        'station', () {
      releaseTheHorde();
      // Mario does shoot a couple of them on the way to the panel.
      for (final zombie in host.spawned.take(2)) {
        zombie.component<HealthComponent>().current = 0;
        director.onEvents(<WorldEvent>[DiedEvent(zombie.id)]);
      }
      settle();
      expect(host.cutscenes, hasLength(1), reason: 'Luigi is still shut in');

      liftTheShutter();

      expect(host.cutscenes, hasLength(2));
      final reunion = host.cutscenes.last;
      expect(host.cutsceneMusic.last, Music.luigi, reason: 'set free');
      expect(reunion.map((frame) => frame.speaker), <String>[
        MallScript.luigi,
        'Mario Rossi',
        MallScript.luigi,
      ]);
      expect(progress.memories, contains(StoryMemory.luigiRescued));

      expect(progress.missions.open, <Mission>[Mission.freeLuigi]);
      host.onCutsceneFinished!();
      expect(
        host.killed,
        host.spawned.skip(2).map((zombie) => zombie.id),
        reason: 'Luigi finishes the ones Mario left',
      );
      settle();
      final lines = host.shown.last;
      expect(lines, hasLength(2));
      for (final line in lines) {
        expect(line.speaker, MallScript.luigi);
        expect(line.portrait, isNotNull);
      }
      expect(lines.first.text, MallScript.trustLine);
      expect(lines.last.text, MallScript.meetAtStationLine);

      expect(host.luigiSent, 0);
      expect(
        progress.missions.isOpen(Mission.freeLuigi),
        isTrue,
        reason: 'crossed out only once Luigi has had his say',
      );
      host.dismiss();
      expect(host.luigiSent, 1);
      expect(progress.missions.done, <Mission>[Mission.freeLuigi]);
      expect(progress.missions.open, <Mission>[Mission.reachLuigi]);
    });

    test('the shutter lifted before his scene: Luigi is free as soon as it '
        'ends, and the reunion waits for the corner to cross him out', () {
      // Along the railing, past the shop unheard, to the panel.
      liftTheShutter();
      expect(host.cutscenes, isEmpty, reason: 'Luigi has not been seen');
      expect(progress.missions.open, isEmpty);

      final trigger = luigiSceneTrigger;
      stepTo(GridPoint(trigger.left + 2, trigger.bottom));
      // One frame: the fake host does not cover the game while it plays.
      director.update(0.1, turnAnimating: false);
      expect(host.cutscenes.single, MallScript.luigiScene);
      host
        ..onCutsceneFinished!()
        ..missionsSettling = true;
      expect(
        progress.missions.done,
        <Mission>[Mission.freeLuigi],
        reason: 'handed out and done at once, the shutter already up',
      );
      expect(progress.missions.isOpen(Mission.freeLuigi), isFalse);
      settle();
      expect(host.cutscenes, hasLength(1), reason: 'the corner comes first');

      host.missionsSettling = false;
      settle();
      expect(host.cutscenes.last, MallScript.reunionScene);
      host.onCutsceneFinished!();
      settle();
      host.dismiss();
      expect(progress.missions.done, <Mission>[Mission.freeLuigi]);
      expect(progress.missions.open, <Mission>[Mission.reachLuigi]);
    });
  });
}
