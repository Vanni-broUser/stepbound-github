import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/report/telemetry.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/settings_menu.dart';

enum _MenuPage { home, newGame, load, settings, credits }

/// The first screen: the Stepbound sign from the title card, then a new
/// game in one of the four slots or a saved game to resume, the settings
/// (sound, language, anonymous data) and the credits.
final class MainMenu extends StatefulWidget {
  const MainMenu({
    required this.saves,
    required this.onNewGame,
    required this.onLoad,
    this.linkNotice,
    this.telemetry,
    this.onReportProblem,
    super.key,
  });

  static const String logo = 'assets/story/ui/logo.png';

  /// The city overrun: zombies chasing people through a burning street.
  ///
  /// The app draws it over the whole screen, bands included (see
  /// [MenuBackdrop]); the menu itself stays on the 16:9 picture.
  static const String background = 'assets/story/ui/menu_background.jpg';

  /// The classic line at the foot of the first screen.
  static String get disclaimer => strings.menuDisclaimer;

  final SaveRepository saves;

  /// What the gift link the app was just opened with did.
  final LinkNotice? linkNotice;

  /// Whose data switch the settings show; the app's own when null.
  final Telemetry? telemetry;

  /// Reports a problem from the settings (see
  /// [SettingsChoices.onReportProblem]); not offered when null.
  final Future<bool> Function(String message)? onReportProblem;

  /// Starts the story; the game will save in the given slot.
  final void Function(int slot) onNewGame;
  final void Function(SaveGame save) onLoad;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

final class _MainMenuState extends State<MainMenu> {
  _MenuPage _page = _MenuPage.home;

  /// What the slots hold, once read; until then they are neither empty
  /// nor taken, and cannot be picked: a slot that turns out to hold a
  /// game is never written over without the question.
  List<SaveRead>? _slots;

  /// The skins given to each slot by gift links: see
  /// [SaveRepository.loadGifts].
  List<Set<PlayerOutfit>> _gifts = List<Set<PlayerOutfit>>.filled(
    SaveRepository.slotCount,
    const <PlayerOutfit>{},
  );

  /// Whether the player has put the [MainMenu.linkNotice] away.
  bool _noticeClosed = false;

  /// Slot waiting for the "overwrite?" answer.
  int? _confirming;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final slots = await widget.saves.all();
    if (!mounted) {
      return;
    }
    setState(() => _slots = slots);
    // Only a label: the slots need not wait for it.
    final gifts = <Set<PlayerOutfit>>[
      for (var slot = 1; slot <= SaveRepository.slotCount; slot++)
        await widget.saves.loadGifts(slot),
    ];
    if (mounted) {
      setState(() => _gifts = gifts);
    }
  }

  void _open(_MenuPage page) => setState(() {
    _page = page;
    _confirming = null;
  });

  void _pickNewGameSlot(int slot) {
    final slots = _slots;
    if (slots == null) {
      return;
    }
    if (slots[slot - 1] is LoadedSave && _confirming != slot) {
      setState(() => _confirming = slot);
      return;
    }
    widget.onNewGame(slot);
  }

  /// Hours and minutes played, as the slot shows them.
  static String _played(Duration played) {
    final minutes = (played.inMinutes % 60).toString().padLeft(2, '0');
    return '${played.inHours}h ${minutes}m';
  }

