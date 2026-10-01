import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/zombie_lore.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  group('out of the Duomo after the massacre', () {
    // The way out of the Duomo, and where it comes out on the harbour.
    late GridPoint inside;
    late GridPoint outside;

    setUp(() {
      inside = world.portals[duomoPortalTile]!.to;
      final out = world.portals.entries.firstWhere(
        (portal) =>
            placeAt(portal.key)?.id == PlaceId.duomo &&
            placeAt(portal.value.to)?.id == PlaceId.harbour,
      );
      outside = out.value.to;
      director.restore(<String, Object?>{
        'duomo': <String, Object?>{'ringDelivered': true, 'massacre': true},
      });
      progress.unlockOutfit(PlayerOutfit.cultist);
    });

    void leave() {
      director.onEvents(<WorldEvent>[
        TeleportedEvent(entityId: world.playerId, from: inside, to: outside),
      ]);
      settle();
    }

    test('in the robe, Mario comes out in his own clothes, told once that '
        'the robe is his and that the clothes will be changed later on', () {
      progress.wearOutfit(PlayerOutfit.cultist);
      leave();
      expect(host.outfitsWorn, <PlayerOutfit>[PlayerOutfit.base]);
      const later =
          "Hai ottenuto l'abbigliamento da occultista. In futuro potrai "
          'scegliere quale abbigliamento usare.';
      expect(host.shown.single.map((line) => line.text), <String>[
        'Mario cambia abbigliamento uscito dal duomo',
        later,
      ]);
      host.dismiss();

      final saved = director.toJson();
      director.restore(saved);
      progress.wearOutfit(PlayerOutfit.cultist);
      leave();
      expect(host.outfitsWorn, hasLength(1), reason: 'only the first time');
      expect(host.shown, hasLength(1));
    });

    test('once Mario has been aboard the train with Luigi, he is told the '
        'clothes are changed there', () {
      progress
        ..remember(StoryMemory.luigiAtStation)
        ..wearOutfit(PlayerOutfit.cultist);
      leave();
      expect(
        host.shown.single.last.text,
        "Hai ottenuto l'abbigliamento da occultista. Potrai scegliere quale "
        'abbigliamento usare sul treno.',
      );
    });

    test('already in his own clothes, nothing is said, then or later', () {
      progress.wearOutfit(PlayerOutfit.base);
      leave();
      progress.wearOutfit(PlayerOutfit.cultist);
      leave();
      expect(host.outfitsWorn, isEmpty);
      expect(host.shown, isEmpty);
    });

    test('before the massacre, the robe stays on', () {
      director.restore(<String, Object?>{
        'duomo': <String, Object?>{'ringDelivered': true},
      });
      progress.wearOutfit(PlayerOutfit.cultist);
      leave();
      expect(host.outfitsWorn, isEmpty);
      expect(host.shown, isEmpty);
    });
  });

  test('the key beside Don Angelo says whose it was, and opens the door '
      'upstairs once', () {
    director.onEvents(<WorldEvent>[pickedUp(duomoKeyPickupId, duomoKey: true)]);
    settle();

    expect(host.pickupAnimations, 1);
    expect(host.shown.single.single.text, BackpacksScript.duomoKeyFound);
    expect(
      BackpacksScript.duomoKeyFound,
      'Hai trovato la Chiave del Duomo vicino il cadavere di Don Angelo',
    );
    expect(host.unlocked, contains(HudElement.duomoKey));
    host.dismiss();

    director.onEvents(<WorldEvent>[
      NoInteractionEvent(duomoUpperLockedDoorTile),
    ]);
    settle();
    expect(host.shown.last.single.text, DuomoScript.keyUsedLine);
    expect(world.map.tileAt(duomoUpperLockedDoorTile).isWalkable, isTrue);
    expect(host.unlocked, isNot(contains(HudElement.duomoKey)));
  });

  test('the door upstairs stays shut without the key', () {
    director.onEvents(<WorldEvent>[
      NoInteractionEvent(duomoUpperLockedDoorTile),
    ]);
    settle();

    expect(host.shown.single.single.text, DuomoScript.lockedDoorLine);
    expect(world.map.tileAt(duomoUpperLockedDoorTile).kind, TileKind.wall);
  });

  test('looking at the fire across the shopping street says it would take '
      'an extinguisher, every time', () {
    for (var look = 0; look < 2; look++) {
      director.onEvents(<WorldEvent>[
        LookedOutEvent(at: shoppingStreetFireTile),
      ]);
      settle();
      expect(host.shown.last.single.text, RoadblockFireScript.fireLine);
      host.dismiss();
    }
    expect(host.shown, hasLength(2));
    expect(
      RoadblockFireScript.fireLine,
      "L'incendio blocca completamente la strada, potresti passare con un "
      'estintore',
    );
  });

  test('the burning lane of the pile-up north of the crossroads, in the '
      'north district, says the same', () {
    director.onEvents(<WorldEvent>[LookedOutEvent(at: northDistrictFireTile)]);
    settle();
    expect(host.shown.single.single.text, RoadblockFireScript.fireLine);
  });

  test(
    'the fire in the gap by the burning car at the station says the same',
    () {
      director.onEvents(<WorldEvent>[LookedOutEvent(at: stationTrackFireTile)]);
      settle();
      expect(host.shown.single.single.text, RoadblockFireScript.fireLine);
    },
  );

  test('each damaged door of the old town says a crowbar would open it, '
      'every time', () {
    for (final door in oldTownDamagedDoorTiles) {
      director.onEvents(<WorldEvent>[LookedOutEvent(at: door)]);
      settle();
      expect(host.shown.last.single.text, DamagedDoorScript.doorLine);
      host.dismiss();
    }
    expect(host.shown, hasLength(oldTownDamagedDoorTiles.length));
    expect(
      DamagedDoorScript.doorLine,
      "Questa porta è un po' danneggiata, con un piede di porco potresti "
      'aprirla',
    );
  });

  test('the gap in the roadblock east of Termini says the same', () {
    director.onEvents(<WorldEvent>[LookedOutEvent(at: roadblockFireTile)]);
    settle();
    expect(host.shown.single.single.text, RoadblockFireScript.fireLine);
  });

  test('looking over the gap between the roofs tells Mario what it would '
      'take, every time he looks', () {
    for (var look = 0; look < 2; look++) {
      director.onEvents(<WorldEvent>[LookedOutEvent(at: rooftopGapTile)]);
      settle();
      expect(host.shown.last.single.text, RooftopsScript.gapLesson);
      expect(
        host.shown.last.single.speaker,
        isNull,
        reason: 'a voice over the roofs, not Mario talking to himself',
      );
      host.dismiss();
    }
    expect(host.shown, hasLength(2));
  });

  test('from the top of the Duomo tower the other tower is a grappling '
      'hook away, as the roofs past the airliner are', () {
    director.onEvents(<WorldEvent>[LookedOutEvent(at: duomoTowerLookoutTile)]);
    settle();
    expect(host.shown.single.single.text, RooftopsScript.gapLesson);
  });

  test('from the hospital roof the next block is a grappling hook away '
      'too', () {
    director.onEvents(<WorldEvent>[
      LookedOutEvent(at: hospitalRoofLookoutTile),
    ]);
    settle();
    expect(host.shown.single.single.text, RooftopsScript.gapLesson);
  });

  test('with the hook, nothing more is said once Mario has swung across: '
      'the line comes before the swing', () {
    director.onEvents(<WorldEvent>[
      TeleportedEvent(
        entityId: world.playerId,
        from: rooftopGapTile.step(Direction.north),
        to: world.grapples[rooftopGapTile]!.to,
        grappled: true,
      ),
    ]);
    settle();
    expect(host.shown, isEmpty);
    expect(RooftopsScript.grappleLine, 'Mario usa il rampino');
  });

  test('a door is no swing', () {
    director.onEvents(<WorldEvent>[
      TeleportedEvent(
        entityId: world.playerId,
        from: duomoPortalTile,
        to: world.portals[duomoPortalTile]!.to,
      ),
    ]);
    settle();
    expect(
      host.shown.expand((lines) => lines).map((line) => line.text),
      isNot(contains(RooftopsScript.grappleLine)),
    );
  });

  test('the grappling hook goes up among what Mario carries', () {
    director.onEvents(<WorldEvent>[
      pickedUp(grapplingHookPickupId, grapplingHook: true),
    ]);
    settle();
    expect(host.pickupAnimations, 1);
    expect(host.shown.single.map((line) => line.text), <String>[
      BackpacksScript.grapplingHookFound,
      BackpacksScript.grapplingHookLesson,
    ]);
    expect(host.unlocked, contains(HudElement.grapplingHook));
  });

  test('a round for the rocket launcher, without the launcher, says there '
      'is none, and puts up its badge', () {
    director.onEvents(<WorldEvent>[
      pickedUp(duomoFarTowerBackpackId, rockets: 1),
    ]);
    settle();
    expect(
      host.shown.single.single.text,
      'Hai trovato 1 colpo per lanciarazzi. Non hai un lanciarazzi',
    );
    expect(host.unlocked, contains(HudElement.rockets));
  });

  test('with the launcher, only what was found is said', () {
    world.player.component<AmmoComponent>().hasRocketLauncher = true;
    director.onEvents(<WorldEvent>[
      pickedUp(duomoFarTowerBackpackId, rockets: 1),
    ]);
    settle();
    expect(
      host.shown.single.single.text,
      'Hai trovato 1 colpo per lanciarazzi',
    );
    expect(
      BackpacksScript.rocketsFound(3, hasLauncher: true),
      'Hai trovato 3 colpi per lanciarazzi',
    );
  });

  test("landing on the Duomo's other tower raises nobody: its cultists "
      'are there from the start', () {
    final edge = duomoTowerLookoutTile;
    director.onEvents(<WorldEvent>[
      TeleportedEvent(
        entityId: world.playerId,
        from: edge.step(world.grapples[edge]!.facing.opposite),
        to: world.grapples[edge]!.to,
        grappled: true,
      ),
    ]);
    settle();
    expect(host.spawned, isEmpty);
  });

  group('the terraces, with the hook', () {
    TeleportedEvent swing(GridPoint edge) => TeleportedEvent(
      entityId: world.playerId,
      from: edge.step(world.grapples[edge]!.facing.opposite),
      to: world.grapples[edge]!.to,
      grappled: true,
    );

    void cross(GridPoint edge) {
      director.onEvents(<WorldEvent>[swing(edge)]);
      settle();
      while (host.isPromptVisible) {
        host.dismiss();
        settle();
      }
    }

    const mission = Mission.exploreTerraces;

    test('no mission without the hook, nor in Rome with it', () {
      settle();
      expect(progress.missions.isOpen(mission), isFalse);
      world.player.component<AmmoComponent>().grapplingHook = true;
      progress.travel(LevelId.rome, rounds: 0);
      settle();
      expect(progress.missions.isOpen(mission), isFalse);
      progress.travel(LevelId.hometown, rounds: 0);
      settle();
      expect(progress.missions.isOpen(mission), isTrue, reason: 'back home');
    });

    test('done once all three gaps are crossed, whichever way, in any '
        'order, and kept across a save', () {
      world.player.component<AmmoComponent>().grapplingHook = true;
      settle();
      expect(progress.missions.open, contains(mission));

      cross(hospitalNextRoofEdgeTile);
      cross(hospitalRoofLookoutTile);
      cross(duomoFarTowerEdgeTile);
      expect(progress.missions.isOpen(mission), isTrue, reason: 'two of three');

      // Through a save, as far as the two done.
      final saved = director.toJson();
      startStory();
      world.player.component<AmmoComponent>().grapplingHook = true;
      director.restore(saved);
      settle();
      expect(progress.missions.isOpen(mission), isTrue);

      cross(rooftopGapTile);
      expect(progress.missions.isDone(mission), isTrue);
      expect(progress.missions.isOpen(mission), isFalse);
    });

    test('the three crossings are the three gaps, each both ways', () {
      expect(hometownGrappleCrossings, hasLength(6));
      expect(hometownGrappleCrossings.values.toSet(), <String>{
        'airliner',
        'duomo',
        'hospital',
      });
    });
  });

  test("Molfetta's errands stay in Molfetta; the hook goes everywhere", () {
    expect(HudElement.duomoKey.level, LevelId.hometown);
    expect(HudElement.barKey.level, LevelId.hometown);
    expect(HudElement.incense.level, LevelId.hometown);
    expect(HudElement.episcopalRing.level, LevelId.hometown);
    expect(HudElement.grapplingHook.level, isNull);
    expect(HudElement.ammo.level, isNull);
    expect(HudElement.molotov.level, isNull);
    expect(HudElement.rockets.level, isNull);
  });

  test('a look anywhere else is no business of the rooftops script', () {
    director.onEvents(<WorldEvent>[const LookedOutEvent(at: GridPoint(0, 0))]);
    settle();
    expect(host.shown, isEmpty);
  });

  test('the zombie lesson follows its alert, the camera still', () {
    director
      ..onEvents(<WorldEvent>[
        AlertedEvent(entityId: tutorialZombieId, at: zombiePosition()),
      ])
      ..update(0.1, turnAnimating: false);
    expect(host.shown, hasLength(1), reason: 'straight away, no pan first');
    expect(host.wholeViews, 1, reason: 'a zoomed view is let go');
    final lines = host.shown.single;
    expect(lines.map((line) => line.text), <String>[
      zombieLore[EntityKind.wanderer]!.lesson,
      StreetScript.zombieSpotted,
    ]);
    expect(lines.first.portrait, zombieLore[EntityKind.wanderer]!.portrait);
    expect(lines.last.speaker, 'Mario Rossi', reason: 'he says it himself');
    expect(lines.last.portrait, isNotNull);
  });

  test('the first zombie is introduced as soon as Mario reaches the column '
      'before the zebra crossing, not before', () {
    final mario = world.player.component<PositionComponent>();
    host.visible.add(zombiePosition());
    director.update(0.1, turnAnimating: false);
    expect(host.shown, isEmpty, reason: 'in sight is not enough');
    mario.position = GridPoint(
      tutorialZombieLessonTrigger.left - 1,
      tutorialZombieLessonTrigger.top + 3,
    );
    director.update(0.1, turnAnimating: false);
    expect(host.shown, isEmpty, reason: 'one column short');
    mario.position = GridPoint(
      tutorialZombieLessonTrigger.left,
      tutorialZombieLessonTrigger.top + 3,
    );
    director.update(0.1, turnAnimating: false);
    expect(host.shown, hasLength(1), reason: 'no need to walk up to it');
    expect(host.shown.single.map((line) => line.text), <String>[
      zombieLore[EntityKind.wanderer]!.lesson,
      StreetScript.zombieSpotted,
    ]);
    host.dismiss();
    director
      ..onEvents(<WorldEvent>[
        AlertedEvent(entityId: tutorialZombieId, at: zombiePosition()),
      ])
      ..update(0.1, turnAnimating: false);
    expect(host.shown, hasLength(1), reason: 'its alert says nothing again');
  });

  test('the first zombie waits for the opening lines to be read', () {
    world.player.component<PositionComponent>().position = GridPoint(
      tutorialZombieLessonTrigger.left,
      tutorialZombieLessonTrigger.top + 3,
    );
    host.inPlay = false;
    director.update(0.1, turnAnimating: false);
    expect(host.shown, isEmpty);
    host.inPlay = true;
    director.update(0.1, turnAnimating: false);
    expect(host.shown, hasLength(1));
  });

  test('the first carabiniere to notice the player gets its own lesson', () {
    final zombies = <Entity>[
      for (final (index, spawn) in carabiniereSpawns.indexed)
        createCarabiniere('carabiniere-$index', spawn),
    ]..forEach(world.addEntity);
    AlertedEvent alert(Entity zombie) => AlertedEvent(
      entityId: zombie.id,
      at: zombie.component<PositionComponent>().position,
    );
    director.onEvents(<WorldEvent>[alert(zombies.first)]);
    expect(host.wholeViews, 1);
    settle();
    final line = host.shown.single.single;
    expect(line.text, zombieLore[EntityKind.carabiniere]!.lesson);
    expect(line.portrait, zombieLore[EntityKind.carabiniere]!.portrait);
    host.dismiss();

    director.onEvents(<WorldEvent>[alert(zombies.last)]);
    settle();
    expect(host.shown, hasLength(1), reason: 'only the first time');
  });

  test('a carabiniere that only heard Mario still gets its lesson', () {
    final zombie = createCarabiniere('carabiniere-0', carabiniereSpawns.first);
    world.addEntity(zombie);
    settle();
    expect(host.shown, isEmpty, reason: 'not aware of Mario yet');
    // Papers underfoot: it hears him and comes, with no alert raised.
    zombie.component<HearingComponent>().lastHeard = const GridPoint(0, 0);
    settle();
    expect(host.wholeViews, 1);
    expect(
      host.shown.single.single.text,
      zombieLore[EntityKind.carabiniere]!.lesson,
    );
  });

  test('the carabinieri in the hospital hordes never give the lesson', () {
    final hordes = world.entities.values
        .where((zombie) => zombie.kind == EntityKind.carabiniere)
        .toList();
    expect(hordes, isNotEmpty);
    for (final zombie in hordes) {
      zombie.component<HearingComponent>().lastHeard = const GridPoint(0, 0);
      host.visible.add(zombie.component<PositionComponent>().position);
    }
    director.onEvents(<WorldEvent>[
      AlertedEvent(
        entityId: hordes.first.id,
        at: hordes.first.component<PositionComponent>().position,
      ),
    ]);
    settle();
    expect(host.shown, isEmpty);
    expect(host.wholeViews, 0);
  });

  test('the zombie types met are recorded in the progress', () {
    expect(progress.knownZombies, isEmpty);
    director.onEvents(<WorldEvent>[
      AlertedEvent(entityId: tutorialZombieId, at: zombiePosition()),
    ]);
    expect(progress.knownZombies, <EntityKind>{EntityKind.wanderer});
    final inside = GridPoint(
      place(PlaceId.barracks).origin.x + 10,
      place(PlaceId.barracks).origin.y + 13,
    );
    for (var i = 0; i < BarracksScript.stepsBeforeCarabinieri; i++) {
      director.onEvents(<WorldEvent>[
        MovedEvent(entityId: world.playerId, from: inside, to: inside),
      ]);
    }
    expect(progress.knownZombies, <EntityKind>{
      EntityKind.wanderer,
      EntityKind.carabiniere,
    });
    // The wanderer's lesson is read first: a new type waits its turn.
    settle();
    host.dismiss();
    final sprinter = world.entities.values.firstWhere(
      (entity) => entity.kind == EntityKind.sprinter,
    );
    host.visible.add(sprinter.component<PositionComponent>().position);
    settle();
    expect(progress.knownZombies, contains(EntityKind.sprinter));
    final restored = Progress.fromJson(progress.toJson());
    expect(restored.knownZombies, progress.knownZombies);
  });

  test('only the rows along the railing slip past Luigi unheard', () {
    final firstFloor = place(PlaceId.mallFirst);
    final railing = firstFloor.rows.lastIndexWhere((row) => row.contains('w'));
    final lastFloorRow = firstFloor.origin.y + railing - 1;
    final column = luigiTile.x;

    // Every row of the corridor from the shutter down to the last two.
    for (var y = luigiSceneTrigger.top; y <= lastFloorRow; y++) {
      final dodging = y > lastFloorRow - luigiDodgeRows;
      expect(
        luigiSceneTrigger.contains(GridPoint(column, y)),
        !dodging,
        reason: 'row $y of ${lastFloorRow - luigiSceneTrigger.top + 1}',
      );
    }
    expect(
      lastFloorRow - luigiSceneTrigger.top + 1,
      greaterThan(luigiDodgeRows * 2),
      reason: 'the way around has to be the narrow one',
    );

    // And the way around is actually walkable, or it is no dodge at all.
    for (var y = lastFloorRow - luigiDodgeRows + 1; y <= lastFloorRow; y++) {
      expect(
        firstFloor.walkableRow(y - firstFloor.origin.y),
        contains(GridPoint(column, y)),
        reason: 'row $y is blocked in front of the shop',
      );
    }
  });

  test("Luigi's scene becomes a memory once played", () {
    expect(progress.memories, isEmpty);
    final trigger = luigiSceneTrigger;
    world.player.component<PositionComponent>().position = GridPoint(
      trigger.left + 1,
      trigger.top,
    );
    settle();
    expect(progress.memories, <StoryMemory>{StoryMemory.luigiTrapped});
  });

  test('prompts wait for the turn animation to finish', () {
    director.onEvents(<WorldEvent>[
      AlertedEvent(entityId: tutorialZombieId, at: zombiePosition()),
    ]);
    for (var i = 0; i < 20; i++) {
      director.update(0.1, turnAnimating: true);
    }
    expect(host.shown, isEmpty);
  });

  test('seeing the backpack teaches interaction and unlocks the button', () {
    settle();
    expect(host.shown, isEmpty, reason: 'not in view yet');
    host.visible.add(world.pickups[ammoBackpackId]!.position);
    settle();
    expect(host.shown.last.map((line) => line.text), <String>[
      BackpacksScript.backpackLesson,
      BackpacksScript.interactLesson,
    ]);
    expect(
      host.shown.last.last.demo,
      ControlDemo.interact,
      reason: 'taps are played beside the line about them',
    );
    expect(host.unlocked, isEmpty, reason: 'unlocked when the text closes');
    host.dismiss();
    expect(host.unlocked, <HudElement>{HudElement.interact});
  });

  test('"no pistol" is said only while the player has none', () {
    director.onEvents(<WorldEvent>[pickedUp(ammoBackpackId, ammo: 2)]);
    settle();
    expect(host.pickupAnimations, 1);
    expect(
      host.shown.last.single.text,
      'Hai trovato 2 proiettili. Non hai una pistola',
    );
    expect(host.unlocked, contains(HudElement.ammo));
    host.dismiss();

    world.player.component<AmmoComponent>().hasGun = true;
    director.onEvents(<WorldEvent>[pickedUp(accidentBackpackId, ammo: 4)]);
    settle();
    expect(host.shown.last.single.text, 'Hai trovato 4 proiettili');
  });

  test('the incense says so and hangs the censer on the HUD', () {
    director.onEvents(<WorldEvent>[pickedUp(incenseBackpackId, incense: true)]);
    settle();
    expect(host.pickupAnimations, 1);
    expect(host.shown.last.single.text, BackpacksScript.incenseFound);
    expect(
      host.unlocked,
      contains(HudElement.incense),
      reason: 'the badge goes up with the news, not after it',
    );
    host.dismiss();
    expect(
      host.unlocked,
      isNot(contains(HudElement.ammo)),
      reason: 'the backpack held no rounds to count',
    );
  });

  test('the pistol unlocks shooting', () {
    director.onEvents(<WorldEvent>[pickedUp(gunBackpackId, gun: true)]);
    settle();
    expect(host.shown.last.map((line) => line.text), <String>[
      BackpacksScript.gunFound,
      BackpacksScript.aimLesson,
      BackpacksScript.fireLesson,
      BackpacksScript.cancelLesson,
    ]);
    expect(host.shown.last.map((line) => line.demo), <ControlDemo?>[
      null,
      ControlDemo.aim,
      ControlDemo.aim,
      ControlDemo.cancelShot,
    ]);
    expect(host.unlocked, isNot(contains(HudElement.shoot)));
    host.dismiss();
    expect(host.unlocked, contains(HudElement.shoot));
  });
}
