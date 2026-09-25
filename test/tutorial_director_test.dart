import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/game/zombie_lore.dart';

final class _FakeHost implements TutorialHost {
  final Set<GridPoint> visible = <GridPoint>{};
  final Set<HudElement> unlocked = <HudElement>{};
  final List<List<TutorialLine>> shown = <List<TutorialLine>>[];
  final List<Entity> spawned = <Entity>[];
  void Function()? _onDismissed;
  int pickupAnimations = 0;
  String? focus;

  @override
  bool isPromptVisible = false;

  /// How many times a queued prompt has held Mario still.
  int stops = 0;

  @override
  void stopWalking() => stops++;

  @override
  bool isTileVisible(GridPoint tile) => visible.contains(tile);

  @override
  void showPrompt(List<TutorialLine> lines, {void Function()? onDismissed}) {
    shown.add(lines);
    isPromptVisible = true;
    _onDismissed = onDismissed;
  }

  void dismiss() {
    isPromptVisible = false;
    _onDismissed?.call();
    _onDismissed = null;
  }

  @override
  void playPickupAnimation() => pickupAnimations++;

  @override
  void focusOn(String? entityId) => focus = entityId;

  @override
  void spawnZombie(Entity zombie) => spawned.add(zombie);

  final List<String> killed = <String>[];

  @override
  void killZombies(Iterable<String> zombieIds) => killed.addAll(zombieIds);

  @override
  void unlock(HudElement element) => unlocked.add(element);

  @override
  void removeHud(HudElement element) => unlocked.remove(element);

  int duomoOpenings = 0;
  int duomoUpperOpenings = 0;
  int cultistRobesCollected = 0;

  @override
  void openDuomo() => duomoOpenings++;

  @override
  void openDuomoUpper() => duomoUpperOpenings++;

  @override
  void collectCultistRobe() => cultistRobesCollected++;

  int duomoMassacres = 0;

  @override
  void startDuomoMassacre() => duomoMassacres++;

  @override
  bool isUnlocked(HudElement element) => unlocked.contains(element);

  final List<List<CutsceneFrame>> cutscenes = <List<CutsceneFrame>>[];
  void Function()? onCutsceneFinished;
  bool cutsceneStaysBlack = false;
  int levelsCompleted = 0;
  int travelMapsOpened = 0;

  @override
  void playCutscene(
    List<CutsceneFrame> frames, {
    void Function()? onFinished,
    bool stayBlack = false,
  }) {
    cutscenes.add(frames);
    onCutsceneFinished = onFinished;
    cutsceneStaysBlack = stayBlack;
  }

  @override
  void completeLevel() => levelsCompleted++;

  @override
  void openTravelMap() => travelMapsOpened++;

  int zombieBooksOpened = 0;
  int memoriesReplayed = 0;

  @override
  void openZombieBook() => zombieBooksOpened++;

  @override
  void replayMemories() => memoriesReplayed++;

  int luigiSent = 0;

  @override
  void sendLuigiAway({void Function()? onFinished}) {
    luigiSent++;
    onFinished?.call();
  }
}

