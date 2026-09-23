import 'dart:async';

import 'package:flutter/services.dart';
import 'package:stepbound/core/core.dart';

enum HapticCue { playerHurt, hitLanded, emptyMagazine }

typedef HapticSink = void Function(HapticCue cue);

void _playSystemHaptic(HapticCue cue) {
  unawaited(_playSystemPattern(cue));
}

Future<void> _playSystemPattern(HapticCue cue) async {
  switch (cue) {
    case HapticCue.playerHurt:
      await HapticFeedback.vibrate();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.heavyImpact();
    case HapticCue.hitLanded:
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.mediumImpact();
    case HapticCue.emptyMagazine:
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 45));
      await HapticFeedback.selectionClick();
  }
}

/// Turns resolved combat events into tactile feedback. Unsupported platforms
/// simply ignore Flutter's system haptic calls.
final class GameplayHaptics {
  const GameplayHaptics({this.sink = _playSystemHaptic});

  final HapticSink sink;

  void onEvents(Iterable<WorldEvent> events, {required String playerId}) {
    for (final event in events) {
      switch (event) {
        case DamagedEvent(entityId: final target) when target == playerId:
          sink(HapticCue.playerHurt);
        case ShotEvent(entityId: final shooter, :final hitEntityId)
            when shooter == playerId && hitEntityId != null:
          sink(HapticCue.hitLanded);
        case DryFiredEvent(entityId: final shooter) when shooter == playerId:
          sink(HapticCue.emptyMagazine);
        case _:
          break;
      }
    }
  }
}
