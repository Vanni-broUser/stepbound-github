/// Sees that the game is written down once for every time the app is
/// away, and that what is written is the game as it was left.
///
/// The write takes a while, and the player may be back before it is done,
/// and away again: a write begun before they came back is of the game as
/// it was then, not as they left it the second time, so it does not count
/// as the game put down. When such a stale write ends with the app away
/// again, a fresh one begins, of the game as it is now.
final class PutDownWriter {
  PutDownWriter(this._write);

  /// Writes the game down; true once written (see
  /// `AppFlowController.suspend`).
  final Future<bool> Function() _write;

  bool _inFront = true;

  /// Bumped every time the app comes back to the front: a write begun
  /// under an earlier value is of a game the player has played since.
  int _stay = 0;
  bool _putDown = false;
  Future<void>? _writing;
  bool _closed = false;

  /// Whether the game has been written down since the app left the front.
  bool get putDown => _putDown;

  /// Whether a write is under way.
  bool get writing => _writing != null;

  /// The app is in front again: the next time away needs a write of its
  /// own, whatever was written before or is being written now.
  void cameToFront() {
    _inFront = true;
    _stay += 1;
    _putDown = false;
  }

  /// The app has left the front, whatever the step (inactive, hidden,
  /// paused): the game is written down, once, unless it already was or
  /// is being.
  void leftFront() {
    _inFront = false;
    _writeUnlessDone();
  }

  /// No write begins after this.
  void close() => _closed = true;

  void _writeUnlessDone() {
    if (_closed || _putDown || _writing != null) {
      return;
    }
    _writing = _writeOnce(_stay);
  }

  Future<void> _writeOnce(int stay) async {
    final bool written;
    try {
      written = await _write();
    } finally {
      _writing = null;
    }
    if (_closed) {
      return;
    }
    if (stay == _stay) {
      _putDown = written;
      return;
    }
    // The player has been back since this began: what it wrote is old.
    // Away again already, the game is written as it is now.
    if (!_inFront) {
      _writeUnlessDone();
    }
  }
}
