import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/input/game_input_controller.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/molotov_blast_component.dart';
import 'package:stepbound/game/render/throw_preview_component.dart';
import 'package:stepbound/game/story/story_director.dart';

/// An open room 15x11 with Mario in the middle of its west half, facing
/// east, carrying [molotovs].
WorldState _room({
  int molotovs = 2,
  List<(String, GridPoint)> zombies = const <(String, GridPoint)>[],
  List<Pickup> pickups = const <Pickup>[],
}) {
  final factory = EntityFactory(BalanceConfig.standard());
  final world = WorldState(
    map: TileMap.fromAscii(<String>[
      '###############',
      for (var i = 0; i < 9; i++) '#.............#',
      '###############',
    ]),
    entities: <Entity>[
      factory.player(id: 'player', position: const GridPoint(3, 5)),
      for (final (id, at) in zombies)
        factory.zombie(id: id, kind: EntityKind.wanderer, position: at),
    ],
    playerId: 'player',
    random: SeededRandom(3),
    pickups: pickups,
  );
  world.player.component<AmmoComponent>().molotovs = molotovs;
  return world;
}

final class _Harness {
  _Harness({int molotovs = 2, this.area}) : world = _room(molotovs: molotovs) {
    input = GameInputController(
      world: world,
      canAct: () => true,
      ignoresKeys: () => false,
      isUnlocked: unlocked.contains,
      submit: submitted.add,
      dropQueuedSteps: () {},
      toggleDebug: () {},
      throwArea: () => area,
    );
  }

  final WorldState world;
  GridRect? area;
  final List<PlayerAction> submitted = <PlayerAction>[];
  final Set<HudElement> unlocked = <HudElement>{
    HudElement.interact,
    HudElement.shoot,
    HudElement.molotov,
  };
  late final GameInputController input;

  Direction get facing => world.player.component<PositionComponent>().facing;

  void key(LogicalKeyboardKey key) => input.onKeyEvent(
    KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyQ,
      logicalKey: key,
      timeStamp: Duration.zero,
    ),
  );
}

