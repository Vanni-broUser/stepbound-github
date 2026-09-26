import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// Turns the keyboard and the touch controls into Mario's actions: a
/// direction held down keeps walking, the pistol goes up and down, and the
/// space bar works like the right half of the screen.
final class GameInputController {
  GameInputController({
    required this.world,
    required this.canAct,
    required this.ignoresKeys,
    required this.isUnlocked,
    required this.submit,
    required this.dropQueuedSteps,
    required this.toggleDebug,
  });

  /// How often a direction held down takes another step.
  static const double holdRepeatSeconds = 0.18;

  /// How long the space bar, or a finger on the right half of the screen,
  /// stays down before Mario raises the pistol. Let go sooner and it is a
  /// tap: he interacts. On the screen the pistol stays up only for as long
  /// as that finger does.
  static const Duration holdToAim = Duration(milliseconds: 300);
  static final double _holdToAimSeconds = holdToAim.inMicroseconds / 1e6;

  final WorldState world;

  /// Whether Mario is free to act: nothing covers the game, no scene holds
  /// him still.
  final bool Function() canAct;

  /// Whether the keys are not for Mario at all: something covers the game,
  /// or his opening lines are playing over it.
  final bool Function() ignoresKeys;
  final bool Function(HudElement element) isUnlocked;
  final void Function(PlayerAction action) submit;
  final void Function() dropQueuedSteps;
  final void Function() toggleDebug;

  final ValueNotifier<bool> aiming = ValueNotifier<bool>(false);

  Direction? _heldDirection;
  double _holdElapsed = 0;

  /// Seconds the space bar has been down, null while it is up, and whether
  /// the pistol was already up when it went down.
  double? _spaceHeld;
  bool _spaceAimedBefore = false;

  Entity get _mario => world.player;

  /// Drops the steps queued and the arrow held, and lowers the pistol.
  void stop() {
    stopWalking();
    aiming.value = false;
    _spaceHeld = null;
  }

  void stopWalking() {
    _releaseHeld();
    dropQueuedSteps();
  }

  void update(double dt) {
    _repeatHeldDirection(dt);
    _raisePistolOnLongSpace(dt);
  }

  // ------------------------------------------------------------ keyboard

  KeyEventResult onKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      return _onSpace(event);
    }
    if (ignoresKeys()) {
      return KeyEventResult.ignored;
    }
    final direction = _directionFor(key);
    if (event is KeyUpEvent && direction != null) {
      releaseDirection(direction);
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (direction != null) {
      pressDirection(direction);
    } else if (key == LogicalKeyboardKey.keyB) {
      pressShoot();
    } else if (key == LogicalKeyboardKey.keyE) {
      pressInteract();
    } else if (key == LogicalKeyboardKey.keyX) {
      pressWait();
    } else if (key == LogicalKeyboardKey.keyG) {
      toggleDebug();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// A tap interacts (or lowers the pistol), holding it raises the pistol,
  /// and then the arrows shoot.
  KeyEventResult _onSpace(KeyEvent event) {
    switch (event) {
      case KeyDownEvent():
        if (ignoresKeys()) {
          return KeyEventResult.ignored;
        }
        _spaceHeld = 0;
        _spaceAimedBefore = aiming.value;
      case KeyUpEvent():
        final held = _spaceHeld;
        _spaceHeld = null;
        if (held == null) {
          return KeyEventResult.ignored;
        }
        if (held < _holdToAimSeconds) {
          if (_spaceAimedBefore) {
            cancelAim();
          } else {
            pressInteract();
          }
        }
      case KeyRepeatEvent():
        break;
    }
    return KeyEventResult.handled;
  }

  void _raisePistolOnLongSpace(double dt) {
    final before = _spaceHeld;
    if (before == null) {
      return;
    }
    final now = before + dt;
    _spaceHeld = now;
    if (!_spaceAimedBefore &&
        before < _holdToAimSeconds &&
        now >= _holdToAimSeconds) {
      beginAim();
    }
  }

  static Direction? _directionFor(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => Direction.north,
    LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => Direction.east,
    LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => Direction.south,
    LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => Direction.west,
    _ => null,
  };

  // ------------------------------------------------------------- walking

  /// With the pistol up, a direction is where the shot goes.
  void pressDirection(Direction direction) {
    if (!canAct()) {
      return;
    }
    if (aiming.value) {
      shootToward(direction);
      return;
    }
    if (_heldDirection == direction) {
      return;
    }
    _heldDirection = direction;
    _holdElapsed = 0;
    submit(MoveAction(direction));
  }

  void releaseDirection(Direction direction) {
    if (_heldDirection == direction) {
      _releaseHeld();
    }
  }

  void _releaseHeld() {
    _heldDirection = null;
    _holdElapsed = 0;
  }

  void _repeatHeldDirection(double dt) {
    final direction = _heldDirection;
    if (direction == null || !canAct()) {
      return;
    }
    _holdElapsed += dt;
    while (_holdElapsed >= holdRepeatSeconds) {
      _holdElapsed -= holdRepeatSeconds;
      submit(MoveAction(direction));
    }
  }

  void pressInteract() {
    if (!canAct()) {
      return;
    }
    if (aiming.value) {
      aiming.value = false;
      return;
    }
    if (isUnlocked(HudElement.interact)) {
      submit(const InteractAction());
    }
  }

  void pressWait() {
    if (canAct() && !aiming.value) {
      submit(const WaitAction());
    }
  }

  // -------------------------------------------------------------- pistol

  /// Aims if not aiming yet, shoots where Mario faces if already aiming.
  void pressShoot() {
    if (!aiming.value) {
      beginAim();
      return;
    }
    if (canAct()) {
      submit(const ShootAction());
      aiming.value = false;
    }
  }

  /// Raises the pistol. With nothing loaded it only clicks.
  void beginAim() {
    if (!canAct() || aiming.value || !isUnlocked(HudElement.shoot)) {
      return;
    }
    if (_mario.component<AmmoComponent>().loaded == 0) {
      submit(const ShootAction());
      return;
    }
    _releaseHeld();
    aiming.value = true;
  }

  /// Turns the aimed pistol to [direction] without firing.
  void aimToward(Direction direction) {
    if (canAct() && aiming.value) {
      _mario.component<PositionComponent>().facing = direction;
    }
  }

  /// Turns the aimed pistol to [direction] and fires at once.
  void shootToward(Direction direction) {
    if (!canAct() || !aiming.value) {
      return;
    }
    _mario.component<PositionComponent>().facing = direction;
    submit(const ShootAction());
    aiming.value = false;
  }

  /// Lowers the pistol without shooting.
  void cancelAim() => aiming.value = false;
}
