import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/ui/blood_decor.dart';

final class TouchControls extends StatelessWidget {
  const TouchControls({required this.game, super.key});

  final StepboundGame game;

  static const double actionButtonSize = 54;
  static const double actionGap = 12;

  @override
  Widget build(BuildContext context) {
    // The tutorial unlocks the action buttons one at a time; the arrows
    // are always there.
    return ValueListenableBuilder<Set<HudElement>>(
      valueListenable: game.hud,
      builder: (context, unlocked, _) {
        return SafeArea(
          minimum: const EdgeInsets.all(10),
          child: Stack(
            children: <Widget>[
              if (unlocked.contains(HudElement.shoot))
                Positioned(
                  left: 0,
                  bottom: actionButtonSize + actionGap,
                  child: _ShootButton(game: game),
                ),
              if (unlocked.contains(HudElement.interact))
                Positioned(
                  left: actionButtonSize + actionGap,
                  bottom: 0,
                  child: _InteractButton(game: game),
                ),
              if (unlocked.contains(HudElement.ammo))
                Positioned(left: 0, bottom: 0, child: _AmmoCounter(game: game)),
              Positioned(
                right: 0,
                bottom: 0,
                child: _DirectionalPad(game: game),
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _ShootButton extends StatelessWidget {
  const _ShootButton({required this.game});

  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.aiming,
      builder: (context, isAiming, _) {
        return ValueListenableBuilder<int>(
          valueListenable: game.ammoLoaded,
          builder: (context, loaded, _) {
            final hasAmmo = loaded > 0;
            return _ActionButton(
              key: const ValueKey<String>('touch-shoot'),
              semanticLabel: isAiming ? 'Spara' : 'Mira',
              active: isAiming,
              enabled: hasAmmo,
              drips: const <BloodDrip>[
                BloodDrip(0.3, 17, 5),
                BloodDrip(0.62, 11, 4),
              ],
              icon: CustomPaint(
                size: const Size(26, 26),
                painter: _PistolIcon(
                  color: hasAmmo
                      ? (isAiming
                            ? BloodColors.bright
                            : const Color(0xffd8cfbf))
                      : const Color(0x668a8377),
                ),
              ),
              onPressed: game.pressShoot,
            );
          },
        );
      },
    );
  }
}

final class _InteractButton extends StatelessWidget {
  const _InteractButton({required this.game});

  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.aiming,
      builder: (context, isAiming, _) {
        return _ActionButton(
          key: const ValueKey<String>('touch-interact'),
          semanticLabel: isAiming ? 'Annulla mira' : 'Interagisci',
          drips: const <BloodDrip>[
            BloodDrip(0.42, 12, 4),
            BloodDrip(0.72, 18, 5),
          ],
          icon: Icon(
            isAiming ? Icons.close : Icons.touch_app,
            color: const Color(0xffd8cfbf),
            size: 26,
          ),
          onPressed: game.pressInteract,
        );
      },
    );
  }
}

final class _AmmoCounter extends StatelessWidget {
  const _AmmoCounter({required this.game});

  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.ammoLoaded,
      builder: (context, loaded, _) {
        final isEmpty = loaded == 0;
        final contentColor = isEmpty
            ? BloodColors.bright
            : const Color(0xffd8cfbf);
        return Semantics(
          label: 'Proiettili: $loaded',
          child: BloodOverlay(
            painter: const BloodPainter(
              band: 3,
              cornerRadius: 8,
              drips: <BloodDrip>[BloodDrip(0.22, 11, 4), BloodDrip(0.8, 7, 3)],
            ),
            child: Container(
              key: const ValueKey<String>('touch-ammo'),
              width: TouchControls.actionButtonSize,
              height: TouchControls.actionButtonSize,
              decoration: BoxDecoration(
                color: const Color(0xcc241a1a),
                border: Border.all(
                  color: isEmpty ? BloodColors.bright : BloodColors.fresh,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CustomPaint(
                    size: const Size(16, 11),
                    painter: _BulletIcon(color: contentColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u00d7$loaded',
                    style: TextStyle(
                      color: contentColor,
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _DirectionalPad extends StatelessWidget {
  const _DirectionalPad({required this.game});

  static const double buttonSize = 46;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: buttonSize * 3,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: buttonSize,
            child: _DirectionButton(
              key: const ValueKey<String>('touch-up'),
              drips: const <BloodDrip>[BloodDrip(0.3, 12, 4)],
              direction: Direction.north,
              icon: Icons.keyboard_arrow_up,
              game: game,
            ),
          ),
          Positioned(
            top: buttonSize,
            child: _DirectionButton(
              key: const ValueKey<String>('touch-left'),
              drips: const <BloodDrip>[BloodDrip(0.7, 9, 3)],
              direction: Direction.west,
              icon: Icons.keyboard_arrow_left,
              game: game,
            ),
          ),
          Positioned(
            top: buttonSize,
            right: 0,
            child: _DirectionButton(
              key: const ValueKey<String>('touch-right'),
              drips: const <BloodDrip>[
                BloodDrip(0.25, 8, 3),
                BloodDrip(0.66, 14, 4),
              ],
              direction: Direction.east,
              icon: Icons.keyboard_arrow_right,
              game: game,
            ),
          ),
          Positioned(
            left: buttonSize,
            bottom: 0,
            child: _DirectionButton(
              key: const ValueKey<String>('touch-down'),
              drips: const <BloodDrip>[BloodDrip(0.55, 10, 4)],
              direction: Direction.south,
              icon: Icons.keyboard_arrow_down,
              game: game,
            ),
          ),
        ],
      ),
    );
  }
}

final class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.direction,
    required this.icon,
    required this.game,
    this.drips = const <BloodDrip>[],
    super.key,
  });

  final Direction direction;
  final IconData icon;
  final StepboundGame game;
  final List<BloodDrip> drips;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Muovi ${direction.name}',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => game.pressDirection(direction),
        onPointerUp: (_) => game.releaseDirection(direction),
        onPointerCancel: (_) => game.releaseDirection(direction),
        child: BloodOverlay(
          painter: BloodPainter(band: 3, cornerRadius: 5, drips: drips),
          child: Container(
            width: _DirectionalPad.buttonSize,
            height: _DirectionalPad.buttonSize,
            decoration: BoxDecoration(
              color: const Color(0xcc241a1a),
              border: Border.all(color: BloodColors.fresh, width: 2),
              borderRadius: BorderRadius.circular(5),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: Icon(icon, color: const Color(0xffd8cfbf), size: 32),
          ),
        ),
      ),
    );
  }
}

final class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.active = false,
    this.enabled = true,
    this.drips = const <BloodDrip>[],
    super.key,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool active;
  final bool enabled;
  final List<BloodDrip> drips;

  @override
  Widget build(BuildContext context) {
    final borderColor = active ? BloodColors.bright : BloodColors.fresh;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: BloodOverlay(
            painter: BloodPainter(
              band: 5,
              cornerRadius: TouchControls.actionButtonSize / 2,
              drips: drips,
              color: active ? BloodColors.bright : BloodColors.fresh,
            ),
            child: Container(
              width: TouchControls.actionButtonSize,
              height: TouchControls.actionButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? const Color(0xdd4a1c1a)
                    : const Color(0xcc2e2020),
                border: Border.all(color: borderColor, width: 2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
                ],
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PistolIcon extends CustomPainter {
  const _PistolIcon({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawRect(const Rect.fromLTWH(2, 8, 19, 4.5), paint)
      ..drawRect(const Rect.fromLTWH(16, 5.5, 3, 2.5), paint)
      ..drawRect(const Rect.fromLTWH(10, 12.5, 2.5, 3.5), paint)
      ..drawPath(
        Path()
          ..moveTo(14, 12.5)
          ..lineTo(18.5, 12.5)
          ..lineTo(16.5, 21.5)
          ..lineTo(12, 21.5)
          ..close(),
        paint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_PistolIcon oldDelegate) => oldDelegate.color != color;
}

final class _BulletIcon extends CustomPainter {
  const _BulletIcon({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas
      ..save()
      ..scale(size.width / 14)
      ..drawRect(const Rect.fromLTWH(1, 2.5, 8, 6), paint)
      ..drawPath(
        Path()
          ..moveTo(9, 2.5)
          ..lineTo(13.5, 5.5)
          ..lineTo(9, 8.5)
          ..close(),
        paint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BulletIcon oldDelegate) => oldDelegate.color != color;
}
