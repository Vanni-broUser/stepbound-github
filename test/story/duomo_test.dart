import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  group('Duomo', () {
    void walkTo(GridPoint to) =>
        world.player.component<PositionComponent>().position = to;

    /// The seafront road right in front of the churchyard alley.
    GridPoint onTheSeafront() =>
        GridPoint(priestGateFront.left + 1, priestSceneTrigger.bottom - 1);

    /// In the alley, right at the gate.
    GridPoint atTheGate() =>
        GridPoint(priestGateFront.left + 1, priestGateFront.bottom);

    /// Down the seafront road, out of earshot of the gate.
    GridPoint awayFromTheGate() =>
        GridPoint(priestSceneTrigger.right + 1, priestSceneTrigger.bottom);

    void killTheZombiesAtTheGate() {
      for (var i = 0; i < priestZombieTiles.length; i++) {
        world.entities['$priestZombiePrefix$i']!
                .component<HealthComponent>()
                .current =
            0;
      }
    }

    /// Walks up, watches the meeting scene and hears Don Angelo out.
    void meetThePriest() {
      walkTo(onTheSeafront());
      settle();
      host.onCutsceneFinished!();
      settle();
      host.dismiss();
    }

    /// Clears the first danger, hears the price and accepts the errand.
    void acceptIncenseErrand() {
      meetThePriest();
      killTheZombiesAtTheGate();
      walkTo(atTheGate());
      settle();
      host.onCutsceneFinished!();
      settle();
      host.dismiss();
    }

    /// Picks up the incense far from the Duomo and reads its notification.
    void collectIncense() {
      walkTo(world.pickups[incenseBackpackId]!.position);
      director.onEvents(<WorldEvent>[
        pickedUp(incenseBackpackId, incense: true),
      ]);
      settle();
      host.dismiss();
    }

    test('walking the seafront plays the meeting, then he asks for the gate '
        'to be cleared', () {
      walkTo(onTheSeafront());
      settle();
      expect(host.shown, isEmpty, reason: 'the pictures come first');
      final frames = host.cutscenes.single;
      expect(host.cutsceneMusic.single, Music.sacred);
      expect(frames.map((frame) => frame.speaker), <String>[
        PriestScript.priest,
        'Mario Rossi',
        PriestScript.priest,
      ]);
      expect(frames.map((frame) => frame.image), <String>[
        PriestScript.gateScene,
        PriestScript.seafrontScene,
        PriestScript.gateScene,
      ]);
      expect(
        frames.first.text,
        'Ohh che piacere vedere qualcuno ancora in vita passeggiare per il '
        'nostro porto',
      );
      expect(progress.memories, <StoryMemory>{StoryMemory.priestMet});

      host.onCutsceneFinished!();
      settle();
      final line = host.shown.single.single;
      expect(line.text, PriestScript.clearThemOut);
      expect(line.speaker, PriestScript.priest);
      expect(line.portrait, PriestScript.priestPortrait);
      expect(
        host.isPromptVisible,
        isTrue,
        reason:
            'no controls until it is '
            'read',
      );
      host.dismiss();
      settle();
      expect(host.cutscenes, hasLength(1), reason: 'the scene plays once');
    });

    test('standing at the gate with the zombies still there says nothing', () {
      meetThePriest();
      walkTo(atTheGate());
      settle();
      expect(host.cutscenes, hasLength(1));
    });

    test(
      'killing them plays the deal, then he sends Mario for the incense',
      () {
        meetThePriest();
        killTheZombiesAtTheGate();
        walkTo(atTheGate());
        settle();

        expect(host.cutscenes, hasLength(2));
        final deal = host.cutscenes.last;
        expect(host.cutsceneMusic.last, Music.sacred);
        expect(deal.map((frame) => frame.speaker), <String>[
          'Mario Rossi',
          PriestScript.priest,
          'Mario Rossi',
          PriestScript.priest,
        ]);
        expect(
          deal.every((frame) => frame.image == PriestScript.dealSceneImage),
          isTrue,
          reason: 'the same picture behind all four lines',
        );
        expect(progress.memories, <StoryMemory>[
          StoryMemory.priestMet,
          StoryMemory.priestErrand,
        ]);

        host.onCutsceneFinished!();
        settle();
        final lines = host.shown.last;
        expect(lines.map((line) => line.text), <String>[
          PriestScript.incenseLine,
          PriestScript.whereLine,
          PriestScript.everyTwoStreetsLine,
        ]);
        expect(lines.map((line) => line.speaker), <String>[
          PriestScript.priest,
          'Mario Rossi',
          PriestScript.priest,
        ]);
        expect(lines.every((line) => line.portrait != null), isTrue);
        final priest = director.scripts.whereType<PriestScript>().single;
        expect(priest.errandGiven, isFalse, reason: 'not until it is read');
        expect(progress.missions.open, <Mission>[Mission.clearGate]);
        host.dismiss();
        expect(priest.errandGiven, isTrue);
        expect(progress.missions.done, <Mission>[Mission.clearGate]);
        expect(progress.missions.open, <Mission>[Mission.findIncense]);
      },
    );

    test('luring them far enough away is as good as killing them', () {
      meetThePriest();
      for (var i = 0; i < priestZombieTiles.length; i++) {
        final zombie = world.entities['$priestZombiePrefix$i']!;
        zombie.component<HearingComponent>().hunting = false;
        zombie.component<PositionComponent>().position = GridPoint(
          priestGateFront.left + PriestScript.safeDistance + 1,
          priestSceneTrigger.bottom,
        );
      }
      walkTo(atTheGate());
      settle();
      expect(host.cutscenes, hasLength(2));
    });

    test('one of them still hunting Mario keeps the priest quiet', () {
      meetThePriest();
      final zombies = <Entity>[
        for (var i = 0; i < priestZombieTiles.length; i++)
          world.entities['$priestZombiePrefix$i']!,
      ];
      for (final zombie in zombies) {
        zombie
          ..component<HearingComponent>().hunting = false
          ..component<PositionComponent>().position = GridPoint(
            priestGateFront.left + PriestScript.safeDistance + 1,
            priestSceneTrigger.bottom,
          );
      }
      zombies.first.component<HearingComponent>().hunting = true;
      walkTo(atTheGate());
      settle();
      expect(host.cutscenes, hasLength(1));
    });

    test('returning with the incense to a clear gate plays the welcome', () {
      acceptIncenseErrand();
      collectIncense();

      walkTo(atTheGate());
      settle();

      expect(host.cutscenes, hasLength(3));
      final welcome = host.cutscenes.last;
      expect(host.cutsceneMusic.last, Music.sacred);
      expect(welcome, PriestScript.welcomeScene);
      expect(welcome, hasLength(5));
      expect(welcome.first.image, PriestScript.welcomeSceneImage);
      expect(welcome.first.speaker, PriestScript.priest);
      expect(welcome.first.text, PriestScript.welcomeLine);
      expect(welcome[1].image, PriestScript.communitySceneImage);
      expect(welcome[1].text, PriestScript.notCommunityYetLine);
      expect(welcome[2].speaker, 'Mario Rossi');
      expect(welcome[2].text, PriestScript.moreWorkLine);
      expect(welcome[3].text, PriestScript.useYourSkillsLine);
      expect(welcome.last.image, PriestScript.barKeySceneImage);
      expect(welcome.last.text, PriestScript.barKeyLine);
      expect(progress.memories.last, StoryMemory.priestWelcomed);

      host.onCutsceneFinished?.call();
      expect(host.unlocked, isNot(contains(HudElement.incense)));
      expect(host.unlocked, contains(HudElement.barKey));
      expect(host.duomoOpenings, 1);

      settle();
      expect(host.cutscenes, hasLength(3), reason: 'the welcome plays once');
    });

    test('a zombie by the entrance makes Don Angelo repeat his warning', () {
      acceptIncenseErrand();
      collectIncense();
      final nearbyZombie = world.entities[tutorialZombieId]!
        ..component<PositionComponent>().position = atTheGate().step(
          Direction.east,
        );

      walkTo(atTheGate());
      settle();

      expect(host.cutscenes, hasLength(2), reason: 'the welcome must wait');
      final warning = host.shown.last.single;
      expect(warning.text, PriestScript.clearThemOut);
      expect(warning.speaker, PriestScript.priest);
      expect(warning.portrait, PriestScript.priestPortrait);

      final warnings = host.shown.length;
      expect(progress.missions.open, <Mission>[Mission.findIncense]);
      host.dismiss();
      expect(progress.missions.open, <Mission>[
        Mission.findIncense,
        Mission.clearGate,
      ], reason: 'the gate is a mission again');
      settle();
      expect(
        host.shown,
        hasLength(warnings),
        reason: 'standing still does not reopen the same box',
      );

      walkTo(awayFromTheGate());
      settle();
      walkTo(atTheGate());
      settle();
      expect(host.shown, hasLength(warnings + 1), reason: 'a new visit warns');

      host.dismiss();
      nearbyZombie.component<HealthComponent>().current = 0;
      settle();
      expect(host.cutscenes.last, PriestScript.welcomeScene);
      host.onCutsceneFinished!();
      expect(
        progress.missions.done,
        <Mission>[Mission.clearGate, Mission.findIncense],
        reason: 'crossed out together, the gate counted once',
      );
      expect(progress.missions.open, <Mission>[Mission.findRing]);
    });

    test('the incense in hand before he asks for it: the gate and the '
        'incense are crossed out, then the welcome', () {
      collectIncense();
      meetThePriest();
      expect(progress.missions.open, contains(Mission.clearGate));
      killTheZombiesAtTheGate();
      walkTo(atTheGate());
      settle();
      expect(host.cutscenes.last, PriestScript.dealScene);
      host.onCutsceneFinished!();
      settle();
      expect(host.shown.last.first.text, PriestScript.incenseLine);
      host.dismiss();
      expect(
        progress.missions.done,
        <Mission>[Mission.clearGate, Mission.findIncense],
        reason: 'the incense is found the moment it is asked for',
      );
      expect(progress.missions.open, isNot(contains(Mission.findIncense)));

      host.missionsSettling = true;
      settle();
      expect(host.cutscenes, hasLength(2), reason: 'the corner comes first');

      host.missionsSettling = false;
      settle();
      expect(host.cutscenes.last, PriestScript.welcomeScene);
      host.onCutsceneFinished!();
      expect(progress.missions.done, <Mission>[
        Mission.clearGate,
        Mission.findIncense,
      ], reason: 'each counted once');
      expect(progress.missions.open, contains(Mission.findRing));
    });

    test('every scene plays where the first one did: with the incense in '
        'hand, the price and the welcome follow on the seafront without a '
        'step', () {
      collectIncense();
      meetThePriest();
      killTheZombiesAtTheGate();
      // The road clear too: on it, any zombie close by keeps him quiet.
      for (final zombie in world.entities.values) {
        if (zombie.kind != EntityKind.player &&
            zombie.component<PositionComponent>().position.manhattanDistanceTo(
                  onTheSeafront(),
                ) <
                PriestScript.safeDistance) {
          zombie.component<HealthComponent>().current = 0;
        }
      }
      settle();
      expect(host.cutscenes.last, PriestScript.dealScene);
      host.onCutsceneFinished!();
      settle();
      host.dismiss();
      expect(progress.missions.isDone(Mission.findIncense), isTrue);

      host.missionsSettling = true;
      settle();
      expect(host.cutscenes, hasLength(2), reason: 'the corner comes first');
      host.missionsSettling = false;
      settle();
      expect(host.cutscenes.last, PriestScript.welcomeScene);
      expect(
        world.player.component<PositionComponent>().position,
        onTheSeafront(),
      );
    });

    test('a save after the welcome does not play it again', () {
      acceptIncenseErrand();
      collectIncense();
      walkTo(atTheGate());
      settle();
      final saved = director.toJson();

      host = FakeStoryHost(progress)..unlock(HudElement.incense);
      director = StoryDirector(world: world, host: host, progress: progress)
        ..restore(saved);
      settle();

      expect(host.cutscenes, isEmpty);
      expect(progress.memories, contains(StoryMemory.priestWelcomed));
    });

    test('a save between the two halves resumes where the priest left off', () {
      meetThePriest();
      // Resting at a camp and loading again: a new director, restored.
      final saved = director.toJson();
      final resumed = StoryDirector(
        world: world,
        host: host = FakeStoryHost(progress),
        progress: progress,
      )..restore(saved);
      director = resumed;

      killTheZombiesAtTheGate();
      walkTo(atTheGate());
      settle();
      expect(
        host.cutscenes.single.last.text,
        PriestScript.dealScene.last.text,
        reason: 'the deal still plays after the reload',
      );
      expect(progress.memories, contains(StoryMemory.priestErrand));
    });

    test('the Duomo and the hypermarket are remembered in the order they '
        'were lived', () {
      meetThePriest();

      // Off to the hypermarket in the middle of the errand.
      world.player.component<PositionComponent>().position = GridPoint(
        luigiSceneTrigger.left + 1,
        luigiSceneTrigger.top,
      );
      settle();
      host.onCutsceneFinished!();
      settle();

      expect(
        progress.missions.done,
        <Mission>[Mission.findSurvivors],
        reason: 'Don Angelo, then Luigi: there are other survivors',
      );

      // Back to the harbour to finish it.
      killTheZombiesAtTheGate();
      walkTo(atTheGate());
      settle();

      expect(progress.memories, <StoryMemory>[
        StoryMemory.priestMet,
        StoryMemory.luigiTrapped,
        StoryMemory.priestErrand,
      ]);
      expect(
        Progress.fromJson(progress.toJson()).memories.toList(),
        progress.memories.toList(),
        reason: 'a save keeps that order',
      );
    });
  });

  test('in Rome the supplies are the mission once Luigi has said his last '
      'word of welcome, not before', () {
    progress.travel(LevelId.rome, rounds: 3);
    settle();
    expect(host.shown.first.first.speaker, 'Luigi Rovaga');
    expect(progress.missions.isOpen(Mission.findSupplies), isFalse);

    host.dismiss();
    expect(progress.missions.open, contains(Mission.findSupplies));
  });
}
