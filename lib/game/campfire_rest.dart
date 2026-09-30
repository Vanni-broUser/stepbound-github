import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/cover_controller.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/report/breadcrumbs.dart';

/// Mario's rest at a campfire, or his bite at the table aboard: he kneels
/// (or sits) for a moment, then the game is saved and a line says whether
/// it worked. He gets up once the line is gone either way; a failed save is
/// tried again by resting at the fire again. While it lasts nothing else
/// can happen to him.
final class CampfireRest {
  CampfireRest({
    required this.progress,
    required this.covers,
    required this.checkpoint,
    required this.onKneel,
    required this.placeName,
    Breadcrumbs? trail,
  }) : trail = trail ?? Breadcrumbs.shared;

  static String get savedLine => strings.saved;
  static String get saveFailedLine => strings.campfireSaveFailed;
  static String get mealSaveFailedLine => strings.mealSaveFailed;

  /// The fires lit are remembered here.
  final Progress progress;

  /// Where the line about the save goes up.
  final CoverController covers;

  /// Saves the game as it is at [String], the fire's name; completes with
  /// whether it was written, null when there is nowhere to save to.
  final Future<bool>? Function(String place) checkpoint;

  /// Mario kneels by the fire at [GridPoint], which roars up.
  final void Function(GridPoint campfire) onKneel;

  /// Where Mario is, for the trail.
  final String Function() placeName;
  final Breadcrumbs trail;

  GridPoint? _campfire;
  double _left = 0;
  bool _saving = false;

  /// Whether Mario is at a fire, kneeling or reading the line about the
  /// save.
  bool get resting => _campfire != null;

  /// Whether the rest is a bite at the train's table.
  bool get atTable => trainFoodTiles.contains(_campfire);

  /// Mario has used the fire at [campfire]: lit, if it has a name and is
  /// not the table, and the rest begins.
  void restAt(GridPoint campfire) {
    _campfire = campfire;
    if (campfireNames[campfire] case final name?
        when !trainFoodTiles.contains(campfire)) {
      progress.lightCampfire(name);
    }
    _left = CharacterComponent.restDuration;
    _saving = false;
    if (!atTable) {
      onKneel(campfire);
    }
  }

  /// Every frame: once the moment is over, the game is saved.
  void update(double dt) {
    if (_campfire == null || _saving) {
      return;
    }
    _left -= dt;
    if (_left <= 0) {
      _saving = true;
      unawaited(_save());
    }
  }

  Future<void> _save() async {
    var saved = true;
    try {
      saved = await checkpoint(campfireNames[_campfire] ?? '') ?? true;
    } on Object catch (error) {
      debugPrint('save: $error');
      saved = false;
    }
    if (saved) {
      covers.showPrompt(<StoryLine>[
        StoryLine(savedLine),
      ], onDismissed: () => _campfire = null);
      return;
    }
    trail.add('salvataggio non riuscito: ${placeName()}');
    covers.showSaveFailed(
      atTable ? mealSaveFailedLine : saveFailedLine,
      onDismissed: () => _campfire = null,
    );
  }
}