void main() {
  late WorldState world;
  late _FakeHost host;
  late TutorialDirector director;
  late Progress progress;

  GridPoint zombiePosition() =>
      world.entities[tutorialZombieId]!.component<PositionComponent>().position;

  /// Runs the director long enough for any queued delay to elapse.
  void settle() {
    for (var i = 0; i < 20; i++) {
      director.update(0.1, turnAnimating: false);
    }
  }

  PickedUpEvent pickedUp(
    String id, {
    int ammo = 0,
    bool gun = false,
    bool incense = false,
    bool episcopalRing = false,
    bool cultistRobe = false,
    bool duomoKey = false,
  }) => PickedUpEvent(
    pickupId: id,
    at: world.pickups[id]!.position,
    ammo: ammo,
    gun: gun,
    incense: incense,
    episcopalRing: episcopalRing,
    cultistRobe: cultistRobe,
    duomoKey: duomoKey,
  );

  setUp(() {
    world = createTutorialWorld();
    host = _FakeHost();
    progress = Progress();
    director = TutorialDirector(world: world, host: host, progress: progress);
  });

  test('a queued prompt stops Mario and counts down while he still walks', () {
    director.queue(
      TutorialPrompt(<TutorialLine>[
        const TutorialLine('Ecco'),
      ], delay: TutorialDirector.reactionDelay),
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
    expect(host.cutscenes.single, hasLength(2));
    expect(host.cutscenes.single.first.image, DuomoScript.initiationImage);
    expect(host.cutscenes.single.first.text, DuomoScript.familyWelcomeLine);
    expect(host.cutscenes.single.last.text, DuomoScript.robeLine);
    expect(progress.memories, contains(StoryMemory.priestFamily));

    host.onCutsceneFinished?.call();
    expect(host.unlocked, isNot(contains(HudElement.episcopalRing)));
    expect(host.duomoUpperOpenings, 1);

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
    host.onCutsceneFinished?.call();
    expect(host.duomoMassacres, 1);

    // Nobody is left in it to answer.
    director.onEvents(<WorldEvent>[
      NoInteractionEvent(duomoPriestTile),
      NoInteractionEvent(duomoWelcomingCultistTile),
    ]);
    settle();
    expect(host.shown, isEmpty);
  });

  test('a save from before the massacre plays only what it has not seen', () {
    // As such a save comes back: the ring handed over, the mass among the
    // memories, the robe on, and nothing said about a massacre.
    director.restore(<String, Object?>{
      'duomo': <String, Object?>{'ringDelivered': true},
    });
    progress
      ..remember(StoryMemory.priestMass)
      ..unlockOutfit(PlayerOutfit.cultist)
      ..wearOutfit(PlayerOutfit.cultist);
    world.player.component<PositionComponent>().position = duomoStairEntryTile;

    settle();

    expect(host.cutscenes.single, DuomoScript.massacreScene);
    expect(progress.memories, contains(StoryMemory.priestMassacre));
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

  test('a look anywhere else is no business of the rooftops script', () {
    director.onEvents(<WorldEvent>[const LookedOutEvent(at: GridPoint(0, 0))]);
    settle();
    expect(host.shown, isEmpty);
  });

  test('the zombie lesson follows its alert, framing the zombie', () {
    director
      ..onEvents(<WorldEvent>[
        AlertedEvent(entityId: tutorialZombieId, at: zombiePosition()),
      ])
      ..update(0.1, turnAnimating: false);
    expect(host.shown, isEmpty, reason: 'the balloon shows first');
    expect(host.focus, tutorialZombieId);
    settle();
    expect(
      host.shown.single.single.text,
      zombieLore[EntityKind.wanderer]!.lesson,
    );
    expect(
      host.shown.single.single.portrait,
      zombieLore[EntityKind.wanderer]!.portrait,
    );
    host.dismiss();
    expect(host.focus, isNull);
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
    expect(host.focus, zombies.first.id);
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
    expect(host.focus, zombie.id);
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
    expect(host.focus, isNull);
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
      BackpacksScript.shootLesson,
    ]);
    expect(host.unlocked, isNot(contains(HudElement.shoot)));
    host.dismiss();
    expect(host.unlocked, contains(HudElement.shoot));
  });

  test('Mario speaks when he reaches the barracks', () {
    world.player.component<PositionComponent>().position = const GridPoint(
      16,
      7,
    );
    settle();
    final lines = host.shown.single;
    expect(lines.map((line) => line.text), <String>[
      BarracksScript.barracksReached,
      BarracksScript.barracksSafe,
    ]);
    expect(lines.every((line) => line.speaker == 'Mario Rossi'), isTrue);
    expect(lines.first.portrait, isNotNull);
  });

  test('a few steps inside, the carabinieri come out of the dark', () {
    final inside = GridPoint(
      place(PlaceId.barracks).origin.x + 10,
      place(PlaceId.barracks).origin.y + 13,
    );
    MovedEvent step() => MovedEvent(
      entityId: world.playerId,
      from: inside.step(Direction.south),
      to: inside,
    );
    for (var i = 1; i < BarracksScript.stepsBeforeCarabinieri; i++) {
      director.onEvents(<WorldEvent>[step()]);
    }
    expect(host.spawned, isEmpty);
    director.onEvents(<WorldEvent>[step()]);
    expect(host.spawned, hasLength(carabiniereSpawns.length));
    expect(
      host.spawned.every((zombie) => zombie.kind == EntityKind.carabiniere),
      isTrue,
    );
    director.onEvents(<WorldEvent>[step()]);
    expect(host.spawned, hasLength(carabiniereSpawns.length));
  });

  test('steps outside do not count', () {
    for (var i = 0; i < 10; i++) {
      director.onEvents(<WorldEvent>[
        MovedEvent(
          entityId: world.playerId,
          from: const GridPoint(7, 36),
          to: const GridPoint(8, 36),
        ),
      ]);
    }
    expect(host.spawned, isEmpty);
  });

  test('the accident backpack teaches interaction if it is seen first', () {
    host.visible.add(world.pickups[accidentBackpackId]!.position);
    settle();
    expect(host.shown.single.map((line) => line.text), <String>[
      BackpacksScript.backpackLesson,
      BackpacksScript.interactLesson,
    ]);
    host
      ..dismiss()
      ..visible.add(world.pickups[ammoBackpackId]!.position);
    settle();
    expect(host.shown, hasLength(1), reason: 'taught only once');
    expect(host.unlocked, contains(HudElement.interact));
  });

  test('hints have no speaker; only people are named', () {
    host.visible.add(world.pickups[ammoBackpackId]!.position);
    settle();
    expect(host.shown.single.every((line) => line.speaker == null), isTrue);
  });

  test('the first camp teaches saving, with the button if still missing', () {
    host.visible.add(
      world.campfires.firstWhere(place(PlaceId.northDistrict).bounds.contains),
    );
    settle();
    expect(host.shown.single.map((line) => line.text), <String>[
      NorthDistrictScript.campLesson,
      BackpacksScript.interactLesson,
    ]);
    host.dismiss();
    expect(host.unlocked, contains(HudElement.interact));
  });

  test('a player who already interacts only hears about the camps', () {
    host
      ..unlocked.add(HudElement.interact)
      ..visible.add(
        world.campfires.firstWhere(
          place(PlaceId.northDistrict).bounds.contains,
        ),
      );
    settle();
    expect(host.shown.single.single.text, NorthDistrictScript.campLesson);
  });

  test('its progress survives a save', () {
    director.onEvents(<WorldEvent>[
      AlertedEvent(entityId: tutorialZombieId, at: zombiePosition()),
    ]);
    final saved = director.toJson();
    final restored = TutorialDirector(
      world: world,
      host: _FakeHost(),
      progress: Progress(),
    )..restore(saved);
    expect(restored.toJson(), saved);
    expect((saved['street']! as Map<String, Object?>)['zombieLesson'], isTrue);
  });

  test('the first sprinter in sight is framed and its pace explained', () {
    final sprinter = world.entities.values.firstWhere(
      (entity) => entity.kind == EntityKind.sprinter,
    );
    final at = sprinter.component<PositionComponent>().position;
    settle();
    expect(host.shown, isEmpty);
    host.visible.add(at);
    settle();
    expect(host.focus, sprinter.id);
    final line = host.shown.single.single;
    expect(line.text, zombieLore[EntityKind.sprinter]!.lesson);
    expect(line.portrait, zombieLore[EntityKind.sprinter]!.portrait);
    expect(line.speaker, isNull);
    host.dismiss();
    expect(host.focus, isNull);
    settle();
    expect(host.shown, hasLength(1), reason: 'the lesson is given once');
  });

  group('zombie discovery', () {
    List<Entity> mutilated() => world.entities.values
        .where((entity) => entity.kind == EntityKind.mutilated)
        .toList();

    GridPoint at(Entity zombie) =>
        zombie.component<PositionComponent>().position;

    test('the first mutilated in sight is framed, introduced with its '
        'portrait and entered in the book', () {
      final zombies = mutilated();
      expect(zombies, isNotEmpty);
      settle();
      expect(host.shown, isEmpty, reason: 'none is on screen yet');
      expect(progress.knownZombies, isNot(contains(EntityKind.mutilated)));

      host.visible.add(at(zombies.first));
      director.update(0.1, turnAnimating: false);
      expect(host.focus, zombies.first.id);
      expect(progress.knownZombies, contains(EntityKind.mutilated));
      expect(host.shown, isEmpty, reason: 'the camera pans first');
      settle();
      final line = host.shown.single.single;
      expect(line.text, zombieLore[EntityKind.mutilated]!.lesson);
      expect(line.portrait, zombieLore[EntityKind.mutilated]!.portrait);
      expect(line.speaker, isNull);
      host.dismiss();
      expect(host.focus, isNull);

      // The others in sight later say nothing more.
      host.visible.addAll(zombies.map(at));
      settle();
      expect(host.shown, hasLength(1), reason: 'the lesson is given once');
    });

    test('the burning zombie on the roofs is introduced when first seen', () {
      final zombie = world.entities[rooftopBurningZombieId]!;
      host.visible.add(at(zombie));
      settle();
      expect(host.focus, zombie.id);
      expect(progress.knownZombies, contains(EntityKind.burning));
      final line = host.shown.single.single;
      expect(line.text, zombieLore[EntityKind.burning]!.lesson);
      expect(line.portrait, zombieLore[EntityKind.burning]!.portrait);
    });

    test('the drunk in the Bar Arcobaleno is introduced when first seen', () {
      final zombie = world.entities[barDrunkZombieId]!;
      expect(zombie.kind, EntityKind.drunk);
      expect(place(PlaceId.barArcobaleno).bounds.contains(at(zombie)), isTrue);
      host.visible.add(at(zombie));
      settle();
      expect(host.focus, zombie.id);
      expect(progress.knownZombies, contains(EntityKind.drunk));
      final line = host.shown.single.single;
      expect(line.text, zombieLore[EntityKind.drunk]!.lesson);
      expect(line.portrait, zombieLore[EntityKind.drunk]!.portrait);
    });

    test('a dead one is no introduction', () {
      final zombie = mutilated().first;
      zombie.component<HealthComponent>().current = 0;
      host.visible.add(at(zombie));
      settle();
      expect(host.shown, isEmpty);
      expect(progress.knownZombies, isNot(contains(EntityKind.mutilated)));
    });

    test('a type met before, in this level or another, is not introduced '
        'again', () {
      final known = TutorialDirector(
        world: world,
        host: host,
        progress: Progress(knownZombies: <EntityKind>[EntityKind.mutilated]),
      );
      host.visible.add(at(mutilated().first));
      for (var i = 0; i < 20; i++) {
        known.update(0.1, turnAnimating: false);
      }
      expect(host.shown, isEmpty);
      expect(host.focus, isNull);
    });

    test('it survives a save through the progress, not the tutorial', () {
      host.visible.add(at(mutilated().first));
      settle();
      host.dismiss();
      final restored = TutorialDirector(
        world: world,
        host: host,
        progress: Progress.fromJson(progress.toJson()),
      )..restore(director.toJson());
      for (var i = 0; i < 20; i++) {
        restored.update(0.1, turnAnimating: false);
      }
      expect(host.shown, hasLength(1));
    });

    test('two new types in sight at once are introduced one after the '
        'other, each framed in turn', () {
      final sprinter = world.entities.values.firstWhere(
        (entity) => entity.kind == EntityKind.sprinter,
      );
      final zombie = mutilated().first;
      host.visible
        ..add(at(sprinter))
        ..add(at(zombie));
      settle();
      expect(host.shown, hasLength(1));
      final first = host.focus;
      host.dismiss();
      settle();
      expect(host.shown, hasLength(2));
      expect(host.focus, isNot(first));
      expect(<String?>{first, host.focus}, <String>{sprinter.id, zombie.id});
      expect(
        <String>{for (final lines in host.shown) lines.single.text},
        <String>{
          zombieLore[EntityKind.sprinter]!.lesson,
          zombieLore[EntityKind.mutilated]!.lesson,
        },
      );
    });

    test('a new type waits for what is being said to be over', () {
      host.showPrompt(const <TutorialLine>[TutorialLine('...')]);
      host.visible.add(at(mutilated().first));
      settle();
      expect(host.focus, isNull, reason: 'the camera stays on Mario');
      expect(progress.knownZombies, isNot(contains(EntityKind.mutilated)));
      host.dismiss();
      settle();
      expect(
        host.shown.last.single.text,
        zombieLore[EntityKind.mutilated]!.lesson,
      );
    });

    test('every zombie type the game places has its lore', () {
      final kinds = <EntityKind>{
        for (final entity in world.entities.values)
          if (entity.kind != EntityKind.player) entity.kind,
        // The barracks' carabinieri come out of the dark later.
        EntityKind.carabiniere,
      };
      for (final kind in kinds) {
        final lore = zombieLore[kind];
        expect(lore, isNotNull, reason: '$kind has no lore');
        expect(lore!.lesson, isNotEmpty, reason: '$kind');
        expect(lore.description, isNotEmpty, reason: '$kind');
        expect(lore.portrait, startsWith('assets/story/portrait_'));
      }
    });
  });

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
      expect(reunion.map((frame) => frame.speaker), <String>[
        MallScript.luigi,
        'Mario Rossi',
        MallScript.luigi,
      ]);
      expect(progress.memories, contains(StoryMemory.luigiRescued));

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
      host.dismiss();
      expect(host.luigiSent, 1);
    });
  });

  group('station', () {
    /// The far platform, in front of the train Luigi is waiting in.
    GridPoint onTheFarPlatform() => GridPoint(
      (stationPlatform.left + stationPlatform.right) ~/ 2,
      stationPlatform.bottom,
    );

    void takeAPlatformStep() {
      final to = onTheFarPlatform();
      world.player.component<PositionComponent>().position = to;
      director.onEvents(<WorldEvent>[
        MovedEvent(
          entityId: world.playerId,
          from: to.step(Direction.west),
          to: to,
        ),
      ]);
      settle();
    }

    test('after Luigi is rescued, his meeting waits for the first step', () {
      progress.remember(StoryMemory.luigiRescued);
      world.player.component<PositionComponent>().position = onTheFarPlatform();
      settle();
      expect(
        host.cutscenes,
        isEmpty,
        reason: 'arriving through the stairs leaves time to see the map',
      );

      takeAPlatformStep();
      expect(host.shown, isEmpty, reason: 'the picture comes first');
      final scene = host.cutscenes.single;
      expect(scene, StationScript.reunionScene);
      expect(scene, hasLength(6));
      final frame = scene.first;
      expect(frame.speaker, StationScript.luigi);
      expect(frame.text, "Eccoti ragazzo, ce l'hai fatta finalmente!");
      expect(frame.image, StationScript.platformScene);
      expect(scene[1].image, StationScript.planScene);
      expect(scene[4].text, 'La nostra meta é Capo Nord ragazzo. In Norvegia');
      expect(scene[4].image, StationScript.northCapeScene);
      expect(
        host.cutsceneStaysBlack,
        isTrue,
        reason: 'the level ends behind it, not back on the platform',
      );
      expect(progress.memories, contains(StoryMemory.luigiAtStation));
      expect(host.levelsCompleted, 0, reason: 'not before the scene is over');

      host.onCutsceneFinished?.call();
      expect(host.levelsCompleted, 1);
      final mario = world.player.component<PositionComponent>();
      expect(
        mario.position,
        trainMapStandTile,
        reason: 'the save, and the way back home, find him at the map',
      );
      expect(mario.facing, Direction.south);
      expect(mario.position.step(mario.facing), trainMapPanelTile);
      director.onEvents(<WorldEvent>[
        TravelMapUsedEvent(at: trainMapTiles.last),
      ]);
      expect(host.travelMapsOpened, 1);
      expect(host.levelsCompleted, 1);
      settle();
      expect(
        host.cutscenes,
        hasLength(1),
        reason: 'walking the platform again does not play it twice',
      );
    });

    test('aboard, Luigi talks, the books hold the zombie types and the '
        'cot the memories, as often as asked', () {
      for (var i = 0; i < 2; i++) {
        director.onEvents(<WorldEvent>[LookedOutEvent(at: trainLuigiTile)]);
        settle();
        final line = host.shown.last.single;
        expect(line.speaker, 'Luigi Rovaga');
        expect(line.portrait, 'assets/story/portrait_luigi.png');
        expect(line.text, "Sarà un viaggio per l'Europa molto impegnativo");
        host.dismiss();
      }
      expect(host.shown, hasLength(2));

      for (final book in trainBookTiles) {
        director.onEvents(<WorldEvent>[LookedOutEvent(at: book)]);
      }
      expect(host.zombieBooksOpened, trainBookTiles.length);
      for (final cot in trainCotTiles) {
        director.onEvents(<WorldEvent>[LookedOutEvent(at: cot)]);
      }
      expect(host.memoriesReplayed, trainCotTiles.length);
      expect(host.shown, hasLength(2), reason: 'neither says anything');
    });

    test('the meeting cannot happen before Luigi has been rescued', () {
      takeAPlatformStep();
      expect(host.cutscenes, isEmpty);
      expect(progress.memories, isNot(contains(StoryMemory.luigiAtStation)));
      director.onEvents(<WorldEvent>[
        TravelMapUsedEvent(at: trainMapPanelTile),
      ]);
      expect(host.travelMapsOpened, 0);
      expect(host.levelsCompleted, 0);
    });

    test('nothing plays anywhere short of that platform', () {
      progress.remember(StoryMemory.luigiRescued);
      world.player.component<PositionComponent>().position = place(
        PlaceId.station,
      ).doorRow('E').first;
      settle();
      expect(host.cutscenes, isEmpty);
      expect(progress.memories, isNot(contains(StoryMemory.luigiAtStation)));
    });

    test('a save taken after it does not play it again on the way back', () {
      progress.remember(StoryMemory.luigiRescued);
      takeAPlatformStep();
      expect(host.cutscenes, hasLength(1));

      final resumed = TutorialDirector(
        world: world,
        host: host,
        progress: progress,
      )..restore(director.toJson());
      for (var i = 0; i < 20; i++) {
        resumed.update(0.1, turnAnimating: false);
      }
      expect(host.cutscenes, hasLength(1));
    });
  });

  group('Duomo', () {
    void walkTo(GridPoint to) =>
        world.player.component<PositionComponent>().position = to;

    /// The seafront road right in front of the churchyard alley.
    GridPoint onTheSeafront() =>
        GridPoint(priestGateFront.left + 1, priestSceneTrigger.bottom - 1);

    /// In the alley, right at the gate.
    GridPoint atTheGate() =>
        GridPoint(priestGateFront.left + 1, priestGateFront.bottom);

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
        host.dismiss();
        expect(priest.errandGiven, isTrue);
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
      host.dismiss();
      settle();
      expect(
        host.shown,
        hasLength(warnings),
        reason: 'standing still does not reopen the same box',
      );

      walkTo(onTheSeafront());
      settle();
      walkTo(atTheGate());
      settle();
      expect(host.shown, hasLength(warnings + 1), reason: 'a new visit warns');

      host.dismiss();
      nearbyZombie.component<HealthComponent>().current = 0;
      settle();
      expect(host.cutscenes.last, PriestScript.welcomeScene);
    });

    test('a save after the welcome does not play it again', () {
      acceptIncenseErrand();
      collectIncense();
      walkTo(atTheGate());
      settle();
      final saved = director.toJson();

      host = _FakeHost()..unlock(HudElement.incense);
      director = TutorialDirector(world: world, host: host, progress: progress)
        ..restore(saved);
      settle();

      expect(host.cutscenes, isEmpty);
      expect(progress.memories, contains(StoryMemory.priestWelcomed));
    });

    test('a save between the two halves resumes where the priest left off', () {
      meetThePriest();
      // Resting at a camp and loading again: a new director, restored.
      final saved = director.toJson();
      final resumed = TutorialDirector(
        world: world,
        host: host = _FakeHost(),
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
}
