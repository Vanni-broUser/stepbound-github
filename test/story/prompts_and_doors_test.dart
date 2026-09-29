import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  test('a queued prompt stops Mario and counts down while he still walks', () {
    director.queue(
      StoryPrompt(<StoryLine>[
        const StoryLine('Ecco'),
      ], delay: StoryDirector.reactionDelay),
    );

    // Holding an arrow down leaves hardly a frame between one step and the
    // next: the delay has to run anyway, or the box lands streets away.
    for (var i = 0; i < 20; i++) {
      director.update(0.05, turnAnimating: true);
    }
    expect(host.stops, greaterThan(0), reason: 'he walked on');
    expect(host.shown, isEmpty, reason: 'the step was still animating');

    director.update(0.05, turnAnimating: false);
    expect(host.shown.single.single.text, 'Ecco');
  });

  test('a step off the edge of a map with no next map shows the '
      'work-in-progress screen, and Mario is back inside once it is '
      'tapped away', () {
    // East of Termini, past the roadblock, where the road runs off the map.
    final piazza = place(PlaceId.piazzaCinquecento);
    final end = GridPoint(piazza.bounds.right, piazza.origin.y + 12);
    final mario = world.player.component<PositionComponent>()
      ..position = end.step(Direction.west)
      ..facing = Direction.east;

    final events = const TurnScheduler().advance(
      world,
      const MoveAction(Direction.east),
    );
    expect(mario.position, end);
    director.onEvents(events);

    expect(host.workInProgressShown, 1);
    expect(mario.position, end.step(Direction.west));
    expect(mario.facing, Direction.west);
  });

  test('the last step of the stairs down into a building with no map yet '
      'shows the work-in-progress screen, and Mario is back on the step '
      'before it, facing back up', () {
    for (final door in <GridPoint>[hospitalNextRoofStairsFoot.first]) {
      host.workInProgressShown = 0;
      final way = world.stairs[door]!;
      final start = door.step(way.opposite);
      final mario = world.player.component<PositionComponent>()
        ..position = start
        ..facing = way;

      final events = const TurnScheduler().advance(world, MoveAction(way));
      expect(mario.position, door);
      director.onEvents(events);

      expect(host.workInProgressShown, 1, reason: '$door');
      expect(mario.position, start);
      expect(mario.facing, way.opposite);
    }
  });

  test('the locked bar door explains that it needs a key', () {
    world.player.component<PositionComponent>()
      ..position = barLockedDoorTile.step(Direction.south)
      ..facing = Direction.north;

    final events = const TurnScheduler().advance(world, const InteractAction());
    director.onEvents(events);
    settle();

    expect(events.whereType<NoInteractionEvent>(), hasLength(1));
    expect(host.shown.single.single.text, BarScript.lockedDoorLine);
    expect(
      world.map.tileAt(barLockedDoorTile).kind,
      TileKind.wall,
      reason: 'the locked service door must not open like a normal door',
    );
  });

  test('the bar key opens the service door, is consumed and says so', () {
    host.unlock(HudElement.barKey);
    world.player.component<PositionComponent>()
      ..position = barLockedDoorTile.step(Direction.south)
      ..facing = Direction.north;

    final events = const TurnScheduler().advance(world, const InteractAction());
    director.onEvents(events);

    expect(events.whereType<NoInteractionEvent>(), hasLength(1));
    expect(world.map.tileAt(barLockedDoorTile).isWalkable, isTrue);
    expect(host.unlocked, isNot(contains(HudElement.barKey)));
    settle();
    expect(host.shown.single.single.text, BarScript.keyUsedLine);
    expect(BarScript.keyUsedLine, 'Hai usato la chiave per aprire la porta');
  });

  test('everyone in the Duomo speaks with a portrait', () {
    for (final (tile, text, speaker, portrait)
        in <(GridPoint, String, String, String)>[
          (
            duomoStairCultistTile,
            DuomoScript.stairBlockedLine,
            DuomoScript.cultist,
            DuomoScript.cultistPortrait,
          ),
          (
            duomoWelcomingCultistTile,
            DuomoScript.welcomeLine,
            DuomoScript.cultist,
            DuomoScript.cultistPortrait,
          ),
          (
            duomoPriestTile,
            DuomoScript.ringReminderLine,
            PriestScript.priest,
            PriestScript.priestPortrait,
          ),
        ]) {
      world.player.component<PositionComponent>()
        ..position = tile.step(Direction.south)
        ..facing = Direction.north;
      final events = const TurnScheduler().advance(
        world,
        const InteractAction(),
      );
      director.onEvents(events);
      settle();

      final line = host.shown.last.single;
      expect(line.text, text);
      expect(line.speaker, speaker);
      expect(line.portrait, portrait);
      host.dismiss();
    }
  });

  test('the episcopal ring is found in a backpack, and its badge comes with '
      'the news', () {
    director.onEvents(<WorldEvent>[
      pickedUp(episcopalRingPickupId, episcopalRing: true),
    ]);
    settle();

    expect(host.pickupAnimations, 1);
    expect(host.shown.single.single.text, BackpacksScript.ringFound);
    expect(host.unlocked, contains(HudElement.episcopalRing));
  });

  test('entering the Duomo with the ring welcomes Mario into the family', () {
    final ring = world.pickups[episcopalRingPickupId]!
      ..active = false
      ..collected = true;
    host.unlock(HudElement.episcopalRing);
    world.player.component<PositionComponent>().position =
        world.portals[duomoPortalTile]!.to;

    settle();

    expect(ring.collected, isTrue);
    expect(host.cutscenes.single, DuomoScript.initiationScene);
    expect(host.cutsceneMusic.single, Music.sacred);
    expect(host.cutscenes.single, hasLength(2));
    expect(host.cutscenes.single.first.image, DuomoScript.initiationImage);
    expect(host.cutscenes.single.first.text, DuomoScript.familyWelcomeLine);
    expect(host.cutscenes.single.last.text, DuomoScript.robeLine);
    expect(progress.memories, contains(StoryMemory.priestFamily));

    progress.missions.give(Mission.findRing);
    host.onCutsceneFinished?.call();
    expect(host.unlocked, isNot(contains(HudElement.episcopalRing)));
    expect(host.duomoUpperOpenings, 1);
    expect(progress.missions.isDone(Mission.findRing), isTrue);
    expect(progress.missions.open, <Mission>[Mission.initiation]);

    director.onEvents(<WorldEvent>[
      NoInteractionEvent(duomoPriestTile),
      NoInteractionEvent(duomoStairCultistMovedTile),
      NoInteractionEvent(duomoUpperLockedDoorTile),
    ]);
    settle();
    expect(host.shown[0].single.text, DuomoScript.initiationReminderLine);
    host.dismiss();
    settle();
    expect(host.shown[1].single.text, DuomoScript.welcomeLine);
    expect(host.shown[1].single.portrait, DuomoScript.cultistPortrait);
    host.dismiss();
    settle();
    expect(host.shown[2].single.text, DuomoScript.lockedDoorLine);
    expect(host.shown[2].single.portrait, isNull);
  });

  test('the robe upstairs, in its backpack, is announced before Mario puts '
      'it on', () {
    director.onEvents(<WorldEvent>[
      pickedUp(cultistRobePickupId, cultistRobe: true),
    ]);
    settle();

    expect(host.pickupAnimations, 1);
    expect(host.shown.single.single.text, DuomoScript.robeFoundLine);
    expect(host.cultistRobesCollected, 0);
    host.dismiss();
    expect(host.cultistRobesCollected, 1);
  });

  test('the mass starts only once Mario is back in the Duomo in the robe', () {
    world.pickups[episcopalRingPickupId]!
      ..active = false
      ..collected = true;
    final position = world.player.component<PositionComponent>()
      ..position = world.portals[duomoPortalTile]!.to;
    settle();
    host.onCutsceneFinished?.call();
    expect(host.cutscenes, hasLength(1), reason: 'only the initiation');

    // Dressed upstairs: the mass is downstairs.
    progress
      ..unlockOutfit(PlayerOutfit.cultist)
      ..wearOutfit(PlayerOutfit.cultist);
    position.position = duomoUpperRobeTile;
    settle();
    expect(host.cutscenes, hasLength(1));

    // Down in his own clothes: everything waits.
    progress.wearOutfit(PlayerOutfit.base);
    position.position = duomoStairEntryTile;
    settle();
    expect(host.cutscenes, hasLength(1));
    expect(progress.memories, isNot(contains(StoryMemory.priestMass)));

    progress.wearOutfit(PlayerOutfit.cultist);
    settle();
    expect(host.cutscenes, hasLength(2));
    // The mass and the massacre it ends in play as one scene.
    expect(host.cutscenes.last, DuomoScript.massSequence);
    expect(host.cutsceneMusic.last, Music.sacred);
    expect(host.cutscenes.last.first.image, DuomoScript.massImage);
    expect(host.cutscenes.last.first.text, DuomoScript.massWelcomeLine);
    expect(host.cutscenes.last[1].image, DuomoScript.crucifiedImage);
    expect(host.cutscenes.last[1].speaker, PriestScript.priest);
    expect(progress.memories, contains(StoryMemory.priestMass));

    // Held once.
    position.position = duomoUpperRobeTile;
    settle();
    position.position = duomoStairEntryTile;
    settle();
    expect(host.cutscenes, hasLength(2));
  });

  test('the mass ends with the community turning on Don Angelo, and leaves '
      'the nave to them', () {
    world.pickups[episcopalRingPickupId]!
      ..active = false
      ..collected = true;
    final position = world.player.component<PositionComponent>()
      ..position = world.portals[duomoPortalTile]!.to;
    settle();
    host.onCutsceneFinished?.call();
    progress
      ..unlockOutfit(PlayerOutfit.cultist)
      ..wearOutfit(PlayerOutfit.cultist);
    position.position = duomoStairEntryTile;
    settle();

    final scene = host.cutscenes.last;
    expect(scene, hasLength(6), reason: 'the mass, then the four of it');
    expect(scene.sublist(2), DuomoScript.massacreScene);
    expect(scene[2].image, DuomoScript.sermonImage);
    expect(scene[2].speaker, PriestScript.priest);
    expect(scene[2].text, DuomoScript.worshipLine);
    expect(scene[3].text, DuomoScript.areYouMadLine);
    expect(scene[3].speaker, 'Mario Rossi');
    expect(scene[4].text, DuomoScript.superZombieLine);
    expect(scene[4].speaker, 'Mario Rossi');
    expect(scene[5].image, DuomoScript.seizedImage);
    expect(scene[5].speaker, PriestScript.priest);
    expect(scene[5].text, DuomoScript.letMeGoLine);
    expect(progress.memories, contains(StoryMemory.priestMassacre));

    // The nave is left to the cultists only once the scene is over.
    expect(host.duomoMassacres, 0);
    expect(progress.missions.isOpen(Mission.initiation), isTrue);
    host.onCutsceneFinished?.call();
    expect(host.duomoMassacres, 1);
    expect(
      progress.missions.isDone(Mission.initiation),
      isTrue,
      reason: 'the ceremony is over once all of the mass has played',
    );
    expect(progress.missions.open, isEmpty);

    // Nobody is left in it to answer.
    director.onEvents(<WorldEvent>[
      NoInteractionEvent(duomoPriestTile),
      NoInteractionEvent(duomoWelcomingCultistTile),
    ]);
    settle();
    expect(host.shown, isEmpty);
  });
}
