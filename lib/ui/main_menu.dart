import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/blood_decor.dart';

enum _MenuPage { home, newGame, load, credits }

/// The first screen: the Stepbound sign from the title card, then a new
/// game in one of the four slots or a saved game to resume, the sound
/// switch and the credits.
final class MainMenu extends StatefulWidget {
  const MainMenu({
    required this.saves,
    required this.onNewGame,
    required this.onLoad,
    super.key,
  });

  static const String logo = 'assets/story/logo.png';

  /// The city overrun: zombies chasing people through a burning street.
  static const String background = 'assets/story/menu_background.jpg';

  final SaveRepository saves;

  /// Starts the story; the game will save in the given slot.
  final void Function(int slot) onNewGame;
  final void Function(SaveGame save) onLoad;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

final class _MainMenuState extends State<MainMenu> {
  _MenuPage _page = _MenuPage.home;
  List<SaveRead> _slots = List<SaveRead>.filled(
    SaveRepository.slotCount,
    const EmptySave(),
  );

  /// Slot waiting for the "overwrite?" answer.
  int? _confirming;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final slots = await widget.saves.all();
    if (mounted) {
      setState(() => _slots = slots);
    }
  }

  void _open(_MenuPage page) => setState(() {
    _page = page;
    _confirming = null;
  });

  void _toggleAudio() {
    final audio = AudioScope.of(context);
    setState(() => audio.muted = !audio.muted);
  }

  void _pickNewGameSlot(int slot) {
    if (_slots[slot - 1] is LoadedSave && _confirming != slot) {
      setState(() => _confirming = slot);
      return;
    }
    widget.onNewGame(slot);
  }

  static String _date(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.day)}/${two(time.month)}/${time.year} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  /// Hours and minutes played, as the slot shows them.
  static String _played(Duration played) {
    final minutes = (played.inMinutes % 60).toString().padLeft(2, '0');
    return '${played.inHours}h ${minutes}m';
  }

  /// A slot whose save is damaged says so, and cannot be loaded; one whose
  /// save was damaged but had a good one before it shows that one, marked
  /// as the backup it is.
  String _slotLabel(int slot) => switch (_slots[slot - 1]) {
    EmptySave() => 'SLOT $slot\nvuoto',
    DamagedSave() => 'SLOT $slot\ndanneggiato, non si può caricare',
    LoadedSave(:final save, :final fromBackup) =>
      'SLOT $slot  ${_date(save.savedAt)}${fromBackup ? '  (riserva)' : ''}\n'
          '${save.place}  ·  ${_played(save.played)}',
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
            Image.asset(MainMenu.background, fit: BoxFit.cover),
            Padding(
              padding: EdgeInsets.all(8 * unit),
              child: Column(
                children: <Widget>[
                  Image.asset(
                    MainMenu.logo,
                    height:
                        constraints.maxHeight *
                        (_page == _MenuPage.home ? 0.32 : 0.22),
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
          ],
        );
      },
    );
  }

  Widget _buttons(double unit) {
    final hasSaves = _slots.any((slot) => slot is LoadedSave);
    final buttons = switch (_page) {
      _MenuPage.home => <Widget>[
        MenuButton(
          key: const ValueKey<String>('menu-new-game'),
          label: 'NUOVA PARTITA',
          unit: unit,
          onPressed: () => _open(_MenuPage.newGame),
        ),
        MenuButton(
          key: const ValueKey<String>('menu-load'),
          label: 'CARICA PARTITA',
          unit: unit,
          onPressed: hasSaves ? () => _open(_MenuPage.load) : null,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MenuButton(
              key: const ValueKey<String>('menu-audio'),
              label: AudioScope.of(context).muted ? 'AUDIO: NO' : 'AUDIO: SÌ',
              unit: unit,
              compact: true,
              width: MenuButton.halfWidth,
              onPressed: _toggleAudio,
            ),
            SizedBox(width: MenuButton.pairGap * unit),
            MenuButton(
              key: const ValueKey<String>('menu-credits'),
              label: 'CREDITI',
              unit: unit,
              compact: true,
              width: MenuButton.halfWidth,
              onPressed: () => _open(_MenuPage.credits),
            ),
          ],
        ),
      ],
      _MenuPage.credits => <Widget>[
        MenuHeading(text: 'CREDITI', unit: unit),
        _Credits(unit: unit),
        MenuButton(
          key: const ValueKey<String>('menu-back'),
          label: 'INDIETRO',
          unit: unit,
          compact: true,
          onPressed: () => _open(_MenuPage.home),
        ),
      ],
      _MenuPage.newGame || _MenuPage.load => <Widget>[
        MenuHeading(
          text: _page == _MenuPage.newGame
              ? 'SCEGLI DOVE SALVARE'
              : 'SCEGLI UN SALVATAGGIO',
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
          label: 'INDIETRO',
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
        label: 'SOVRASCRIVERE LO SLOT $slot?\nTOCCA ANCORA PER CONFERMARE',
        unit: unit,
        compact: true,
        warning: true,
        onPressed: () => _pickNewGameSlot(slot),
      );
    }
    final save = _slots[slot - 1].game;
    return MenuButton(
      key: ValueKey<String>('menu-slot-$slot'),
      label: _slotLabel(slot),
      unit: unit,
      compact: true,
      onPressed: switch (_page) {
        _MenuPage.newGame => () => _pickNewGameSlot(slot),
        _ when save != null => () => widget.onLoad(save),
        _ => null,
      },
    );
  }
}

final class MenuHeading extends StatelessWidget {
  const MenuHeading({required this.text, required this.unit, super.key});

  final String text;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: BloodColors.bright,
        fontFamily: 'monospace',
        fontSize: 11 * unit,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5 * unit,
        decoration: TextDecoration.none,
      ),
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
    super.key,
  });

  final String label;
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

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final rim = warning ? BloodColors.bright : BloodColors.fresh;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
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
              drips: <BloodDrip>[
                BloodDrip(0.12, 7 * unit, 2.6 * unit),
                BloodDrip(0.83, 10 * unit, 3 * unit),
              ],
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
          Text('MUSICA', style: style.copyWith(color: BloodColors.bright)),
          for (final credit in musicCredits)
            Text(
              '"${credit.title}" - ${credit.author} - ${credit.licence}',
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
/// because the way back to the game is not one of the choices.
final class MenuColumn extends StatelessWidget {
  const MenuColumn({
    required this.unit,
    required this.children,
    this.trailing,
    super.key,
  });

  final double unit;
  final List<Widget> children;
  final Widget? trailing;

  /// The gap between two choices, and the wider one above [trailing].
  static const double gap = 2.5;
  static const double trailingGap = 9;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
    super.key,
  });

  final double unit;
  final Widget child;

  /// In virtual pixels; as wide as it can be when null.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == null ? null : width! * unit,
      padding: EdgeInsets.all(6 * unit),
      decoration: BoxDecoration(
        color: const Color(0xe6140c0c),
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
