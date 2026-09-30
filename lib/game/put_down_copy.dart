import 'package:stepbound/game/game_snapshot.dart';

/// The game as it last was when it could be put down, for when the app
/// leaves at a moment it cannot: in the middle of a story line, a place
/// card or a scene, the copy a few steps back is what gets written. Taken
/// as soon as the game can be put down again, and every [interval]
/// seconds after; dropped once Mario is dead, or a fire's save is newer.
final class PutDownCopy {
  PutDownCopy({this.interval = defaultInterval});

  /// Three seconds: a few steps back at most.
  static const double defaultInterval = 3;

  /// How often, while the game can be put down, the copy is renewed.
  final double interval;

  GameSnapshot? _copy;
  double _since = 0;
  bool _could = false;

  /// The copy kept, if any.
  GameSnapshot? get copy => _copy;

  /// Every frame: renews the copy when the game [canBePutDown], at once
  /// when it has just become so and every [interval] seconds after.
  void keep(
    double dt, {
    required bool canBePutDown,
    required GameSnapshot Function() take,
  }) {
    if (!canBePutDown) {
      _could = false;
      return;
    }
    _since += dt;
    if (!_could || _since >= interval) {
      _copy = take();
      _since = 0;
    }
    _could = true;
  }

  /// What to write when the app leaves: the game as it is when it
  /// [canBePutDown], or else the copy; null with neither.
  GameSnapshot? snapshot({
    required bool canBePutDown,
    required GameSnapshot Function() take,
  }) => canBePutDown ? take() : _copy;

  /// A save of the slot's own has been made: whatever was copied before it
  /// is older, and is never written over it.
  void drop() => _copy = null;
}