  /// A slot whose save is damaged says so, and cannot be loaded; one whose
  /// save was damaged but had a good one before it shows that one, marked
  /// as the backup it is; one holding the game as it was put down, since
  /// its last campfire, says that too.
  String _slotLabel(int slot, SaveRead read) => switch (read) {
    EmptySave() => 'SLOT $slot\n${strings.menuSlotEmpty}',
    DamagedSave() => 'SLOT $slot\n${strings.menuSlotDamaged}',
    LoadedSave(:final save, :final fromBackup, :final suspended) =>
      'SLOT $slot  ${strings.date(save.savedAt)}'
          '${fromBackup ? '  ${strings.menuSlotBackup}' : ''}'
          '${suspended ? '  ${strings.menuSlotSuspended}' : ''}\n'
          '${strings.place(save.place)}  ·  ${_played(save.played)}',
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1.0;
        return Stack(
          key: const ValueKey<String>('main-menu'),
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(8 * unit),
              child: Column(
                children: <Widget>[
                  Image.asset(
                    MainMenu.logo,
                    // Smaller where there is more under it: the settings
                    // have the most.
                    height:
                        constraints.maxHeight *
                        switch (_page) {
                          _MenuPage.home => 0.32,
                          _MenuPage.settings => 0.13,
                          _ => 0.22,
                        },
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 6 * unit),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(child: _buttons(unit)),
                    ),
                  ),
                ],
              ),
            ),
            if (_page == _MenuPage.home)
              Align(
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.all(4 * unit),
                    child: Text(
                      MainMenu.disclaimer,
                      key: const ValueKey<String>('menu-disclaimer'),
                      textAlign: TextAlign.center,
                      style: menuTextStyle(
                        unit,
                        5,
                      ).copyWith(color: const Color(0xccd8ccbb)),
                    ),
                  ),
                ),
              ),
            if (widget.linkNotice case final notice? when !_noticeClosed)
              _LinkNoticePanel(
                notice: notice,
                unit: unit,
                onClose: () => setState(() => _noticeClosed = true),
              ),
          ],
        );
      },
    );
  }

  Widget _buttons(double unit) {
    final hasSaves = _slots?.any((slot) => slot is LoadedSave) ?? false;
    final buttons = switch (_page) {
      _MenuPage.home => <Widget>[
        MenuButton(
          key: const ValueKey<String>('menu-new-game'),
          label: strings.menuNewGame,
          unit: unit,
          onPressed: () => _open(_MenuPage.newGame),
        ),
        MenuButton(
          key: const ValueKey<String>('menu-load'),
          label: strings.menuLoadGame,
          unit: unit,
          onPressed: hasSaves ? () => _open(_MenuPage.load) : null,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MenuButton(
              key: const ValueKey<String>('menu-settings'),
              label: strings.settingsTitle,
              unit: unit,
              compact: true,
              width: MenuButton.halfWidth,
              onPressed: () => _open(_MenuPage.settings),
            ),
            SizedBox(width: MenuButton.pairGap * unit),
            MenuButton(
              key: const ValueKey<String>('menu-credits'),
              label: strings.menuCredits,
              unit: unit,
              compact: true,
              width: MenuButton.halfWidth,
              onPressed: () => _open(_MenuPage.credits),
            ),
          ],
        ),
      ],
      _MenuPage.settings => <Widget>[
        SettingsChoices(
          unit: unit,
          telemetry: widget.telemetry,
          onReportProblem: widget.onReportProblem,
          onBack: () => _open(_MenuPage.home),
        ),
      ],
      _MenuPage.credits => <Widget>[
        MenuHeading(text: strings.menuCredits, unit: unit),
        _Credits(unit: unit),
        MenuButton(
          key: const ValueKey<String>('menu-back'),
          label: strings.back,
          unit: unit,
          compact: true,
          onPressed: () => _open(_MenuPage.home),
        ),
      ],
      _MenuPage.newGame || _MenuPage.load => <Widget>[
        MenuHeading(
          text: _page == _MenuPage.newGame
              ? strings.menuChooseNewSlot
              : strings.menuChooseSave,
          unit: unit,
        ),
        // Two by two, so all four slots fit on a phone in landscape.
        Wrap(
          spacing: 5 * unit,
          runSpacing: 5 * unit,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (var slot = 1; slot <= SaveRepository.slotCount; slot++)
              _slotButton(slot, unit),
          ],
        ),
        MenuButton(
          key: const ValueKey<String>('menu-back'),
          label: strings.back,
          unit: unit,
          compact: true,
          onPressed: () => _open(_MenuPage.home),
        ),
      ],
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final button in buttons)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 2.5 * unit),
            child: button,
          ),
      ],
    );
  }

  Widget _slotButton(int slot, double unit) {
    if (_confirming == slot) {
      return MenuButton(
        key: ValueKey<String>('menu-slot-$slot-confirm'),
        label: strings.menuOverwrite(slot),
        unit: unit,
        compact: true,
        warning: true,
        onPressed: () => _pickNewGameSlot(slot),
      );
    }
    final read = _slots?[slot - 1];
    final save = read?.game;
    final button = MenuButton(
      key: ValueKey<String>('menu-slot-$slot'),
      // Still being read: neither empty nor taken, and not to be picked.
      label: read == null ? 'SLOT $slot\n...' : _slotLabel(slot, read),
      unit: unit,
      compact: true,
      onPressed: switch (_page) {
        _ when read == null => null,
        _MenuPage.newGame => () => _pickNewGameSlot(slot),
        _ when save != null => () => widget.onLoad(save),
        _ => null,
      },
    );
    if (_gifts[slot - 1].isEmpty) {
      return button;
    }
    // Pinned across the top right corner, like a label stuck on a parcel.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        button,
        Positioned(
          top: -4 * unit,
          right: -5 * unit,
          child: IgnorePointer(
            child: GiftTag(
              key: ValueKey<String>('menu-slot-$slot-gift'),
              unit: unit,
            ),
          ),
        ),
      ],
    );
  }
}

