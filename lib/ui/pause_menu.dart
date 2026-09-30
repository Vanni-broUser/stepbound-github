import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/ui/letterbox.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/portrait_image.dart';

enum _PausePage { home, outfits, resume, restart, quit }

/// How many places the outfit page has: the outfits still to come stay
/// "???", as the zombie book's cards do.
const int outfitSlots = 12;

/// Where the save the game can go back to was made, and how the menus
/// name it.
enum ResumePoint {
  /// Resting at a campfire.
  campfire,

  /// Aboard the train, at the end of the level.
  train;

  String get resumeLabel => switch (this) {
    campfire => strings.resumeCampfire,
    train => strings.resumeTrain,
  };

  String get confirmLabel => switch (this) {
    campfire => strings.resumeCampfireConfirm,
    train => strings.resumeTrainConfirm,
  };

  /// What going back to it costs, said plainly.
  String get cost => switch (this) {
    campfire => strings.resumeCampfireCost,
    train => strings.resumeTrainCost,
  };

  /// Why leaving for the main menu costs what has been done since.
  String get quitCost => switch (this) {
    campfire => strings.quitSinceCampfireCost,
    train => strings.quitSinceTrainCost,
  };

  /// What restarting the level from the first story scene (Molfetta),
  /// or else from the arrival in town, loses of this save.
  String restartCost({required bool fromStory}) => switch (this) {
    campfire => strings.gameOverRestartCampfireCost(fromStory: fromStory),
    train => strings.gameOverRestartTrainCost(fromStory: fromStory),
  };
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
    this.onShareReport,
    this.restartsFromStory = true,
    this.wardrobe = false,
    super.key,
  });

  /// Opened from the wardrobe aboard: only the page of outfits, and its
  /// back button goes straight back to the game.
  final bool wardrobe;

  /// Shares a report of the game as it is, trail and all, for the bugs
  /// that throw nothing; the button is not there when the app cannot
  /// share.
  final VoidCallback? onShareReport;

  static String get shareLabel => strings.shareReport;

  final Progress progress;

  /// Where the slot's save to go back to was made, a campfire or the
  /// train. Without one there is nothing to resume, so that choice is not
  /// offered.
  final ResumePoint? resumePoint;
  final VoidCallback onResumeFromCamp;

  /// Whether the level starts over from the first story scene (Molfetta),
  /// or from where Mario arrived in it.
  final bool restartsFromStory;
  final VoidCallback onRestartLevel;
  final VoidCallback onMainMenu;
  final VoidCallback onClose;
  final ValueChanged<PlayerOutfit> onWearOutfit;

  @override
  State<PauseMenu> createState() => _PauseMenuState();
}

final class _PauseMenuState extends State<PauseMenu> {
  late _PausePage _page = widget.wardrobe
      ? _PausePage.outfits
      : _PausePage.home;

  /// Opens on what Mario is wearing: a gift can come before it.
  late int _selectedOutfit = widget.progress.unlockedOutfits.toList().indexOf(
    widget.progress.activeOutfit,
  );

  void _open(_PausePage page) => setState(() => _page = page);

  /// What the player is about to lose, said plainly.
  String get _cost => switch (_page) {
    _PausePage.resume => widget.resumePoint?.cost ?? '',
    _PausePage.restart when !widget.restartsFromStory =>
      strings.pauseRestartFromArrivalCost,
    _PausePage.restart => strings.pauseRestartFromStoryCost,
    _PausePage.quit => widget.resumePoint?.quitCost ?? strings.quitUnsavedCost,
    _PausePage.home || _PausePage.outfits => '',
  };

  /// On the 16:9 picture over the whole screen. The choices leave the
  /// world in view as it is; the clothes dim it with the veil of the other
  /// things looked at over the game, wherever they are changed.
  @override
  Widget build(BuildContext context) {
    return Letterbox(
      color: _page == _PausePage.outfits
          ? Letterbox.veil
          : const Color(0x00000000),
      child: _picture(),
    );
  }

  Widget _picture() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1.0;
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
      label: strings.pauseBackToGame,
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
        label: strings.restartLevel,
        unit: unit,
        compact: true,
        onPressed: () => _open(_PausePage.restart),
      ),
      MenuButton(
        key: const ValueKey<String>('pause-quit'),
        label: strings.pauseToMainMenu,
        unit: unit,
        compact: true,
        onPressed: () => _open(_PausePage.quit),
      ),
      if (widget.onShareReport case final share?)
        MenuButton(
          key: const ValueKey<String>('pause-share'),
          label: PauseMenu.shareLabel,
          unit: unit,
          compact: true,
          onPressed: share,
        ),
    ],
  );

  Widget _confirm(double unit) {
    final (String label, VoidCallback act) = switch (_page) {
      _PausePage.resume => (
        widget.resumePoint?.confirmLabel ?? '',
        widget.onResumeFromCamp,
      ),
      _PausePage.restart => (strings.yesRestart, widget.onRestartLevel),
      _PausePage.quit => (strings.pauseYesQuit, widget.onMainMenu),
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
          label: strings.no,
          unit: unit,
          compact: true,
          onPressed: () => _open(_PausePage.home),
        ),
      ],
    );
  }

  /// The outfit in [slot], null for the places still to come: first the
  /// ones Mario has, in the order they became his, then the rest, all
  /// alike whether the game has them or not yet.
  PlayerOutfit? _outfitAt(int slot) {
    final owned = widget.progress.unlockedOutfits;
    return slot < owned.length ? owned.elementAt(slot) : null;
  }

  bool _unlocked(PlayerOutfit? outfit) =>
      outfit != null && widget.progress.unlockedOutfits.contains(outfit);

  /// The same catalogue layout as the known-zombie page: choices on the
  /// left, portrait on the right and a wear button in place of a description.
  /// Outfits not found yet are "???" and the black shape of the base
  /// clothes, whichever they are.
  Widget _outfits(double unit) {
    final outfit = _outfitAt(_selectedOutfit);
    final unlocked = _unlocked(outfit);
    final active = widget.progress.activeOutfit == outfit;
    final buttonLabel = active
        ? strings.outfitWorn
        : unlocked
        ? strings.outfitWear
        : strings.outfitLocked;
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
                  itemCount: math.max(outfitSlots, PlayerOutfit.values.length),
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
                            ? PortraitImage(
                                outfit!.portrait,
                                key: ValueKey<String>(
                                  'pause-outfit-portrait-$_selectedOutfit',
                                ),
                              )
                            // Not found yet: just a black shape.
                            : ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Color(0xff050303),
                                  BlendMode.srcIn,
                                ),
                                child: PortraitImage(
                                  PlayerOutfit.base.portrait,
                                ),
                              ),
                      ),
                      SizedBox(height: 4 * unit),
                      Text(
                        unlocked ? outfit!.label.toUpperCase() : '???',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: menuTextColour,
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
            label: strings.back,
            unit: unit,
            compact: true,
            onPressed: widget.onClose,
          ),
        ),
      ],
    );
  }
}
