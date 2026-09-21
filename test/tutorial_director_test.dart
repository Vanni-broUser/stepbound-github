import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
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

  @override
  void unlock(HudElement element) => unlocked.add(element);

  @override
  bool isUnlocked(HudElement element) => unlocked.contains(element);
}

void main() {
  late WorldState world;
  late _FakeHost host;
  late TutorialDirector director;

  GridPoint zombiePosition() =>
      world.entities[tutorialZombieId]!.component<PositionComponent>().position;

  /// Runs the director long enough for any queued delay to elapse.
  void settle() {
    for (var i = 0; i < 20; i++) {
      director.update(0.1, turnAnimating: false);
    }
  }

  PickedUpEvent pickedUp(String id, {int ammo = 0, bool gun = false}) =>
      PickedUpEvent(
        pickupId: id,
        at: world.pickups[id]!.position,
        ammo: ammo,
        gun: gun,
      );

  setUp(() {
    world = createStreetWorld();
    host = _FakeHost();
    director = TutorialDirector(world: world, host: host);
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
    expect(host.shown.single.single.text, TutorialDirector.zombieLesson);
    expect(
      host.shown.single.single.portrait,
      TutorialDirector.wandererPortrait,
    );
    host.dismiss();
    expect(host.focus, isNull);
  });

  test('the first carabiniere to notice the player gets its own lesson', () {
    final zombies = <Entity>[
      for (final (index, spawn) in carabiniereSpawns().indexed)
        createCarabiniere('carabiniere-$index', spawn),
    ];
    for (final zombie in zombies) {
      world.entities[zombie.id] = zombie;
    }
    AlertedEvent alert(Entity zombie) => AlertedEvent(
      entityId: zombie.id,
      at: zombie.component<PositionComponent>().position,
    );
    director.onEvents(<WorldEvent>[alert(zombies.first)]);
    expect(host.focus, zombies.first.id);
    settle();
    final line = host.shown.single.single;
    expect(line.text, TutorialDirector.carabiniereLesson);
    expect(line.portrait, TutorialDirector.carabinierePortrait);
    host.dismiss();

    director.onEvents(<WorldEvent>[alert(zombies.last)]);
    settle();
    expect(host.shown, hasLength(1), reason: 'only the first time');
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
      TutorialDirector.backpackLesson,
      TutorialDirector.interactLesson,
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

  test('the pistol unlocks shooting', () {
    director.onEvents(<WorldEvent>[pickedUp(gunBackpackId, gun: true)]);
    settle();
    expect(host.shown.last.map((line) => line.text), <String>[
      TutorialDirector.gunFound,
      TutorialDirector.shootLesson,
    ]);
    expect(host.unlocked, isNot(contains(HudElement.shoot)));
    host.dismiss();
    expect(host.unlocked, contains(HudElement.shoot));
  });

  test('Mario speaks when he reaches the barracks', () {
    world.player.component<PositionComponent>().position = const GridPoint(
      16,
      17,
    );
    settle();
    final lines = host.shown.single;
    expect(lines.map((line) => line.text), <String>[
      TutorialDirector.barracksReached,
      TutorialDirector.barracksSafe,
    ]);
    expect(lines.every((line) => line.speaker == 'Mario Rossi'), isTrue);
    expect(lines.first.portrait, isNotNull);
  });

  test('a few steps inside, the carabinieri come out of the dark', () {
    final inside = GridPoint(barracksOrigin.x + 10, barracksOrigin.y + 13);
    MovedEvent step() => MovedEvent(
      entityId: world.playerId,
      from: inside.step(Direction.south),
      to: inside,
    );
    for (var i = 1; i < TutorialDirector.stepsBeforeCarabinieri; i++) {
      director.onEvents(<WorldEvent>[step()]);
    }
    expect(host.spawned, isEmpty);
    director.onEvents(<WorldEvent>[step()]);
    expect(host.spawned, hasLength(carabiniereSpawns().length));
    expect(
      host.spawned.every((zombie) => zombie.kind == EntityKind.carabiniere),
      isTrue,
    );
    director.onEvents(<WorldEvent>[step()]);
    expect(host.spawned, hasLength(carabiniereSpawns().length));
  });

  test('steps outside do not count', () {
    for (var i = 0; i < 10; i++) {
      director.onEvents(<WorldEvent>[
        MovedEvent(
          entityId: world.playerId,
          from: const GridPoint(7, 46),
          to: const GridPoint(8, 46),
        ),
      ]);
    }
    expect(host.spawned, isEmpty);
  });

  test('the accident backpack teaches interaction if it is seen first', () {
    host.visible.add(world.pickups[accidentBackpackId]!.position);
    settle();
    expect(host.shown.single.map((line) => line.text), <String>[
      TutorialDirector.backpackLesson,
      TutorialDirector.interactLesson,
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
    host.visible.add(world.campfires.single);
    settle();
    expect(host.shown.single.map((line) => line.text), <String>[
      TutorialDirector.campLesson,
      TutorialDirector.interactLesson,
    ]);
    host.dismiss();
    expect(host.unlocked, contains(HudElement.interact));
  });

  test('a player who already interacts only hears about the camps', () {
    host
      ..unlocked.add(HudElement.interact)
      ..visible.add(world.campfires.single);
    settle();
    expect(host.shown.single.single.text, TutorialDirector.campLesson);
  });

  test('its progress survives a save', () {
    director.onEvents(<WorldEvent>[
      AlertedEvent(entityId: tutorialZombieId, at: zombiePosition()),
    ]);
    final saved = director.toJson();
    final restored = TutorialDirector(world: world, host: _FakeHost())
      ..restore(saved);
    expect(restored.toJson(), saved);
    expect(saved['zombieLesson'], isTrue);
  });
}
