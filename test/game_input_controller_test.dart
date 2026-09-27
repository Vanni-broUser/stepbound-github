import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/input/game_input_controller.dart';
import 'package:stepbound/game/story/story_director.dart';

import 'test_world.dart';

/// A controller with everything unlocked, recording what it submits.
final class _Harness {
  _Harness() {
    input = GameInputController(
      world: world,
      canAct: () => canAct,
      ignoresKeys: () => ignoresKeys,
      isUnlocked: unlocked.contains,
      submit: submitted.add,
      dropQueuedSteps: () => dropped++,
      toggleDebug: () => debugToggles++,
    );
  }

  final WorldState world = playerOnlyWorld();
  final List<PlayerAction> submitted = <PlayerAction>[];
  final Set<HudElement> unlocked = <HudElement>{
    HudElement.interact,
    HudElement.shoot,
  };
  bool canAct = true;
  bool ignoresKeys = false;
  int dropped = 0;
  int debugToggles = 0;
  late final GameInputController input;

  AmmoComponent get ammo => world.player.component<AmmoComponent>();
  Direction get facing => world.player.component<PositionComponent>().facing;

  KeyEventResult press(LogicalKeyboardKey key) => input.onKeyEvent(
    KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.space,
      logicalKey: key,
      timeStamp: Duration.zero,
    ),
  );

  KeyEventResult release(LogicalKeyboardKey key) => input.onKeyEvent(
    KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.space,
      logicalKey: key,
      timeStamp: Duration.zero,
    ),
  );
}

void main() {
  const repeat = GameInputController.holdRepeatSeconds;
  final holdToAim = GameInputController.holdToAim.inMicroseconds / 1e6;

  group('walking', () {
    test('a direction held down steps again every repeat interval', () {
      final h = _Harness();
      h.input.pressDirection(Direction.east);
      expect(h.submitted, hasLength(1));

      h.input.update(repeat * 2.5);
      expect(h.submitted, hasLength(3));
      expect(h.submitted.every((a) => a is MoveAction), isTrue);

      h.input
        ..releaseDirection(Direction.east)
        ..update(repeat * 3);
      expect(h.submitted, hasLength(3), reason: 'let go, no more steps');
    });

    test('letting go of another direction keeps the held one walking', () {
      final h = _Harness();
      h.input
        ..pressDirection(Direction.east)
        ..releaseDirection(Direction.west)
        ..update(repeat);
      expect(h.submitted, hasLength(2));
    });

    test('nothing moves while Mario cannot act', () {
      final h = _Harness()..canAct = false;
      h.input
        ..pressDirection(Direction.east)
        ..pressInteract()
        ..pressWait()
        ..update(1);
      expect(h.submitted, isEmpty);
    });

    test('stopping drops the queued steps and lowers the pistol', () {
      final h = _Harness();
      h.input
        ..pressDirection(Direction.east)
        ..beginAim()
        ..stop()
        ..update(repeat * 3);
      expect(h.input.aiming.value, isFalse);
      expect(h.dropped, 1);
      expect(h.submitted, hasLength(1));
    });
  });

  group('pistol', () {
    test('a direction with the pistol up turns Mario and fires', () {
      final h = _Harness();
      h.input
        ..beginAim()
        ..pressDirection(Direction.north);
      expect(h.facing, Direction.north);
      expect(h.submitted.single, isA<ShootAction>());
      expect(h.input.aiming.value, isFalse);
    });

    test('with nothing loaded aiming only clicks', () {
      final h = _Harness();
      h.ammo.loaded = 0;
      h.input.beginAim();
      expect(h.input.aiming.value, isFalse);
      expect(h.submitted.single, isA<ShootAction>());
    });

    test('the pistol stays down until shooting is unlocked', () {
      final h = _Harness()..unlocked.remove(HudElement.shoot);
      h.input.pressShoot();
      expect(h.input.aiming.value, isFalse);
      expect(h.submitted, isEmpty);
    });

    test('interacting with the pistol up only lowers it', () {
      final h = _Harness();
      h.input
        ..beginAim()
        ..pressInteract();
      expect(h.input.aiming.value, isFalse);
      expect(h.submitted, isEmpty);
    });
  });

  group('keyboard', () {
    const space = LogicalKeyboardKey.space;

    test('a short space interacts, a long one raises the pistol', () {
      final h = _Harness()
        ..press(space)
        ..release(space);
      expect(h.submitted.single, isA<InteractAction>());

      h
        ..press(space)
        ..input.update(holdToAim);
      expect(h.input.aiming.value, isTrue);
      h.release(space);
      expect(h.input.aiming.value, isTrue, reason: 'letting go keeps it up');

      h
        ..press(space)
        ..release(space);
      expect(h.input.aiming.value, isFalse, reason: 'a tap lowers it');
    });

    test('keys map to actions, and to the debug overlay', () {
      final h = _Harness()
        ..press(LogicalKeyboardKey.keyD)
        ..press(LogicalKeyboardKey.keyE)
        ..press(LogicalKeyboardKey.keyX)
        ..press(LogicalKeyboardKey.keyG);
      expect(h.submitted.map((a) => a.runtimeType), <Type>[
        MoveAction,
        InteractAction,
        WaitAction,
      ]);
      expect(h.debugToggles, 1);
      expect(h.press(LogicalKeyboardKey.keyQ), KeyEventResult.ignored);
    });

    test('keys are left alone while something covers the game', () {
      final h = _Harness()..ignoresKeys = true;
      expect(h.press(LogicalKeyboardKey.keyD), KeyEventResult.ignored);
      expect(h.press(space), KeyEventResult.ignored);
      expect(h.submitted, isEmpty);
    });
  });
}
