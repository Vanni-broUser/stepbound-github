import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/input/game_input_controller.dart';
import 'package:stepbound/game/input/hud_icons.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/blood_decor.dart';

/// The badge of the thing Mario carries for [element], or null for the
/// elements that are buttons and not things: interacting and shooting.
Widget? carriedBadge(HudElement element, {required StepboundGame game}) =>
    switch (element) {
      HudElement.ammo => _AmmoBadge(game: game),
      HudElement.incense => _QuestItemBadge(
        key: const ValueKey<String>('hud-incense'),
        game: game,
        label: 'Incenso per Don Angelo',
        name: 'Incenso',
        drips: const <BloodDrip>[BloodDrip(0.3, 13, 4), BloodDrip(0.74, 8, 3)],
        icon: const CustomPaint(size: Size(26, 30), painter: CenserIcon()),
      ),
      HudElement.barKey => _QuestItemBadge(
        key: const ValueKey<String>('hud-bar-key'),
        game: game,
        label: 'Chiave del Bar Arcobaleno',
        drips: const <BloodDrip>[BloodDrip(0.24, 8, 3), BloodDrip(0.68, 12, 4)],
        icon: const CustomPaint(size: Size(28, 28), painter: KeyIcon()),
      ),
      HudElement.episcopalRing => _QuestItemBadge(
        key: const ValueKey<String>('hud-episcopal-ring'),
        game: game,
        label: 'Anello episcopale',
        drips: const <BloodDrip>[BloodDrip(0.34, 10, 3), BloodDrip(0.78, 7, 3)],
        icon: Image.asset(
          'assets/objects/episcopal_ring.png',
          width: 28,
          height: 28,
          filterQuality: FilterQuality.none,
        ),
      ),
      HudElement.duomoKey => _QuestItemBadge(
        key: const ValueKey<String>('hud-duomo-key'),
        game: game,
        label: 'Chiave del Duomo',
        drips: const <BloodDrip>[BloodDrip(0.28, 11, 4), BloodDrip(0.7, 9, 3)],
        icon: const CustomPaint(size: Size(28, 28), painter: ChurchKeyIcon()),
      ),
      HudElement.molotov => _MolotovBadge(game: game),
      HudElement.interact || HudElement.shoot => null,
    };

/// The side of every badge in the corner.
const double _badgeSize = 44;

/// The frame every badge sits in: a dark square with a bloody rim.
BoxDecoration _frame({Color fill = const Color(0xcc241a1a), Color? rim}) =>
    BoxDecoration(
      color: fill,
      border: Border.all(color: rim ?? BloodColors.fresh, width: 2),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0x99000000), offset: Offset(2, 2)),
      ],
    );

/// A disabled badge: the colour drained out of it, and half gone.
const ColorFilter _greyed = ColorFilter.matrix(<double>[
  0.30, 0.59, 0.11, 0, 0, //
  0.30, 0.59, 0.11, 0, 0, //
  0.30, 0.59, 0.11, 0, 0, //
  0, 0, 0, 0.5, 0,
]);

/// The pistol and the bullets Mario carries, in the row of the things he
/// holds up in the corner: the pistol in colour like the rest, and the
/// count written in blood over the bottom-right corner, spilling past it.
/// Until the pistol is found the badge is a button nothing can press yet:
/// greyed out and deaf to taps, though the count keeps up with every round
/// picked up. With the pistol, a tap tells how many there are.
final class _AmmoBadge extends StatelessWidget {
  const _AmmoBadge({required this.game});

  final StepboundGame game;