/// What opening a gift link did, as the main menu tells it.
sealed class LinkNotice {
  const LinkNotice();
}

/// The link gave [outfit] to the four slots.
final class SkinGiftNotice extends LinkNotice {
  const SkinGiftNotice(this.outfit);

  final PlayerOutfit outfit;
}

/// The link had expired, or was not one the game made: nothing given.
final class InvalidLinkNotice extends LinkNotice {
  const InvalidLinkNotice();
}

/// A [LinkNotice] over the menu until put away: the skin given,
/// with Mario wearing it, or the link that gave nothing.
final class _LinkNoticePanel extends StatelessWidget {
  const _LinkNoticePanel({
    required this.notice,
    required this.unit,
    required this.onClose,
  });

  final LinkNotice notice;
  final double unit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final content = switch (notice) {
      SkinGiftNotice(:final outfit) => <Widget>[
        BloodyTitle(strings.menuGift, fontSize: 15 * unit),
        Text(
          strings.menuSkin(outfit.label),
          key: const ValueKey<String>('skin-gift-name'),
          textAlign: TextAlign.center,
          style: menuTextStyle(unit, 9).copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 3 * unit),
        Image.asset(
          outfit.portrait,
          key: const ValueKey<String>('skin-gift-portrait'),
          height: 96 * unit,
          fit: BoxFit.contain,
        ),
      ],
      InvalidLinkNotice() => <Widget>[
        BloodyTitle(strings.menuLinkExpired, fontSize: 15 * unit),
        BloodyTitle(strings.menuLinkInvalid, fontSize: 15 * unit),
      ],
    };
    return ColoredBox(
      key: ValueKey<String>(
        notice is SkinGiftNotice ? 'skin-gift-notice' : 'skin-link-invalid',
      ),
      // Clear, but it still keeps taps off the menu underneath.
      color: const Color(0x00000000),
      child: Center(
        child: MenuPanel(
          unit: unit,
          opaque: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ...content,
              SizedBox(height: 5 * unit),
              MenuButton(
                key: const ValueKey<String>('skin-link-close'),
                label: strings.ok,
                unit: unit,
                compact: true,
                width: MenuButton.halfWidth,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "REGALO" on a slot that holds gifts, written in blood on a scrap of
/// label, tilted, with a couple of drips running off it.
final class GiftTag extends StatelessWidget {
  const GiftTag({required this.unit, super.key});

  final double unit;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.14,
      child: BloodOverlay(
        painter: BloodPainter(
          band: 1.2 * unit,
          cornerRadius: 1.5 * unit,
          drips: <BloodDrip>[
            BloodDrip(0.2, 2.6 * unit, 1.4 * unit),
            BloodDrip(0.72, 3.2 * unit, 1.6 * unit),
          ],
          // Dripped off the label onto the slot below.
          drops: <BloodDrop>[
            BloodDrop(0.3, 1.3, 0.9 * unit),
            BloodDrop(0.78, 1.5, 1.1 * unit),
          ],
          color: BloodColors.bright,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 4 * unit,
            vertical: 1.5 * unit,
          ),
          decoration: BoxDecoration(
            color: const Color(0xffe8dccb),
            border: Border.all(color: BloodColors.fresh, width: 1.2 * unit),
            borderRadius: BorderRadius.circular(1.5 * unit),
            boxShadow: <BoxShadow>[
              BoxShadow(color: const Color(0x99000000), blurRadius: 2 * unit),
            ],
          ),
          child: Text(
            strings.menuGift,
            style: TextStyle(
              color: BloodColors.fresh,
              fontFamily: 'monospace',
              fontSize: 7 * unit,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2 * unit,
              height: 1.1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// The pale letters of the menus, with a black shadow so they read over
/// any picture: [size] in virtual pixels.
TextStyle menuTextStyle(double unit, double size) => TextStyle(
  color: menuTextColour,
  fontFamily: 'monospace',
  fontSize: size * unit,
  decoration: TextDecoration.none,
  shadows: <Shadow>[
    Shadow(blurRadius: 3 * unit),
    Shadow(offset: Offset(unit * 0.6, unit * 0.6)),
  ],
);

const Color menuTextColour = Color(0xffe8dccb);

final class MenuHeading extends StatelessWidget {
  const MenuHeading({required this.text, required this.unit, super.key});

  final String text;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: menuTextStyle(
        unit,
        11,
      ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5 * unit),
    );
  }
}

/// Dark plate with a blood-red rim and a couple of drips, like the in-game
/// buttons and dialogue boxes.
final class MenuButton extends StatelessWidget {
  const MenuButton({
    required this.label,
    required this.unit,
    required this.onPressed,
    this.compact = false,
    this.warning = false,
    this.width,
    this.semanticsLabel,
    super.key,
  });

  final String label;

  /// What a screen reader says for it, when [label] is too short to.
  final String? semanticsLabel;
  final double unit;
  final VoidCallback? onPressed;
  final bool compact;
  final bool warning;

  /// In virtual pixels; by default as wide as the main buttons.
  final double? width;

  /// Every full-width button, narrow enough to leave the menu art visible
  /// on both sides and as wide as a pair of [halfWidth] buttons, so their
  /// edges line up.
  static const double fullWidth = halfWidth * 2 + pairGap;
  static const double halfWidth = 84;
  static const double pairGap = 4;

  /// What the blood on the rim is drawn from: the key when there is one,
  /// so a switch keeps its stains when its label changes, else the label.
  String get _bloodName => key?.toString() ?? label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final rim = warning ? BloodColors.bright : BloodColors.fresh;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel ?? label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed == null
            ? null
            : () {
                AudioScope.of(context).play(Sfx.uiClick);
                onPressed!();
              },
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: BloodOverlay(
            painter: BloodPainter(
              band: 2.5 * unit,
              cornerRadius: 4 * unit,
              drips: rimDrips(_bloodName, unit),
              bandVariant: stableSeed(_bloodName) % 6,
              color: rim,
            ),
            child: Container(
              width: (width ?? fullWidth) * unit,
              padding: EdgeInsets.symmetric(
                horizontal: 8 * unit,
                vertical: (compact ? 4 : 6) * unit,
              ),
              decoration: BoxDecoration(
                color: warning
                    ? const Color(0xee3a0c0c)
                    : const Color(0xe6140c0c),
                border: Border.all(color: rim, width: 1.5 * unit),
                borderRadius: BorderRadius.circular(4 * unit),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xffe8dccb),
                  fontFamily: 'monospace',
                  fontSize: (compact ? 7.5 : 11) * unit,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  letterSpacing: (compact ? 0.4 : 1.5) * unit,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who made the music and the sounds, as their licences ask.
final class _Credits extends StatelessWidget {
  const _Credits({required this.unit});

  final double unit;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: const Color(0xffe8dccb),
      fontFamily: 'monospace',
      fontSize: 6.5 * unit,
      height: 1.35,
      decoration: TextDecoration.none,
    );
    return Padding(
      key: const ValueKey<String>('menu-credits-page'),
      padding: EdgeInsets.symmetric(vertical: 3 * unit),
      child: Column(
        children: <Widget>[
          Text(
            strings.creditsMusic,
            style: style.copyWith(fontWeight: FontWeight.bold),
          ),
          for (final credit in musicCredits)
            Text(
              '"${credit.title}" - ${credit.author} - '
              '${credit.licence ?? strings.creditsAttribution}',
              textAlign: TextAlign.center,
              style: style,
            ),
          SizedBox(height: 3 * unit),
          Text(effectsCredit, textAlign: TextAlign.center, style: style),
        ],
      ),
    );
  }
}

/// A column of [MenuButton]s over the game: the camp menu and the menu
/// opened mid-game. [trailing] sits further down, apart from the rest,
/// because the way back to the game is not one of the choices; [leading]
/// sits apart above them in the same way (the settings, which change
/// nothing in the game).
final class MenuColumn extends StatelessWidget {
  const MenuColumn({
    required this.unit,
    required this.children,
    this.leading,
    this.trailing,
    super.key,
  });

  final double unit;
  final List<Widget> children;

  final Widget? leading;
  final Widget? trailing;

  /// The gap between two choices, and the wider one that sets [trailing]
  /// apart.
  static const double gap = 2.5;
  static const double trailingGap = 9;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leading case final leading?)
          Padding(
            padding: EdgeInsets.only(
              top: gap * unit,
              bottom: trailingGap * unit,
            ),
            child: leading,
          ),
        for (final child in children)
          Padding(
            padding: EdgeInsets.symmetric(vertical: gap * unit),
            child: child,
          ),
        if (trailing case final trailing?)
          Padding(
            padding: EdgeInsets.only(
              top: trailingGap * unit,
              bottom: gap * unit,
            ),
            child: trailing,
          ),
      ],
    );
  }
}

/// A dark plate with the blood-red rim of the buttons, so text reads over
/// the world behind it.
final class MenuPanel extends StatelessWidget {
  const MenuPanel({
    required this.unit,
    required this.child,
    this.width,
    this.opaque = false,
    super.key,
  });

  final double unit;
  final Widget child;

  /// In virtual pixels; as wide as it can be when null.
  final double? width;

  /// Whether nothing behind shows through it.
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == null ? null : width! * unit,
      padding: EdgeInsets.all(6 * unit),
      decoration: BoxDecoration(
        color: Color(opaque ? 0xff140c0c : 0xe6140c0c),
        border: Border.all(color: BloodColors.fresh, width: 1.5 * unit),
        borderRadius: BorderRadius.circular(4 * unit),
      ),
      child: child,
    );
  }
}

/// Body text on a [MenuPanel].
final class MenuParagraph extends StatelessWidget {
  const MenuParagraph(
    this.text, {
    required this.unit,
    this.center = false,
    super.key,
  });

  final String text;
  final double unit;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: TextStyle(
        color: const Color(0xffe8dccb),
        fontFamily: 'monospace',
        fontSize: 7.5 * unit,
        height: 1.3,
        decoration: TextDecoration.none,
      ),
    );
  }
}

/// The menu's picture over the whole screen, whatever its shape: it is cut
/// at the edges rather than leaving bands beside it.
final class MenuBackdrop extends StatelessWidget {
  const MenuBackdrop({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
    MainMenu.background,
    key: const ValueKey<String>('menu-backdrop'),
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
  );
}
