import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/input/game_input_controller.dart';
import 'package:stepbound/game/input/hud_icons.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/fire_frame.dart';

/// The badge of the thing Mario carries for [element], or null for the
/// elements that are buttons and not things (interacting and shooting)
/// and for an errand of another level than the one he is in.
Widget? carriedBadge(HudElement element, {required StepboundGame game}) {
  final level = element.level;
  if (level != null && level != game.progress.level) {
    return null;
  }
  return _badge(element, game: game);
}

Widget? _badge(HudElement element, {required StepboundGame game}) =>
    switch (element) {
      HudElement.ammo => _AmmoBadge(game: game),
      HudElement.incense => _QuestItemBadge(
        key: const ValueKey<String>('hud-incense'),
        game: game,
        label: strings.itemIncenseLabel,
        name: strings.itemIncense,
        drips: const <BloodDrip>[BloodDrip(0.3, 13, 4), BloodDrip(0.74, 8, 3)],
        icon: const CustomPaint(size: Size(26, 30), painter: CenserIcon()),
      ),
      HudElement.barKey => _QuestItemBadge(
        key: const ValueKey<String>('hud-bar-key'),
        game: game,
        label: strings.itemBarKey,
        drips: const <BloodDrip>[BloodDrip(0.24, 8, 3), BloodDrip(0.68, 12, 4)],
        icon: const CustomPaint(size: Size(28, 28), painter: KeyIcon()),
      ),
      HudElement.episcopalRing => _QuestItemBadge(
        key: const ValueKey<String>('hud-episcopal-ring'),
        game: game,
        label: strings.itemEpiscopalRing,
        drips: const <BloodDrip>[BloodDrip(0.34, 10, 3), BloodDrip(0.78, 7, 3)],
        icon: Image.asset(
          'assets/objects/episcopal_ring.png',
          width: 28,
          height: 28,
          // Without a fit, a picture smaller than its box is drawn at its
          // own size and not blown up to fill it.
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
      HudElement.duomoKey => _QuestItemBadge(
        key: const ValueKey<String>('hud-duomo-key'),
        game: game,
        label: strings.itemDuomoKey,
        drips: const <BloodDrip>[BloodDrip(0.28, 11, 4), BloodDrip(0.7, 9, 3)],
        icon: const CustomPaint(size: Size(28, 28), painter: ChurchKeyIcon()),
      ),
      HudElement.palazzoKey => _QuestItemBadge(
        key: const ValueKey<String>('hud-palazzo-key'),
        game: game,
        label: strings.itemPalazzoKey,
        drips: const <BloodDrip>[BloodDrip(0.3, 10, 3), BloodDrip(0.72, 8, 3)],
        icon: const CustomPaint(size: Size(28, 28), painter: KeyIcon()),
      ),
      HudElement.grapplingHook => _QuestItemBadge(
        key: const ValueKey<String>('hud-grappling-hook'),
        game: game,
        label: strings.itemGrapplingHook,
        drips: const <BloodDrip>[BloodDrip(0.3, 9, 3), BloodDrip(0.76, 12, 4)],
        icon: Image.asset(
          'assets/objects/grappling_hook.png',
          width: 28,
          height: 28,
          // Without a fit, a picture smaller than its box is drawn at its
          // own size and not blown up to fill it.
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
      HudElement.goldIngot => _QuestItemBadge(
        key: const ValueKey<String>('hud-gold-ingot'),
        game: game,
        label: strings.itemGoldIngot,
        drips: const <BloodDrip>[BloodDrip(0.32, 9, 3), BloodDrip(0.74, 11, 4)],
        icon: Image.asset(
          'assets/objects/gold_ingot.png',
          width: 28,
          height: 28,
          // Without a fit, a picture smaller than its box is drawn at its
          // own size and not blown up to fill it.
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
      HudElement.colosseumTicket => _QuestItemBadge(
        key: const ValueKey<String>('hud-colosseum-ticket'),
        game: game,
        label: strings.itemColosseumTicket,
        drips: const <BloodDrip>[BloodDrip(0.26, 10, 3), BloodDrip(0.7, 8, 4)],
        icon: Image.asset(
          'assets/objects/colosseum_ticket.png',
          width: 28,
          height: 28,
          // Without a fit, a picture smaller than its box is drawn at its
          // own size and not blown up to fill it.
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
      HudElement.molotov => _MolotovBadge(game: game),
      HudElement.rockets => _RocketBadge(game: game),
      HudElement.interact || HudElement.shoot => null,
    };

/// The side of every badge in the corner.
const double _badgeSize = 44;

/// The gap between two badges in the row of what Mario carries, the same
/// between any two of them: wide enough for a count written over the
/// corner of the one after it to spill into without touching the one
/// before.
const double carriedBadgeGap = 11;

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
/// count written in blood over the bottom-left corner, spilling past it.
/// Until the pistol is found the badge is a button nothing can press yet:
/// greyed out and deaf to taps, though the count keeps up with every round
/// picked up. With the pistol and molotovs too, a tap takes the pistol in
/// hand and the one in hand burns round its rim; with the pistol alone, a
/// tap tells how many rounds there are.
final class _AmmoBadge extends StatelessWidget {
  const _AmmoBadge({required this.game});

  final StepboundGame game;

  /// How far the count spills past the left and bottom edges.
  static const double spill = 7;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.ammoLoaded,
      builder: (context, loaded, _) => ValueListenableBuilder<bool>(
        valueListenable: game.hasGun,
        builder: (context, hasGun, _) => ListenableBuilder(
          // The flames also follow whether there is another weapon.
          listenable: game.weaponsCarried,
          builder: (context, _) {
            final isEmpty = loaded == 0;
            final golden = game.progress.hasGoldenPistol;
            final pistol = golden ? strings.goldenPistol : strings.pistol;
            // Flames only when there is a choice: the pistol alone is simply
            // the pistol.
            final inHand =
                hasGun &&
                game.input.weapon.value == Weapon.pistol &&
                game.input.hasWeaponChoice;
            final box = Container(
              key: const ValueKey<String>('touch-ammo'),
              width: _badgeSize,
              height: _badgeSize,
              decoration: _frame(
                rim: inHand
                    ? inHandBorder
                    : !hasGun
                    ? BloodColors.dried
                    : isEmpty
                    ? BloodColors.bright
                    : BloodColors.fresh,
              ),
              // A little up and right of the middle, so the count does not
              // cover the grip.
              child: Align(
                alignment: const Alignment(0.2, -0.3),
                child: _Mirrored(
                  CustomPaint(
                    size: const Size(34, 23.4),
                    painter: ColourPistolIcon(golden: golden),
                  ),
                ),
              ),
            );
            var frame = inHand
                ? FireFrame(child: box)
                : BloodOverlay(
                    painter: const BloodPainter(
                      band: 3,
                      cornerRadius: 8,
                      drips: <BloodDrip>[
                        BloodDrip(0.22, 11, 4),
                        BloodDrip(0.8, 7, 3),
                      ],
                    ),
                    child: box,
                  );
            if (!hasGun) {
              frame = ColorFiltered(colorFilter: _greyed, child: frame);
            }
            return Semantics(
              button: true,
              enabled: hasGun,
              selected: inHand,
              label: !hasGun
                  ? strings.pistolMissing(pistol, loaded)
                  : inHand
                  ? strings.pistolInHand(pistol, loaded)
                  : strings.pistolToTake(pistol, loaded),
              child: GestureDetector(
                onTap: hasGun
                    ? () {
                        AudioScope.of(context).play(Sfx.uiClick);
                        game.tapWeapon(Weapon.pistol);
                      }
                    : null,
                child: Padding(
                  // Room under it for the count spilling out; to the left it
                  // spills into the gap before the next badge, which is as
                  // wide as every other gap in the row (see
                  // [carriedBadgeGap]).
                  padding: const EdgeInsets.only(bottom: spill),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      frame,
                      Positioned(
                        left: -spill,
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
      ),
    );
  }
}

/// The rim of the weapon in hand, under its flames.
const Color inHandBorder = Color(0xffffa53a);

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

/// An item's picture turned to face the other way: the row of things
/// Mario carries starts from the right, and they face into it.
final class _Mirrored extends StatelessWidget {
  const _Mirrored(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Transform.flip(flipX: true, child: child);
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
            child: Center(child: _Mirrored(icon)),
          ),
        ),
      ),
    );
  }
}

/// The molotovs Mario carries, counted like the bullets, shown only while
/// there is one. A tap puts one in his hand in place of the pistol: the
/// weapon in hand burns round its rim, and aiming then picks where it
/// lands.
final class _MolotovBadge extends StatelessWidget {
  const _MolotovBadge({required this.game});

  static const double spill = _AmmoBadge.spill;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.molotovs,
      builder: (context, count, _) => ListenableBuilder(
        listenable: game.weaponsCarried,
        builder: (context, _) {
          final inHand =
              game.input.weapon.value == Weapon.molotov &&
              game.input.hasWeaponChoice;
          final box = Container(
            key: const ValueKey<String>('hud-molotov'),
            width: _badgeSize,
            height: _badgeSize,
            decoration: _frame(rim: inHand ? inHandBorder : BloodColors.fresh),
            child: const Align(
              alignment: Alignment(0.2, -0.2),
              child: _Mirrored(
                CustomPaint(size: Size(24, 32), painter: MolotovIcon()),
              ),
            ),
          );
          final frame = inHand
              ? FireFrame(child: box)
              : BloodOverlay(
                  painter: const BloodPainter(
                    band: 3,
                    cornerRadius: 8,
                    drips: <BloodDrip>[
                      BloodDrip(0.34, 9, 3),
                      BloodDrip(0.7, 12, 4),
                    ],
                  ),
                  child: box,
                );
          return Semantics(
            button: true,
            selected: inHand,
            label: inHand
                ? strings.molotovInHand(count)
                : strings.molotovToTake(count),
            child: GestureDetector(
              onTap: () {
                AudioScope.of(context).play(Sfx.uiClick);
                game.tapWeapon(Weapon.molotov);
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: spill),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    frame,
                    Positioned(
                      left: -spill,
                      bottom: -spill,
                      child: _BloodCount(
                        key: const ValueKey<String>('hud-molotov-count'),
                        text: '×$count',
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

/// The rocket launcher and its rounds, like the pistol before it is found:
/// until Mario has the launcher itself the badge is greyed out and deaf to
/// taps, and only the count of rounds found keeps up. With the launcher
/// and another weapon too, a tap takes the launcher in hand and the one
/// in hand burns round its rim; with the launcher alone, a tap tells how
/// many rounds there are.
final class _RocketBadge extends StatelessWidget {
  const _RocketBadge({required this.game});

  static const double spill = _AmmoBadge.spill;
  final StepboundGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.rockets,
      builder: (context, count, _) => ListenableBuilder(
        listenable: game.weaponsCarried,
        builder: (context, _) {
          final hasLauncher = game.hasRocketLauncher.value;
          final inHand =
              hasLauncher &&
              game.input.weapon.value == Weapon.rocketLauncher &&
              game.input.hasWeaponChoice;
          final box = Container(
            key: const ValueKey<String>('hud-rockets'),
            width: _badgeSize,
            height: _badgeSize,
            decoration: _frame(
              rim: inHand
                  ? inHandBorder
                  : !hasLauncher
                  ? BloodColors.dried
                  : count == 0
                  ? BloodColors.bright
                  : BloodColors.fresh,
            ),
            child: Align(
              alignment: const Alignment(0.2, -0.3),
              child: _Mirrored(
                Image.asset(
                  'assets/objects/rocket_launcher.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
          );
          var frame = inHand
              ? FireFrame(child: box)
              : BloodOverlay(
                  painter: const BloodPainter(
                    band: 3,
                    cornerRadius: 8,
                    drips: <BloodDrip>[
                      BloodDrip(0.26, 10, 3),
                      BloodDrip(0.72, 8, 3),
                    ],
                  ),
                  child: box,
                );
          if (!hasLauncher) {
            frame = ColorFiltered(colorFilter: _greyed, child: frame);
          }
          return Semantics(
            button: true,
            enabled: hasLauncher,
            selected: inHand,
            label: !hasLauncher
                ? strings.launcherMissing(count)
                : inHand
                ? strings.launcherInHand(count)
                : strings.launcherToTake(count),
            child: GestureDetector(
              onTap: hasLauncher
                  ? () {
                      AudioScope.of(context).play(Sfx.uiClick);
                      game.tapWeapon(Weapon.rocketLauncher);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.only(bottom: spill),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    frame,
                    Positioned(
                      left: -spill,
                      bottom: -spill,
                      child: Opacity(
                        opacity: hasLauncher ? 1 : 0.6,
                        child: _BloodCount(
                          key: const ValueKey<String>('hud-rockets-count'),
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
