import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// What Mario has in hand when he aims.
enum Weapon {
  pistol,

  /// Thrown in an arc at a 3x3 square, see [ThrowMolotovAction].
  molotov,
}

/// Turns the keyboard and the touch controls into Mario's actions: a
/// direction held down keeps walking, the pistol goes up and down, and the
/// space bar works like the right half of the screen. With the molotov in
/// hand, aiming picks the square it lands on instead of a direction.
final class GameInputController {
  GameInputController({
    required this.world,
    required this.canAct,
    required this.ignoresKeys,
    required this.isUnlocked,
    required this.submit,
    required this.dropQueuedSteps,
    required this.toggleDebug,
    required this.throwArea,
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

  /// The rectangle a molotov may land in: the place Mario stands in, so a
  /// bottle never flies into the next map laid out beside it.
  final GridRect? Function() throwArea;

  /// Tiles ahead of Mario a molotov lands when aiming starts.
  static const int throwStart = 3;

  final ValueNotifier<bool> aiming = ValueNotifier<bool>(false);

  /// What aiming raises: the pistol, or a molotov once he has some.
  final ValueNotifier<Weapon> weapon = ValueNotifier<Weapon>(Weapon.pistol);

  /// The centre of the 3x3 square the molotov in hand would burst over,
  /// while aiming it; null otherwise.
  final ValueNotifier<GridPoint?> throwTarget = ValueNotifier<GridPoint?>(null);

  /// Aiming, with a molotov in hand.
  bool get throwing => aiming.value && weapon.value == Weapon.molotov;

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
    cancelAim();
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
    } else if (key == LogicalKeyboardKey.keyQ) {
      toggleWeapon();
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

  /// With the pistol up, a direction is where the shot goes; with a
  /// molotov, it moves the square it lands on by a tile.
  void pressDirection(Direction direction) {
    if (!canAct()) {
      return;
    }
    if (throwing) {
      final target = throwTarget.value;
      if (target != null) {
        _setThrowTarget(_fitThrow(target.step(direction)) ?? target);
      }
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
      cancelAim();
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

  /// Aims if not aiming yet, shoots where Mario faces (or throws at the
  /// square picked) if already aiming.
  void pressShoot() {
    if (!aiming.value) {
      beginAim();
      return;
    }
    if (throwing) {
      throwMolotov();
      return;
    }
    if (canAct()) {
      submit(const ShootAction());
      cancelAim();
    }
  }

  /// Whether holding down would raise anything: the pistol once shooting
  /// is taught, a molotov once one is in hand.
  bool get canAim => switch (weapon.value) {
    Weapon.pistol => isUnlocked(HudElement.shoot),
    Weapon.molotov =>
      isUnlocked(HudElement.molotov) &&
          _mario.component<AmmoComponent>().molotovs > 0,
  };

  /// Raises the pistol, or a molotov with the square it would land on a
  /// few tiles ahead. The pistol with nothing loaded only clicks.
  void beginAim() {
    if (!canAct() || aiming.value || !canAim) {
      return;
    }
    if (weapon.value == Weapon.molotov) {
      _releaseHeld();
      _setThrowTarget(_startingThrow());
      aiming.value = true;
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
    if (canAct() && aiming.value && !throwing) {
      _mario.component<PositionComponent>().facing = direction;
    }
  }

  /// Turns the aimed pistol to [direction] and fires at once.
  void shootToward(Direction direction) {
    if (!canAct() || !aiming.value || throwing) {
      return;
    }
    _mario.component<PositionComponent>().facing = direction;
    submit(const ShootAction());
    cancelAim();
  }

  /// Moves the square the molotov lands on where the stick points:
  /// [pull] is the stick's offset, its length from 0 (just out of the ring
  /// in the middle) to 1 (at the stick's reach), and it lands from
  /// [ThrowMolotovAction.minRange] to [ThrowMolotovAction.maxRange] tiles
  /// off that way. Mario turns to face it.
  void aimThrow(Offset pull) {
    if (!canAct() || !throwing || pull == Offset.zero) {
      return;
    }
    const near = ThrowMolotovAction.minRange;
    const far = ThrowMolotovAction.maxRange;
    final strength = math.min(pull.distance, 1);
    final reach = near + strength * (far - near);
    final unit = pull / pull.distance;
    final from = _mario.component<PositionComponent>().position;
    final target = _fitThrow(
      GridPoint(
        from.x + (unit.dx * reach).round(),
        from.y + (unit.dy * reach).round(),
      ),
    );
    if (target != null) {
      _setThrowTarget(target);
    }
  }

  /// Throws the molotov in hand at the square picked. The last one gone,
  /// the pistol is back in hand.
  void throwMolotov() {
    final target = throwTarget.value;
    if (!canAct() || !throwing || target == null) {
      return;
    }
    submit(ThrowMolotovAction(target));
    cancelAim();
    if (_mario.component<AmmoComponent>().molotovs <= 1) {
      weapon.value = Weapon.pistol;
    }
  }

  /// Swaps the pistol for a molotov and back. Only between aims, and only
  /// with a molotov to take.
  void toggleWeapon() {
    if (aiming.value) {
      return;
    }
    if (weapon.value == Weapon.molotov) {
      weapon.value = Weapon.pistol;
    } else if (isUnlocked(HudElement.molotov) &&
        _mario.component<AmmoComponent>().molotovs > 0) {
      weapon.value = Weapon.molotov;
    }
  }

  /// Lowers the pistol, or the molotov, without shooting.
  void cancelAim() {
    aiming.value = false;
    throwTarget.value = null;
  }

  void _setThrowTarget(GridPoint? target) {
    throwTarget.value = target;
    if (target != null) {
      final position = _mario.component<PositionComponent>();
      position.facing = ThrowMolotovAction.facingToward(
        position.position,
        target,
      );
    }
  }

  /// Where a molotov raised now would land: [throwStart] tiles the way
  /// Mario faces, or the first other way there is room for.
  GridPoint? _startingThrow() {
    final position = _mario.component<PositionComponent>();
    final ways = <Direction>[
      position.facing,
      ...Direction.values.where((way) => way != position.facing),
    ];
    for (final way in ways) {
      var target = position.position;
      for (var i = 0; i < throwStart; i++) {
        target = target.step(way);
      }
      final fitted = _fitThrow(target);
      if (fitted != null) {
        return fitted;
      }
    }
    return null;
  }

  /// [target] brought within reach of Mario and inside [throwArea] and the
  /// map, or null when it cannot be: then the square stays where it was.
  GridPoint? _fitThrow(GridPoint target) {
    final from = _mario.component<PositionComponent>().position;
    var dx = target.x - from.x;
    var dy = target.y - from.y;
    const near = ThrowMolotovAction.minRange;
    const far = ThrowMolotovAction.maxRange;
    // Too close: pushed out along the axis it leans on, so the square
    // never takes Mario in.
    if (math.max(dx.abs(), dy.abs()) < near) {
      if (dx.abs() >= dy.abs()) {
        dx = dx < 0 ? -near : near;
      } else {
        dy = dy < 0 ? -near : near;
      }
    }
    // Too far: pulled back along the same line.
    while (dx * dx + dy * dy > far * far) {
      if (dx.abs() >= dy.abs()) {
        dx -= dx.sign;
      } else {
        dy -= dy.sign;
      }
    }
    // Past the edge of the place: stopped at it.
    final area = throwArea();
    final map = world.map;
    final left = math.max(0, area?.left ?? 0);
    final top = math.max(0, area?.top ?? 0);
    final right = math.min(map.width - 1, area?.right ?? map.width);
    final bottom = math.min(map.height - 1, area?.bottom ?? map.height);
    final fitted = GridPoint(
      (from.x + dx).clamp(left, right),
      (from.y + dy).clamp(top, bottom),
    );
    return ThrowMolotovAction.canReach(from, fitted) ? fitted : null;
  }
}
