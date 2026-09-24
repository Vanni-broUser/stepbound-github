import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/main_menu.dart';

enum _PausePage { home, resume, restart, quit }

/// Where the save the game can go back to was made, and how the menus
/// name it.
enum ResumePoint {
  /// Resting at a campfire.
  campfire(
    resumeLabel: 'RIPRENDI DAL FALÒ',
    confirmLabel: 'SÌ, TORNA AL FALÒ',
    goBack: 'Tornare all’ultimo falò?',
    since: 'dall’ultimo falò',
    savedHere: 'Il falò dove hai salvato',
  ),

  /// Aboard the train, at the end of the level.
  train(
    resumeLabel: 'RIPRENDI DAL TRENO',
    confirmLabel: 'SÌ, TORNA AL TRENO',
    goBack: 'Tornare al treno?',
    since: 'dal treno',
    savedHere: 'Il salvataggio sul treno',
  );

  const ResumePoint({
    required this.resumeLabel,
    required this.confirmLabel,
    required this.goBack,
    required this.since,
    required this.savedHere,
  });

  final String resumeLabel;
  final String confirmLabel;
  final String goBack;

  /// Ends "what you have done ...".
  final String since;

  /// Starts "... is lost".
  final String savedHere;
}

/// Opened by the button in the corner, over the game: back to the last
/// save, the level from the start, or out to the main menu. Every one
/// of them throws away something the player has done, so every one of them
/// asks first and says what it costs.
final class PauseMenu extends StatefulWidget {
  const PauseMenu({
    required this.resumePoint,
    required this.onResumeFromCamp,
    required this.onRestartLevel,
    required this.onMainMenu,
    required this.onClose,
    super.key,
  });

  /// Where the slot's save to go back to was made, a campfire or the
  /// train. Without one there is nothing to resume, so that choice is not
  /// offered.
  final ResumePoint? resumePoint;
  final VoidCallback onResumeFromCamp;
  final VoidCallback onRestartLevel;
  final VoidCallback onMainMenu;
  final VoidCallback onClose;

  @override
  State<PauseMenu> createState() => _PauseMenuState();
}

final class _PauseMenuState extends State<PauseMenu> {
  _PausePage _page = _PausePage.home;

  void _open(_PausePage page) => setState(() => _page = page);

  /// What the player is about to lose, said plainly.
  String get _cost => switch (_page) {
    _PausePage.resume =>
      '${widget.resumePoint?.goBack} Quello che hai fatto da lì in '
          'poi va perso.',
    _PausePage.restart =>
      'Ricominciare il livello? Si riparte dalla prima scena della storia: '
          'proiettili, zombi conosciuti e ricordi si azzerano, e lo slot '
          'viene salvato all’inizio del livello. Restano solo le ore '
          'di gioco.',
    _PausePage.quit when widget.resumePoint != null =>
      'Uscire al menù principale? Quello che hai fatto '
          '${widget.resumePoint?.since} va perso.',
    _PausePage.quit =>
      'Uscire al menù principale? Questa partita non è mai stata '
          'salvata: esci e la perdi tutta.',
    _PausePage.home => '',
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1.0;
        // No backdrop: the world stays in view behind it.
        return Padding(
          key: const ValueKey<String>('pause-menu'),
          padding: EdgeInsets.all(8 * unit),
          child: Center(
            child: SingleChildScrollView(
              child: _page == _PausePage.home ? _choices(unit) : _confirm(unit),
            ),
          ),
        );
      },
    );
  }

  Widget _choices(double unit) => MenuColumn(
    unit: unit,
    // Apart from the three: going back to the game costs nothing.
    trailing: MenuButton(
      key: const ValueKey<String>('pause-close'),
      label: 'TORNA AL GIOCO',
      unit: unit,
      compact: true,
      onPressed: widget.onClose,
    ),
    children: <Widget>[
      if (widget.resumePoint case final point?)
        MenuButton(
          key: const ValueKey<String>('pause-resume'),
          label: point.resumeLabel,
          unit: unit,
          compact: true,
          onPressed: () => _open(_PausePage.resume),
        ),
      MenuButton(
        key: const ValueKey<String>('pause-restart'),
        label: 'RICOMINCIA IL LIVELLO',
        unit: unit,
        compact: true,
        onPressed: () => _open(_PausePage.restart),
      ),
      MenuButton(
        key: const ValueKey<String>('pause-quit'),
        label: 'VAI AL MENÙ PRINCIPALE',
        unit: unit,
        compact: true,
        onPressed: () => _open(_PausePage.quit),
      ),
    ],
  );

  Widget _confirm(double unit) {
    final (String label, VoidCallback act) = switch (_page) {
      _PausePage.resume => (
        widget.resumePoint?.confirmLabel ?? '',
        widget.onResumeFromCamp,
      ),
      _PausePage.restart => ('SÌ, RICOMINCIA', widget.onRestartLevel),
      _PausePage.quit => ('SÌ, ESCI', widget.onMainMenu),
      _PausePage.home => ('', widget.onClose),
    };
    return MenuColumn(
      unit: unit,
      children: <Widget>[
        MenuPanel(
          unit: unit,
          width: MenuButton.fullWidth,
          child: MenuParagraph(
            _cost,
            key: const ValueKey<String>('pause-cost'),
            unit: unit,
            center: true,
          ),
        ),
        MenuButton(
          key: const ValueKey<String>('pause-confirm'),
          label: label,
          unit: unit,
          compact: true,
          warning: true,
          onPressed: act,
        ),
        MenuButton(
          key: const ValueKey<String>('pause-back'),
          label: 'NO',
          unit: unit,
          compact: true,
          onPressed: () => _open(_PausePage.home),
        ),
      ],
    );
  }
}
