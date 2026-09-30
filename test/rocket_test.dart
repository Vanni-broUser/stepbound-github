import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/anim/turn_presentation_controller.dart';
import 'package:stepbound/game/input/game_input_controller.dart';
import 'package:stepbound/game/render/rocket_component.dart';
import 'package:stepbound/game/story/story_director.dart';

/// A corridor 15 tiles long with Mario at its west end facing east, the
/// launcher on his shoulder unless [launcher] is false, [rockets] rounds
/// for it and [loaded] for the pistol; zombies where told. A wreck stands
/// in the middle of the corridor, and a closed door at its east end
/// shuts off the last tile.
WorldState _corridor({
  bool launcher = true,
  int rockets = 2,
  int loaded = 1,
  List<(String, GridPoint, EntityKind)> zombies =
      const <(String, GridPoint, EntityKind)>[],
  List<Pickup> pickups = const <Pickup>[],
}) {
  final factory = EntityFactory(BalanceConfig.standard());
  final world = WorldState(
    map: TileMap.fromAscii(const <String>[
      '###############',
      '#......o....+.#',
      '###############',
    ]),
    entities: <Entity>[
      factory.player(id: 'player', position: const GridPoint(1, 1)),
      for (final (id, at, kind) in zombies)
        factory.zombie(id: id, kind: kind, position: at),
    ],
    playerId: 'player',
    random: SeededRandom(5),
    pickups: pickups,
  );
  world.player.component<AmmoComponent>()
    ..hasRocketLauncher = launcher
    ..rockets = rockets
    ..loaded = loaded;
  world.player.component<PositionComponent>().facing = Direction.east;
  return world;
}

final class _Harness {
  _Harness({bool launcher = true, int rockets = 2})
    : world = _corridor(launcher: launcher, rockets: rockets) {
    input = GameInputController(
      world: world,
      canAct: () => true,
      ignoresKeys: () => false,
      isUnlocked: unlocked.contains,
      submit: submitted.add,
      dropQueuedSteps: () {},
      toggleDebug: () {},
      throwArea: () => null,
    );
  }

  final WorldState world;
  final List<PlayerAction> submitted = <PlayerAction>[];
  final Set<HudElement> unlocked = <HudElement>{
    HudElement.interact,
    HudElement.shoot,
    HudElement.molotov,
    HudElement.rockets,
  };
  late final GameInputController input;

  AmmoComponent get ammo => world.player.component<AmmoComponent>();
}