  /// How far the count spills past the right and bottom edges.
  static const double spill = 7;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.ammoLoaded,
      builder: (context, loaded, _) => ValueListenableBuilder<bool>(
        valueListenable: game.hasGun,
        builder: (context, hasGun, _) {
          final isEmpty = loaded == 0;
          Widget frame = BloodOverlay(
            painter: const BloodPainter(
              band: 3,
              cornerRadius: 8,
              drips: <BloodDrip>[BloodDrip(0.22, 11, 4), BloodDrip(0.8, 7, 3)],
            ),
            child: Container(
              key: const ValueKey<String>('touch-ammo'),
              width: _badgeSize,
              height: _badgeSize,
              decoration: _frame(
                rim: !hasGun
                    ? BloodColors.dried
                    : isEmpty
                    ? BloodColors.bright
                    : BloodColors.fresh,
              ),
              // A little up and left of the middle, so the count does not
              // cover the grip.
              child: const Align(
                alignment: Alignment(-0.2, -0.3),
                child: CustomPaint(
                  size: Size(34, 23.4),
                  painter: ColourPistolIcon(),
                ),
              ),
            ),
          );
          if (!hasGun) {
            frame = ColorFiltered(colorFilter: _greyed, child: frame);
          }
          return Semantics(
            button: true,
            enabled: hasGun,
            label: hasGun
                ? 'Pistola, proiettili: $loaded'
                : 'Pistola da trovare, proiettili: $loaded',
            child: GestureDetector(
              onTap: hasGun
                  ? () {
                      AudioScope.of(context).play(Sfx.uiClick);
                      game.inspectAmmo();
                    }
                  : null,
              child: Padding(
                // Room for the count spilling out, so the row does not lay
                // the next badge over it.
                padding: const EdgeInsets.only(right: spill, bottom: spill),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    frame,
                    Positioned(
                      right: -spill,
                      bottom: -spill,
                      child: Opacity(
                        opacity: hasGun ? 1 : 0.6,
                        child: _BloodCount(
                          key: const ValueKey<String>('touch-ammo-count'),
                          text: '×$loaded',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A count written with a finger dipped in blood: thick red strokes gone
/// dark at the edges, and drops running down from the foot of the figures.
final class _BloodCount extends StatelessWidget {
  const _BloodCount({required this.text, super.key});

  final String text;

  static const double fontSize = 17;

  static TextStyle _style({Paint? foreground, Color? color}) => TextStyle(
    color: color,
    foreground: foreground,
    fontFamily: 'monospace',
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: -1,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _BloodRunPainter(text.length),
      child: Stack(
        children: <Widget>[
          // The dried rim, then the wet blood over it.
          Text(
            text,
            style: _style(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xff2a0404),
            ),
          ),
          Text(text, style: _style(color: BloodColors.fresh)),
          Text(
            text,
            style: _style(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = BloodColors.bright,
            ),
          ),
        ],
      ),
    );
  }
}

/// The drops running down from the foot of a blood count: one under every
/// other figure, of lengths that do not repeat from one to the next.
final class _BloodRunPainter extends CustomPainter {
  const _BloodRunPainter(this.figures);

  final int figures;

  static const List<double> _lengths = <double>[5, 3, 6, 4];

  @override
  void paint(Canvas canvas, Size size) {
    final blood = Paint()..color = BloodColors.fresh;
    final drop = Paint()..color = BloodColors.bright;
    final step = size.width / math.max(1, figures);
    for (var i = 0; i < figures; i += 2) {
      final x = step * (i + 0.6);
      final length = _lengths[i % _lengths.length];
      final top = size.height - 3;
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 1, top, 2, length),
            const Radius.circular(1),
          ),
          blood,
        )
        ..drawCircle(Offset(x, top + length), 1.6, drop);
    }
  }

  @override
  bool shouldRepaint(_BloodRunPainter oldDelegate) =>
      oldDelegate.figures != figures;
}

/// Something Mario carries for someone, hanging in the top corner for as
/// long as he does: the errand he is on, always in sight. A tap names it,
/// as [name], or as [label] when the two are the same.
final class _QuestItemBadge extends StatelessWidget {
  const _QuestItemBadge({
    required this.game,
    required this.label,
    required this.drips,
    required this.icon,
    this.name,
    super.key,
  });

  final StepboundGame game;

  /// What the badge is, for whoever cannot see it.
  final String label;

  /// What a tap on it says; [label] when null.
  final String? name;
  final List<BloodDrip> drips;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          AudioScope.of(context).play(Sfx.uiClick);
          game.inspectInventory(name ?? label);
        },
        child: BloodOverlay(
          painter: BloodPainter(band: 3, cornerRadius: 8, drips: drips),
          child: Container(
            width: _badgeSize,
            height: _badgeSize,
            decoration: _frame(),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

/// The molotovs Mario carries, counted like the bullets. A tap puts one
/// in his hand in place of the pistol, and another puts it back: the
/// badge in hand is lit, and aiming then picks where it lands.
final class _MolotovBadge extends StatelessWidget {
  const _MolotovBadge({required this.game});

  static const double spill = _AmmoBadge.spill;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.molotovs,
      builder: (context, count, _) => ValueListenableBuilder<Weapon>(
        valueListenable: game.input.weapon,
        builder: (context, weapon, _) {
          final inHand = weapon == Weapon.molotov;
          Widget frame = BloodOverlay(
            painter: const BloodPainter(
              band: 3,
              cornerRadius: 8,
              drips: <BloodDrip>[BloodDrip(0.34, 9, 3), BloodDrip(0.7, 12, 4)],
            ),
            child: Container(
              key: const ValueKey<String>('hud-molotov'),
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                color: inHand
                    ? const Color(0xcc4a1a0c)
                    : const Color(0xcc241a1a),
                border: Border.all(
                  color: inHand ? const Color(0xffffa53a) : BloodColors.fresh,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: <BoxShadow>[
                  const BoxShadow(
                    color: Color(0x99000000),
                    offset: Offset(2, 2),
                  ),
                  if (inHand)
                    const BoxShadow(color: Color(0x88ff7a1c), blurRadius: 10),
                ],
              ),
              child: const Align(
                alignment: Alignment(-0.2, -0.2),
                child: CustomPaint(size: Size(24, 32), painter: MolotovIcon()),
              ),
            ),
          );
          if (count == 0) {
            frame = ColorFiltered(colorFilter: _greyed, child: frame);
          }
          return Semantics(
            button: true,
            enabled: count > 0,
            selected: inHand,
            label: inHand
                ? 'Molotov in mano: $count'
                : 'Molotov: $count, tocca per prenderne una',
            child: GestureDetector(
              onTap: count > 0 || inHand
                  ? () {
                      AudioScope.of(context).play(Sfx.uiClick);
                      game.input.toggleWeapon();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.only(right: spill, bottom: spill),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    frame,
                    Positioned(
                      right: -spill,
                      bottom: -spill,
                      child: Opacity(
                        opacity: count > 0 ? 1 : 0.6,
                        child: _BloodCount(
                          key: const ValueKey<String>('hud-molotov-count'),
                          text: '×$count',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
