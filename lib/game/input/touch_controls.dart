import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/blood_decor.dart';

final class TouchControls extends StatelessWidget {
  const TouchControls({required this.game, super.key});

  final StepboundGame game;

  static const double actionButtonSize = 54;
  static const double actionGap = 12;

  /// The way out, in the far corner from the thumbs: smaller than the
  /// action buttons, so it is never the one hit by mistake.
  static const double menuButtonSize = 38;

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
              // Interact sits where the thumb rests; shooting is the one
              // worth reaching for.
              if (unlocked.contains(HudElement.interact))
                Positioned(
                  right: 0,
                  bottom: actionButtonSize + actionGap,
                  child: _InteractButton(game: game),
                ),
              if (unlocked.contains(HudElement.shoot))
                Positioned(
                  right: actionButtonSize + actionGap,
                  bottom: 0,
                  child: _ShootButton(game: game),
                ),
              if (unlocked.contains(HudElement.ammo))
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _AmmoCounter(game: game),
                ),
              Positioned(
                left: 0,
                bottom: 0,
                child: _DirectionalPad(game: game),
              ),
              // Always there, unlocked or not: it is the way out, not
              // something the tutorial hands over.
              Positioned(right: 0, top: 0, child: _PauseButton(game: game)),
              // No button at all: what Mario is carrying for Don Angelo.
              // The far top corner from the menu, out of both thumbs' way.
              if (unlocked.contains(HudElement.incense) ||
                  unlocked.contains(HudElement.barKey) ||
                  unlocked.contains(HudElement.episcopalRing))
                Positioned(
                  left: 0,
                  top: 0,
                  child: Column(
                    children: <Widget>[
                      if (unlocked.contains(HudElement.incense))
                        _IncenseBadge(game: game),
                      if (unlocked.contains(HudElement.barKey))
                        _BarKeyBadge(game: game),
                      if (unlocked.contains(HudElement.episcopalRing))
                        _EpiscopalRingBadge(game: game),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Opens the menu over the game. The gameplay buttons go with it: the
/// menu replaces whatever covers the game, and these are what is drawn
/// when nothing does.
final class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.game});

  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      key: const ValueKey<String>('touch-menu'),
      semanticLabel: 'Menù',
      size: TouchControls.menuButtonSize,
      drips: const <BloodDrip>[BloodDrip(0.35, 9, 3)],
      icon: const Icon(Icons.menu, color: Color(0xffd8cfbf), size: 20),
      onPressed: () {
        AudioScope.of(context).play(Sfx.uiClick);
        game.openMenu();
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
              dimmed: !hasAmmo,
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

/// The censer found in San Nicola, hanging in the top corner for as long
/// as Mario carries it: the errand he is on, always in sight.
final class _IncenseBadge extends StatelessWidget {
  const _IncenseBadge({required this.game});

  static const double size = 44;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Incenso per Don Angelo',
      child: GestureDetector(
        onTap: () {
          AudioScope.of(context).play(Sfx.uiClick);
          game.inspectInventory('Incenso');
        },
        child: BloodOverlay(
          painter: const BloodPainter(
            band: 3,
            cornerRadius: 8,
            drips: <BloodDrip>[BloodDrip(0.3, 13, 4), BloodDrip(0.74, 8, 3)],
          ),
          child: Container(
            key: const ValueKey<String>('hud-incense'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xcc241a1a),
              border: Border.all(color: BloodColors.fresh, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: const Center(
              child: CustomPaint(size: Size(26, 30), painter: _CenserIcon()),
            ),
          ),
        ),
      ),
    );
  }
}

/// The key Don Angelo gives Mario for the Bar Arcobaleno service door.
final class _BarKeyBadge extends StatelessWidget {
  const _BarKeyBadge({required this.game});

  static const double size = 44;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Chiave del Bar Arcobaleno',
      child: GestureDetector(
        onTap: () {
          AudioScope.of(context).play(Sfx.uiClick);
          game.inspectInventory('Chiave del Bar Arcobaleno');
        },
        child: BloodOverlay(
          painter: const BloodPainter(
            band: 3,
            cornerRadius: 8,
            drips: <BloodDrip>[BloodDrip(0.24, 8, 3), BloodDrip(0.68, 12, 4)],
          ),
          child: Container(
            key: const ValueKey<String>('hud-bar-key'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xcc241a1a),
              border: Border.all(color: BloodColors.fresh, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: const Center(
              child: CustomPaint(size: Size(28, 28), painter: _KeyIcon()),
            ),
          ),
        ),
      ),
    );
  }
}

/// Don Angelo's ring, carried only from the bar storeroom to the altar.
final class _EpiscopalRingBadge extends StatelessWidget {
  const _EpiscopalRingBadge({required this.game});

