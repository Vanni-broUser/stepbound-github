import 'package:flutter/material.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/input/action_zone.dart';
import 'package:stepbound/game/input/hud_badges.dart';
import 'package:stepbound/game/input/move_zone.dart';
import 'package:stepbound/game/input/pinch_zone.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/blood_decor.dart';

/// What is drawn over the game while nothing else covers it: the two
/// halves of the screen that walk ([MoveZone]) and act ([ActionZone]),
/// the pinch that zooms ([PinchZone]) over both, and, in the corners, the
/// menu button and the badges of what Mario carries (hud_badges.dart).
final class TouchControls extends StatelessWidget {
  const TouchControls({required this.game, super.key});

  final StepboundGame game;

  static const double actionButtonSize = 54;

  /// The way out, in the far corner from the thumbs: smaller than the
  /// action buttons, so it is never the one hit by mistake.
  static const double menuButtonSize = 38;

  @override
  Widget build(BuildContext context) {
    // No buttons to play: the left half of the screen walks, the right
    // half interacts and shoots, two fingers zoom. What is drawn on top
    // only shows state, plus the menu and the items carried, which take
    // their own taps.
    return ValueListenableBuilder<Set<HudElement>>(
      valueListenable: game.hud,
      builder: (context, unlocked, _) {
        final badges = <Widget>[
          for (final element in unlocked) ?carriedBadge(element, game: game),
        ];
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: PinchZone(
                game: game,
                child: Row(
                  children: <Widget>[
                    Expanded(child: MoveZone(game: game)),
                    Expanded(child: ActionZone(game: game)),
                  ],
                ),
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(10),
              child: Stack(
                children: <Widget>[
                  // Always there, unlocked or not: it is the way out, not
                  // something the tutorial hands over.
                  Positioned(right: 0, top: 0, child: _PauseButton(game: game)),
                  // What Mario carries, in the order he picked it up: the
                  // bullets counted, then whatever the story has him hold
                  // for someone. One row in the far top corner from the
                  // menu, out of both thumbs' way.
                  if (badges.isNotEmpty)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Wrap(spacing: 8, runSpacing: 8, children: badges),
                    ),
                ],
              ),
            ),
          ],
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

final class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    required this.size,
    this.drips = const <BloodDrip>[],
    super.key,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final List<BloodDrip> drips;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: BloodOverlay(
          painter: BloodPainter(band: 5, cornerRadius: size / 2, drips: drips),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xcc2e2020),
              border: Border.all(color: BloodColors.fresh, width: 2),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
              ],
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