void main() {
  group('ThrowMolotovAction', () {
    test('burns everyone on the 3x3 square, and nobody off it', () {
      final world = _room(
        zombies: <(String, GridPoint)>[
          ('corner', const GridPoint(7, 4)),
          ('middle', const GridPoint(8, 5)),
          ('edge', const GridPoint(9, 6)),
          ('outside', const GridPoint(10, 5)),
        ],
      );
      const ThrowMolotovAction(GridPoint(8, 5)).resolve(world);

      bool alive(String id) => world.entities[id]!.isAlive;
      expect(alive('corner'), isFalse);
      expect(alive('middle'), isFalse);
      expect(alive('edge'), isFalse);
      expect(alive('outside'), isTrue);
      expect(world.player.component<AmmoComponent>().molotovs, 1);
      final events = world.pendingEvents;
      expect(
        events.whereType<MolotovThrownEvent>().single.target,
        const GridPoint(8, 5),
      );
      // The throw is told before the hits, which wait for the landing.
      expect(
        events.indexWhere((e) => e is MolotovThrownEvent),
        lessThan(events.indexWhere((e) => e is DamagedEvent)),
      );
      expect(
        world.player.component<PositionComponent>().facing,
        Direction.east,
      );
    });

    test('turns Mario to the axis the square lies furthest on', () {
      final world = _room();
      const ThrowMolotovAction(GridPoint(4, 1)).resolve(world);
      expect(
        world.player.component<PositionComponent>().facing,
        Direction.north,
      );
    });

    test('with none left, or out of reach, nothing is thrown', () {
      for (final (molotovs, target) in <(int, GridPoint)>[
        (0, const GridPoint(6, 5)),
        (1, const GridPoint(4, 5)),
        (1, const GridPoint(12, 5)),
      ]) {
        final world = _room(molotovs: molotovs);
        ThrowMolotovAction(target).resolve(world);
        expect(world.pendingEvents.whereType<MolotovThrownEvent>(), isEmpty);
        expect(world.player.component<AmmoComponent>().molotovs, molotovs);
      }
    });

    test('never reaches Mario: every square in range leaves him out', () {
      const from = GridPoint(0, 0);
      for (var y = -8; y <= 8; y++) {
        for (var x = -8; x <= 8; x++) {
          final target = GridPoint(x, y);
          if (!ThrowMolotovAction.canReach(from, target)) {
            continue;
          }
          expect(
            x.abs() > 1 || y.abs() > 1,
            isTrue,
            reason: '$target would burn Mario',
          );
        }
      }
    });

    test('a backpack of molotovs adds to those carried', () {
      final world = _room(
        molotovs: 0,
        pickups: <Pickup>[
          Pickup(id: 'bag', position: const GridPoint(4, 5), molotovs: 1),
        ],
      );
      const InteractAction().resolve(world);
      expect(world.player.component<AmmoComponent>().molotovs, 1);
      expect(world.pendingEvents.whereType<PickedUpEvent>().single.molotovs, 1);
    });
  });

  group('aiming a molotov', () {
    test('raising it puts the square three tiles ahead', () {
      final h = _Harness();
      h.input
        ..toggleWeapon()
        ..beginAim();
      expect(h.input.throwing, isTrue);
      expect(h.input.throwTarget.value, const GridPoint(6, 5));
    });

    test('the stick moves the square and turns Mario toward it', () {
      final h = _Harness();
      h.input
        ..toggleWeapon()
        ..beginAim()
        ..aimThrow(const Offset(0, 0.5));
      expect(h.input.throwTarget.value, const GridPoint(3, 9));
      expect(h.facing, Direction.south);

      h.input.aimThrow(const Offset(-0.1, 0));
      expect(h.input.throwTarget.value!.x, 3 - ThrowMolotovAction.minRange);
      expect(h.facing, Direction.west);
    });

    test('letting go throws at the square, then the pistol is back', () {
      final h = _Harness(molotovs: 1);
      h.input
        ..toggleWeapon()
        ..beginAim()
        ..aimThrow(const Offset(0.7, -0.7))
        ..throwMolotov();
      final action = h.submitted.single as ThrowMolotovAction;
      expect(
        ThrowMolotovAction.canReach(const GridPoint(3, 5), action.target),
        isTrue,
      );
      expect(h.input.aiming.value, isFalse);
      expect(h.input.throwTarget.value, isNull);
      expect(h.input.weapon.value, Weapon.pistol);
    });

    test('the square stops at the edge of the place Mario is in', () {
      final h = _Harness(area: const GridRect(0, 0, 7, 10));
      h.input
        ..toggleWeapon()
        ..beginAim()
        ..aimThrow(const Offset(1, 0));
      expect(h.input.throwTarget.value, const GridPoint(7, 5));
      // Straight down, the map ends before the reach does.
      h.input.aimThrow(const Offset(0, 1));
      expect(h.input.throwTarget.value, const GridPoint(3, 10));
    });

    test('on the keyboard: Q takes it, arrows move the square, B throws', () {
      final h = _Harness()
        ..key(LogicalKeyboardKey.keyQ)
        ..key(LogicalKeyboardKey.keyB);
      expect(h.input.throwTarget.value, const GridPoint(6, 5));
      h
        ..key(LogicalKeyboardKey.arrowDown)
        ..key(LogicalKeyboardKey.arrowRight);
      expect(h.input.throwTarget.value, const GridPoint(7, 6));
      expect(h.submitted, isEmpty, reason: 'arrows only move the square');
      h.key(LogicalKeyboardKey.keyB);
      expect(
        (h.submitted.single as ThrowMolotovAction).target,
        const GridPoint(7, 6),
      );
    });

    test('with none carried, it cannot be taken in hand', () {
      final h = _Harness(molotovs: 0);
      h.input.toggleWeapon();
      expect(h.input.weapon.value, Weapon.pistol);
    });
  });

  test('the aimed square and the blast draw every frame of their life', () {
    final world = _room();
    final target = ValueNotifier<GridPoint?>(null);
    final preview = ThrowPreviewComponent(simulation: world, target: target);
    var landed = 0;
    final blast = MolotovBlastComponent(
      origin: const GridPoint(3, 5),
      target: const GridPoint(7, 4),
      onLanded: () => landed++,
    );
    void frame() {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      preview.render(canvas);
      blast.render(canvas);
      recorder.endRecording().dispose();
    }

    frame();
    target.value = const GridPoint(7, 4);
    const total =
        MolotovBlastComponent.flightSeconds +
        MolotovBlastComponent.burstSeconds;
    for (var t = 0.0; t < total + 0.1; t += 1 / 30) {
      preview.update(1 / 30);
      blast.update(1 / 30);
      frame();
    }
    expect(landed, 1);
  });

  test('molotovs stay in the level they were carried out of', () {
    final progress = Progress.newGame();
    expect(progress.swapMolotovs(LevelId.rome, molotovs: 1), 0);
    progress.travel(LevelId.rome, rounds: 3);
    expect(progress.swapMolotovs(LevelId.hometown, molotovs: 0), 1);
    final restored = Progress.fromJson(progress.toJson());
    expect(restored.molotovsLeft, <LevelId, int>{
      LevelId.hometown: 1,
      LevelId.rome: 0,
    });
  });

  test(
    'the molotov backpack lies on the park path, before the carabiniere',
    () {
      final world = createGameWorld(seed: 1);
      final bag = world.pickups[molotovBackpackId]!;
      expect(bag.molotovs, 1);
      expect(world.map.tileAt(bag.position).isWalkable, isTrue);
      final carabiniere = world.entities.values.singleWhere(
        (entity) =>
            entity.kind == EntityKind.carabiniere &&
            entity.component<PositionComponent>().position.y ==
                bag.position.y &&
            placeAt(entity.component<PositionComponent>().position)?.id ==
                PlaceId.mallNorthStreet,
      );
      final at = carabiniere.component<PositionComponent>().position;
      expect(at.x - bag.position.x, 4);
    },
  );
}