  static const double size = 44;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Anello episcopale',
      child: GestureDetector(
        onTap: () {
          AudioScope.of(context).play(Sfx.uiClick);
          game.inspectInventory('Anello episcopale');
        },
        child: BloodOverlay(
          painter: const BloodPainter(
            band: 3,
            cornerRadius: 8,
            drips: <BloodDrip>[BloodDrip(0.34, 10, 3), BloodDrip(0.78, 7, 3)],
          ),
          child: Container(
            key: const ValueKey<String>('hud-episcopal-ring'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xcc241a1a),
              border: Border.all(color: BloodColors.fresh, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/sprites/episcopal_ring.png',
                width: 28,
                height: 28,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ),
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
    this.dimmed = false,
    this.drips = const <BloodDrip>[],
    this.size = TouchControls.actionButtonSize,
    super.key,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool active;
  final bool dimmed;
  final List<BloodDrip> drips;
  final double size;

  @override
  Widget build(BuildContext context) {
    final borderColor = active ? BloodColors.bright : BloodColors.fresh;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: BloodOverlay(
            painter: BloodPainter(
              band: 5,
              cornerRadius: size / 2,
              drips: drips,
              color: active ? BloodColors.bright : BloodColors.fresh,
            ),
            child: Container(
              width: size,
              height: size,
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

/// A thurible swinging on its chain, smoking: the ring at the top, the
/// three chains down to the pierced lid, the bowl under it.
final class _CenserIcon extends CustomPainter {
  const _CenserIcon();

  static const Color _brass = Color(0xffd6b25c);
  static const Color _brassDark = Color(0xff8a6a2e);
  static const Color _chain = Color(0xffd8cfbf);
  static const Color _hole = Color(0xff3a2a14);
  static const Color _smoke = Color(0x55e6ded0);

  @override
  void paint(Canvas canvas, Size size) {
    final brass = Paint()..color = _brass;
    final dark = Paint()..color = _brassDark;
    final chain = Paint()..color = _chain;
    final hole = Paint()..color = _hole;
    final smoke = Paint()..color = _smoke;
    final ring = Paint()
      ..color = _chain
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas
      ..save()
      // Drawn in a 24-wide square, then scaled to whatever it is given.
      ..scale(size.width / 24)
      ..drawCircle(const Offset(12, 2.5), 2.2, ring)
      // the three chains, the outer two splayed to the rim of the lid
      ..drawRect(const Rect.fromLTWH(11.25, 4.5, 1.5, 7.5), chain)
      ..drawRect(const Rect.fromLTWH(5.5, 8, 1.5, 4), chain)
      ..drawRect(const Rect.fromLTWH(17, 8, 1.5, 4), chain)
      ..drawRect(const Rect.fromLTWH(5.5, 8, 13, 1.5), chain)
      // the pierced lid, smoke coming through it
      ..drawPath(
        Path()
          ..moveTo(12, 9.5)
          ..lineTo(18.5, 15)
          ..lineTo(5.5, 15)
          ..close(),
        brass,
      )
      ..drawRect(const Rect.fromLTWH(9, 13, 1.5, 1.5), hole)
      ..drawRect(const Rect.fromLTWH(13.5, 13, 1.5, 1.5), hole)
      ..drawRect(const Rect.fromLTWH(4.5, 15, 15, 1.5), dark)
      // the bowl
      ..drawPath(
        Path()
          ..moveTo(5, 16.5)
          ..lineTo(19, 16.5)
          ..lineTo(16, 23.5)
          ..lineTo(8, 23.5)
          ..close(),
        brass,
      )
      ..drawRect(const Rect.fromLTWH(7, 20, 10, 1.5), dark)
      // the smoke, curling away from the lid
      ..drawRect(const Rect.fromLTWH(2.5, 11.5, 2, 1.5), smoke)
      ..drawRect(const Rect.fromLTWH(1, 8.5, 2, 1.5), smoke)
      ..drawRect(const Rect.fromLTWH(20, 11, 2, 1.5), smoke)
      ..drawRect(const Rect.fromLTWH(21.5, 7.5, 2, 1.5), smoke)
      ..restore();
  }

  @override
  bool shouldRepaint(_CenserIcon oldDelegate) => false;
}

final class _KeyIcon extends CustomPainter {
  const _KeyIcon();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()..color = const Color(0xffd6b25c);
    final dark = Paint()..color = const Color(0xff8a6a2e);
    final hole = Paint()..color = const Color(0xff3a2618);
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawCircle(const Offset(7, 8), 6, dark)
      ..drawCircle(const Offset(7, 8), 4.5, gold)
      ..drawCircle(const Offset(7, 8), 2.2, hole)
      ..drawRect(const Rect.fromLTWH(10, 7, 12, 3), gold)
      ..drawRect(const Rect.fromLTWH(17, 10, 3, 4), gold)
      ..drawRect(const Rect.fromLTWH(20, 10, 2, 3), gold)
      ..drawRect(const Rect.fromLTWH(11, 9, 11, 1), dark)
      ..restore();
  }

  @override
  bool shouldRepaint(_KeyIcon oldDelegate) => false;
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
