import 'package:flutter/material.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';

enum _PausePage { home, outfits, resume, restart, quit }

/// How many places the outfit page has: the outfits still to come stay
/// "???", as the zombie book's cards do.
const int outfitSlots = 12;

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

/// Opened by the button in the corner, over the game: change Mario's clothes,
/// go back to the last save, restart the level or leave for the main menu.
/// Every choice that discards progress asks first and says what it costs.
final class PauseMenu extends StatefulWidget {
  const PauseMenu({
    required this.progress,
    required this.resumePoint,
    required this.onResumeFromCamp,
    required this.onRestartLevel,
    required this.onMainMenu,
    required this.onClose,
    required this.onWearOutfit,
    super.key,
  });

  final Progress progress;

  /// Where the slot's save to go back to was made, a campfire or the
  /// train. Without one there is nothing to resume, so that choice is not
  /// offered.
  final ResumePoint? resumePoint;
  final VoidCallback onResumeFromCamp;
  final VoidCallback onRestartLevel;
  final VoidCallback onMainMenu;
  final VoidCallback onClose;
  final ValueChanged<PlayerOutfit> onWearOutfit;

  @override
  State<PauseMenu> createState() => _PauseMenuState();
}

final class _PauseMenuState extends State<PauseMenu> {
  _PausePage _page = _PausePage.home;
  int _selectedOutfit = 0;

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
    _PausePage.home || _PausePage.outfits => '',
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
          child: _page == _PausePage.outfits
              ? _outfits(unit)
              : Center(
                  child: SingleChildScrollView(
                    child: _page == _PausePage.home
                        ? _choices(unit)
                        : _confirm(unit),
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
      // Offered once there is something besides the base clothes to wear.
      if (widget.progress.unlockedOutfits.length > 1)
        MenuButton(
          key: const ValueKey<String>('pause-outfits'),
          label: 'CAMBIA ABBIGLIAMENTO',
          unit: unit,
          compact: true,
          onPressed: () => _open(_PausePage.outfits),
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
      _PausePage.home || _PausePage.outfits => ('', widget.onClose),
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

  /// The outfit in [slot], null for the places still to come.
  static PlayerOutfit? _outfitAt(int slot) =>
      slot < PlayerOutfit.values.length ? PlayerOutfit.values[slot] : null;

  bool _unlocked(PlayerOutfit? outfit) =>
      outfit != null && widget.progress.unlockedOutfits.contains(outfit);

  /// The same catalogue layout as the known-zombie page: choices on the
  /// left, portrait on the right and a wear button in place of a description.
  /// Outfits not found yet are "???" and a black shape.
  Widget _outfits(double unit) {
    final outfit = _outfitAt(_selectedOutfit);
    final unlocked = _unlocked(outfit);
    final active = widget.progress.activeOutfit == outfit;
    final buttonLabel = active
        ? 'GIÀ IN USO'
        : unlocked
        ? 'INDOSSA'
        : 'NON DISPONIBILE';
    return Column(
      key: const ValueKey<String>('pause-outfit-page'),
      children: <Widget>[
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 96 * unit,
                child: ListView.builder(
                  itemCount: outfitSlots,
                  itemBuilder: (context, index) {
                    final entry = _outfitAt(index);
                    return Padding(
                      padding: EdgeInsets.only(bottom: 3 * unit),
                      child: MenuButton(
                        key: ValueKey<String>('pause-outfit-$index'),
                        label: _unlocked(entry)
                            ? entry!.label.toUpperCase()
                            : '???',
                        unit: unit,
                        compact: true,
                        warning: index == _selectedOutfit,
                        width: 90,
                        onPressed: () =>
                            setState(() => _selectedOutfit = index),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 8 * unit),
              Expanded(
                child: MenuPanel(
                  unit: unit,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: unlocked
                            ? Image.asset(
                                outfit!.portrait,
                                key: ValueKey<String>(
                                  'pause-outfit-portrait-$_selectedOutfit',
                                ),
                                fit: BoxFit.contain,
                              )
                            // Not found yet: just a black shape.
                            : ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Color(0xff050303),
                                  BlendMode.srcIn,
                                ),
                                child: Image.asset(
                                  PlayerOutfit.base.portrait,
                                  fit: BoxFit.contain,
                                ),
                              ),
                      ),
                      SizedBox(height: 4 * unit),
                      Text(
                        unlocked ? outfit!.label.toUpperCase() : '???',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: BloodColors.bright,
                          fontFamily: 'monospace',
                          fontSize: 9 * unit,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 4 * unit),
                      Center(
                        child: MenuButton(
                          key: const ValueKey<String>('pause-outfit-wear'),
                          label: buttonLabel,
                          unit: unit,
                          compact: true,
                          width: 100,
                          onPressed: !unlocked || active
                              ? null
                              : () {
                                  widget.onWearOutfit(outfit!);
                                  setState(() {});
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4 * unit),
        Align(
          alignment: Alignment.centerLeft,
          child: MenuButton(
            key: const ValueKey<String>('pause-outfit-back'),
            label: 'INDIETRO',
            unit: unit,
            compact: true,
            onPressed: () => _open(_PausePage.home),
          ),
        ),
      ],
    );
  }
}