void main() {
  group('FireRocketAction', () {
    test('spends the round and names everyone in its line, over the wreck '
        'and up to the door, but hurts nobody yet and makes no noise', () {
      final world = _corridor(
        zombies: <(String, GridPoint, EntityKind)>[
          ('near', const GridPoint(3, 1), EntityKind.wanderer),
          ('tough', const GridPoint(5, 1), EntityKind.cultist),
          ('far', const GridPoint(10, 1), EntityKind.brute),
          // Behind the closed door: out of the rocket's way.
          ('safe', const GridPoint(13, 1), EntityKind.wanderer),
        ],
      );
      const action = FireRocketAction();
      expect(action.tickCost, 0, reason: 'nobody moves while it flies');
      action.resolve(world);
      final fired = world.pendingEvents.whereType<RocketFiredEvent>().single;
      expect(fired.hitEntityIds, <String>['near', 'tough', 'far']);
      expect(fired.impact, const GridPoint(12, 1), reason: 'the door');
      expect(fired.direction, Direction.east);
      expect(fired.origin, const GridPoint(1, 1));
      expect(fired.description, contains('near, tough, far'));
      expect(world.pendingEvents.whereType<DamagedEvent>(), isEmpty);
      expect(world.pendingEvents.whereType<NoiseEvent>(), isEmpty);
      expect(world.player.component<AmmoComponent>().rockets, 1);
      for (final id in <String>['near', 'tough', 'far', 'safe']) {
        expect(world.entities[id]!.isAlive, isTrue, reason: id);
      }
    });

    test('each one it passes takes three damage, enough for a cultist; the '
        'burst at the end is heard further off than the pistol', () {
      final world = _corridor(
        zombies: <(String, GridPoint, EntityKind)>[
          ('tough', const GridPoint(5, 1), EntityKind.cultist),
          ('far', const GridPoint(10, 1), EntityKind.brute),
        ],
      );
      const RocketHitAction('tough').resolve(world);
      expect(world.entities['tough']!.isAlive, isFalse);
      expect(world.entities['far']!.isAlive, isTrue);
      final hit = world.pendingEvents.whereType<DamagedEvent>().single;
      expect(hit.amount, 3);
      expect(hit.sourceEntityId, 'player');
      // Somebody already gone, or never there: nothing happens.
      const RocketHitAction('tough').resolve(world);
      const RocketHitAction('nobody').resolve(world);
      expect(world.pendingEvents.whereType<DamagedEvent>(), hasLength(1));

      const burst = RocketBurstAction(GridPoint(12, 1));
      expect(burst.tickCost, 1, reason: 'then the zombies move');
      burst.resolve(world);
      final noise = world.pendingEvents.whereType<NoiseEvent>().single;
      expect(noise.origin, const GridPoint(12, 1));
      expect(noise.radius, greaterThan(const ShootAction().noiseRadius));
    });

    test('with nothing in its way it stops at the wall, naming nobody', () {
      final world = _corridor();
      world.player.component<PositionComponent>().facing = Direction.west;
      const FireRocketAction().resolve(world);
      final fired = world.pendingEvents.whereType<RocketFiredEvent>().single;
      expect(fired.hitEntityIds, isEmpty);
      expect(fired.impact, const GridPoint(0, 1));
      expect(fired.description, contains('west'));
    });

    test('without the launcher, or without a round, the trigger only '
        'clicks and nothing is spent', () {
      for (final world in <WorldState>[
        _corridor(launcher: false),
        _corridor(rockets: 0),
      ]) {
        const FireRocketAction().resolve(world);
        expect(world.pendingEvents.whereType<DryFiredEvent>(), hasLength(1));
        expect(world.pendingEvents.whereType<RocketFiredEvent>(), isEmpty);
        expect(world.pendingEvents.whereType<NoiseEvent>(), isEmpty);
      }
    });

    test('the pistol still stops in the first one it hits', () {
      final world = _corridor(
        zombies: <(String, GridPoint, EntityKind)>[
          ('first', const GridPoint(3, 1), EntityKind.wanderer),
          ('second', const GridPoint(5, 1), EntityKind.wanderer),
        ],
      );
      const ShootAction().resolve(world);
      expect(world.entities['first']!.isAlive, isFalse);
      expect(world.entities['second']!.isAlive, isTrue);
      final shot = world.pendingEvents.whereType<ShotEvent>().single;
      expect(shot.hitEntityId, 'first');
      expect(shot.impact, const GridPoint(3, 1));
    });

    test('the same path traced for the aim line: to the first one for the '
        'pistol, on to the wall for the rocket', () {
      final world = _corridor(
        zombies: <(String, GridPoint, EntityKind)>[
          ('first', const GridPoint(3, 1), EntityKind.wanderer),
          ('second', const GridPoint(9, 1), EntityKind.wanderer),
        ],
      );
      const from = GridPoint(1, 1);
      final pistol = traceShot(
        world,
        from,
        Direction.east,
        throughEntities: false,
      );
      expect(pistol.impact, const GridPoint(3, 1));
      expect(pistol.hit.map((e) => e.id), <String>['first']);
      final rocket = traceShot(
        world,
        from,
        Direction.east,
        throughEntities: true,
      );
      expect(rocket.impact, const GridPoint(12, 1));
      expect(rocket.hit.map((e) => e.id), <String>['first', 'second']);
      // Neither is stopped by the wreck at 7.
      expect(world.map.tileAt(const GridPoint(7, 1)).isWalkable, isFalse);
    });

    test('the backpack with the launcher puts it on his shoulder', () {
      final world = _corridor(
        launcher: false,
        pickups: <Pickup>[
          Pickup(
            id: 'launcher',
            position: const GridPoint(2, 1),
            rocketLauncher: true,
          ),
        ],
      );
      const InteractAction().resolve(world);
      expect(world.player.component<AmmoComponent>().hasRocketLauncher, isTrue);
      final picked = world.pendingEvents.whereType<PickedUpEvent>().single;
      expect(picked.rocketLauncher, isTrue);
      expect(picked.description, contains('rocket launcher'));
      expect(
        Pickup.fromJson(world.pickups['launcher']!.toJson()).rocketLauncher,
        isTrue,
      );
    });
  });

  group('a rocket in play', () {
    test('nobody moves while it flies; each one falls as it passes, in '
        'order; only its burst is heard, and only then do the zombies and '
        'the steps asked for meanwhile go', () {
      final world = _corridor(
        zombies: <(String, GridPoint, EntityKind)>[
          ('near', const GridPoint(4, 1), EntityKind.wanderer),
          ('far', const GridPoint(10, 1), EntityKind.wanderer),
        ],
      );
      final presentation = TurnPresentationController(world: world);
      final tick = world.tick;
      const origin = GridPoint(1, 1);
      const impact = GridPoint(12, 1);
      final nearAt = RocketComponent.flightSecondsFor(
        origin,
        const GridPoint(4, 1),
      );
      final farAt = RocketComponent.flightSecondsFor(
        origin,
        const GridPoint(10, 1),
      );
      final flight = RocketComponent.flightSecondsFor(origin, impact);
      expect(nearAt, lessThan(farAt));
      expect(farAt, lessThan(flight));

      presentation.submit(const FireRocketAction());
      expect(
        presentation.lastEvents.whereType<RocketFiredEvent>(),
        hasLength(1),
      );
      expect(presentation.holdsProjectile, isTrue);
      expect(world.tick, tick, reason: 'firing takes no turn of its own');
      final firedTurn = presentation.turnCount;

      presentation
        ..submit(const MoveAction(Direction.south))
        ..update(nearAt / 2);
      expect(presentation.isAnimating, isTrue);
      expect(world.entities['near']!.isAlive, isTrue);
      expect(presentation.turnCount, firedTurn);

      presentation.update(nearAt / 2 + 0.001);
      expect(world.entities['near']!.isAlive, isFalse, reason: 'passed');
      expect(world.entities['far']!.isAlive, isTrue);
      expect(presentation.turnCount, firedTurn + 1);
      expect(
        presentation.lastEvents.whereType<DamagedEvent>().single.entityId,
        'near',
      );
      expect(presentation.lastEvents.whereType<DiedEvent>(), hasLength(1));
      expect(presentation.lastEvents.whereType<RocketFiredEvent>(), isEmpty);
      expect(world.tick, tick);

      presentation.update(farAt - nearAt);
      expect(world.entities['far']!.isAlive, isFalse);
      expect(presentation.turnCount, firedTurn + 2);
      expect(presentation.isAnimating, isTrue);
      expect(presentation.holdsProjectile, isTrue);

      // The burst: its turn, the noise of it, then the step asked for.
      presentation.update(flight - farAt + 0.001);
      expect(presentation.holdsProjectile, isFalse);
      expect(world.tick, tick + 1);
      expect(presentation.lastEvents.whereType<NoiseEvent>(), hasLength(1));
      presentation.update(1);
      expect(
        world.player.component<PositionComponent>().position,
        const GridPoint(1, 1),
        reason: 'the step south is into the wall',
      );
      expect(world.tick, tick + 2);
    });

    test('nobody in its line: only the burst, at the wall', () {
      final world = _corridor();
      final presentation = TurnPresentationController(world: world)
        ..submit(const FireRocketAction());
      expect(presentation.holdsProjectile, isTrue);
      presentation.update(
        RocketComponent.flightSecondsFor(
              const GridPoint(1, 1),
              const GridPoint(12, 1),
            ) +
            0.01,
      );
      expect(presentation.holdsProjectile, isFalse);
      expect(
        presentation.lastEvents.whereType<NoiseEvent>().single.origin,
        const GridPoint(12, 1),
      );
    });
  });

  group('the launcher in hand', () {
    test('is a weapon to choose once found and loaded, and the keyboard '
        'cycles pistol, molotov, launcher', () {
      final harness = _Harness();
      expect(harness.input.hasWeapon(Weapon.rocketLauncher), isTrue);
      expect(harness.input.hasWeaponChoice, isTrue);
      expect(harness.input.weaponsCarried, <Weapon>[
        Weapon.pistol,
        Weapon.rocketLauncher,
      ]);
      harness.input.toggleWeapon();
      expect(harness.input.weapon.value, Weapon.rocketLauncher);
      harness.input.toggleWeapon();
      expect(harness.input.weapon.value, Weapon.pistol);
      harness.ammo.molotovs = 1;
      harness.input
        ..toggleWeapon()
        ..toggleWeapon();
      expect(harness.input.weapon.value, Weapon.rocketLauncher);
    });

    test('is not one without a round for it, nor before it is found', () {
      expect(
        _Harness(rockets: 0).input.hasWeapon(Weapon.rocketLauncher),
        isFalse,
      );
      expect(
        _Harness(launcher: false).input.hasWeapon(Weapon.rocketLauncher),
        isFalse,
      );
      final harness = _Harness()..unlocked.remove(HudElement.rockets);
      expect(harness.input.hasWeapon(Weapon.rocketLauncher), isFalse);
      harness.input.selectWeapon(Weapon.rocketLauncher);
      expect(harness.input.weapon.value, Weapon.pistol);
    });

    test('aimed, a direction fires a rocket that way, and the aim goes '
        'down; the empty pistol still clicks', () {
      final harness = _Harness()..input.selectWeapon(Weapon.rocketLauncher);
      harness.input.beginAim();
      expect(harness.input.aiming.value, isTrue);
      expect(harness.input.throwing, isFalse);
      harness.input.shootToward(Direction.west);
      expect(harness.submitted.single, isA<FireRocketAction>());
      expect(
        harness.world.player.component<PositionComponent>().facing,
        Direction.west,
      );
      expect(harness.input.aiming.value, isFalse);

      harness.submitted.clear();
      harness.ammo.loaded = 0;
      harness.input
        ..selectWeapon(Weapon.pistol)
        ..beginAim();
      expect(harness.input.aiming.value, isFalse, reason: 'only a click');
      expect(harness.submitted.single, isA<ShootAction>());
    });
  });
}
