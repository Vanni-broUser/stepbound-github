import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

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
  bool isUnlocked(HudElement element) => unlocked.contains(element);

  final List<List<CutsceneFrame>> cutscenes = <List<CutsceneFrame>>[];
  void Function()? onCutsceneFinished;

  @override
  void playCutscene(List<CutsceneFrame> frames, {void Function()? onFinished}) {
    cutscenes.add(frames);
    onCutsceneFinished = onFinished;
  }

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
  }) => PickedUpEvent(
    pickupId: id,
    at: world.pickups[id]!.position,
    ammo: ammo,
    gun: gun,
    incense: incense,
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

  test('the zombie lesson follows its alert, framing the zombie', () {
    director
      ..onEvents(<WorldEvent>[
        AlertedEvent(entityId: tutorialZombieId, at: zombiePosition()),
      ])
      ..update(0.1, turnAnimating: false);
    expect(host.shown, isEmpty, reason: 'the balloon shows first');
    expect(host.focus, tutorialZombieId);
    settle();
    expect(host.shown.single.single.text, StreetScript.zombieLesson);
    expect(host.shown.single.single.portrait, StreetScript.wandererPortrait);
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
    expect(line.text, BarracksScript.carabiniereLesson);
    expect(line.portrait, BarracksScript.carabinierePortrait);
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
    expect(host.shown.single.single.text, BarracksScript.carabiniereLesson);
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
    expect(line.text, NorthDistrictScript.sprinterLesson);
    expect(line.portrait, NorthDistrictScript.sprinterPortrait);
    expect(line.speaker, isNull);
    host.dismiss();
    expect(host.focus, isNull);
    settle();
    expect(host.shown, hasLength(1), reason: 'the lesson is given once');
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

    test('coming up onto the far platform plays the meeting with Luigi', () {
      world.player.component<PositionComponent>().position = onTheFarPlatform();
      settle();
      expect(host.shown, isEmpty, reason: 'the picture comes first');
      final frame = host.cutscenes.single.single;
      expect(frame.speaker, StationScript.luigi);
      expect(frame.text, "Eccoti ragazzo, ce l'hai fatta finalmente!");
      expect(frame.image, StationScript.platformScene);
      expect(progress.memories, contains(StoryMemory.luigiAtStation));

      host.onCutsceneFinished?.call();
      settle();
      expect(
        host.cutscenes,
        hasLength(1),
        reason: 'walking the platform again does not play it twice',
      );
    });

    test('nothing plays anywhere short of that platform', () {
      world.player.component<PositionComponent>().position = place(
        PlaceId.station,
      ).doorRow('E').first;
      settle();
      expect(host.cutscenes, isEmpty);
      expect(progress.memories, isEmpty);
    });

    test('a save taken after it does not play it again on the way back', () {
      world.player.component<PositionComponent>().position = onTheFarPlatform();
      settle();
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
