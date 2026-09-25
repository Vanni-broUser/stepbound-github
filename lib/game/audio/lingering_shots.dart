import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stepbound/game/audio/sound.dart';

/// Cuts short one playing copy of an effect.
typedef StopShot = Future<void> Function();

/// Every copy of a long effect ([Sfx.lingers]) that has been asked to play
/// and not stopped yet, including the ones still starting.
///
/// Starting one takes a while (the first time, its file is loaded), and
/// keeping only the last copy's stop function lost track of the others: a
/// stop that came in before the copy had started found nothing, so the game
/// over sting played its half minute over the game resumed at the fire,
/// and a second game over in that half minute took its place, after which
/// nothing could stop the first one, not even the app going to the
/// background. Here a copy stopped while it is starting is cut the moment
/// it has started, and a new copy of the same effect cuts the older ones.
final class LingeringShots {
  final Map<Sfx, List<_Shot>> _shots = <Sfx, List<_Shot>>{};

  /// [starting] completes with the way to stop the copy just started.
  void add(Sfx sfx, Future<StopShot> starting) {
    stop(sfx);
    final shot = _Shot();
    _shots.putIfAbsent(sfx, () => <_Shot>[]).add(shot);
    unawaited(
      starting.then(
        shot.started,
        onError: (Object error) {
          debugPrint('audio: $error');
        },
      ),
    );
  }

  /// Cuts every copy of [sfx], the playing ones and the starting ones.
  void stop(Sfx sfx) {
    for (final shot in _shots.remove(sfx) ?? const <_Shot>[]) {
      shot.cancel();
    }
  }

  /// Cuts every copy of every effect: the app is going to the background,
  /// and a one-shot has nothing to come back to.
  void stopAll() {
    _shots.keys.toList().forEach(stop);
  }

  /// How many copies are playing or starting, for tests.
  @visibleForTesting
  int get length =>
      _shots.values.fold(0, (count, shots) => count + shots.length);
}

final class _Shot {
  StopShot? _stop;
  bool _cancelled = false;

  void started(StopShot stop) {
    if (_cancelled) {
      _run(stop);
    } else {
      _stop = stop;
    }
  }

  void cancel() {
    _cancelled = true;
    final stop = _stop;
    _stop = null;
    if (stop != null) {
      _run(stop);
    }
  }

  static void _run(StopShot stop) {
    unawaited(
      stop().catchError((Object error) {
        debugPrint('audio: $error');
      }),
    );
  }
}
