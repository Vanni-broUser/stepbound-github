import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/stepbound_game.dart';

final class TouchControls extends StatelessWidget {
  const TouchControls({required this.game, super.key});

  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(10),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            bottom: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: game.aiming,
              builder: (context, isAiming, child) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _ActionButton(
                      key: const ValueKey<String>('touch-shoot'),
                      letter: 'B',
                      label: isAiming ? 'SPARA' : 'MIRA',
                      active: isAiming,
                      onPressed: game.pressShoot,
                    ),
                    const SizedBox(width: 10),
                    _ActionButton(
                      key: const ValueKey<String>('touch-interact'),
                      letter: 'A',
                      label: isAiming ? 'ANNULLA' : 'AZIONE',
                      onPressed: game.pressInteract,
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(right: 0, bottom: 0, child: _DirectionalPad(game: game)),
        ],
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
              direction: Direction.north,
              icon: Icons.keyboard_arrow_up,
              game: game,
            ),
          ),
          Positioned(
            top: buttonSize,
            child: _DirectionButton(
              key: const ValueKey<String>('touch-left'),
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
    super.key,
  });

  final Direction direction;
  final IconData icon;
  final StepboundGame game;

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
        child: Container(
          width: _DirectionalPad.buttonSize,
          height: _DirectionalPad.buttonSize,
          decoration: BoxDecoration(
            color: const Color(0xcc20282a),
            border: Border.all(color: const Color(0xff8a8377), width: 2),
            borderRadius: BorderRadius.circular(5),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
            ],
          ),
          child: Icon(icon, color: const Color(0xffd8cfbf), size: 32),
        ),
      ),
    );
  }
}

final class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.letter,
    required this.label,
    required this.onPressed,
    this.active = false,
    super.key,
  });

  final String letter;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final borderColor = active
        ? const Color(0xffe4705f)
        : const Color(0xff8a8377);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xdd4a2823) : const Color(0xcc39332c),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                letter,
                style: TextStyle(
                  color: borderColor,
                  fontFamily: 'monospace',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xffd8cfbf),
                  fontFamily: 'monospace',
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
